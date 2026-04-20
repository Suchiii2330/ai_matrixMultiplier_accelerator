// =============================================================
//  matrix_accelerator  (top module)
//
//  Replaces the old v1 top that used control_fsm + v1 mac_datapath.
//  Now drives mac_datapath (v2) directly via an internal sequencer FSM.
//
//  Strategy: one shared mac_datapath (N=2) is reused 4 times,
//  once per output cell C[0]..C[3].
//
//  For each cell the sequencer:
//    S_CLEAR -> pulse clear_acc           (zero the accumulator)
//    S_FEED  -> pulse valid_in            (push one data beat in)
//    S_WAIT0 -> pipeline stage 1 in-flight (prod_r latching)
//    S_WAIT1 -> pipeline stage 2 in-flight (adder tree + acc update)
//    S_LATCH -> sample result, advance to next cell or assert done
//
//  Pipeline latency of mac_datapath = 2 cycles after valid_in:
//    cycle 0: valid_in  -> multipliers fire, prod computed
//    cycle 1: prod_r latched (valid_s1 set)
//    cycle 2: adder tree + accumulator updated (valid_s2 set) <- result ready
//
//  Mapping (A=[a00 a01; a10 a11], B=[b00 b01; b10 b11]):
//    C[0]=c00 = [a00,a01] . [b00,b10]
//    C[1]=c01 = [a00,a01] . [b01,b11]
//    C[2]=c10 = [a10,a11] . [b00,b10]
//    C[3]=c11 = [a10,a11] . [b01,b11]
// =============================================================
module matrix_accelerator (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    //input reg:8bits-> flattened version
    input  logic [31:0] A_flat,
    input  logic [31:0] B_flat,
    //output -> accumulator:32 bits per element, 4 elements = 128 bits
    output logic [127:0] C_flat,
    output logic         done
);
    //declare actual unflattened reg we're working with
    logic [7:0] A [0:3]; // 4 A registers of 8bits each
    logic [7:0] B [0:3];
    logic [31:0] C [0:3]; //4 C reg of 32 bits each

    //unpack inputs
    assign A[0] = A_flat[7:0];   // assign first A register
    assign A[1] = A_flat[15:8];
    assign A[2] = A_flat[23:16];
    assign A[3] = A_flat[31:24];
    assign B[0] = B_flat[7:0];   // assign first B register
    assign B[1] = B_flat[15:8];
    assign B[2] = B_flat[23:16];
    assign B[3] = B_flat[31:24];

    //pack outputs before sending them outside modules
    //no array ports at module boundaries
    assign C_flat[31:0]   = C[0];
    assign C_flat[63:32]  = C[1];
    assign C_flat[95:64]  = C[2];
    assign C_flat[127:96] = C[3];

    ////////////////////////////////////////////////
    // SEQUENCER FSM STATES
    ////////////////////////////////////////////////
    typedef enum logic [2:0] {
        S_IDLE  = 3'd0, // wait for start
        S_CLEAR = 3'd1, // pulse clear_acc, set mux
        S_FEED  = 3'd2, // pulse valid_in
        S_WAIT0 = 3'd3, // pipeline stage 1 in-flight
        S_WAIT1 = 3'd4, // pipeline stage 2 in-flight
         S_SETTLE = 3'd5,  // NEW: let acc settle for one cycle
        S_LATCH = 3'd6, // latch result into C[cell_idx]
        S_DONE  = 3'd7  // assert done for one cycle
    } state_t;

    state_t     state;
    logic [1:0] cell_idx; // selects which output cell C[0]..C[3]
 


    ////////////////////////////////////////////////
    // mac_datapath CONTROL WIRES
    ////////////////////////////////////////////////
    logic [7:0] dp_A [0:1]; // N=2: one row-of-A pair
    logic [7:0] dp_B [0:1]; // N=2: one col-of-B pair
    logic        valid_in;
    logic        clear_acc;
    logic [31:0] result;
    logic        valid_out;

    ////////////////////////////////////////////////
    // INPUT MUX
    // Selects A-row and B-col for each output cell
    // cell_idx encoding:
    //   0 -> c00: A_row0=[a00,a01]  B_col0=[b00,b10]
    //   1 -> c01: A_row0=[a00,a01]  B_col1=[b01,b11]
    //   2 -> c10: A_row1=[a10,a11]  B_col0=[b00,b10]
    //   3 -> c11: A_row1=[a10,a11]  B_col1=[b01,b11]
    ////////////////////////////////////////////////
    always_comb begin
        case (cell_idx)
            2'd0: begin dp_A[0]=A[0]; dp_A[1]=A[1]; dp_B[0]=B[0]; dp_B[1]=B[2]; end
            2'd1: begin dp_A[0]=A[0]; dp_A[1]=A[1]; dp_B[0]=B[1]; dp_B[1]=B[3]; end
            2'd2: begin dp_A[0]=A[2]; dp_A[1]=A[3]; dp_B[0]=B[0]; dp_B[1]=B[2]; end
            2'd3: begin dp_A[0]=A[2]; dp_A[1]=A[3]; dp_B[0]=B[1]; dp_B[1]=B[3]; end
            default: begin dp_A[0]='0; dp_A[1]='0; dp_B[0]='0; dp_B[1]='0; end
        endcase
    end

    ////////////////////////////////////////////////
    // SEQUENCER FSM
    ////////////////////////////////////////////////
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= S_IDLE;
            cell_idx  <= 2'd0;
          
            valid_in  <= 1'b0;
            clear_acc <= 1'b0;
            done      <= 1'b0;
               for (int k = 0; k < 4; k++) C[k] <= '0;
            
        end else begin
            //defaults: deassert each cycle unless explicitly driven
            valid_in  <= 1'b0;
            clear_acc <= 1'b0;
            done      <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (start) begin
                        cell_idx <= 2'd0;
                        state    <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    //zero the accumulator ONCE; mux is already set by cell_idx
                    clear_acc <= 1'b1;
                 
                    state     <= S_FEED;
                end

                S_FEED: begin
                    //send one valid data beat into the pipeline
                    valid_in <= 1'b1;
                
                    state <= S_WAIT0; 
            
            end

                S_WAIT0: begin
                    //pipeline stage 1: prod_r latching
                    state <= S_WAIT1;
                end

                S_WAIT1: begin
                   
                     //pipeline stage 2: adder tree + accumulator
    //acc gets its new value on THIS clock edge
    //need one more cycle before reading result
    state <= S_SETTLE;  // was S_LATCH - that was the bug
                end


      S_SETTLE: begin
    //acc is now stable with the correct dot-product result
    //result wire reflects the new acc value -> safe to latch
    state <= S_LATCH;
end

             S_LATCH: begin
    //capture result for current output cell
    C[cell_idx] <= result;
    
    if (cell_idx == 2'd3) begin
        state <= S_DONE;
    end else begin
        cell_idx <= cell_idx + 1'b1;
        state    <= S_CLEAR; //loop back for next cell
    end
end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

    ////////////////////////////////////////////////
    // mac_datapath INSTANTIATION  (N=2 for 2x2 matrix)
    ////////////////////////////////////////////////
    mac_datapath #(
        .N     (2),
        .DATA_W(8),
        .ACC_W (32)
    ) dp (
        .clk      (clk),
        .reset    (reset),
        .valid_in (valid_in),
        .clear_acc(clear_acc),
        .A        (dp_A),
        .B        (dp_B),
        .result   (result),
        .valid_out(valid_out)
    );

endmodule


