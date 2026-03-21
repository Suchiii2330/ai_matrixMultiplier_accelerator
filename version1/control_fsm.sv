module control_fsm(
    input logic clk,
    input logic reset,
    input logic start,

    output logic cycle_sel,
    output logic accum_en,
    output logic done
);

//fsm states
typedef enum logic [2:0] {

    IDLE,
    LOAD,
    COMPUTE1,
    ACCUM1,
    COMPUTE2,
    ACCUM2,
    DONE

} state_t;
state_t state;


always_ff @(posedge clk or posedge reset)
begin
    if(reset)
        state <= IDLE;
    else
    begin
        case(state)

        IDLE:
            if(start)
                state <= LOAD;

        LOAD:
            state <= COMPUTE1;

        COMPUTE1:
            state <= ACCUM1;

        ACCUM1:
            state <= COMPUTE2;

        COMPUTE2:
            state <= ACCUM2;

        ACCUM2:
            state <= DONE;

        DONE:
            state <= IDLE;

        endcase
    end
    // DEBUG PRINT
    $display("Time=%0t  STATE=%0d  start=%0b  cycle_sel=%0b  accum_en=%0b  done=%0b",
             $time, state, start, cycle_sel, accum_en, done);
end

//fsm only generates control signals
//FSM does not know about multipliers or registers.
always_comb
begin
    cycle_sel = 0;
    accum_en  = 0;
    done      = 0;

    case(state)

        COMPUTE1:
            cycle_sel = 0; //send first operands to multipliers

        ACCUM1: begin
        cycle_sel = 0;  //cycle_sel=0 for first accumulation
            accum_en = 1; //first results arrive-> update C reg
end
        COMPUTE2:
            cycle_sel = 1;// send second operands to multiplier

        ACCUM2:begin
        cycle_sel=1;     //cycle_sel=1 for 2nd accumulation
            accum_en = 1;// second results arrive-> update/accumulate them into the C reg
end
        DONE:
            done = 1;
            
          

    endcase
end

endmodule