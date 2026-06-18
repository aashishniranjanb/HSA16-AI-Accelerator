`timescale 1ns/1ps

//==============================================================================
// pe_row_gated
//
// 3-Stage Pipelined Signed MAC Processing Element with Row-Gating clock enables
//==============================================================================

module pe_row_gated
(
    input  logic               clk,
    input  logic               rst_n,

    input  logic               valid_in,

    input  logic signed [7:0]  act_in,
    input  logic signed [7:0]  weight_in,

    input  logic signed [31:0] psum_in,

    output logic               valid_out,

    output logic signed [7:0]  act_out,
    output logic signed [7:0]  weight_out,

    output logic signed [31:0] psum_out
);

    //==========================================================================
    // Gating Detection
    //==========================================================================
    wire row_active = valid_in && (act_in != 8'sd0);

    //==========================================================================
    // Stage 1 Registers
    //==========================================================================

    logic               s1_valid;
    logic signed [7:0]  s1_act;
    logic signed [7:0]  s1_weight;
    logic signed [31:0] s1_psum;
    logic               s1_row_active;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s1_valid      <= 1'b0;
            s1_act        <= '0;
            s1_weight     <= '0;
            s1_psum       <= '0;
            s1_row_active <= 1'b0;
        end
        else if (row_active || valid_in) // Clock enable style gating
        begin
            s1_valid      <= valid_in;
            s1_act        <= act_in;
            s1_weight     <= weight_in;
            s1_psum       <= psum_in;
            s1_row_active <= row_active;
        end
        else
        begin
            s1_valid      <= 1'b0;
            s1_act        <= '0;
            s1_weight     <= '0;
            s1_psum       <= psum_in; // psum must always propagate
            s1_row_active <= 1'b0;
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
    logic               s2_row_active;

    // Operand Isolation
    wire signed [7:0] s1_act_iso    = s1_row_active ? s1_act : 8'sd0;
    wire signed [7:0] s1_weight_iso = s1_row_active ? s1_weight : 8'sd0;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s2_valid      <= 1'b0;
            s2_act        <= '0;
            s2_weight     <= '0;
            s2_prod       <= '0;
            s2_psum       <= '0;
            s2_row_active <= 1'b0;
        end
        else if (s1_row_active || s1_valid)
        begin
            s2_valid      <= s1_valid;
            s2_act        <= s1_act;
            s2_weight     <= s1_weight;
            s2_psum       <= s1_psum;
            s2_row_active <= s1_row_active;

            if (s1_row_active)
                s2_prod   <= s1_act_iso * s1_weight_iso;
            else
                s2_prod   <= '0;
        end
        else
        begin
            s2_valid      <= 1'b0;
            s2_act        <= '0;
            s2_weight     <= '0;
            s2_prod       <= '0;
            s2_psum       <= s1_psum; // psum must always propagate
            s2_row_active <= 1'b0;
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
    // Stage 3 Registers & Accumulate
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

            if (s2_row_active)
                psum_out <= s2_psum + s2_prod_ext;
            else
                psum_out <= s2_psum;
        end
    end

endmodule
