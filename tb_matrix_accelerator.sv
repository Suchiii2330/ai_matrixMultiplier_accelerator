// =============================================================
//  Testbench
// =============================================================
`timescale 1ns/1ps
module tb_matrix_accelerator;
    logic        clk;
    logic        reset;
    logic        start;
    logic [31:0] A_flat;
    logic [31:0] B_flat;
    logic [127:0] C_flat;
    logic        done;
 
    //design under test
    //dut is the top module-> which has sequencer FSM and mac_datapath instantiated in it
    matrix_accelerator dut (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .A_flat(A_flat),
        .B_flat(B_flat),
        .C_flat(C_flat),
        .done  (done)
    );
 
    // CLOCK
    initial clk = 0;
    always #5 clk = ~clk;
 
    ////////////////////////////////////////////////
    // TASK: run one matrix multiply test
    // kind of a function which will be called during tests
    ////////////////////////////////////////////////
    task automatic run_test(
        //inputs of 8 bits, will be given during task call
        input [7:0] a00, a01, a10, a11,
        input [7:0] b00, b01, b10, b11
    );
        logic [31:0] c00, c01, c10, c11;
        logic [31:0] exp_c00, exp_c01, exp_c10, exp_c11;
        //for comparison of dut results vs expected results
    begin
        //tb sends flattened input-> top_module-> sequencer FSM + mac_datapath
        A_flat = {a11, a10, a01, a00};
        B_flat = {b11, b10, b01, b00};
        //concatenate four 8 bit regs into one.why?
        //as the top module expects one 32 bit bus as i/p, not 4 separate signals
 
        //start pulse synchronous with clk
        @(posedge clk); #1;
        start = 1;
        @(posedge clk); #1;
        start = 0;
 
        wait (done == 1);
        @(posedge clk); #1;
        //timing control that introduces a delay of one time unit in simulation
        //-> zero effect on hardware/synthesis
 
        //packed output from top_module (128 bits)-> assigned to 32 bit wires for display
        //dut output
        c00 = C_flat[31:0];
        c01 = C_flat[63:32];
        c10 = C_flat[95:64];
        c11 = C_flat[127:96];
 
        //expected output
        //cast to 32 bits first to prevent 8-bit overflow during multiplication
        exp_c00 = 32'(a00)*32'(b00) + 32'(a01)*32'(b10);
        exp_c01 = 32'(a00)*32'(b01) + 32'(a01)*32'(b11);
        exp_c10 = 32'(a10)*32'(b00) + 32'(a11)*32'(b10);
        exp_c11 = 32'(a10)*32'(b01) + 32'(a11)*32'(b11);
 
        if (c00==exp_c00 && c01==exp_c01 && c10==exp_c10 && c11==exp_c11)
            $display("  PASS: c00=%0d c01=%0d c10=%0d c11=%0d",
                     c00, c01, c10, c11);
        else
            $display("  FAIL: expected c00=%0d c01=%0d c10=%0d c11=%0d  |  got c00=%0d c01=%0d c10=%0d c11=%0d",
                     exp_c00, exp_c01, exp_c10, exp_c11,
                     c00, c01, c10, c11);
    end
    endtask
 
    ////////////////////////////////////////////////
    // TEST SEQUENCE
    ////////////////////////////////////////////////
    //initial blocks are not synthesizable (FPGA/ASIC hardware won't use them)
    //-> only for simulation
    initial begin
        clk   = 0;
        reset = 1;
        start = 0;
        A_flat = 0;
        B_flat = 0;
        repeat(4) @(posedge clk); // hold reset for 4 clock cycles
        reset = 0;
 
        //////////////////////////////////////////////
        // TEST 1: basic numbers
        //////////////////////////////////////////////
        //reset before each test to clear previous values stored in registers
        reset = 1; @(posedge clk); #1; reset = 0;
        $display("TEST 1: basic numbers  (expect c00=19 c01=22 c10=43 c11=50)");
        //fail means datapath is wrong
        //A=[1 2; 3 4]  B=[5 6; 7 8]
        //c00=1*5+2*7=19  c01=1*6+2*8=22
        //c10=3*5+4*7=43  c11=3*6+4*8=50
        run_test(1,2, 3,4,  5,6, 7,8);
 
        //////////////////////////////////////////////
        // TEST 2: identity matrix
        //////////////////////////////////////////////
        reset = 1; @(posedge clk); #1; reset = 0;
        $display("TEST 2: identity * B   (expect c00=9  c01=8  c10=7  c11=6)");
        //should give back same matrix B-> checks mux indexing
        //Verify correct operand selection via mux logic
        //A=[1 0; 0 1]  B=[9 8; 7 6]
        run_test(1,0, 0,1,  9,8, 7,6);
 
        //////////////////////////////////////////////
        // TEST 3: zero matrix
        //////////////////////////////////////////////
        reset = 1; @(posedge clk); #1; reset = 0;
        $display("TEST 3: zero A         (expect all zeros)");
        //fails if accumulation is incorrect
        run_test(0,0, 0,0,  3,4, 5,6);
 
        //////////////////////////////////////////////
        // TEST 4: random values
        //////////////////////////////////////////////
        reset = 1; @(posedge clk); #1; reset = 0;
        $display("TEST 4: random values  (expect c00=19 c01=62 c10=15 c11=64)");
        //A=[4 7; 2 9]  B=[3 5; 1 6]
        //c00=4*3+7*1=19  c01=4*5+7*6=62
        //c10=2*3+9*1=15  c11=2*5+9*6=64
        run_test(4,7, 2,9,  3,5, 1,6);
 
        #100;
        $display("All tests complete.");
        $finish;
    end
 
endmodule
