//============================================================
// Sparsity Estimator — Counts zero elements in weights & acts
//============================================================

`include "hsa_params.svh"

module sparsity_estimator
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    // Weight loading monitor
    input  logic                                 load_weight,
    input  logic signed [DATA_WIDTH-1:0]         weight_in [0:ARRAY_SIZE-1],

    // Activation stream monitor
    input  logic                                 start,
    input  logic signed [DATA_WIDTH-1:0]         act_in    [0:ARRAY_SIZE-1],

    // Outputs
    output logic [8:0]                           weight_zero_cnt,
    output logic [8:0]                           act_zero_cnt
);

    //----------------------------------------------------------
    // 1. Weight Sparsity Counting (Dynamic during weight load)
    //----------------------------------------------------------
    logic [8:0] weight_zero_accum;
    logic [4:0] weight_zeros_comb;

    always_comb begin
        weight_zeros_comb = '0;
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (weight_in[i] == 8'sd0)
                weight_zeros_comb = weight_zeros_comb + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_zero_accum <= '0;
        end else if (load_weight) begin
            weight_zero_accum <= weight_zero_accum + weight_zeros_comb;
        end
    end

    assign weight_zero_cnt = weight_zero_accum;

    //----------------------------------------------------------
    // 2. Activation Sparsity Counting (First 16 cycles of compute)
    //----------------------------------------------------------
    logic [8:0] act_zero_accum;
    logic [4:0] cycle_cnt;
    logic [4:0] act_zeros_comb;

    always_comb begin
        act_zeros_comb = '0;
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (act_in[i] == 8'sd0)
                act_zeros_comb = act_zeros_comb + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_zero_accum <= '0;
            cycle_cnt      <= '0;
        end else if (start) begin
            cycle_cnt      <= 5'd1;
            act_zero_accum <= act_zeros_comb;
        end else if (cycle_cnt > 0 && cycle_cnt < ARRAY_SIZE) begin
            cycle_cnt      <= cycle_cnt + 1'b1;
            act_zero_accum <= act_zero_accum + act_zeros_comb;
        end else if (cycle_cnt == ARRAY_SIZE) begin
            cycle_cnt      <= '0; // stop counting
        end
    end

    assign act_zero_cnt = act_zero_accum;

endmodule
