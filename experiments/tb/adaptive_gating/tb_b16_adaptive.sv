//============================================================
// TB B16 Adaptive — Adaptive Gating Systolic Array Verification
//============================================================

`timescale 1ns/1ps

module tb_b16_adaptive;

    localparam N = 16;

    //----------------------------------------------------------
    // DUT Signals
    //----------------------------------------------------------

    logic                  clk;
    logic                  rst_n;

    logic [2:0]            host_mode_sel;
    logic [1:0]            active_policy;

    logic                  load_weight;
    logic [3:0]            weight_row_sel;
    logic signed [7:0]     weight_in [0:N-1];

    logic                  start;
    logic signed [7:0]     act_in    [0:N-1];

    logic                  done;
    logic signed [31:0]    result    [0:N-1][0:N-1];

    logic [31:0]           total_tile_gated;
    logic [31:0]           total_row_gated;
    logic [31:0]           total_pe_gated;
    logic [31:0]           total_exec;

    //----------------------------------------------------------
    // Test Vector Memories
    //----------------------------------------------------------

    logic signed [7:0]     A_mem     [0:N*N-1];
    logic signed [7:0]     B_mem     [0:N*N-1];
    logic signed [31:0]    C_expected[0:N*N-1];

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------

    systolic16x16_adaptive dut
    (
        .clk              (clk),
        .rst_n            (rst_n),

        .host_mode_sel    (host_mode_sel),
        .active_policy    (active_policy),

        .load_weight      (load_weight),
        .weight_row_sel   (weight_row_sel),
        .weight_in        (weight_in),

        .start            (start),
        .act_in           (act_in),

        .done             (done),
        .result           (result),

        .total_tile_gated (total_tile_gated),
        .total_row_gated  (total_row_gated),
        .total_pe_gated   (total_pe_gated),
        .total_exec       (total_exec)
    );

    //----------------------------------------------------------
    // Clock — 500 MHz
    //----------------------------------------------------------

    initial
    begin
        clk = 1'b0;
        forever #1 clk = ~clk;
    end

    //----------------------------------------------------------
    // Scoreboard
    //----------------------------------------------------------

    integer total_pass;
    integer total_fail;
    integer test_pass;
    integer test_fail;

    //----------------------------------------------------------
    // Reset Task
    //----------------------------------------------------------

    task automatic reset_dut;
    begin
        rst_n        = 1'b0;
        load_weight  = 1'b0;
        weight_row_sel = '0;
        start        = 1'b0;

        for (int i = 0; i < N; i++)
        begin
            weight_in[i] = '0;
            act_in[i]    = '0;
        end

        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
    end
    endtask

    //----------------------------------------------------------
    // Load Weights from Memory
    //----------------------------------------------------------

    task automatic load_weights_from_mem;
    begin
        for (int row = 0; row < N; row++)
        begin
            @(posedge clk);
            load_weight    <= 1'b1;
            weight_row_sel <= row[3:0];

            for (int col = 0; col < N; col++)
                weight_in[col] <= B_mem[row * N + col];
        end

        @(posedge clk);
        load_weight <= 1'b0;
        repeat(2) @(posedge clk);
    end
    endtask

    //----------------------------------------------------------
    // Stream Activations
    //----------------------------------------------------------

    task automatic stream_activations_from_mem;
    begin
        @(posedge clk);
        start <= 1'b1;

        for (int i = 0; i < N; i++)
        begin
            for (int k = 0; k < N; k++)
                act_in[k] <= A_mem[i * N + k];

            @(posedge clk);
            if (i == 0)
                start <= 1'b0;
        end

        for (int k = 0; k < N; k++)
            act_in[k] <= '0;
    end
    endtask

    //----------------------------------------------------------
    // Test data arrays for identity and ones tests
    //----------------------------------------------------------
    logic signed [7:0]  test_A [0:N*N-1];
    logic signed [7:0]  test_B [0:N*N-1];
    logic signed [31:0] test_C [0:N*N-1];

    task automatic load_weights_array;
    begin
        for (int row = 0; row < N; row++)
        begin
            @(posedge clk);
            load_weight    <= 1'b1;
            weight_row_sel <= row[3:0];
            for (int col = 0; col < N; col++)
                weight_in[col] <= test_B[row * N + col];
        end
        @(posedge clk);
        load_weight <= 1'b0;
        repeat(2) @(posedge clk);
    end
    endtask

    task automatic stream_activations_array;
    begin
        @(posedge clk);
        start <= 1'b1;
        for (int i = 0; i < N; i++)
        begin
            for (int k = 0; k < N; k++)
                act_in[k] <= test_A[i * N + k];
            @(posedge clk);
            if (i == 0)
                start <= 1'b0;
        end
        for (int k = 0; k < N; k++)
            act_in[k] <= '0;
    end
    endtask

    task automatic check_results_array(
        input string test_name
    );
    begin
        test_pass = 0;
        test_fail = 0;
        for (int i = 0; i < N; i++)
        begin
            for (int j = 0; j < N; j++)
            begin
                if (dut.result[i][j] === test_C[i * N + j])
                begin
                    test_pass++;
                    total_pass++;
                end
                else
                begin
                    test_fail++;
                    total_fail++;
                    $display("[FAIL] %s: C[%0d][%0d] expected=%0d got=%0d",
                        test_name, i, j, test_C[i * N + j], dut.result[i][j]);
                end
            end
        end
        $display("[%s] %s: %0d/%0d passed",
            (test_fail == 0) ? "PASS" : "FAIL", test_name, test_pass, test_pass + test_fail);
    end
    endtask

    //----------------------------------------------------------
    // Check Results Against Expected
    //----------------------------------------------------------

    task automatic check_results_mem(
        input string test_name
    );
    begin
        test_pass = 0;
        test_fail = 0;

        for (int i = 0; i < N; i++)
        begin
            for (int j = 0; j < N; j++)
            begin
                if (dut.result[i][j] === C_expected[i * N + j])
                begin
                    test_pass++;
                    total_pass++;
                end
                else
                begin
                    test_fail++;
                    total_fail++;
                    $display("[FAIL] %s: C[%0d][%0d] expected=%0d got=%0d",
                        test_name, i, j, C_expected[i * N + j], dut.result[i][j]);
                end
            end
        end

        $display("[%s] %s: %0d/%0d passed",
            (test_fail == 0) ? "PASS" : "FAIL", test_name, test_pass, test_pass + test_fail);
    end
    endtask

    //----------------------------------------------------------
    // X Detection
    //----------------------------------------------------------

    always @(posedge clk)
    begin
        if (done)
        begin
            for (int i = 0; i < N; i++)
            begin
                for (int j = 0; j < N; j++)
                begin
                    if (^dut.result[i][j] === 1'bx)
                    begin
                        $error("X detected at result[%0d][%0d]", i, j);
                        $finish;
                    end
                end
            end
        end
    end

    //----------------------------------------------------------
    // Workload Runner Task
    //----------------------------------------------------------
    task automatic run_workload(input string name);
    begin
        $readmemh({"vectors/", name, "/A_matrix.mem"}, A_mem);
        $readmemh({"vectors/", name, "/B_matrix.mem"}, B_mem);
        $readmemh({"vectors/", name, "/C_expected.mem"}, C_expected);

        reset_dut();
        load_weights_from_mem();
        stream_activations_from_mem();

        wait(done);
        @(posedge clk);

        check_results_mem(name);
    end
    endtask

    // Helper function to return policy string
    function string get_policy_string(input [1:0] policy);
        case (policy)
            2'b11: return "Tile Gating";
            2'b10: return "Row Gating";
            2'b01: return "PE Gating";
            2'b00: return "Hierarchical";
            default: return "Unknown";
        endcase
    endfunction

    //----------------------------------------------------------
    // Main Test Sequence
    //----------------------------------------------------------

    initial
    begin
        total_pass = 0;
        total_fail = 0;
        host_mode_sel = 3'b000; // Autonomous Mode

        $display("");
        $display("==========================================================================");
        $display(" B16 ADAPTIVE GATING ARRAY VERIFICATION START");
        $display("==========================================================================");
        $display("");

        reset_dut();

        //------------------------------------------------------
        // Test 1: Identity Matrix
        //------------------------------------------------------
        $display("--- Test 1: Identity Matrix ---");
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                test_A[i * N + j] = ((i * N + j) % 256) - 128;
                test_B[i * N + j] = (i == j) ? 8'sd1 : 8'sd0;
                test_C[i * N + j] = test_A[i * N + j];
            end
        end
        load_weights_array();
        stream_activations_array();
        wait(done);
        @(posedge clk);
        check_results_array("Identity");
        $display("Dynamic Mode Selected: %s", get_policy_string(active_policy));
        reset_dut();

        //------------------------------------------------------
        // Test 2: All-Ones Matrix
        //------------------------------------------------------
        $display("--- Test 2: All-Ones Matrix ---");
        for (int i = 0; i < N * N; i++) begin
            test_A[i] = 8'sd1;
            test_B[i] = 8'sd1;
            test_C[i] = 32'sd16;
        end
        load_weights_array();
        stream_activations_array();
        wait(done);
        @(posedge clk);
        check_results_array("All-Ones");
        $display("Dynamic Mode Selected: %s", get_policy_string(active_policy));
        reset_dut();

        //------------------------------------------------------
        // Run Workloads under Autonomous Mode and print stats
        //------------------------------------------------------
        $display("\n=========================================================================================================");
        $display(" ADAPTIVE GATING WORKLOAD CHARACTERIZATION (AUTONOMOUS MODE)");
        $display("=========================================================================================================");
        $display("Workload     | Selected Mode | Tile Gated | Row Gated | PE Gated | Executed | Total MACs | Zeros (W/A)");
        $display("---------------------------------------------------------------------------------------------------------");

        // 1. Dense
        run_workload("dense");
        $display("Dense        | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 2. Sparse50
        run_workload("sparse50");
        $display("Sparse50     | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 3. Sparse70
        run_workload("sparse70");
        $display("Sparse70     | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 4. Sparse90
        run_workload("sparse90");
        $display("Sparse90     | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 5. Sparse95
        run_workload("sparse95");
        $display("Sparse95     | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 6. AlexNet
        run_workload("alexnet");
        $display("AlexNet      | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 7. VGG16
        run_workload("vgg16");
        $display("VGG16        | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 8. ResNet18
        run_workload("resnet18");
        $display("ResNet18     | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 9. MobileNetV2
        run_workload("mobilenetv2");
        $display("MobileNetV2  | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        // 10. EfficientNet-B0
        run_workload("efficientnet_b0");
        $display("EfficientNet | %13s | %10d | %9d | %8d | %8d | %10d | %d/%d", 
            get_policy_string(active_policy), total_tile_gated, total_row_gated, total_pe_gated, total_exec, 4096,
            dut.weight_zero_cnt, dut.act_zero_cnt);

        $display("=========================================================================================================");
        $display(" TOTAL PASS = %0d", total_pass);
        $display(" TOTAL FAIL = %0d", total_fail);
        $display("=========================================================================================================");

        if (total_fail == 0)
            $display("ADAPTIVE_GATED_B16_TEST PASSED");
        else
            $display("ADAPTIVE_GATED_B16_TEST FAILED");

        $finish;
    end

    initial
    begin
        $dumpfile("flow/xrun/adaptive.vcd");
        $dumpvars(0, tb_b16_adaptive);
    end

endmodule
