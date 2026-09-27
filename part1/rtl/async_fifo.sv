`timescale 1ns/1ps

package fifo_utils;
    
    function automatic logic [31:0] bin2gray (input logic [31:0] bin);
        return bin^(bin >> 1);
    endfunction

    function automatic logic [31:0] gray2bin (input logic [31:0] gray);
        logic [31:0] bin;
        bin = gray;
        for (int i = 1; i < 32; i++)
            bin ^= (gray >> i);
        return bin;
    endfunction

endpackage

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_W = 4
)(
    fifo_interface.fifo_side fifo_port      // interface port (FIFO-side view)
);

    logic wclk, rclk, wrst_n, rrst_n, wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wdata;

    assign wclk = fifo_port.wr_clk;
    assign rclk = fifo_port.rd_clk;
    assign wrst_n = fifo_port.wrst_n;
    assign rrst_n = fifo_port.rrst_n;
    assign wr_en = fifo_port.wr_en;
    assign rd_en = fifo_port.rd_en;
    assign wdata = fifo_port.wdata;

    // gray pointers 
    logic [ADDR_W:0] wgray, rgray;

    logic [ADDR_W:0] rgray1, rgray2;   // rgray -> write domain
    logic [ADDR_W:0] wgray1, wgray2;   // wgray -> read domain

    // binary addresses, read data, status flags
    logic [ADDR_W-1:0]     waddr, raddr;
    logic [DATA_WIDTH-1:0] rdata;
    logic full, almost_full, empty, almost_empty;

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {rgray2, rgray1} <= '0;
        else         {rgray2, rgray1} <= {rgray1, rgray};
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {wgray2, wgray1} <= '0;
        else         {wgray2, wgray1} <= {wgray1, wgray};
    end

    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_W     (ADDR_W)
    ) u_fifo_mem (.*);

    wptr_full #(
        .ADDR_W (ADDR_W)
    ) u_wptr_full (
        .rgray_sync (rgray2),   // no matching top-level name
        .*
    );

    rptr_empty #(
        .ADDR_W (ADDR_W)
    ) u_rptr_empty (
        .wgray_sync (wgray2),   // no matching top-level name
        .*
    );

    assign fifo_port.full = full;
    assign fifo_port.almost_full = almost_full;
    assign fifo_port.empty = empty;
    assign fifo_port.almost_empty = almost_empty;
    assign fifo_port.rdata = rdata;

endmodule

module fifo_mem #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_W = 4
)(
    input logic wclk,
    input logic wr_en,
    input logic full,
    input [ADDR_W - 1:0] waddr,
    input [DATA_WIDTH - 1:0] wdata,
    input [ADDR_W - 1: 0]   raddr,
    output [DATA_WIDTH - 1:0]   rdata 
);

    localparam int DEPTH = 1 << ADDR_W;
    logic [DATA_WIDTH - 1:0] mem [DEPTH];

    always_ff @(posedge wclk ) begin: write
        if (wr_en && !full) mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];  // asynchronous read: rdata is valid asap raddr is valid. 
                                // raddr is gated/checked in async_fifo outside the fifo_mem.

endmodule

module wptr_full #(
    parameter int ADDR_W = 4
) (
    input logic wclk,
    input logic wrst_n,
    input logic wr_en,
    input logic [ADDR_W:0] rgray_sync,      // gray read pointer, synchronized into write domain
    output logic [ADDR_W-1:0] waddr,
    output logic [ADDR_W:0] wgray,
    output logic full,
    output logic almost_full
);

    logic [ADDR_W:0] wbin;
    logic [ADDR_W:0] wbin_next;
    logic [ADDR_W:0] wgray_next;

    logic [ADDR_W:0] rbin_sync;
    logic [ADDR_W:0] occupancy;

    logic full_next, almost_full_next;

    localparam int unsigned DEPTH = 1 << ADDR_W;
    import fifo_utils::*;

    assign wbin_next = wbin + (wr_en && !full);
    assign wgray_next = bin2gray(wbin_next);
    assign full_next = (wgray_next == {~rgray_sync[ADDR_W:ADDR_W-1], rgray_sync[ADDR_W-2 :0]});
    assign rbin_sync = gray2bin(rgray_sync);
    assign occupancy = wbin_next - rbin_sync;
    assign almost_full_next = (occupancy >= 3 * DEPTH / 4);

    assign waddr = wbin[ADDR_W - 1:0];

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= 0;
            wgray <= 0;
            full <= 0;
            almost_full <= 0;
        end
        else begin
            wbin <= wbin_next;
            wgray <= wgray_next;
            full <= full_next;
            almost_full <= almost_full_next;
        end
    
    end
    
endmodule

module rptr_empty #(
    parameter int ADDR_W = 4
)(
    input logic rclk,
    input logic rrst_n,
    input logic rd_en,
    input logic [ADDR_W:0] wgray_sync,      // gray write pointer, synchronized into read domain
    output logic [ADDR_W:0] rgray,
    output logic [ADDR_W-1:0] raddr,
    output logic empty,
    output logic almost_empty
);

    logic [ADDR_W:0] rbin;
    logic [ADDR_W:0] rbin_next;
    logic [ADDR_W:0] rgray_next;
    logic [ADDR_W:0] occupancy;

    logic empty_next;
    logic almost_empty_next;

    import fifo_utils::*;
    localparam int unsigned DEPTH = 1 << ADDR_W;

    assign rbin_next = rbin + (rd_en && !empty);
    assign rgray_next = bin2gray(rbin_next);
    assign empty_next = (rgray_next == wgray_sync);
    assign occupancy = gray2bin(wgray_sync) - rbin_next;
    assign almost_empty_next = (occupancy <= DEPTH / 4);

    assign raddr = rbin[ADDR_W - 1: 0];

    always_ff @(posedge rclk or negedge rrst_n) begin
        if(!rrst_n) begin
            rbin <= 0;
            rgray <= 0;
            empty <= 1'b1;
            almost_empty <= 1'b1;
        end
        else begin
            rbin <= rbin_next;
            rgray <= rgray_next;
            empty <= empty_next;
            almost_empty <= almost_empty_next;
        end
    
    end

endmodule
