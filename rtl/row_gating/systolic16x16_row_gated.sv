//============================================================
// Systolic 16×16 with Row Gating — Weight-Stationary Array
//============================================================

`include "hsa_params.svh"

module systolic16x16_row_gated
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    //------------------------------------------------------
    // Weight Loading Interface
    //------------------------------------------------------
    input  logic                                 load_weight,
    input  logic [3:0]                           weight_row_sel,
    input  logic signed [DATA_WIDTH-1:0]         weight_in  [0:ARRAY_SIZE-1],

    //------------------------------------------------------
    // Compute Interface
    //------------------------------------------------------
    input  logic                                 start,
    input  logic signed [DATA_WIDTH-1:0]         act_in     [0:ARRAY_SIZE-1],

    //------------------------------------------------------
    // Output Interface
    //------------------------------------------------------
    output logic                                 done,
    output logic signed [ACC_WIDTH-1:0]          result     [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1],

    //------------------------------------------------------
    // Gating Statistics
    //------------------------------------------------------
    output logic [31:0]                          row_skip_counter
);

    //----------------------------------------------------------
    // 1. Weight Memory
    //----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] weight_mem [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < ARRAY_SIZE; r++)
                for (int c = 0; c < ARRAY_SIZE; c++)
                    weight_mem[r][c] <= '0;
        end else if (load_weight) begin
            for (int c = 0; c < ARRAY_SIZE; c++)
                weight_mem[weight_row_sel][c] <= weight_in[c];
        end
    end

    //----------------------------------------------------------
    // 2. FSM (Expanded window to let wavefront flush)
    //----------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE    = 2'b00,
        S_COMPUTE = 2'b01,
        S_DONE    = 2'b10
    } state_t;

    state_t state, state_next;
    logic [7:0] cycle_cnt;

    // 150 cycles guarantees all skews and 3-cycle PEs flush completely
    localparam TOTAL_COMPUTE_CYCLES = 150; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cycle_cnt <= '0;
        end else begin
            state <= state_next;
            if (state == S_COMPUTE)
                cycle_cnt <= cycle_cnt + 1'b1;
            else
                cycle_cnt <= '0;
        end
    end

    always_comb begin
        state_next = state;
        case (state)
            S_IDLE:    if (start) state_next = S_COMPUTE;
            S_COMPUTE: if (cycle_cnt == TOTAL_COMPUTE_CYCLES - 1) state_next = S_DONE;
            S_DONE:    state_next = S_IDLE;
            default:   state_next = S_IDLE;
        endcase
    end

    assign done = (state == S_DONE);

    //----------------------------------------------------------
    // 3. Activation Capture (Captures exactly 16 rows of A)
    //----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] act_captured [0:ARRAY_SIZE-1];
    logic                         act_captured_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < ARRAY_SIZE; k++) act_captured[k] <= '0;
            act_captured_valid <= 1'b0;
        end else if ((state == S_IDLE && start) || (state == S_COMPUTE && cycle_cnt < ARRAY_SIZE - 1)) begin
            for (int k = 0; k < ARRAY_SIZE; k++) act_captured[k] <= act_in[k];
            act_captured_valid <= 1'b1;
        end else begin
            for (int k = 0; k < ARRAY_SIZE; k++) act_captured[k] <= '0;
            act_captured_valid <= 1'b0;
        end
    end

    //----------------------------------------------------------
    // 4. Input Row Skewing (3 cycles per PE row)
    //----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] row_act   [0:ARRAY_SIZE-1];
    logic                         row_valid [0:ARRAY_SIZE-1];

    assign row_act[0]   = act_captured[0];
    assign row_valid[0] = act_captured_valid;

    genvar gr;
    generate
        for (gr = 1; gr < ARRAY_SIZE; gr = gr + 1) begin : gen_row_skew
            localparam DELAY = PIPE_STAGES * gr; // 3 cycles per row

            logic signed [DATA_WIDTH-1:0] sr_data  [0:DELAY-1];
            logic                         sr_valid [0:DELAY-1];

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sr_data[0]  <= '0;
                    sr_valid[0] <= 1'b0;
                end else begin
                    sr_data[0]  <= act_captured[gr];
                    sr_valid[0] <= act_captured_valid;
                end
            end

            for (genvar s = 1; s < DELAY; s = s + 1) begin : gen_sr_stage
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        sr_data[s]  <= '0;
                        sr_valid[s] <= 1'b0;
                    end else begin
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
    // 5. PE Array Connectivity (Valid flows HORIZONTALLY)
    //----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] act_wire   [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    logic                         valid_wire [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0]  psum_wire  [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weight_out_unused [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    // Connect skewed inputs to the left side of the array
    generate
        for (gr = 0; gr < ARRAY_SIZE; gr = gr + 1) begin : gen_left_bound
            assign act_wire[gr][0]   = row_act[gr];
            assign valid_wire[gr][0] = row_valid[gr];
        end
    endgenerate

    // Connect 0 to the top of the partial sum vertical chains
    genvar gcol;
    generate
        for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1) begin : gen_top_bound
            assign psum_wire[0][gcol] = '0;
        end
    endgenerate

    generate
        for (gr = 0; gr < ARRAY_SIZE; gr = gr + 1) begin : gen_pe_row
            for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1) begin : gen_pe_col
                pe_row_gated u_pe (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    // Horizontal flow
                    .valid_in   (valid_wire[gr][gcol]),
                    .act_in     (act_wire[gr][gcol]),
                    .valid_out  (valid_wire[gr][gcol+1]),
                    .act_out    (act_wire[gr][gcol+1]),
                    
                    // Static weight
                    .weight_in  (weight_mem[gr][gcol]),
                    .weight_out (weight_out_unused[gr][gcol]),
                    
                    // Vertical flow
                    .psum_in    (psum_wire[gr][gcol]),
                    .psum_out   (psum_wire[gr+1][gcol])
                );
            end
        end
    endgenerate

    //----------------------------------------------------------
    // 6. Result Capture (Using Bottom Row's Horizontal Valid)
    //----------------------------------------------------------
    logic [4:0] result_row_cnt [0:ARRAY_SIZE-1];

    generate
        for (gcol = 0; gcol < ARRAY_SIZE; gcol = gcol + 1) begin : gen_result_capture
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result_row_cnt[gcol] <= '0;
                    for (int r = 0; r < ARRAY_SIZE; r++)
                        result[r][gcol] <= '0;
                end else if (state == S_IDLE && start) begin
                    result_row_cnt[gcol] <= '0;
                end 
                // When valid_out of PE[15][gcol] is high, psum_out is complete
                else if (valid_wire[ARRAY_SIZE-1][gcol+1] && result_row_cnt[gcol] < ARRAY_SIZE) begin
                    result[result_row_cnt[gcol]][gcol] <= psum_wire[ARRAY_SIZE][gcol];
                    result_row_cnt[gcol] <= result_row_cnt[gcol] + 1'b1;
                end
            end
        end
    endgenerate

    //----------------------------------------------------------
    // 7. Statistics Gating Counters
    //----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_skip_counter <= '0;
        end else if (state == S_COMPUTE) begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                if (row_valid[i] && (row_act[i] == 8'sd0)) begin
                    row_skip_counter <= row_skip_counter + 1'b1;
                end
            end
        end
    end

endmodule
