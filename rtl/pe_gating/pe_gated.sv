`timescale 1ns/1ps

//==============================================================================
// pe_gated
//
// 3-Stage Pipelined Signed MAC Processing Element with PE Gating (Zero-Operand Gating)
//
// Stage 1 : Input Capture & Zero Detection
// Stage 2 : Signed Multiply with Operand Isolation
// Stage 3 : Conditional Accumulate
//==============================================================================

module pe_gated
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

    output logic signed [31:0] psum_out,

    //----------------------------------------------------------------------
    // Statistics Counters
    //----------------------------------------------------------------------
    output logic [31:0]        gated_mac_cnt,
    output logic [31:0]        executed_mac_cnt
);

    //==========================================================================
    // Stage 1 Registers & Gating Logic
    //==========================================================================

    logic               s1_valid;
    logic signed [7:0]  s1_act;
    logic signed [7:0]  s1_weight;
    logic signed [31:0] s1_psum;
    logic               s1_mac_en;

    // Zero operand detection at input
    wire mac_en_in = valid_in && (act_in != 8'sd0) && (weight_in != 8'sd0);

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s1_valid   <= 1'b0;
            s1_act     <= '0;
            s1_weight  <= '0;
            s1_psum    <= '0;
            s1_mac_en  <= 1'b0;
        end
        else
        begin
            s1_valid   <= valid_in;
            s1_act     <= act_in;
            s1_weight  <= weight_in;
            s1_psum    <= psum_in;
            s1_mac_en  <= mac_en_in;
        end
    end

    //==========================================================================
    // Stage 2 Registers & Operand Isolation
    //==========================================================================

    logic               s2_valid;
    logic signed [7:0]  s2_act;
    logic signed [7:0]  s2_weight;
    logic signed [15:0] s2_prod;
    logic signed [31:0] s2_psum;
    logic               s2_mac_en;

    // Operand Isolation: force multiplier inputs to zero when disabled
    wire signed [7:0] s1_act_iso    = s1_mac_en ? s1_act : 8'sd0;
    wire signed [7:0] s1_weight_iso = s1_mac_en ? s1_weight : 8'sd0;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s2_valid   <= 1'b0;
            s2_act     <= '0;
            s2_weight  <= '0;
            s2_prod    <= '0;
            s2_psum    <= '0;
            s2_mac_en  <= 1'b0;
        end
        else
        begin
            s2_valid   <= s1_valid;
            s2_act     <= s1_act;
            s2_weight  <= s1_weight;
            s2_psum    <= s1_psum;
            s2_mac_en  <= s1_mac_en;

            // Conditional multiplication to save dynamic toggle power
            if (s1_mac_en)
                s2_prod <= s1_act_iso * s1_weight_iso;
            else
                s2_prod <= '0;
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
    // Stage 3 Registers & Conditional Accumulate
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

            // Gated accumulation path
            if (s2_mac_en)
                psum_out <= s2_psum + s2_prod_ext;
            else
                psum_out <= s2_psum;
        end
    end

    //==========================================================================
    // Statistics Counters
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            gated_mac_cnt     <= '0;
            executed_mac_cnt  <= '0;
        end
        else if (valid_in)
        begin
            if (mac_en_in)
                executed_mac_cnt <= executed_mac_cnt + 1'b1;
            else
                gated_mac_cnt    <= gated_mac_cnt + 1'b1;
        end
    end

endmodule
