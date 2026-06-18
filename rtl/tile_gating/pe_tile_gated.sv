`timescale 1ns/1ps

//==============================================================================
// pe_tile_gated
//
// 3-Stage Pipelined Signed MAC Processing Element with Tile Gating Enable
//==============================================================================

module pe_tile_gated
(
    input  logic               clk,
    input  logic               rst_n,

    input  logic               valid_in,

    input  logic signed [7:0]  act_in,
    input  logic signed [7:0]  weight_in,

    input  logic signed [31:0] psum_in,

    input  logic               tile_gate_en, // 1: enabled, 0: gated/disabled

    output logic               valid_out,

    output logic signed [7:0]  act_out,
    output logic signed [7:0]  weight_out,

    output logic signed [31:0] psum_out
);

    // Gating condition: dynamic activation valid and tile gate enable
    wire active = valid_in && tile_gate_en;

    //==========================================================================
    // Stage 1 Registers
    //==========================================================================

    logic               s1_valid;
    logic signed [7:0]  s1_act;
    logic signed [7:0]  s1_weight;
    logic signed [31:0] s1_psum;
    logic               s1_active;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s1_valid  <= 1'b0;
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= '0;
            s1_active <= 1'b0;
        end
        else if (active)
        begin
            s1_valid  <= valid_in;
            s1_act    <= act_in;
            s1_weight <= weight_in;
            s1_psum   <= psum_in;
            s1_active <= 1'b1;
        end
        else
        begin
            s1_valid  <= valid_in; // propagate valid wavefront
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= psum_in;   // propagate partial sum
            s1_active <= 1'b0;
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
    logic               s2_active;

    // Operand Isolation
    wire signed [7:0] s1_act_iso    = s1_active ? s1_act : 8'sd0;
    wire signed [7:0] s1_weight_iso = s1_active ? s1_weight : 8'sd0;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s2_valid  <= 1'b0;
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= '0;
            s2_active <= 1'b0;
        end
        else if (s1_active)
        begin
            s2_valid  <= s1_valid;
            s2_act    <= s1_act;
            s2_weight <= s1_weight;
            s2_psum   <= s1_psum;
            s2_active <= s1_active;
            s2_prod   <= s1_act_iso * s1_weight_iso;
        end
        else
        begin
            s2_valid  <= s1_valid; // propagate valid wavefront
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= s1_psum;   // propagate partial sum
            s2_active <= 1'b0;
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

            if (s2_active)
                psum_out <= s2_psum + s2_prod_ext;
            else
                psum_out <= s2_psum;
        end
    end

endmodule
