`timescale 1ns/1ps

//==============================================================================
// pe_hierarchical
//
// 3-Stage Pipelined Signed MAC Processing Element with Hierarchical Gating
// (Tile Gating + Row Gating + PE Gating) and statistics counters.
//==============================================================================

module pe_hierarchical
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

    output logic signed [31:0] psum_out,

    // Statistics Counters
    output logic [31:0]        tile_gated_cnt,
    output logic [31:0]        row_gated_cnt,
    output logic [31:0]        pe_gated_cnt,
    output logic [31:0]        exec_cnt
);

    // Gating Hierarchy condition for clock-enabling input registers
    // Tile Gating and Row Gating gate the input registers because activation is zero.
    // PE Gating (weight == 0) does NOT gate activation propagation.
    wire active = valid_in && tile_gate_en && (act_in != 8'sd0);

    //==========================================================================
    // Stage 1 Registers
    //==========================================================================

    logic               s1_valid;
    logic signed [7:0]  s1_act;
    logic signed [7:0]  s1_weight;
    logic signed [31:0] s1_psum;
    logic               s1_mac_en;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s1_valid  <= 1'b0;
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= '0;
            s1_mac_en <= 1'b0;
        end
        else if (active)
        begin
            s1_valid  <= valid_in;
            s1_act    <= act_in;
            s1_weight <= weight_in;
            s1_psum   <= psum_in;
            s1_mac_en <= (weight_in != 8'sd0); // Only compute if weight is non-zero
        end
        else
        begin
            s1_valid  <= valid_in; // propagate valid wavefront
            s1_act    <= '0;
            s1_weight <= '0;
            s1_psum   <= psum_in;   // propagate partial sum
            s1_mac_en <= 1'b0;
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

    // Operand Isolation
    wire signed [7:0] s1_act_iso    = s1_mac_en ? s1_act : 8'sd0;
    wire signed [7:0] s1_weight_iso = s1_mac_en ? s1_weight : 8'sd0;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            s2_valid  <= 1'b0;
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= '0;
            s2_mac_en <= 1'b0;
        end
        else if (s1_valid)
        begin
            s2_valid  <= s1_valid;
            s2_act    <= s1_act;
            s2_weight <= s1_weight;
            s2_psum   <= s1_psum;
            s2_mac_en <= s1_mac_en;
            if (s1_mac_en)
                s2_prod   <= s1_act_iso * s1_weight_iso;
            else
                s2_prod   <= '0;
        end
        else
        begin
            s2_valid  <= 1'b0;
            s2_act    <= '0;
            s2_weight <= '0;
            s2_prod   <= '0;
            s2_psum   <= s1_psum;   // propagate partial sum
            s2_mac_en <= 1'b0;
        end
    end

    //==========================================================================
    // Explicit Sign Extension
    //==========================================================================

    logic signed [31:0] s2_prod_ext;
    assign s2_prod_ext = {{16{s2_prod[15]}}, s2_prod};

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
            tile_gated_cnt  <= '0;
            row_gated_cnt   <= '0;
            pe_gated_cnt    <= '0;
            exec_cnt        <= '0;
        end
        else if (valid_in)
        begin
            if (!tile_gate_en)
                tile_gated_cnt <= tile_gated_cnt + 1'b1;
            else if (act_in == 8'sd0)
                row_gated_cnt  <= row_gated_cnt + 1'b1;
            else if (weight_in == 8'sd0)
                pe_gated_cnt   <= pe_gated_cnt + 1'b1;
            else
                exec_cnt       <= exec_cnt + 1'b1;
        end
    end

endmodule
