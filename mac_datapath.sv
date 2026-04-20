
// =============================================================
//  mac_datapath
//  N multipliers -> pipeline register -> adder tree -> accumulator
// =============================================================
module mac_datapath #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic clear_acc,              // start new computation
    input  logic [DATA_W-1:0] A [0:N-1],
    input  logic [DATA_W-1:0] B [0:N-1],
    output logic [ACC_W-1:0]  result,
    output logic               valid_out
);
    ////////////////////////////////////////////////
    // VALID PIPELINE
    ////////////////////////////////////////////////
    logic valid_s1, valid_s2;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_s1 <= 0;
            valid_s2 <= 0;
        end else begin
            valid_s1 <= valid_in;
            valid_s2 <= valid_s1;
        end
    end

    ////////////////////////////////////////////////
    // STAGE 1: MULTIPLIERS
    ////////////////////////////////////////////////
    logic [2*DATA_W-1:0] prod [0:N-1];
    genvar i;
    generate
    //hardware creation of n multipliers
        for (i = 0; i < N; i++) begin : MULT
            assign prod[i] = A[i] * B[i]; // A and B are NxN matrices
        end
    endgenerate

    ////////////////////////////////////////////////
    // STAGE 2: PIPELINE REGISTER
    ////////////////////////////////////////////////
    logic [2*DATA_W-1:0] prod_r [0:N-1];
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < N; i++)
                prod_r[i] <= 0;
        end else begin
            for (int i = 0; i < N; i++)
                prod_r[i] <= prod[i];
        end
    end

    ////////////////////////////////////////////////
    // STAGE 3: ADDER TREE (BALANCED REDUCTION)
    ////////////////////////////////////////////////
    // FIX: tree_sum and tree_valid declared here before use
    logic [ACC_W-1:0] tree_sum;
    logic             tree_valid;

    adder_tree_pipelined #(
        .N     (N),
        .DATA_W(2*DATA_W), //input to tree = product width (16 bits for 8-bit inputs)
        .ACC_W (ACC_W)
    ) tree_inst (
        .clk      (clk),
        .reset    (reset),
        .valid_in (valid_s1),   // input valid, if s1=> cycle2 and prod_r is ready=> proceed to adder_tree
        .in       (prod_r),
        .sum_out  (tree_sum),   // o/p of adder tree
        .valid_out(tree_valid)  //final output valid
    );

    ////////////////////////////////////////////////
    // STAGE 4: ACCUMULATOR (TRUE MAC)
    ////////////////////////////////////////////////
    logic [ACC_W-1:0] acc;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            acc <= 0;
        else if (clear_acc)
            acc <= 0;  // start new dot-product / tile
        else if (valid_s2)
            acc <= acc + tree_sum;
    end

    ////////////////////////////////////////////////
    // OUTPUT
    ////////////////////////////////////////////////
    assign result    = acc;
    assign valid_out = valid_s2;

endmodule

