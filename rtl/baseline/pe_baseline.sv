`timescale 1ns/1ps

//==============================================================================
// pe_baseline
//
// 3-Stage Pipelined Signed MAC Processing Element
//
// Stage 1 : Input Capture
// Stage 2 : Signed Multiply
// Stage 3 : Accumulate
//
// INT8 × INT8 -> INT16
// INT16 -> INT32 Sign Extension
// INT32 Accumulation
//
// Target:
//   - Cadence Genus
//   - Xcelium
//   - Synopsys DC
//
//==============================================================================

module pe_baseline
(
    //----------------------------------------------------------------------
    // Clock / Reset
    //----------------------------------------------------------------------
    input  logic               clk,
    input  logic               rst_n,

    //----------------------------------------------------------------------
    // Input Interface
    //----------------------------------------------------------------------
    input  logic               valid_in,

    input  logic signed [7:0]  act_in,
    input  logic signed [7:0]  weight_in,

    input  logic signed [31:0] psum_in,

    //----------------------------------------------------------------------
    // Output Interface
    //----------------------------------------------------------------------
    output logic               valid_out,

    output logic signed [7:0]  act_out,
    output logic signed [7:0]  weight_out,

    output logic signed [31:0] psum_out
);

    //==========================================================================
    // Stage 1 Registers
    //==========================================================================

    logic               s1_valid;
    logic signed [7:0]  s1_act;
    logic signed [7:0]  s1_weight;
    logic signed [31:0] s1_psum;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s1_valid  <= 1'b0;
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= '0;
        end
        else
        begin
            s1_valid  <= valid_in;
            s1_act    <= act_in;
            s1_weight <= weight_in;
            s1_psum   <= psum_in;
        end
    end

    //==========================================================================
    // Stage 2 Registers
    //==========================================================================

    logic               s2_valid;
    logic signed [7:0]  s2_act;
    logic signed [7:0]  s2_weight;

    logic signed [15:0] s2_prod;
    logic signed [31:0] s2_psum;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s2_valid  <= 1'b0;
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= '0;
        end
        else
        begin
            s2_valid  <= s1_valid;
            s2_act    <= s1_act;
            s2_weight <= s1_weight;

            // Signed Multiplier
            s2_prod   <= s1_act * s1_weight;

            s2_psum   <= s1_psum;
        end
    end

    //==========================================================================
    // Explicit Sign Extension
    //==========================================================================

    logic signed [31:0] s2_prod_ext;

    always_comb
    begin
        s2_prod_ext = {{16{s2_prod[15]}}, s2_prod};
    end

    //==========================================================================
    // Stage 3 Registers
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            valid_out  <= 1'b0;

            act_out    <= '0;
            weight_out <= '0;

            psum_out   <= '0;
        end
        else
        begin
            valid_out  <= s2_valid;

            act_out    <= s2_act;
            weight_out <= s2_weight;

            // Final Accumulation
            psum_out   <= s2_psum + s2_prod_ext;
        end
    end

endmodule
