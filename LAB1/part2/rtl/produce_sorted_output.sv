`timescale 1ns/1ps

// Two-state FSM. Reset selects EVEN first. 
// A successful read from one parity changes the state to the other parity.
module produce_sorted_output #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  read_en,

    input  logic [DATA_WIDTH-1:0] even_fifo_rdata,
    input  logic [DATA_WIDTH-1:0] odd_fifo_rdata,
    input  logic                  even_fifo_empty,
    input  logic                  odd_fifo_empty,
    output logic                  even_fifo_rd_en,
    output logic                  odd_fifo_rd_en,

    output logic [DATA_WIDTH-1:0] data_out
);

    typedef enum logic {
        EVEN_STATE,
        ODD_STATE
    } parity_state_t;

    parity_state_t state;

    // At most one read enable can be asserted. 
    // Forward read_en signal to the proper FIFO.
    always_comb begin
        even_fifo_rd_en = 1'b0;
        odd_fifo_rd_en  = 1'b0;

        case (state)
            EVEN_STATE:
                even_fifo_rd_en = read_en && !even_fifo_empty;

            ODD_STATE:
                odd_fifo_rd_en = read_en && !odd_fifo_empty;

            default: begin
                even_fifo_rd_en = 1'b0;
                odd_fifo_rd_en  = 1'b0;
            end
        endcase
    end

    // Active-low asynchronous reset matches the underlying FIFO reset polarity.
    always_ff @(posedge clock or negedge reset) begin
        if (!reset) begin
            state    <= EVEN_STATE;
            data_out <= '0;
        end
        else begin
            case (state)
                EVEN_STATE: begin // We should produce an even number.
                    if (read_en && !even_fifo_empty) begin
                        // Read is enabled, and an even number is available.
                        data_out <= even_fifo_rdata;
                        state    <= ODD_STATE; // Jump to the next state.
                    end
                end

                ODD_STATE: begin // We should produce an odd number.
                    if (read_en && !odd_fifo_empty) begin
                        // Read is enabled, and an odd number is available.
                        data_out <= odd_fifo_rdata;
                        state    <= EVEN_STATE; // Jump to the next state.
                    end
                end

                default: begin
                    state    <= EVEN_STATE;
                    data_out <= '0;
                end
            endcase
        end
    end

endmodule
