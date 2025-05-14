// ***************************************************************************
// Testbench: LIFO Reuse Verification
// Input sequence:
//   Cycle 0:  I0:  LI   ar4,   0xa    (VALID)  Commit: none
//   Cycle 1:                   (VALID)  Commit: I0
//   Cycle 2:  I1:  LI   ar5,   0xb    (VALID)  Commit: none
//   Cycle 3:                   (VALID)  Commit: I1
//   Cycle 4:  I2:  ADD  ar3, ar4, ar5 (VALID)  Commit: none
//   Cycle 5:                   (VALID)  Commit: I2
//   Cycle 6:  I3:  ADD  ar3, ar4, ar5 (VALID)  Commit: none
//   Cycle 7:                   (VALID)  Commit: I3
//   Cycle 8:  I4:  ADD  ar3, ar4, ar5 (VALID)  Commit: none
//   Cycle 9:                   (VALID)  Commit: I4
//
// Expected issue_q.sbe.rd values (with dealloc → LIFO reuse):
//   I0 → pr1
//   I1 → pr2
//   I2 → pr3
//   I3 → pr4
//   I4 → pr3   ← recycled immediately after I3’s retire
/*
I0: rd 1  rs1 x  rs2 x
I1: rd 2  rs1 x  rs2 x
I2: rd 3  rs1 1  rs2 2
I3: rd 4  rs1 1  rs2 2
I4: rd 3  rs1 1  rs2 2
*/
// ***************************************************************************
module lifo_reuse_tb import ariane_pkg::*; #(
    parameter int unsigned ARCH_REG_WIDTH = 5,
    parameter int unsigned PHYS_REG_WIDTH = 6
);
    // Clock, reset, and rename‐unit I/O
    reg                                clk_i;
    reg                                rst_ni;
    logic                              fetch_entry_ready_i;
    issue_struct_t                     issue_n;
    issue_struct_t                     issue_q;
    logic [PHYS_REG_WIDTH-1:0]         waddr_i;
    logic                              we_gp_i;

    // Clock generator: 20 ns period
    initial begin
        clk_i = 1'b0;
        forever #10 clk_i = ~clk_i;
    end

    // Stimulus & checks
    initial begin
        // ----- reset sequence -----
        rst_ni               = 1'b1;
        fetch_entry_ready_i  = 1'b0;
        issue_n.valid        = 1'b0;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #10;
        rst_ni = 1'b0;
        #10;
        rst_ni = 1'b1;
        // now at t=20ns, Cycle 0 begins

        // ---- I0: LI ar4 ----
        issue_n.valid        = 1'b1;
        issue_n.sbe.rd       = 4;    // ar4→pr1
        issue_n.sbe.rs1      = 'x;
        issue_n.sbe.rs2      = 'x;
        fetch_entry_ready_i  = 1'b1;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #20;  // now at t=40ns, end of Cycle 0

        $display("I0: rd %0d  rs1 %0d  rs2 %0d",
                 issue_q.sbe.rd, issue_q.sbe.rs1, issue_q.sbe.rs2);

        // retire I0
        fetch_entry_ready_i  = 1'b0;
        we_gp_i              = 1'b1;
        waddr_i              = issue_q.sbe.rd;  // should be pr1
        #20;  // Cycle 1

        // ---- I1: LI ar5 ----
        issue_n.valid        = 1'b1;
        issue_n.sbe.rd       = 5;    // ar5→pr2
        issue_n.sbe.rs1      = 'x;
        issue_n.sbe.rs2      = 'x;
        fetch_entry_ready_i  = 1'b1;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #20;  // Cycle 2

        $display("I1: rd %0d  rs1 %0d  rs2 %0d",
                 issue_q.sbe.rd, issue_q.sbe.rs1, issue_q.sbe.rs2);

        // retire I1
        fetch_entry_ready_i  = 1'b0;
        we_gp_i              = 1'b1;
        waddr_i              = issue_q.sbe.rd;  // should be pr2
        #20;  // Cycle 3

        // ---- I2: ADD ar3, ar4, ar5 ----
        issue_n.valid        = 1'b1;
        issue_n.sbe.rd       = 3;    // ar3→pr3
        issue_n.sbe.rs1      = 4;    // ar4→pr1
        issue_n.sbe.rs2      = 5;    // ar5→pr2
        fetch_entry_ready_i  = 1'b1;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #20;  // Cycle 4

        $display("I2: rd %0d  rs1 %0d  rs2 %0d",
                 issue_q.sbe.rd, issue_q.sbe.rs1, issue_q.sbe.rs2);

        // retire I2
        fetch_entry_ready_i  = 1'b0;
        we_gp_i              = 1'b1;
        waddr_i              = issue_q.sbe.rd;  // should be pr3
        #20;  // Cycle 5

        // ---- I3: ADD ar3, ar4, ar5 ----
        issue_n.valid        = 1'b1;
        issue_n.sbe.rd       = 3;    // ar3→pr4
        issue_n.sbe.rs1      = 4;    // ar4→pr1
        issue_n.sbe.rs2      = 5;    // ar5→pr2
        fetch_entry_ready_i  = 1'b1;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #20;  // Cycle 6

        $display("I3: rd %0d  rs1 %0d  rs2 %0d",
                 issue_q.sbe.rd, issue_q.sbe.rs1, issue_q.sbe.rs2);

        // retire I3
        fetch_entry_ready_i  = 1'b0;
        we_gp_i              = 1'b1;
        waddr_i              = issue_q.sbe.rd;  // should be pr4
        #20;  // Cycle 7

        // ---- I4: ADD ar3, ar4, ar5 (should reuse pr3) ----
        issue_n.valid        = 1'b1;
        issue_n.sbe.rd       = 3;    // ar3→reuse pr3
        issue_n.sbe.rs1      = 4;    // ar4→pr1
        issue_n.sbe.rs2      = 5;    // ar5→pr2
        fetch_entry_ready_i  = 1'b1;
        we_gp_i              = 1'b0;
        waddr_i              = '0;
        #20;  // Cycle 8

        $display("I4: rd %0d  rs1 %0d  rs2 %0d",
                 issue_q.sbe.rd, issue_q.sbe.rs1, issue_q.sbe.rs2);

        $finish;
    end

    // instantiate your renamer
    renaming_map u_ren (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .fetch_entry_ready_i(fetch_entry_ready_i),
        .issue_n(issue_n),
        .issue_q(issue_q),
        .waddr_i(waddr_i),
        .we_gp_i(we_gp_i)
    );

endmodule
