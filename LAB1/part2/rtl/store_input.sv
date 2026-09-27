`timescale 1ns/1ps

// Classifies every asserted write request by data_in[0] and stores the word in
// one of two 64-entry async FIFOs.
module store_input #(
    parameter int DATA_WIDTH  = 8,
    parameter int FIFO_ADDR_W = 6
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  write_en,

    input  logic                  even_fifo_rd_en,
    input  logic                  odd_fifo_rd_en,
    output logic [DATA_WIDTH-1:0] even_fifo_rdata,
    output logic [DATA_WIDTH-1:0] odd_fifo_rdata,
    output logic                  even_fifo_empty,
    output logic                  odd_fifo_empty
);

    localparam int FIFO_DEPTH = 1 << FIFO_ADDR_W;

    // Both FIFO domains use the assignment's one clock. 
    // Both active-low FIFO resets receive the public active-low reset directly.
    fifo_interface #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_W     (FIFO_ADDR_W),
        .DEPTH      (FIFO_DEPTH)
    ) even_fifo_bus (
        .wr_clk (clock),
        .rd_clk (clock),
        .wrst_n (reset),
        .rrst_n (reset)
    );

    fifo_interface #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_W     (FIFO_ADDR_W),
        .DEPTH      (FIFO_DEPTH)
    ) odd_fifo_bus (
        .wr_clk (clock),
        .rd_clk (clock),
        .wrst_n (reset),
        .rrst_n (reset)
    );

    assign even_fifo_bus.wdata = data_in;
    assign odd_fifo_bus.wdata  = data_in;

    // Exactly one parity FIFO can receive a given input word. 
    // The full term avoids overwriting unread data if the stated workload is ever violated.
    // We raise an error when full is triggered in the testbench, so we can remove full terms, too.
    assign even_fifo_bus.wr_en = write_en && !data_in[0] && !even_fifo_bus.full;
    assign odd_fifo_bus.wr_en  = write_en &&  data_in[0] && !odd_fifo_bus.full;

    // The output FSM owns the FIFO read enables.
    assign even_fifo_bus.rd_en = even_fifo_rd_en;
    assign odd_fifo_bus.rd_en  = odd_fifo_rd_en;

    // FIFO rdata is a show-ahead value and is valid only while empty is low.
    assign even_fifo_rdata = even_fifo_bus.rdata;
    assign odd_fifo_rdata  = odd_fifo_bus.rdata;
    assign even_fifo_empty = even_fifo_bus.empty;
    assign odd_fifo_empty  = odd_fifo_bus.empty;

    // Initialize even and odd FIFOs.
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_W     (FIFO_ADDR_W)
    ) even_async_fifo (
        .fifo_port (even_fifo_bus.fifo_side)
    );

    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_W     (FIFO_ADDR_W)
    ) odd_async_fifo (
        .fifo_port (odd_fifo_bus.fifo_side)
    );

endmodule
