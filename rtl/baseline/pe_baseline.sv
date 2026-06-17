//============================================================
// PE Baseline — 3-Stage Pipelined Processing Element
//============================================================
// Weight-Stationary INT8×INT8 → INT32 MAC unit
//
// Pipeline:
//   Stage 1: Input registers   (act_reg, weight_reg)
//   Stage 2: Multiplier        (product_reg <= act_reg * weight_reg)
//   Stage 3: Accumulator       (psum_reg <= psum_in + product_reg)
//
// Dataflow:
//   Activations  → pass right  (act_out = act_reg, 1-cycle delayed)
//   Weights      → pass down   (weight_out = weight_reg, 1-cycle delayed)
//   Partial sums → pass down   (psum_out = psum_reg, 3-cycle delayed)
//
// Reset: Asynchronous active-low
// Target: 500 MHz, TSMC 28nm
//============================================================

`include "hsa_params.svh"

module pe_baseline
(
    input  logic                          clk,
    input  logic                          rst_n,

    // Control
    input  logic                          valid_in,

    // Data inputs
    input  logic signed [DATA_WIDTH-1:0]  act_in,
    input  logic signed [DATA_WIDTH-1:0]  weight_in,
    input  logic signed [ACC_WIDTH-1:0]   psum_in,

    // Control output
    output logic                          valid_out,

    // Data outputs — pass-through for systolic connectivity
    output logic signed [DATA_WIDTH-1:0]  act_out,
    output logic signed [DATA_WIDTH-1:0]  weight_out,

    // Accumulated result
    output logic signed [ACC_WIDTH-1:0]   psum_out
);

    //----------------------------------------------------------
    // Internal Registers
    //----------------------------------------------------------

    // Stage 1: Input registers
    logic signed [DATA_WIDTH-1:0]    act_reg;
    logic signed [DATA_WIDTH-1:0]    weight_reg;

    // Stage 2: Multiplier output
    logic signed [PRODUCT_WIDTH-1:0] product_reg;

    // Stage 3: Accumulator output
    logic signed [ACC_WIDTH-1:0]     psum_reg;

    // Valid pipeline
    logic valid_s1;
    logic valid_s2;
    logic valid_s3;

    // Stage 2 needs delayed psum_in to align with product_reg
    logic signed [ACC_WIDTH-1:0]     psum_in_s1;
    logic signed [ACC_WIDTH-1:0]     psum_in_s2;

    //----------------------------------------------------------
    // Stage 1 — Input Register
    //----------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            act_reg    <= '0;
            weight_reg <= '0;
            valid_s1   <= 1'b0;
            psum_in_s1 <= '0;
        end
        else
        begin
            act_reg    <= act_in;
            weight_reg <= weight_in;
            valid_s1   <= valid_in;
            psum_in_s1 <= psum_in;
        end
    end

    //----------------------------------------------------------
    // Stage 2 — Multiplier
    //----------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            product_reg <= '0;
            valid_s2    <= 1'b0;
            psum_in_s2  <= '0;
        end
        else
        begin
            product_reg <= act_reg * weight_reg;
            valid_s2    <= valid_s1;
            psum_in_s2  <= psum_in_s1;
        end
    end

    //----------------------------------------------------------
    // Stage 3 — Accumulator
    //----------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            psum_reg <= '0;
            valid_s3 <= 1'b0;
        end
        else
        begin
            psum_reg <= psum_in_s2 + {{(ACC_WIDTH-PRODUCT_WIDTH){product_reg[PRODUCT_WIDTH-1]}}, product_reg};
            valid_s3 <= valid_s2;
        end
    end

    //----------------------------------------------------------
    // Output Assignments
    //----------------------------------------------------------

    // Systolic pass-through (1-cycle delayed)
    assign act_out    = act_reg;
    assign weight_out = weight_reg;

    // Accumulated result (3-cycle delayed)
    assign psum_out   = psum_reg;

    // Valid output
    assign valid_out  = valid_s3;

endmodule
