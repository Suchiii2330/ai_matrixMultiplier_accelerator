//  adder_tree_pipelined
//  Balanced pipelined adder tree, one registered stage per level
// =============================================================
module adder_tree_pipelined #(
    parameter N      = 4,
    parameter DATA_W = 16, //input width
    parameter ACC_W  = 32  //safe output width-> allows later expansion
)(
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic [DATA_W-1:0] in [0:N-1], //in =prod_r
    output logic [ACC_W-1:0]  sum_out,
    output logic               valid_out
);
    ////////////////////////////////////////////////
    // INTERNAL STORAGE
    ////////////////////////////////////////////////
    logic [ACC_W-1:0] stage [0:$clog2(N)][0:N-1];
    //$clog2(N) = number of levels
    //stage[level][index]
    //why is stage width =accumulator width?
    //avoid overflow;keep uniform width;simplify design
    logic valid_pipe [0:$clog2(N)]; //one valid register per level

    ////////////////////////////////////////////////
    // INPUT ASSIGN
    ////////////////////////////////////////////////
    //fill level0
    always_comb begin
        for (int i = 0; i < N; i++)
            stage[0][i] = ACC_W'(in[i]);
            //first level = direct inputs
            //stage[0] = [p0, p1, p2, p3]
    end

    ////////////////////////////////////////////////
    // VALID PIPELINE
    ////////////////////////////////////////////////
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i <= $clog2(N); i++) //$clog2(N)= no. of levels
                valid_pipe[i] <= 0;
        end else begin
            valid_pipe[0] <= valid_in;
            for (int i = 1; i <= $clog2(N); i++)
                valid_pipe[i] <= valid_pipe[i-1];
                //valid experiences same delay as data
        end
    end

    ////////////////////////////////////////////////
    // TREE LEVELS
    ////////////////////////////////////////////////
    genvar lvl, i; //special variable for generate loops
    //compile-time loop (loop for hardware creation: 3 hardware stages here)
    generate
        for (lvl = 0; lvl < $clog2(N); lvl++) begin : LEVEL //loops over levels

        //Each stage is registered -> pipeline stage
            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin //j=pair size
                //reset next stage
                    for (int j = 0; j < N; j++)
                        stage[lvl+1][j] <= 0;
                end

                else begin
    //each level pair size doubles
    //lvl 0=> step size=2 => j = 0, 2, 4, 6
    //lvl 1=> j=4
    //lvl 2=> j=8; final sum
                    for (int j = 0; j < N; j = j + 2**(lvl+1)) begin
                        stage[lvl+1][j] <= stage[lvl][j] + stage[lvl][j + 2**lvl];
                    end
                end
            end
        end
    endgenerate

    ////////////////////////////////////////////////
    // OUTPUT
    ////////////////////////////////////////////////
    assign sum_out   = stage[$clog2(N)][0]; //final stage's 0th element stores the final sum
    assign valid_out = valid_pipe[$clog2(N)]; //valid signal in final stage

endmodule

