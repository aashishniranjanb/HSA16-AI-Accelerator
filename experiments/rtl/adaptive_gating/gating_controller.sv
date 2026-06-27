//============================================================
// Gating Controller — Selects gating mode dynamically via FSM
//============================================================

`include "hsa_params.svh"

module gating_controller
#(
    parameter PE_ROW_TH   = 8'd50, // 50% sparsity threshold
    parameter ROW_TILE_TH = 8'd80  // 80% sparsity threshold
)
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    input  logic [8:0]                           weight_zero_cnt,
    input  logic [8:0]                           act_zero_cnt,
    input  logic [2:0]                           host_mode_sel,
    input  logic                                 done,

    output logic                                 mode_pe_gating,
    output logic                                 mode_row_gating,
    output logic                                 mode_tile_gating,
    output logic [1:0]                           active_policy
);

    //----------------------------------------------------------
    // 1. Effective Sparsity Calculation (Dynamic & Combined)
    //----------------------------------------------------------
    logic [9:0] total_zeros;
    assign total_zeros = weight_zero_cnt + act_zero_cnt;

    // eff_sparsity_pct = (total_zeros * 100) / 512
    logic [7:0] eff_sparsity;
    assign eff_sparsity = (total_zeros * 25) >> 7; // range 0 to 100

    // Preliminary sparsity based on static weight count (weight_zero_cnt * 100 / 256)
    logic [7:0] weight_sparsity;
    assign weight_sparsity = (weight_zero_cnt * 25) >> 6;

    //----------------------------------------------------------
    // 2. FSM State Definitions
    //----------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE            = 3'b000,
        ST_LOAD_ESTIMATE   = 3'b001,
        ST_ACTIVE_ESTIMATE = 3'b010,
        ST_SELECT_MODE     = 3'b011,
        ST_RUN             = 3'b100
    } state_t;

    state_t state, state_next;
    logic [4:0] est_cycle_cnt;
    logic [1:0] policy_reg;
    logic [1:0] policy_next;

    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            est_cycle_cnt <= '0;
            policy_reg    <= 2'b01; // Default to PE Gating
        end else begin
            state         <= state_next;
            policy_reg    <= policy_next;
            if (state == ST_ACTIVE_ESTIMATE) begin
                est_cycle_cnt <= est_cycle_cnt + 1'b1;
            end else begin
                est_cycle_cnt <= '0;
            end
        end
    end

    // FSM Next-State and Policy-Selection Logic
    always_comb begin
        state_next  = state;
        policy_next = policy_reg;

        case (state)
            ST_IDLE: begin
                policy_next = 2'b01; // PE Mode
                if (weight_zero_cnt > 0) begin
                    state_next = ST_LOAD_ESTIMATE;
                end
            end

            ST_LOAD_ESTIMATE: begin
                // Select preliminary policy based on loaded weights
                if (weight_sparsity >= ROW_TILE_TH)
                    policy_next = 2'b11; // Tile Gating
                else if (weight_sparsity >= PE_ROW_TH)
                    policy_next = 2'b10; // Row Gating
                else
                    policy_next = 2'b01; // PE Gating

                // If loading completes and compute starts
                if (act_zero_cnt > 0) begin
                    state_next = ST_ACTIVE_ESTIMATE;
                end
            end

            ST_ACTIVE_ESTIMATE: begin
                // Hold weight-based policy while counting activations (16 cycles)
                if (est_cycle_cnt == 5'd15) begin
                    state_next = ST_SELECT_MODE;
                end
            end

            ST_SELECT_MODE: begin
                // Select final gating policy based on combined effective sparsity
                if (eff_sparsity >= ROW_TILE_TH)
                    policy_next = 2'b11;
                else if (eff_sparsity >= PE_ROW_TH)
                    policy_next = 2'b10;
                else
                    policy_next = 2'b01;

                state_next = ST_RUN;
            end

            ST_RUN: begin
                if (done) begin
                    state_next = ST_IDLE;
                end
            end

            default: state_next = ST_IDLE;
        endcase
    end

    //----------------------------------------------------------
    // 3. Gating Modes Decoding
    //----------------------------------------------------------
    always_comb begin
        mode_pe_gating   = 1'b0;
        mode_row_gating  = 1'b0;
        mode_tile_gating = 1'b0;
        active_policy    = policy_reg;

        case (host_mode_sel)
            3'b000: begin // Autonomous FSM mode
                mode_pe_gating   = (policy_reg == 2'b01);
                mode_row_gating  = (policy_reg == 2'b10);
                mode_tile_gating = (policy_reg == 2'b11);
                active_policy    = policy_reg;
            end
            3'b001: begin // Force PE Gating
                mode_pe_gating   = 1'b1;
                active_policy    = 2'b01;
            end
            3'b010: begin // Force Row Gating
                mode_row_gating  = 1'b1;
                active_policy    = 2'b10;
            end
            3'b011: begin // Force Tile Gating
                mode_tile_gating = 1'b1;
                active_policy    = 2'b11;
            end
            3'b100: begin // Force Hierarchical Gating (All enabled)
                mode_pe_gating   = 1'b1;
                mode_row_gating  = 1'b1;
                mode_tile_gating = 1'b1;
                active_policy    = 2'b00;
            end
            default: begin
                mode_pe_gating   = 1'b1;
                active_policy    = 2'b01;
            end
        endcase
    end

endmodule
