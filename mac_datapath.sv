module mac_datapath (
    input logic  clk,
    input logic reset,
    //fsm's outputs(control signals)->inputs to datapath, connected via top module 
    input logic cycle_sel,
    input logic accum_en,
    input logic prod_latch_en,

    input logic [7:0] A [0:3],
    input logic [7:0] B [0:3],

    output logic [31:0] C [0:3]
);

//(4 for a + 4 for b)=8 muxes : allow us to use only 4 multipliers= hardware efficiency
logic [7:0] mul_a [0:3];
logic [7:0] mul_b [0:3];

//multiplier results of two 8 bits: 16bits
logic [15:0] prod[0:3]; //combinational

logic [15:0] prod_reg[0:3];// stores values of prod, stable 


// MUX layer
assign mul_a[0] = cycle_sel ? A[1] : A[0];
assign mul_b[0] = cycle_sel ? B[2] : B[0];

assign mul_a[1] = cycle_sel ? A[1] : A[0];
assign mul_b[1] = cycle_sel ? B[3] : B[1];

assign mul_a[2] = cycle_sel ? A[3] : A[2];
assign mul_b[2] = cycle_sel ? B[2] : B[0];

assign mul_a[3] = cycle_sel ? A[3] : A[2];
assign mul_b[3] = cycle_sel ? B[3] : B[1];

///////////////////////////////////////
// Multipliers
/////////////////////////////////////////

assign prod[0] = mul_a[0] * mul_b[0];
assign prod[1] = mul_a[1] * mul_b[1];
assign prod[2] = mul_a[2] * mul_b[2];
assign prod[3] = mul_a[3] * mul_b[3];


// inputs are changed too early
//ACCUM1 → COMPUTE2
//At COMPUTE2: cycle_sel flips, mux changes inputs, prod changes IMMEDIATELY

//So during ACCUM1 edge:
// Sometimes accumulating new prod instead of old prod
// similar to Race condition

// pipeline the multiplier output
//Add register stage between multiplier and accumulator
// Register the multiplier output
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        prod_reg[0] <= 0;
        prod_reg[1] <= 0;
        prod_reg[2] <= 0;
        prod_reg[3] <= 0;
        end
   else if (prod_latch_en) begin 
        prod_reg[0] <= prod[0];
        prod_reg[1] <= prod[1];
        prod_reg[2] <= prod[2];
        prod_reg[3] <= prod[3];
    end
end

// Accumulators
always_ff @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        C[0] <= 0;
        C[1] <= 0;
        C[2] <= 0;
        C[3] <= 0;
    end
    else if(accum_en)
    begin
     C[0] <= C[0] + prod_reg[0];
C[1] <= C[1] + prod_reg[1];
C[2] <= C[2] + prod_reg[2];
C[3] <= C[3] + prod_reg[3];
    end
end

endmodule
