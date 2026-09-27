`timescale 1ns/1ps

module tb_async_fifo;

    logic wrst_n = 1'b1, rrst_n = 1'b1;   
    logic wr_clk = 1'b0;    // 10ns 100MHz
    logic rd_clk = 1'b0;    // 20ns 50 MHz
    // generate clock
    localparam int PERIOD_WR = 1000/100;
    localparam int PERIOD_RD = 1000/50;
    
    always #(PERIOD_WR/2) wr_clk = ~wr_clk;
    always #(PERIOD_RD/2) rd_clk = ~rd_clk;

    // dump waveform
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_async_fifo,  "+mda");    // whole TB
    end

    initial begin
        #500000;
        $display("[%0t] TIMEOUT - test did not finish", $time);
        $finish;    
    end

    localparam int DATA_WIDTH = 8;
    localparam int ADDR_W = 4;
    // instantiating fifo interface
    fifo_interface #(.DATA_WIDTH(DATA_WIDTH), .ADDR_W(ADDR_W)) fifo_bus(
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .wrst_n(wrst_n),
        .rrst_n(rrst_n)
    );


    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_W(ADDR_W)) async_fifo_inst(
        .fifo_port (fifo_bus.fifo_side)
    );


    // check scoreboard
    localparam int DEPTH = 1 << ADDR_W;
    localparam int TEST_LENGTH = 2048;

    logic [DATA_WIDTH - 1: 0] expected_queue [0: TEST_LENGTH - 1];

    integer wr_ptr = 0;
    integer rd_ptr = 0;
    integer num_writes = 0;
    integer num_reads = 0;
    integer num_errors = 0;

    task automatic write_once (input logic [DATA_WIDTH - 1: 0] data);
        @(posedge wr_clk);
        fifo_bus.wr_en <= 1'b1; 
        fifo_bus.wdata <= data;
        @(posedge wr_clk);
        fifo_bus.wr_en <= 1'b0; 
    endtask

    task automatic read_aligned();
        @(posedge rd_clk);
        while (fifo_bus.empty !== 1'b0) @(posedge rd_clk);   // wait until not empty
        fifo_bus.rd_en <= 1'b1;
        @(posedge rd_clk);           // read once
        fifo_bus.rd_en <= 1'b0;
    endtask

    task automatic write_aligned (input logic [DATA_WIDTH-1:0] data);
        @(posedge wr_clk);
        while (fifo_bus.full !== 1'b0) @(posedge wr_clk);  // write until not full
        fifo_bus.wr_en <= 1'b1;
        fifo_bus.wdata <= data;
        @(posedge wr_clk);                                  // write once
        fifo_bus.wr_en <= 1'b0;
    endtask

    initial begin
        // Resets start deasserted; assert low AFTER time 0 so the DUT's
        // asynchronous resets observe a clean negedge.
        fifo_bus.wr_en = 1'b0; 
        fifo_bus.rd_en = 1'b0;
        fifo_bus.wdata = 0;

        @(posedge wr_clk); wrst_n = 1'b0;
        @(posedge rd_clk); rrst_n = 1'b0;

        repeat(4) @(posedge wr_clk);
        repeat(4) @(posedge rd_clk);

        @(posedge wr_clk); wrst_n <= 1'b1;
        @(posedge rd_clk); rrst_n <= 1'b1;

        $display("[%0t] after reset: full=%b empty=%b almost_full=%b almost_empty=%b",
                 $time, fifo_bus.full, fifo_bus.empty, fifo_bus.almost_full, fifo_bus.almost_empty);

        write_once(8'hA0); // [A]
        write_once(8'hB0); // [A, B]
        write_once(8'hC0); // [A, B, C]
        read_aligned();    // expect A, [B, C]
        write_once(8'hD0); // [B, C, D]
        read_aligned();    // expect B, [C, D]
        read_aligned();    // expect C, [D]
        read_aligned();    // expect D

        repeat(4) @(posedge wr_clk);
        repeat(4) @(posedge rd_clk);

        for(integer i = 0; i < DEPTH; i ++) begin
            write_once(i);
        end

        for(integer i = 0; i < DEPTH; i ++) begin
            read_aligned();
        end


        repeat (2) @(posedge rd_clk);   // let the final smoke monitor event settle

        $display("=== FILL STRESS START ===");
        fork
            for (int i = 0; i < 200; i++) write_aligned(8'(i));   // writer
            for (int i = 0; i < 200; i++) read_aligned();         // reader
        join
        repeat (2) @(posedge rd_clk);                             // settle last monitor event
        $display("=== FILL STRESS END ===");

        $display("=== DRAIN STRESS START ===");
        fork
            begin
                for (int b = 0; b < 25; b++) begin
                    for (int i = 0; i < 8; i++) write_aligned(8'(b*8 + i));
                    repeat (100) @(posedge wr_clk);   // idle gap -> reader drains
                end
            end
            begin
                for (int i = 0; i < 200; i++) read_aligned();
            end
        join
        repeat (2) @(posedge rd_clk);                             // settle last monitor event
        $display("=== DRAIN STRESS END ===");

        repeat (4) @(posedge wr_clk);
        repeat (4) @(posedge rd_clk);

        if (num_reads !== num_writes) begin
            $error("[ERROR] count mismatch: writes=%0d reads=%0d", num_writes, num_reads);
            num_errors = num_errors + 1;
        end
        if (rd_ptr !== wr_ptr) begin
            $error("[ERROR] queue not drained: rd_ptr=%0d wr_ptr=%0d", rd_ptr, wr_ptr);
            num_errors = num_errors + 1;
        end
        if (fifo_bus.empty !== 1'b1) begin
            $error("[ERROR] empty must be asserted after drain");
            num_errors = num_errors + 1;
        end
        if (fifo_bus.almost_empty !== 1'b1) begin
            $error("[ERROR] almost_empty must be asserted after drain");
            num_errors = num_errors + 1;
        end
        if (fifo_bus.almost_full !== 1'b0) begin
            $error("[ERROR] almost_full must be de-asserted after drain");
            num_errors = num_errors + 1;
        end

        $display("TEST DONE: writes=%0d reads=%0d errors=%0d", num_writes, num_reads, num_errors);
        $finish;
    end


    // write check
    always @(posedge wr_clk) begin
        if (wrst_n && fifo_bus.wr_en && fifo_bus.full === 1'b0) begin

            // $display("[%0t] WRITE accepted: %0h full: %0h almost_full: %0h empty: %0h almost empty: %0h", 
            //                 $time, fifo_bus.wdata, fifo_bus.full, fifo_bus.almost_full, 
            //                 fifo_bus.empty, fifo_bus.almost_empty);


            if (wr_ptr >= TEST_LENGTH) begin
                $error("[ERROR] [%0t] expected_queue overflow (test too long)", $time);
                num_errors = num_errors + 1;
            end
            else begin
                expected_queue[wr_ptr] = fifo_bus.wdata; // write to reference queue

                if ((wr_ptr - rd_ptr) >= DEPTH) begin
                    $error("[ERROR] [%0t] FIFO overflow: occupancy %0d >= DEPTH", $time, wr_ptr - rd_ptr);
                    num_errors = num_errors + 1;
                end
                else if ((wr_ptr - rd_ptr) >= 3 * DEPTH / 4) begin
                    if(fifo_bus.almost_full !== 1'b1) begin
                        $error("[ERROR] [%0t] FIFO almost full should be asserted: occupancy %0D/%0D", $time, wr_ptr - rd_ptr, DEPTH);
                        num_errors = num_errors + 1;
                    end
                end
                // else if ((wr_ptr - rd_ptr) < 3 * DEPTH / 4) begin
                //     if(fifo_bus.almost_full !== 1'b0) begin
                //         $error("[ERROR] [%0t] FIFO almost full must be de-asserted: occupancy %0D/%0D", $time, wr_ptr - rd_ptr, DEPTH);
                //         num_errors = num_errors + 1;
                //     end
                // end
                wr_ptr = wr_ptr + 1;
                num_writes = num_writes + 1;
            end


        end
    end

    always @(posedge rd_clk) begin
        if (rrst_n && fifo_bus.rd_en && fifo_bus.empty === 1'b0) begin
            // $display("[%0t] READ accepted: %0h full: %0h almost_full: %0h empty: %0h almost empty: %0h",
            //                 $time, fifo_bus.rdata, fifo_bus.full, fifo_bus.almost_full, 
            //                 fifo_bus.empty, fifo_bus.almost_empty);


            num_reads = num_reads + 1;
            if (rd_ptr >= wr_ptr) begin
                // underflow: DUT accepted a read while the model is empty
                $error("[ERROR] [%0t] READ while empty", $time);
                num_errors = num_errors + 1;
            end
            else begin
                if (fifo_bus.rdata !== expected_queue[rd_ptr]) begin
                    // wrong read sequence
                    $error("[ERROR] [%0t] MISMATCH: read %0h, expected %0h",
                           $time, fifo_bus.rdata, expected_queue[rd_ptr]);
                    num_errors = num_errors + 1;
                end
                if ((wr_ptr - rd_ptr) <= DEPTH / 4) begin
                    if(fifo_bus.almost_empty !== 1'b1) begin
                        $error("[ERROR] [%0t] FIFO almost empty should be asserted: occupancy %0D/%0D", $time, wr_ptr-rd_ptr, DEPTH);
                        num_errors = num_errors + 1;
                    end
                end
                // if ((wr_ptr-rd_ptr) > DEPTH / 4) begin
                //     if(fifo_bus.almost_empty !== 1'b0) begin
                //         $error("[ERROR] [%0t] FIFO almost empty must be de-asserted: occupancy %0D/%0D", $time, wr_ptr-rd_ptr, DEPTH);
                //         num_errors = num_errors + 1;
                //     end
                // end
                rd_ptr = rd_ptr + 1; 

            end
        end
    end





endmodule
