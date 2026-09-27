`timescale 1ns/1ps

interface fifo_interface #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_W = 4,
    parameter DEPTH = 2 ** ADDR_W
)(
    input logic wr_clk,
    input logic rd_clk,
    input logic wrst_n,
    input logic rrst_n
);

    logic   wr_en;
    logic   [DATA_WIDTH - 1: 0] wdata;
    logic   full;
    logic   almost_full;

    logic   rd_en;
    logic   [DATA_WIDTH - 1: 0] rdata;
    logic   empty;
    logic   almost_empty;

    modport fifo_side (
        input wr_clk, rd_clk, wrst_n, rrst_n, wr_en, wdata, rd_en,
        output full, almost_full, empty, almost_empty, rdata
    );

    modport tb_side (
        input wr_clk, rd_clk, wrst_n, rrst_n, full, almost_full, rdata, empty, almost_empty,
        output wr_en, wdata, rd_en
    );





endinterface