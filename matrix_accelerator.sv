module matrix_accelerator( //top module: instantiation of hardware blocks
    input logic clk,
    input logic reset,
    input logic start,

//input reg:8bits-> flattened version
    input logic [31:0] A_flat,
    input logic [31:0] B_flat,
//output -> accumulator:32 bits
   output logic [127:0] C_flat,
    output logic  done
);

logic cycle_sel;
logic accum_en;

//declare actual unflattened reg we're working with
logic [7:0] A [0:3];// 4 A registers of 8bits each
logic [7:0] B [0:3];
logic [31:0] C [0:3];//4 C reg of 32 bits each

//unpack inputs

assign A[0] = A_flat[7:0];// assign first A register 
assign A[1] = A_flat[15:8];
assign A[2] = A_flat[23:16];
assign A[3] = A_flat[31:24];

assign B[0] = B_flat[7:0];// assign first B register 
assign B[1] = B_flat[15:8];
assign B[2] = B_flat[23:16];
assign B[3] = B_flat[31:24];


//pack outputs before sending them outside modules
//no array ports at module boundaries
assign C_flat[31:0]   = C[0];
assign C_flat[63:32]  = C[1];
assign C_flat[95:64]  = C[2];
assign C_flat[127:96] = C[3];


control_fsm ctrl(
    .clk(clk),
    .reset(reset),
    .start(start),
    .cycle_sel(cycle_sel),
    .accum_en(accum_en),
    .done(done)
);
//v1:
mac_datapath dp(
    .clk(clk),
    .reset(reset),
    .cycle_sel(cycle_sel),
    .accum_en(accum_en),
    .A(A),
    .B(B),
    .C(C)
);

endmodule
