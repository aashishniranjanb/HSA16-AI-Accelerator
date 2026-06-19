# HSA16-AI-Accelerator

Industrial-style 16×16 INT8 systolic AI accelerator with hierarchical sparsity-aware power management, DFT-aware verification, and Cadence synthesis flow.

---

## Overview

**HSA16** is a research-grade 16×16 weight-stationary systolic array accelerator targeting INT8 inference workloads. The project implements a hierarchical sparsity-aware power management scheme that exploits zero-valued operands at three levels — PE, row, and tile — to reduce dynamic power consumption without sacrificing throughput or accuracy.

### Key Features

- **256-PE Systolic Array** — 16×16 weight-stationary INT8×INT8→INT32 MAC
- **3-Stage Pipelined PE** — Input → Multiply → Accumulate (500 MHz target)
- **Hierarchical Power Gating** — PE-level → Row-level → Tile-level sparsity detection
- **DFT Support** — Scan-enable, test-mode bypass for manufacturing test
- **Automated Verification** — Self-checking testbenches with NumPy golden model
- **Cadence Synthesis Flow** — Genus synthesis scripts with area/timing/power reports

### Target Metrics

| Parameter | Value |
|-----------|-------|
| Array Size | 16×16 (256 PEs) |
| Data Type | INT8 (signed) |
| Accumulator | INT32 |
| Dataflow | Weight-Stationary |
| Target Frequency | 500 MHz |
| Technology | TSMC 28nm |

---

## Architecture

```
                    Weight Loading
                         │
                    ┌────▼────┐
                    │ Weight  │
                    │  SRAM   │
                    └────┬────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ PE[0][0]│────►│ PE[0][1]│────►│  ...    │──► act pass-through
    └────┬────┘     └────┬────┘     └────┬────┘
         │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ PE[1][0]│────►│ PE[1][1]│────►│  ...    │    psum flows ↓
    └────┬────┘     └────┬────┘     └────┬────┘
         │               │               │
        ...             ...             ...
         │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │PE[15][0]│────►│PE[15][1]│────►│PE[15][15│
    └────┬────┘     └────┬────┘     └────┬────┘
         │               │               │
       C[*][0]         C[*][1]       C[*][15]
```

### PE Pipeline

| Stage | Operation | Register |
|-------|-----------|----------|
| 1 | Input Capture | `act_reg`, `weight_reg` |
| 2 | Multiply | `product_reg <= act_reg × weight_reg` |
| 3 | Accumulate | `psum_reg <= psum_in + product_reg` |

---

## Repository Structure

```
HSA16-AI-Accelerator/
│
├── rtl/
│   ├── common/
│   │   └── hsa_params.svh              # Shared parameters
│   ├── baseline/
│   │   ├── pe_baseline.sv              # 3-stage pipelined PE
│   │   └── systolic16x16_baseline.sv   # 16×16 systolic array
│   ├── pe_gating/                      # (Phase 2)
│   ├── row_gating/                     # (Phase 2)
│   ├── tile_gating/                    # (Phase 2)
│   └── dft/                           # (Phase 2)
│
├── tb/
│   └── baseline/
│       ├── tb_pe_baseline.sv           # PE self-checking testbench
│       └── tb_b16.sv                   # Full array testbench
│
├── python/
│   └── golden_model/
│       └── matmul_reference.py         # NumPy golden reference model
│
├── vectors/                            # Generated test vectors
│   ├── identity/
│   ├── ones/
│   ├── dense/
│   ├── sparse50/
│   ├── sparse70/
│   ├── sparse90/
│   └── sparse95/
│
├── docs/                               # (Future: architecture docs)
├── scripts/                            # (Future: Cadence scripts)
├── .gitignore
└── README.md
```

---

## Build Flow

### Prerequisites

- SystemVerilog simulator: Icarus Verilog (`iverilog`), ModelSim, Questa, or Xcelium
- Python 3.8+ with NumPy
- Cadence Genus (for synthesis — Phase 3)

### Generate Test Vectors

```bash
cd python/golden_model
python matmul_reference.py
```

Generates 7 datasets: `identity`, `ones`, `dense`, `sparse50`, `sparse70`, `sparse90`, `sparse95`

### PE Verification

```bash
iverilog -g2012 -I rtl/common -o pe_test \
    rtl/baseline/pe_baseline.sv \
    tb/baseline/tb_pe_baseline.sv
vvp pe_test
```

Expected: `PE_BASELINE_TEST PASSED` (108/108 vectors)

### B16 Array Verification

```bash
iverilog -g2012 -I rtl/common -o b16_test \
    rtl/baseline/pe_baseline.sv \
    rtl/baseline/systolic16x16_baseline.sv \
    tb/baseline/tb_b16.sv
vvp b16_test
```

Expected: `B16_TEST PASSED` (1024/1024 elements across 4 test suites)

---

## Verification Flow

| Test Suite | Type | Vectors | Checks |
|------------|------|---------|--------|
| PE Directed | Signed corners | 8 | pos×pos, neg×pos, neg×neg, zero, boundary |
| PE Random | Randomized | 100 | Golden-model scoreboard |
| B16 Identity | A × I = A | 256 | Structural correctness |
| B16 All-Ones | Known result | 256 | C[i][j] = 16 |
| B16 Dense | Random INT8 | 256 | RTL vs NumPy |
| B16 Negative | Signed stress | 256 | All-negative accumulation |

---

## Cadence Flow (Phase 3)

```tcl
# Genus Synthesis
read_hdl -sv rtl/common/hsa_params.svh
read_hdl -sv rtl/baseline/pe_baseline.sv
read_hdl -sv rtl/baseline/systolic16x16_baseline.sv
elaborate systolic16x16_baseline
synthesize -to_mapped

# Reports
report_area > reports/b16_area.rpt
report_timing > reports/b16_timing.rpt
report_power > reports/b16_power.rpt
```

---

## Results

*Results will be populated after Cadence synthesis.*

| Design | Power Saving | Area | Timing |
|--------|-------------|------|--------|
| B16 | Baseline | — | — |
| HSA-PE | TBD | — | — |
| HSA-ROW | TBD | — | — |
| HSA-TILE | TBD | — | — |
| HSA-DFT | TBD | — | — |

---

## Publications

- **ITC India 2026** — *Self Executing Power Aware Test Framework for Dense Sparse AI Workloads* (Submission 184)

---

## Branch Structure

```
main                          # Stable RTL only
└── develop                   # Current working architecture
    ├── feature/b16-baseline  # ← Current (Phase 1)
    ├── feature/pe-gating     # Phase 2 Step 1
    ├── feature/row-gating    # Phase 2 Step 2
    ├── feature/tile-gating   # Phase 2 Step 3
    ├── feature/dft-support   # Phase 2 Step 4
    ├── feature/dnn-workloads # Phase 3
    └── feature/cadence-flow  # Phase 3
```

### Release Tags

| Tag | Milestone |
|-----|-----------|
| `v1.0-b16` | Baseline verified |
| `v1.1-pe` | PE gating |
| `v1.2-row` | Row gating |
| `v1.3-tile` | Tile gating |
| `v1.4-dft` | DFT support |
| `v2.0-itc-submission` | Paper submission |

---

## Authors

- **Dinesh Babu A** — SRM Institute of Science and Technology, Vadapalani Campus
- **Nagarajan P** — SRM Institute of Science and Technology, Vadapalani Campus
- **Aashish Niranjan Barathykannan** — SRM Institute of Science and Technology, Vadapalani Campus
- **Shanganidhi K N** — SRM Institute of Science and Technology, Vadapalani Campus
- **Akhilesh M** — SRM Institute of Science and Technology, Vadapalani Campus

---

## License

This project is part of academic research at SRM Institute of Science and Technology.
