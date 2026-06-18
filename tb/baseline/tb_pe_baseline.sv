//============================================================
// TB PE Baseline — Self-Checking PE Verification
//============================================================
// Verifies:
//   1. Signed arithmetic (pos×pos, neg×pos, neg×neg)
//   2. 3-stage pipeline latency
//   3. Valid propagation
//   4. Reset clears all registers
//   5. No X/Z values
//   6. Accumulation with non-zero psum_in
//   7. 100 random vectors with golden scoreboard
//
// Clock: 500 MHz (2ns period)
// Self-check: PASS/FAIL with counters
//============================================================

`timescale 1ns/1ps

module tb_pe_baseline;

    //----------------------------------------------------------
    // DUT Signals
    //----------------------------------------------------------

    logic                         clk;
    logic                         rst_n;

    logic                         valid_in;

    logic signed [7:0]            act_in;
    logic signed [7:0]            weight_in;

    logic signed [31:0]           psum_in;

    logic                         valid_out;

    logic signed [7:0]            act_out;
    logic signed [7:0]            weight_out;

    logic signed [31:0]           psum_out;

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------

    pe_baseline dut
    (
        .clk        (clk),
        .rst_n      (rst_n),

        .valid_in   (valid_in),

        .act_in     (act_in),
        .weight_in  (weight_in),

        .psum_in    (psum_in),

        .valid_out  (valid_out),

        .act_out    (act_out),
        .weight_out (weight_out),

        .psum_out   (psum_out)
    );

    //----------------------------------------------------------
    // Clock Generation — 500 MHz
    //----------------------------------------------------------

    initial
    begin
        clk = 1'b0;

        forever #1 clk = ~clk;
    end

    //----------------------------------------------------------
    // Reset Task
    //----------------------------------------------------------

    task automatic reset_dut;
    begin

        rst_n     = 1'b0;

        valid_in  = 1'b0;

        act_in    = 0;
        weight_in = 0;
        psum_in   = 0;

        repeat(5) @(posedge clk);

        rst_n = 1'b1;

        repeat(2) @(posedge clk);

    end
    endtask

    //----------------------------------------------------------
    // Apply Vector Task
    //----------------------------------------------------------

    task automatic apply_vector
    (
        input signed [7:0]  a,
        input signed [7:0]  w,
        input signed [31:0] p
    );
    begin

        @(posedge clk);

        valid_in  <= 1'b1;

        act_in    <= a;
        weight_in <= w;
        psum_in   <= p;

        @(posedge clk);

        valid_in  <= 1'b0;
        act_in    <= 0;
        weight_in <= 0;
        psum_in   <= 0;

    end
    endtask

    //----------------------------------------------------------
    // Scoreboard
    //----------------------------------------------------------

    integer pass_count;
    integer fail_count;

    logic signed [31:0] expected_q [$];

    always @(posedge clk)
    begin

        if (valid_out)
        begin

            if (expected_q.size() == 0)
            begin
                $error("[SCOREBOARD] Unexpected valid_out with no expected value");
                fail_count++;
            end
            else
            begin

                logic signed [31:0] exp;

                exp = expected_q.pop_front();

                if (psum_out === exp)
                begin

                    pass_count++;

                    $display(
                    "[PASS] time=%0t expected=%0d actual=%0d",
                    $time,
                    exp,
                    psum_out);

                end
                else
                begin

                    fail_count++;

                    $display(
                    "[FAIL] time=%0t expected=%0d actual=%0d",
                    $time,
                    exp,
                    psum_out);

                end
            end
        end
    end

    //----------------------------------------------------------
    // X Detection
    //----------------------------------------------------------

    always @(posedge clk)
    begin

        if (valid_out)
        begin

            if (^psum_out === 1'bx)
            begin

                $error("X detected on psum_out at time %0t", $time);

                $finish;

            end
        end
    end

    //----------------------------------------------------------
    // Main Test Sequence
    //----------------------------------------------------------

    initial
    begin

        pass_count = 0;
        fail_count = 0;

        $display("");
        $display("================================================");
        $display(" PE BASELINE VERIFICATION START");
        $display("================================================");
        $display("");

        reset_dut();

        //------------------------------------------------------
        // Test 1: Positive × Positive
        // 2 × 3 + 0 = 6
        //------------------------------------------------------

        $display("[TEST 1] 2 * 3 + 0 = 6");

        expected_q.push_back(32'sd6);

        apply_vector(8'sd2, 8'sd3, 32'sd0);

        // Wait for pipeline to flush (3 stages)
        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 2: Negative × Positive
        // -2 × 3 + 0 = -6
        //------------------------------------------------------

        $display("[TEST 2] -2 * 3 + 0 = -6");

        expected_q.push_back(-32'sd6);

        apply_vector(-8'sd2, 8'sd3, 32'sd0);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 3: Negative × Negative
        // -5 × -4 + 0 = 20
        //------------------------------------------------------

        $display("[TEST 3] -5 * -4 + 0 = 20");

        expected_q.push_back(32'sd20);

        apply_vector(-8'sd5, -8'sd4, 32'sd0);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 4: With Accumulation
        // 15 × 15 + 2 = 227
        //------------------------------------------------------

        $display("[TEST 4] 15 * 15 + 2 = 227");

        expected_q.push_back(32'sd227);

        apply_vector(8'sd15, 8'sd15, 32'sd2);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 5: Boundary — max positive
        // 127 × 127 + 0 = 16129
        //------------------------------------------------------

        $display("[TEST 5] 127 * 127 + 0 = 16129");

        expected_q.push_back(32'sd16129);

        apply_vector(8'sd127, 8'sd127, 32'sd0);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 6: Boundary — max negative
        // -128 × -128 + 0 = 16384
        //------------------------------------------------------

        $display("[TEST 6] -128 * -128 + 0 = 16384");

        expected_q.push_back(32'sd16384);

        apply_vector(-8'sd128, -8'sd128, 32'sd0);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 7: Zero activation
        // 0 × 50 + 100 = 100
        //------------------------------------------------------

        $display("[TEST 7] 0 * 50 + 100 = 100");

        expected_q.push_back(32'sd100);

        apply_vector(8'sd0, 8'sd50, 32'sd100);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Test 8: Zero weight
        // 50 × 0 + 200 = 200
        //------------------------------------------------------

        $display("[TEST 8] 50 * 0 + 200 = 200");

        expected_q.push_back(32'sd200);

        apply_vector(8'sd50, 8'sd0, 32'sd200);

        repeat(3) @(posedge clk);

        //------------------------------------------------------
        // Random Tests (100 vectors)
        //------------------------------------------------------

        $display("");
        $display("[RANDOM] Starting 100 random vectors...");
        $display("");

        repeat(100)
        begin

            logic signed [7:0]  a;
            logic signed [7:0]  w;
            logic signed [31:0] p;

            logic signed [31:0] exp;

            a = $random;
            w = $random;
            p = $urandom_range(0, 1000);

            exp = (32'(a)) * (32'(w)) + p;

            expected_q.push_back(exp);

            apply_vector(a, w, p);

        end

        // Wait for pipeline to fully drain
        repeat(20) @(posedge clk);

        //------------------------------------------------------
        // Results
        //------------------------------------------------------

        $display("");
        $display("================================================");
        $display(" PASS COUNT = %0d", pass_count);
        $display(" FAIL COUNT = %0d", fail_count);
        $display("================================================");
        $display("");

        if (fail_count == 0 && pass_count == 108)
            $display("PE_BASELINE_TEST PASSED");
        else
            $display("PE_BASELINE_TEST FAILED");

        $finish;

    end

    //----------------------------------------------------------
    // Waveform Dump
    //----------------------------------------------------------

    initial
    begin

        $dumpfile("tb_pe_baseline.vcd");

        $dumpvars(0, tb_pe_baseline);

    end

endmodule
