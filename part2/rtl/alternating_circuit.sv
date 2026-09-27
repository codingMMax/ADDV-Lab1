`timescale 1ns/1ps

// Top-level module for Lab 1, Part 2.
//
// The single external clock drives both sides of each reused async FIFO.
module alternating_circuit #(
    parameter int DATA_WIDTH  = 8,
    parameter int FIFO_ADDR_W = 6
) (
    alternating_circuit_interface.circuit_side circuit_port
);

    logic [DATA_WIDTH-1:0] even_fifo_rdata;
    logic [DATA_WIDTH-1:0] odd_fifo_rdata;
    logic                  even_fifo_empty;
    logic                  odd_fifo_empty;
    logic                  even_fifo_rd_en;
    logic                  odd_fifo_rd_en;
    logic [DATA_WIDTH-1:0] data_out;

    // First module that receives the sequence of numbers, and writes into either
    // the even FIFO or odd FIFO depending on their parity.
    store_input #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FIFO_ADDR_W (FIFO_ADDR_W)
    ) u_store_input (
        // Input
        .clock           (circuit_port.clock),
        .reset           (circuit_port.reset),
        .data_in         (circuit_port.data_in),
        .write_en        (circuit_port.write_en),
         // The next module will determine whether we need even FIFO's input or odd FIFO's input.
        .even_fifo_rd_en (even_fifo_rd_en),
        .odd_fifo_rd_en  (odd_fifo_rd_en),
        // Output
        .even_fifo_rdata (even_fifo_rdata),
        .odd_fifo_rdata  (odd_fifo_rdata),
        .even_fifo_empty (even_fifo_empty),
        .odd_fifo_empty  (odd_fifo_empty)
    );

    // Second module that requests read of even and odd FIFOs using a 2-stage FSM, and produces output. 
    produce_sorted_output #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_produce_sorted_output (
        // Input
        .clock           (circuit_port.clock),
        .reset           (circuit_port.reset),
        .read_en         (circuit_port.read_en),
        .even_fifo_rdata (even_fifo_rdata),
        .odd_fifo_rdata  (odd_fifo_rdata),
         // If there's no available even or odd numbers, we should stop producing outputs.
        .even_fifo_empty (even_fifo_empty),
        .odd_fifo_empty  (odd_fifo_empty),
        // Output
        .even_fifo_rd_en (even_fifo_rd_en),
        .odd_fifo_rd_en  (odd_fifo_rd_en),
        .data_out        (data_out)
    );

    assign circuit_port.data_out = data_out;

endmodule
