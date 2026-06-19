//============================================================
// PE Adaptive — Dynamic Sparsity-Aware Processing Element
//============================================================

`include "hsa_params.svh"

module pe_adaptive
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    // Gating Mode Controls
    input  logic                                 mode_pe_gating,
    input  logic                                 mode_row_gating,
    input  logic                                 mode_tile_gating,

    // Gating Enables from Detectors
    input  logic                                 tile_gate_en,

    // Dataflow Inputs
    input  logic                                 valid_in,
    input  logic signed [DATA_WIDTH-1:0]         act_in,
    input  logic signed [DATA_WIDTH-1:0]         weight_in,
    input  logic signed [ACC_WIDTH-1:0]          psum_in,

    // Dataflow Outputs
    output logic                                 valid_out,
    output logic signed [DATA_WIDTH-1:0]         act_out,
    output logic signed [DATA_WIDTH-1:0]         weight_out,
    output logic signed [ACC_WIDTH-1:0]          psum_out,

    // Stats Counters
    output logic [31:0]                          tile_gated_cnt,
    output logic [31:0]                          row_gated_cnt,
    output logic [31:0]                          pe_gated_cnt,
    output logic [31:0]                          exec_cnt
);

    //----------------------------------------------------------
    // 1. History-Based Zero Predictor (2-bit History Register)
    //----------------------------------------------------------
    logic [1:0] act_history;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_history <= 2'b00;
        end else if (valid_in) begin
            act_history <= {act_history[0], act_in == 8'sd0};
        end
    end

    wire predict_zero = (act_history == 2'b11);

    // Gating Decisions
    wire row_gate_active  = mode_row_gating  ? (predict_zero && (act_in == 8'sd0)) : 1'b0;
    wire tile_gate_active = mode_tile_gating ? !tile_gate_en : 1'b0;

    // Registers Gated status
    wire gate_regs = valid_in && (tile_gate_active || row_gate_active);

    //----------------------------------------------------------
    // 2. Stage 1 Registers
    //----------------------------------------------------------
    logic                                 s1_valid;
    logic signed [DATA_WIDTH-1:0]         s1_act;
    logic signed [DATA_WIDTH-1:0]         s1_weight;
    logic signed [ACC_WIDTH-1:0]          s1_psum;
    logic                                 s1_gated;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid  <= 1'b0;
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= '0;
            s1_gated  <= 1'b0;
        end else begin
            s1_valid  <= valid_in; // Always propagate valid wavefront
            s1_psum   <= psum_in;  // Always propagate partial sum
            s1_gated  <= gate_regs;
            if (gate_regs) begin
                s1_act    <= '0;
                s1_weight <= '0;
            end else begin
                s1_act    <= act_in;
                s1_weight <= weight_in;
            end
        end
    end

    //----------------------------------------------------------
    // 3. Stage 2 Registers & Operand Isolation
    //----------------------------------------------------------
    logic                                 s2_valid;
    logic signed [DATA_WIDTH-1:0]         s2_act;
    logic signed [DATA_WIDTH-1:0]         s2_weight;
    logic signed [ACC_WIDTH-1:0]          s2_psum;
    logic signed [DATA_WIDTH*2-1:0]       s2_prod;
    logic                                 s2_gated;

    // Operand Isolation for multiplier inputs
    wire pe_gate_active = mode_pe_gating ? (s1_weight == 8'sd0) : 1'b0;
    wire mac_en = s1_valid && !pe_gate_active && !s1_gated;
    wire signed [DATA_WIDTH-1:0] mult_a = mac_en ? s1_act : 8'sd0;
    wire signed [DATA_WIDTH-1:0] mult_b = mac_en ? s1_weight : 8'sd0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid  <= 1'b0;
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= '0;
            s2_gated  <= 1'b0;
        end else begin
            s2_valid  <= s1_valid; // Always propagate valid
            s2_psum   <= s1_psum;  // Always propagate partial sum
            s2_prod   <= mult_a * mult_b;
            s2_gated  <= s1_gated;
            if (s1_gated) begin
                s2_act    <= '0;
                s2_weight <= '0;
            end else begin
                s2_act    <= s1_act;
                s2_weight <= s1_weight;
            end
        end
    end

    //----------------------------------------------------------
    // 4. Stage 3 Registers & Accumulation
    //----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out  <= 1'b0;
            act_out    <= '0;
            weight_out <= '0;
            psum_out   <= '0;
        end else begin
            valid_out  <= s2_valid;
            act_out    <= s2_act;
            weight_out <= s2_weight;
            psum_out   <= s2_psum + {{16{s2_prod[15]}}, s2_prod};
        end
    end

    //----------------------------------------------------------
    // 5. Statistics Counters
    //----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_gated_cnt <= '0;
            row_gated_cnt  <= '0;
            pe_gated_cnt   <= '0;
            exec_cnt       <= '0;
        end else if (valid_in) begin
            if (mode_tile_gating && tile_gate_active) begin
                tile_gated_cnt <= tile_gated_cnt + 1'b1;
            end else if (mode_row_gating && row_gate_active) begin
                row_gated_cnt  <= row_gated_cnt + 1'b1;
            end else if (mode_pe_gating && (s1_weight == 8'sd0) && !gate_regs) begin
                pe_gated_cnt   <= pe_gated_cnt + 1'b1;
            end else if (!gate_regs) begin
                exec_cnt       <= exec_cnt + 1'b1;
            end
        end
    end

endmodule
