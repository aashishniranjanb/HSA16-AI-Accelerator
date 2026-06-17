//============================================================
// HSA Parameters Package
//============================================================
// Central parameter file for Hierarchical Sparsity Architecture
// Used by all RTL modules across B16 and HSA variants
//
// Author  : HSA-16 Project
// Target  : 500 MHz, TSMC 28nm (Cadence Genus)
//============================================================

`ifndef HSA_PARAMS_SVH
`define HSA_PARAMS_SVH

//------------------------------------------------------------
// Data Widths
//------------------------------------------------------------
parameter DATA_WIDTH    = 8;            // INT8 activations & weights
parameter ACC_WIDTH     = 32;           // INT32 accumulator
parameter PRODUCT_WIDTH = 2 * DATA_WIDTH; // 16-bit product

//------------------------------------------------------------
// Array Dimensions
//------------------------------------------------------------
parameter ARRAY_SIZE    = 16;           // 16×16 systolic array
parameter TILE_SIZE     = 4;            // 4×4 tile (for Phase 2)
parameter NUM_TILES     = ARRAY_SIZE / TILE_SIZE; // 4 tiles per dim

//------------------------------------------------------------
// Pipeline
//------------------------------------------------------------
parameter PIPE_STAGES   = 3;           // PE pipeline depth

//------------------------------------------------------------
// Clock
//------------------------------------------------------------
parameter CLK_PERIOD_NS = 2;           // 500 MHz target

`endif // HSA_PARAMS_SVH
