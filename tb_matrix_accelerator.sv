`timescale 1ns/1ps

module tb_matrix_accelerator;

logic clk;
logic reset;
logic start;

logic [31:0] A_flat;
logic [31:0] B_flat;

logic [127:0] C_flat;
logic done;

//design under test
//dut is the top module-> which has fsm and datapath modules already instantiated
//in it
matrix_accelerator dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .A_flat(A_flat),
    .B_flat(B_flat),
    .C_flat(C_flat),
    .done(done)
);

// CLOCK
always #5 clk = ~clk;

// TASK: run test
//kind of a function which will be called during tests
task automatic run_test(
//inputs of 8 bits, will be given during task call
    input [7:0] a00,a01,a10,a11,
    input [7:0] b00,b01,b10,b11
);

logic [31:0] c00,c01,c10,c11;
logic [31:0] exp_c00,exp_c01,exp_c10,exp_c11;
//for comaprison of dut resulys vs expected results

begin
//tb sends flattened input-> top_module->individual block(datapth+ctrl_fsm)
    A_flat = {a11,a10,a01,a00};
    B_flat = {b11,b10,b01,b00};
//concatenate four 8 bit regs into one.why?
//as the top module expects one 32 bit C bus as i/p ,not 4 seperate signals


//start pulse synchronous with clk
    @(posedge clk);
start <= 1;

@(posedge clk);
start <= 0;

    wait(done);
@(posedge clk);
//packed output from top_module(128bits)-> assigned to 32bit wires for display
  //dut output
    c00 = C_flat[31:0];
    c01 = C_flat[63:32];
    c10 = C_flat[95:64];
    c11 = C_flat[127:96];

//expected output
exp_c00 = a00*b00 + a01*b10;
    exp_c01 = a00*b01 + a01*b11;
    exp_c10 = a10*b00 + a11*b10;
    exp_c11 = a10*b01 + a11*b11;

    if(c00==exp_c00 &&
       c01==exp_c01 &&
       c10==exp_c10 &&
       c11==exp_c11)

        $display("TEST PASS");

    else
       $display("TEST FAIL: expected=%0d %0d %0d %0d got=%0d %0d %0d %0d",
exp_c00,exp_c01,exp_c10,exp_c11,
c00,c01,c10,c11);

end

endtask

////////////////////////////////////////////////
// TEST SEQUENCE
////////////////////////////////////////////////

//initial blocks are not synthesizable (FPGA/ASIC hardware won't use them)-> only for simulation
initial begin

clk = 0;
reset = 1;
start = 0;

reset = 1;
repeat(3) @(posedge clk);  // hold reset for 3 clock cycles
reset = 0;

//////////////////////////////////////////////
// TEST 1
//////////////////////////////////////////////

//reset before each test to clear previous values stored in registers
reset = 1;
@(posedge clk);
reset = 0;

$display("TEST1: basic numbers");
//fail means datapath is wrong
run_test(
    1,2,
    3,4,

    5,6,
    7,8
);

//////////////////////////////////////////////
// TEST 2
//////////////////////////////////////////////

reset = 1;
@(posedge clk);
reset = 0;

$display("TEST2: identity matrix");
//should give back same matrix-> checks mux indexing
//Verify correct operand selection via mux logic
run_test(
    1,0,
    0,1,

    9,8,
    7,6
    
);

//////////////////////////////////////////////
// TEST 3
//////////////////////////////////////////////

reset = 1;
@(posedge clk);
reset = 0;

$display("TEST3: zero matrix");
//fails if accumulation is incorrect
run_test(
    0,0,
    0,0,

    3,4,
    5,6
);

//////////////////////////////////////////////
// TEST 4
//////////////////////////////////////////////
reset = 1;
@(posedge clk);
reset = 0;

$display("TEST4: random values");

run_test(
    4,7,
    2,9,

    3,5,
    1,6
);

#100;

$finish;

end

endmodule