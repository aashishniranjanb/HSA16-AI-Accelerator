//============================================================
// Systolic 16×16 Baseline — Weight-Stationary Array
//============================================================
// Architecture:
//   16×16 grid of pe_baseline instances (256 PEs)
//   Weight-Stationary dataflow
//
// For C[i][j] = Σ_k A[i][k] * B[k][j]:
//   - B[k][j] is pre-loaded into weight_mem[k][j]
//   - PE[k][j] always multiplies its activation input by B[k][j]
//   - Partial sums flow top→bottom in each column
//   - psum at bottom of column j gives C[i][j]
//
// Critical Timing:
//   The PE has a 3-stage pipeline (psum_out appears 3 cycles
//   after act_in/psum_in are presented). Therefore:
//   - Row k must receive its activation 3*k cycles after row 0
//     (not 1*k), so that psum from PE[k-1][j] arrives at PE[k][j]
//     exactly when PE[k][j]'s activation is ready
//   - Column j adds j cycles of delay (activation pass-through)
//
// Operation:
//   Phase 1 — Weight Loading:
//     Assert load_weight=1, set weight_row_sel, drive weight_in
//     16 cycles to load all rows of B matrix
//
//   Phase 2 — Compute:
//     Assert start=1 for first cycle
//     Stream A matrix: at cycle t, act_in[k] = A[t][k]
//     Internal skew handles proper timing alignment
//     Total cycles: 16 + 3*15 + 3 = 64
//
// Target: 500 MHz, TSMC 28nm
//============================================================

`include "hsa_params.svh"

module systolic16x16_baseline
(
    input  logic                         clk,
    input  logic                         rst_n,

    //------------------------------------------------------
    // Weight Loading Interface
    //------------------------------------------------------
    input  logic                         load_weight,
    input  logic [3:0]                   weight_row_sel,
    input  logic signed [DATA_WIDTH-1:0] weight_in  [0:ARRAY_SIZE-1],

    //------------------------------------------------------
    // Compute Interface
    //------------------------------------------------------
    input  logic                         start,
    input  logic signed [DATA_WIDTH-1:0] act_in     [0:ARRAY_SIZE-1],

    //------------------------------------------------------
    // Output Interface
    //------------------------------------------------------
    output logic                         done,
    output logic signed [ACC_WIDTH-1:0]  result     [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1]
);

    //----------------------------------------------------------
    // Weight Memory
    //----------------------------------------------------------

    logic signed [DATA_WIDTH-1:0] weight_mem [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            for (int r = 0; r < ARRAY_SIZE; r++)
                for (int c = 0; c < ARRAY_SIZE; c++)
                    weight_mem[r][c] <= '0;
        end
        else if (load_weight)
        begin
            for (int c = 0; c < ARRAY_SIZE; c++)
                weight_mem[weight_row_sel][c] <= weight_in[c];
        end
    end

    //----------------------------------------------------------
    // State Machine
    //----------------------------------------------------------

    typedef enum logic [1:0] {
        S_IDLE    = 2'b00,
        S_COMPUTE = 2'b01,
        S_DONE    = 2'b10
    } state_t;

    state_t state, state_next;

    logic [7:0] cycle_cnt;

    // Total cycles needed:
    // - 16 cycles of activation streaming
    // - 3*15 = 45 cycles for max row skew (row 15 starts 45 cycles late)
    // - 15 cycles for activation to propagate to rightmost column
    // - 3 cycles for pipeline of last PE
    // Total: 16 + 45 + 15 + 3 = 79 (conservative upper bound)
    // More precisely: last result appears at cycle:
    //   (N-1)*3 [row skew for row 15] + (N-1) [col propagation] + 3 [pipeline]
    //   + N-1 [last activation is streamed at cycle N-1]
    //   = 15*3 + 15 + 3 + 15 = 78
    // Plus 1 for margin = 79. Use 80 for safety.
    localparam TOTAL_COMPUTE_CYCLES = 80;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            state     <= S_IDLE;
            cycle_cnt <= '0;
        end
        else
        begin
            state <= state_next;

            if (state == S_COMPUTE)
                cycle_cnt <= cycle_cnt + 1;
            else
                cycle_cnt <= '0;
        end
    end

    always_comb
    begin
        state_next = state;

        case (state)
            S_IDLE:
                if (start)
                    state_next = S_COMPUTE;

            S_COMPUTE:
                if (cycle_cnt == TOTAL_COMPUTE_CYCLES - 1)
                    state_next = S_DONE;

            S_DONE:
                state_next = S_IDLE;

            default:
                state_next = S_IDLE;
        endcase
    end

    assign done = (state == S_DONE);

    //----------------------------------------------------------
    // Activation Input Capture
    //----------------------------------------------------------
    // During first 16 cycles of compute, capture act_in
    // act_in[k] = A[cycle][k] for cycle = 0..15

    logic signed [DATA_WIDTH-1:0] act_captured [0:ARRAY_SIZE-1];
    logic                         act_captured_valid;

    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            for (int k = 0; k < ARRAY_SIZE; k++)
                act_captured[k] <= '0;
            act_captured_valid <= 1'b0;
        end
        else if (state == S_COMPUTE && cycle_cnt < ARRAY_SIZE)
        begin
            for (int k = 0; k < ARRAY_SIZE; k++)
                act_captured[k] <= act_in[k];
            act_captured_valid <= 1'b1;
        end
        else
        begin
            for (int k = 0; k < ARRAY_SIZE; k++)
                act_captured[k] <= '0;
            act_captured_valid <= 1'b0;
        end
    end

    //----------------------------------------------------------
    // Per-Row Activation Skew (3 cycles per row)
    //----------------------------------------------------------
    // Row k needs 3*k cycles of delay
    // This aligns with the PE's 3-stage pipeline:
    //   psum from PE[k-1][j] takes 3 cycles to appear
    //   so PE[k][j] must receive its activation 3 cycles later
    //
    // Row 0: 0 delay (direct)
    // Row 1: 3-cycle delay
    // Row k: 3*k-cycle delay

    logic signed [DATA_WIDTH-1:0] row_act   [0:ARRAY_SIZE-1];
    logic                         row_valid [0:ARRAY_SIZE-1];

    // Row 0: no delay
    assign row_act[0]   = act_captured[0];
    assign row_valid[0] = act_captured_valid;

    // Rows 1..15: 3*k stage shift register
    genvar gr;
    generate
        for (gr = 1; gr < ARRAY_SIZE; gr = gr + 1)
        begin : gen_row_skew

            localparam DELAY = PIPE_STAGES * gr; // 3*k

            logic signed [DATA_WIDTH-1:0] sr_data  [0:DELAY-1];
            logic                         sr_valid [0:DELAY-1];

            // Stage 0
            always_ff @(posedge clk or negedge rst_n)
            begin
                if (!rst_n)
                begin
                    sr_data[0]  <= '0;
                    sr_valid[0] <= 1'b0;
                end
                else
                begin
                    sr_data[0]  <= act_captured[gr];
                    sr_valid[0] <= act_captured_valid;
                end
            end

            // Stages 1..DELAY-1
            for (genvar s = 1; s < DELAY; s = s + 1)
            begin : gen_sr_stage
                always_ff @(posedge clk or negedge rst_n)
                begin
                    if (!rst_n)
                    begin
                        sr_data[s]  <= '0;
                        sr_valid[s] <= 1'b0;
                    end
                    else
                    begin
                        sr_data[s]  <= sr_data[s-1];
                        sr_valid[s] <= sr_valid[s-1];
                    end
                end
            end

            assign row_act[gr]   = sr_data[DELAY-1];
            assign row_valid[gr] = sr_valid[DELAY-1];

        end
    endgenerate

    //----------------------------------------------------------
    // PE Array — Direct Weight Connection
    //----------------------------------------------------------

    // Interconnect wires
    logic signed [DATA_WIDTH-1:0] act_wire   [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0]  psum_wire  [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    logic                         valid_wire [0:ARRAY_SIZE][0:ARRAY_SIZE-1];

    // Unused weight pass-through
    logic signed [DATA_WIDTH-1:0] weight_out_unused [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    genvar grow, gcol;
    generate
        for (grow = 0; grow < ARRAY_SIZE; grow = grow + 1)
        begin : gen_pe_row
            for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1)
            begin : gen_pe_col

                pe_baseline u_pe
                (
                    .clk        (clk),
                    .rst_n      (rst_n),

                    .valid_in   (valid_wire[grow][gcol]),

                    .act_in     (act_wire[grow][gcol]),
                    .weight_in  (weight_mem[grow][gcol]),
                    .psum_in    (psum_wire[grow][gcol]),

                    .valid_out  (valid_wire[grow+1][gcol]),

                    .act_out    (act_wire[grow][gcol+1]),
                    .weight_out (weight_out_unused[grow][gcol]),

                    .psum_out   (psum_wire[grow+1][gcol])
                );

            end
        end
    endgenerate

    //----------------------------------------------------------
    // Boundary Connections
    //----------------------------------------------------------

    // Top row: psum = 0
    generate
        for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1)
        begin : gen_top_psum
            assign psum_wire[0][gcol] = '0;
        end
    endgenerate

    // Left column: activation from row skew logic
    generate
        for (grow = 0; grow < ARRAY_SIZE; grow = grow + 1)
        begin : gen_left_act
            assign act_wire[grow][0] = row_act[grow];
        end
    endgenerate

    // Top row valid: each column needs proper delay
    // Column 0: gets valid from row_valid[0] directly
    // Column j: activation arrives j cycles later (1 cycle per PE hop in act pass-through)
    // So valid for column j at row 0 should be delayed by j cycles

    logic col0_valid;
    assign col0_valid = row_valid[0];

    generate
        assign valid_wire[0][0] = col0_valid;

        for (gcol = 1; gcol < ARRAY_SIZE; gcol = gcol + 1)
        begin : gen_col_valid_delay

            logic vd [0:gcol-1];

            always_ff @(posedge clk or negedge rst_n)
            begin
                if (!rst_n)
                    vd[0] <= 1'b0;
                else
                    vd[0] <= col0_valid;
            end

            for (genvar d = 1; d < gcol; d = d + 1)
            begin : gen_vd_stage
                always_ff @(posedge clk or negedge rst_n)
                begin
                    if (!rst_n)
                        vd[d] <= 1'b0;
                    else
                        vd[d] <= vd[d-1];
                end
            end

            assign valid_wire[0][gcol] = vd[gcol-1];

        end
    endgenerate

    //----------------------------------------------------------
    // Result Capture
    //----------------------------------------------------------
    // psum emerges from the bottom of each column as valid_wire[ARRAY_SIZE][col]
    // pulses. Each pulse carries one C[i][j] result.
    // Results emerge in order i=0,1,...,15 for each column j,
    // but columns emit at different times (column j is delayed by j cycles).

    logic [4:0] result_row_cnt [0:ARRAY_SIZE-1];

    generate
        for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1)
        begin : gen_result_capture

            always_ff @(posedge clk or negedge rst_n)
            begin
                if (!rst_n)
                begin
                    result_row_cnt[gcol] <= '0;
                    for (int r = 0; r < ARRAY_SIZE; r++)
                        result[r][gcol] <= '0;
                end
                else if (state == S_IDLE && start)
                begin
                    result_row_cnt[gcol] <= '0;
                end
                else if (valid_wire[ARRAY_SIZE][gcol] && result_row_cnt[gcol] < ARRAY_SIZE)
                begin
                    result[result_row_cnt[gcol]][gcol] <= psum_wire[ARRAY_SIZE][gcol];
                    result_row_cnt[gcol] <= result_row_cnt[gcol] + 1;
                end
            end

        end
    endgenerate

endmodule
