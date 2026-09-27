`timescale 1ns/1ps

// The interface for alternating_circuit, as stated in the Lab 1 Notion page. 
// Reset is active-low.
interface alternating_circuit_interface #(
    parameter int DATA_WIDTH = 8
) (
    input logic clock,
    input logic reset
);

    logic [DATA_WIDTH-1:0] data_in;
    logic                  write_en;
    logic [DATA_WIDTH-1:0] data_out;
    logic                  read_en;

    // View used by the design under test.
    modport circuit_side (
        input  clock, reset, data_in, write_en, read_en,
        output data_out
    );

    // View used by the producer/consumer testbench.
    modport tb_side (
        input  clock, reset, data_out,
        output data_in, write_en, read_en
    );

endinterface
