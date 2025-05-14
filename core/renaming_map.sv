// Renaming map module
// While you are free to structure your implementation however you
// like, you are advised to only add code to the TODO sections
module renaming_map import ariane_pkg::*; #(
    parameter int unsigned ARCH_REG_WIDTH = 5,
    parameter int unsigned PHYS_REG_WIDTH = 6
)(
    // Clock and reset signals
    input logic clk_i,
    input logic rst_ni,

    // Indicator that there is a new instruction to rename
    input logic fetch_entry_ready_i,

    // Input decoded instruction entry from the ID stage
    input issue_struct_t issue_n,

    // Output instruction entry with registers renamed
    output issue_struct_t issue_q,

    // Destination register of the committing instruction
    input logic [PHYS_REG_WIDTH-1:0] waddr_i,
    
    // Indicator signal that there is a new committing instruction
    input logic we_gp_i
);

    // 32 architectural registers and 64 physical registers
    localparam ARCH_NUM_REGS = 2**ARCH_REG_WIDTH;
    localparam PHYS_NUM_REGS = 2**PHYS_REG_WIDTH;

    logic [PHYS_REG_WIDTH-1:0] rs1;
    logic [PHYS_REG_WIDTH-1:0] rs2;
    logic [PHYS_REG_WIDTH-1:0] rd;

    // TODO: ADD STRUCTURES TO EXECUTE REGISTER RENAMING
    logic [PHYS_REG_WIDTH-1:0] remap [0:ARCH_NUM_REGS-1];
    logic map_valid [0:ARCH_NUM_REGS-1];
    
    parameter FREE_DEPTH = PHYS_NUM_REGS - 1;
    logic [PHYS_REG_WIDTH-1:0] free_list [0:FREE_DEPTH-1];
    logic [$clog2(FREE_DEPTH+1)-1:0] free_list_head, free_list_tail;
    logic free_empty, free_full;

    logic [PHYS_REG_WIDTH-1:0] dealloc_map [0:PHYS_NUM_REGS-1];


    // Positive clock edge used for renaming new instructions
    always @(posedge clk_i, negedge rst_ni) begin
        // Processor reset: revert renaming state to reset conditions    
        if (~rst_ni) begin

            // TODO: ADD LOGIC TO RESET RENAMING STATE
            // all elements are initially invalid
            issue_q      <= '{default:'0};
            for (int i = 0; i < ARCH_NUM_REGS; i++) begin
                remap[i] <= 0;
                map_valid[i] <= 0;
            end
            map_valid[0] <= 1;
            remap[0] <= 0;
            // free list has pr1 to pr63
            for (int i = 0; i < FREE_DEPTH; i++) begin
                free_list[i] <= i+1;
            end
            free_list_head <= 0;
            free_list_tail <= FREE_DEPTH-1;
            free_empty <= 0;
            free_full <= 1;
            // dealloc_map is empty
            for (int i = 0; i < PHYS_NUM_REGS; i++) begin
                dealloc_map[i] <= 0;
            end
    
        // New incoming valid instruction to rename   
        end else if (fetch_entry_ready_i && issue_n.valid) begin
            // Get values of registers in new instruction
            rs1 = issue_n.sbe.rs1[PHYS_REG_WIDTH-1:0];
            rs2 = issue_n.sbe.rs2[PHYS_REG_WIDTH-1:0];
            rd = issue_n.sbe.rd[PHYS_REG_WIDTH-1:0];

            // Set outgoing instruction to incoming instruction without
            // renaming by default. Keep this line since all fields of the 
            // incoming issue_struct_t should carry over to the output
            // except for the register values, which you may rename below
            issue_q = issue_n;

            // TODO: ADD LOGIC TO RENAME OUTGOING INSTRUCTION
            // The registers of the outgoing instruction issue_q can be set like so:
            // issue_q.sbe.rs1[PHYS_REG_WIDTH-1:0] = your new rs1 register value;
            // issue_q.sbe.rs2[PHYS_REG_WIDTH-1:0] = your new rs2 register value;
            // issue_q.sbe.rd[PHYS_REG_WIDTH-1:0] = your new rd register value;
            issue_q.sbe.rs1[PHYS_REG_WIDTH-1:0] <=
            (rs1 == 0)                                ? '0
            : (map_valid[rs1] ? remap[rs1] : '0); 
            issue_q.sbe.rs2[PHYS_REG_WIDTH-1:0] <=
            (rs2 == 0)                                ? '0
            : (map_valid[rs2] ? remap[rs2] : '0);
            if (rd != 0 && !free_empty) begin
                logic [PHYS_REG_WIDTH-1:0] new_pr;
                logic [$clog2(FREE_DEPTH+1)-1:0] next_head;
                new_pr = free_list[free_list_head];
                next_head = (free_list_head == FREE_DEPTH-1)
                      ? '0
                      : free_list_head + 1;
                // update the free-list pointers & flags
                free_list_head <= next_head;
                free_empty     <= (next_head == free_list_tail);
                free_full      <= 1'b0;           

                dealloc_map[new_pr] <= map_valid[rd] ? remap[rd] : '0;
                // install the new mapping
                remap[rd]     <= new_pr;
                map_valid[rd] <= 1'b1;
                issue_q.sbe.rd <= new_pr;
            end
    
        // If there is no new instruction this clock cycle, simply pass on the
        // incoming instruction without renaming
        end else begin
            issue_q = issue_n;
        end
    end
    

    // Negative clock edge used for physical register deallocation 
    always @(negedge clk_i) begin
        if (rst_ni) begin
            // If there is a new committing instruction and its prd is not pr0,
            // execute register deallocation logic to reuse physical registers
            if (we_gp_i && waddr_i != 0) begin
        
                // TODO: IMPLEMENT REGISTER DEALLOCATION LOGIC
                logic [PHYS_REG_WIDTH-1:0]        pr_to_free;      
                logic [$clog2(FREE_DEPTH+1)-1:0]  new_head;
                
                pr_to_free = dealloc_map[waddr_i];
                if (pr_to_free != '0 && !free_full) begin
                    // LIFO push
                    new_head = (free_list_head == 0)
                        ? FREE_DEPTH-1
                        : free_list_head - 1;
                    free_list_head <= new_head;
                    free_list[new_head] <= pr_to_free;
                    dealloc_map[waddr_i] <= '0;
                end
            end
        end
    end
endmodule
