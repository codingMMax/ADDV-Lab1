`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Self-checking testbench for alternating_circuit
// -----------------------------------------------------------------------------
// The testbench implements two timing cases from Case 9 of the FIFO-depth
// document. Each case lasts 200 input cycles and contains two 80-word blocks:
//
//   Case 3: WRITE[0:79], IDLE[80:99], WRITE[100:179], IDLE[180:199]
//   Case 4: IDLE[0:19], WRITE[20:179], IDLE[180:199]
//
// Thus every aligned 100-cycle window contains exactly 80 writes. read_en uses
// a repeating 1111111100 pattern, which requests 8 reads per 10 clock cycles.
// Read requests continue after input cycle 200 until all 160 words are drained.
//
// Test 1 combines Case 3 with two fixed random permutations. Test 2 combines
// Case 4 with even-then-odd followed by odd-then-even. The Case 4 data stream is
// therefore even[40], odd[80], even[40], stressing one parity FIFO strongly.
// -----------------------------------------------------------------------------
module tb_alternating_circuit;

    localparam int DATA_WIDTH          = 8;
    localparam int FIFO_ADDR_W         = 6;
    localparam int ITEMS_PER_BLOCK     = 80;
    localparam int ITEMS_PER_PARITY    = 40;
    localparam int BLOCKS_PER_TEST     = 2;
    localparam int TOTAL_TEST_ITEMS    = ITEMS_PER_BLOCK * BLOCKS_PER_TEST;
    localparam int TOTAL_INPUT_CYCLES  = 200;
    localparam int CLOCK_PERIOD_NS     = 10;

    localparam int CASE_3 = 3;
    localparam int CASE_4 = 4;

    logic clock = 1'b0;
    logic reset = 1'b1;

    always #(CLOCK_PERIOD_NS/2) clock = ~clock;
    
    // dump waveform
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_alternating_circuit,  "+mda");    // whole TB
    end

    initial begin
        #300000;
        $fatal(1, "[TB] TIMEOUT: alternating_circuit did not finish");
    end

    alternating_circuit_interface #(
        .DATA_WIDTH (DATA_WIDTH)
    ) circuit_bus (
        .clock (clock),
        .reset (reset)
    );

    alternating_circuit #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FIFO_ADDR_W (FIFO_ADDR_W)
    ) dut (
        .circuit_port (circuit_bus.circuit_side)
    );

    // Default assumes simulation is launched from Lab1/Part2/sim.
    // Running in another directory requires declaration of DATA_DIR
    // with +DATA_DIR=/absolute/or/relative/path.
    string data_directory = "../tb/data";

    initial begin
        string plusarg_directory;
        if ($value$plusargs("DATA_DIR=%s", plusarg_directory))
            data_directory = plusarg_directory;
    end

    // To test input timing patterns of 200 cycles in the FIFO size calculation document,
    // we should have two 80 input blocks.
    logic [DATA_WIDTH-1:0] input_block_1 [0:ITEMS_PER_BLOCK-1];
    logic [DATA_WIDTH-1:0] input_block_2 [0:ITEMS_PER_BLOCK-1];

    // Each test writes 80 even and 80 odd words in total.
    // These arrays hold the exact expected order within each parity FIFO.
    logic [DATA_WIDTH-1:0] expected_even [0:2*ITEMS_PER_PARITY-1];
    logic [DATA_WIDTH-1:0] expected_odd  [0:2*ITEMS_PER_PARITY-1];

    // Each test ends when output_count becomes 160. 
    integer output_count;
    integer even_output_count;
    integer odd_output_count;
    integer error_count;
    integer test_number;

    logic expected_output_odd;

    task automatic report_error(input string message);
        begin
            $error("[TB][test %0d][%0t] %s", test_number, $time, message);
            error_count = error_count + 1;
        end
    endtask

    // Load two 80 numbers arrays and build one reference sequence for each parity.
    task automatic load_input_blocks(
        input string first_file,
        input string second_file
    );
        integer block;
        integer index;
        integer even_index;
        integer odd_index;
        logic [DATA_WIDTH-1:0] value;
        begin
            $readmemh(first_file, input_block_1);
            $readmemh(second_file, input_block_2);

            even_index = 0;
            odd_index  = 0;

            for (block = 0; block < BLOCKS_PER_TEST; block = block + 1) begin
                // For each block (total 2 blocks),
                for (index = 0; index < ITEMS_PER_BLOCK; index = index + 1) begin
                    // we have 80 numbers.
                    if (block == 0)
                        value = input_block_1[index];
                    else
                        value = input_block_2[index];

                    if (value[0] == 1'b0) begin
                        // Put an even number to the array expected_even while preserving
                        // the order of even numbers.
                        expected_even[even_index] = value;
                        even_index = even_index + 1;
                    end
                    else begin
                        // Put an odd number to the array expected_odd while preserving
                        // the order of odd numbers.
                        expected_odd[odd_index] = value;
                        odd_index = odd_index + 1;
                    end
                end
            end
        end
    endtask

    // Active-low asynchronous reset. Requests remain low throughout reset.
    task automatic reset_dut;
        begin
            circuit_bus.data_in  = '0;
            circuit_bus.write_en = 1'b0;
            circuit_bus.read_en  = 1'b0;

            reset = 1'b0;
            repeat (4) @(posedge clock);  // Give four cycles for reset
            @(negedge clock);
            reset = 1'b1;
            @(posedge clock);
        end
    endtask

    // Define the write enable signal based on the case in the FIFO size calculation document.
    function automatic logic is_write_cycle(
        input integer timing_case,
        input integer cycle
    );
        begin
            case (timing_case)
                CASE_3:
                    is_write_cycle = ((cycle >= 0)   && (cycle < 80)) ||
                                     ((cycle >= 100) && (cycle < 180));

                CASE_4:
                    is_write_cycle = (cycle >= 20) && (cycle < 180);

                default:
                    is_write_cycle = 1'b0;
            endcase
        end
    endfunction

    // Drive one complete 200-cycle input timing case.
    task automatic drive_input_case(input integer timing_case);
        integer cycle;
        integer item_index;
        begin
            item_index = 0;

            // TOTAL_INPUT_CYCLES is 200.
            for (cycle = 0; cycle < TOTAL_INPUT_CYCLES; cycle = cycle + 1) begin
                @(negedge clock);

                if (is_write_cycle(timing_case, cycle)) begin
                    // Enable write and feed a number.
                    circuit_bus.write_en = 1'b1;
                    if (item_index < ITEMS_PER_BLOCK)
                        // First 80 numbers.
                        circuit_bus.data_in = input_block_1[item_index];
                    else
                        // Next 80 numbers.
                        circuit_bus.data_in = input_block_2[item_index-ITEMS_PER_BLOCK];

                    item_index = item_index + 1;
                end
                else begin
                    // Input is idel for 20 cycles per 100 cycles.
                    circuit_bus.write_en = 1'b0;
                    circuit_bus.data_in  = '0;
                end
            end

            @(negedge clock);
            // All inputs are fed.
            circuit_bus.write_en = 1'b0;
            circuit_bus.data_in  = '0;
        end
    endtask

    // Request eight reads per ten cycles.
    task automatic drive_read_requests;
        integer request_cycle;
        begin
            request_cycle = 0;
            while (output_count < TOTAL_TEST_ITEMS) begin
                // Until we read all 160 outputs,
                @(negedge clock);
                // we request read 8 cycles per 10 cycles.
                // The pattern is 1 1 1 1 1 1 1 1 0 0.
                circuit_bus.read_en = ((request_cycle % 10) < 8);
                request_cycle = request_cycle + 1;
            end

            @(negedge clock);
            circuit_bus.read_en = 1'b0;
        end
    endtask

    // The main task running tasks.
    task automatic run_test(
        input integer timing_case,
        input string test_name,
        input string first_filename,
        input string second_filename
    );
        string first_path;
        string second_path;
        begin
            test_number = test_number + 1;
            first_path  = $sformatf("%s/%s", data_directory, first_filename);
            second_path = $sformatf("%s/%s", data_directory, second_filename);

            $display("\n[TB] Starting test %0d: %s", test_number, test_name);
            $display("[TB]   block 1: %s", first_path);
            $display("[TB]   block 2: %s", second_path);

            // Keep the DUT in idle while preparing the inputs.
            reset                = 1'b0;
            circuit_bus.write_en = 1'b0;
            circuit_bus.read_en  = 1'b0;
            output_count         = 0;
            even_output_count    = 0;
            odd_output_count     = 0;
            expected_output_odd  = 1'b0;

            load_input_blocks(first_path, second_path); // Load inputs.
            reset_dut(); // Then, reset.

            fork
                drive_input_case(timing_case); // Feed inputs.
                drive_read_requests(); // Request read.
            join

            repeat (2) @(posedge clock);
            $display("[TB] Finished test %0d", test_number);
            $display("[TB]   outputs=%0d", output_count);
        end
    endtask

    // The calculated depth (64 buffers) should prevent either FIFO from ever reaching full.
    // Check whether any of the FIFO is full (which is an error).
    always @(posedge clock) begin
        if (reset) begin
            if (dut.u_store_input.even_fifo_bus.full)
                report_error("even FIFO full asserted");
            if (dut.u_store_input.odd_fifo_bus.full)
                report_error("odd FIFO full asserted");
        end
    end

    // Identify successful reads from the internal parity FIFO read enables.
    // data_out is registered, so comparison occurs 1 ps after the clock edge.
    always @(posedge clock) begin : output_monitor
        logic actual_even_read;
        logic actual_odd_read;
        logic read_succeeded;

        if (reset) begin
            actual_even_read  = dut.even_fifo_rd_en;
            actual_odd_read   = dut.odd_fifo_rd_en;
            read_succeeded    = actual_even_read || actual_odd_read; // There's a valid output.

            if (read_succeeded) begin
                if (actual_odd_read !== expected_output_odd)
                    // Check if the order is correct.
                    // Entering here means odd output is produced when even number should be produced.
                    report_error($sformatf(
                        "parity alternation error: expected %s read",
                        expected_output_odd ? "odd" : "even"));

                #1ps;
                if (actual_even_read) begin
                    if (even_output_count >= 2*ITEMS_PER_PARITY)
                        report_error("received more than 80 even outputs");
                    else if (circuit_bus.data_out !== expected_even[even_output_count])
                        // Compare the actual output value.
                        report_error($sformatf(
                            "even order mismatch at index %0d: got %0h expected %0h",
                            even_output_count, circuit_bus.data_out,
                            expected_even[even_output_count]));
                    even_output_count = even_output_count + 1;
                end
                else begin
                    if (odd_output_count >= 2*ITEMS_PER_PARITY)
                        report_error("received more than 80 odd outputs");
                    else if (circuit_bus.data_out !== expected_odd[odd_output_count])
                        // Compare the actual output value.
                        report_error($sformatf(
                            "odd order mismatch at index %0d: got %0h expected %0h",
                            odd_output_count, circuit_bus.data_out,
                            expected_odd[odd_output_count]));
                    odd_output_count = odd_output_count + 1;
                end

                output_count        = output_count + 1;
                expected_output_odd = !expected_output_odd;
            end
        end
    end

    initial begin
        circuit_bus.data_in  = '0;
        circuit_bus.write_en = 1'b0;
        circuit_bus.read_en  = 1'b0;
        reset                 = 1'b0;
        error_count          = 0;
        test_number          = 0;
        output_count         = 0;
        even_output_count    = 0;
        odd_output_count     = 0;
        expected_output_odd  = 1'b0;

        run_test(
            CASE_3,
            "Case 3 with two random 40-even/40-odd blocks",
            "random_1.dat",
            "random_2.dat"
        );

        run_test(
            CASE_4,
            "Case 4 with even[40], odd[80], even[40]",
            "even_then_odd.dat",
            "odd_then_even.dat"
        );

        if (error_count == 0) begin
            $display("\n[TB] PASS: Case 3 and Case 4 completed without errors");
            $finish;
        end
        else begin
            $fatal(1, "[TB] FAIL: %0d total error(s)", error_count);
        end
    end

endmodule
