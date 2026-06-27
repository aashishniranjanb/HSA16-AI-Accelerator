# HSA16 ASIC Implementation Flow

Complete ASIC implementation flow for the **HSA16 AI Accelerator** — from RTL simulation through Genus synthesis to Innovus place-and-route, across all six gating architectures.

---

## Directory Structure

```text
flow/
├── constraints/
│   └── systolic16x16.sdc          # 500 MHz SDC (2.0 ns period)
├── genus/
│   ├── baseline.tcl               # Genus synthesis scripts (one per arch)
│   ├── pe_gating.tcl
│   ├── row_gating.tcl
│   ├── tile_gating.tcl
│   ├── hierarchical.tcl
│   └── adaptive.tcl
├── innovus/
│   ├── baseline.tcl               # Innovus PnR scripts (one per arch)
│   ├── pe_gating.tcl
│   ├── row_gating.tcl
│   ├── tile_gating.tcl
│   ├── hierarchical.tcl
│   └── adaptive.tcl
├── run_genus.sh                   # Simulate + Genus synthesis
├── run_innovus.sh                 # Innovus PnR (needs Genus netlist first)
├── run_full.sh                    # Full flow: xrun -> Genus -> Innovus
├── run_frequency_sweep.sh         # Multi-frequency sweep
├── reports/
│   ├── genus/                     # Area, Timing, Power, QoR reports
│   └── innovus/                   # Post-route reports
├── netlists/                      # Mapped Verilog + SDC from Genus
├── xrun/                          # VCD and SAIF activity files
├── innovus_db/                    # Innovus layout databases
└── logs/                          # All tool logs
```

---

## Quick Start

### Prerequisites

Make sure Cadence tools are in your PATH:

```bash
which xrun        # Xcelium simulator
which genus       # Genus synthesis
which innovus     # Innovus PnR
```

If not found, source your lab's Cadence environment first (ask your lab instructor).

### Fix Windows Line Endings (first time only)

If you cloned from Windows:

```bash
sed -i 's/\r$//' flow/*.sh
chmod +x flow/*.sh
```

---

## Running the Flow

### 1. Genus Only (Simulation + Synthesis)

**Single architecture:**

```bash
./flow/run_genus.sh baseline
./flow/run_genus.sh pe_gating
./flow/run_genus.sh row_gating
./flow/run_genus.sh tile_gating
./flow/run_genus.sh hierarchical
./flow/run_genus.sh adaptive
```

Short names also work:

```bash
./flow/run_genus.sh pe          # same as pe_gating
./flow/run_genus.sh row         # same as row_gating
./flow/run_genus.sh tile        # same as tile_gating
```

**All six architectures:**

```bash
./flow/run_genus.sh --all
```

**Skip simulation (Genus only, use if xrun already passed):**

```bash
./flow/run_genus.sh --skip-sim adaptive
./flow/run_genus.sh --skip-sim --all
```

### 2. Innovus PnR (after Genus)

Requires the Genus netlist at `flow/netlists/<arch>_synth.v`.

```bash
./flow/run_innovus.sh baseline
./flow/run_innovus.sh --all
```

### 3. Full Flow (xrun → Genus → Innovus)

```bash
./flow/run_full.sh adaptive
./flow/run_full.sh --all
./flow/run_full.sh --skip-sim --all     # skip sim, run Genus + Innovus
```

---

## What Each Script Does

### `run_genus.sh`

| Step | Tool | Action |
|:-----|:-----|:-------|
| 1 | `xrun` | RTL simulation with Xcelium (skippable with `--skip-sim`) |
| 2 | `vcd2saif` | Convert VCD → SAIF for power annotation (best-effort, skips if unavailable) |
| 3 | `genus` | Batch synthesis: `syn_generic` → `syn_map` → `syn_opt` |

**Outputs:**
- `flow/netlists/<arch>_synth.v` — Mapped gate-level netlist
- `flow/netlists/<arch>_synth.sdc` — Gate-level constraints
- `flow/reports/genus/<arch>_area.rpt` — Area breakdown
- `flow/reports/genus/<arch>_timing.rpt` — Timing analysis
- `flow/reports/genus/<arch>_power.rpt` — Power estimation
- `flow/reports/genus/<arch>_qor.rpt` — Quality of Results
- `flow/reports/genus/<arch>_clock_gating.rpt` — Clock gating report
- `flow/reports/genus/<arch>_summary.rpt` — Design summary
- `flow/reports/genus/<arch>_messages.rpt` — All warnings/errors

### `run_innovus.sh`

Floorplan → Placement → CTS → Routing → RC Extraction → Verification → Power/Timing Reports

**Outputs:**
- `flow/reports/innovus/<arch>_post_route_area.rpt`
- `flow/reports/innovus/<arch>_post_route_timing.rpt`
- `flow/reports/innovus/<arch>_post_route_power.rpt`
- `flow/innovus_db/<arch>_final.enc` — Layout database

---

## Genus Speed Optimizations

The Tcl scripts are tuned for fast synthesis:

| Setting | Value | Effect |
|:--------|:------|:-------|
| `max_cpus_per_server` | 8 | Parallel synthesis across CPU cores |
| `syn_generic_effort` | medium | Faster generic synthesis (vs. default high) |
| `syn_map_effort` | medium | Faster technology mapping |
| `syn_opt_effort` | medium | Faster post-map optimization |
| `init_hdl_search_path` | `rtl/common` | Resolves `hsa_params.svh` includes |

Expected synthesis time: **~10-15 min per architecture** (down from 42+ min).

---

## Benchmark Workloads

All testbenches evaluate against these workloads:

| Workload | Description |
|:---------|:------------|
| Dense (0%) | Worst-case, no sparsity |
| Sparse 50/70/90/95% | Synthetic uniform sparsity |
| AlexNet | Early CNN, moderate sparsity |
| VGG16 | Dense conv layers with zero clusters |
| ResNet18 | Residual blocks, high activation sparsity |
| MobileNetV2 | Lightweight depthwise separable convolutions |
| EfficientNet-B0 | Modern efficient CNN for edge AI |

---

## Architectures

| Name | Script Key | Description |
|:-----|:-----------|:------------|
| Baseline | `baseline` | No gating, reference design |
| PE Gating | `pe_gating` | Per-PE zero detection and clock gating |
| Row Gating | `row_gating` | Row-level wavefront gating |
| Tile Gating | `tile_gating` | 4×4 tile-level gating |
| Hierarchical | `hierarchical` | Combined tile + row + PE gating |
| Adaptive (AHSA) | `adaptive` | FSM-based runtime mode selection |

---

## Troubleshooting

### `command not found: genus`

The Cadence environment is not loaded. Ask your lab instructor for the setup command, e.g.:

```bash
source /home/Cadence/setup.sh
```

### `^M: bad interpreter`

Windows line endings. Fix with:

```bash
sed -i 's/\r$//' flow/*.sh && chmod +x flow/*.sh
```

### Genus takes 40+ minutes

Make sure you're using the updated Tcl scripts with `medium` effort. Check:

```bash
grep syn_generic_effort flow/genus/baseline.tcl
# Should show: set_db syn_generic_effort  medium
```

### `SAIF file not found` warning

This is normal. Without SAIF, Genus uses vectorless power estimation. To generate SAIF, run the full flow (simulation → VCD → SAIF → Genus).

### `report_gates` error

Old scripts used `report_gates` which doesn't exist in Genus 20.x. Updated scripts use `report_summary` instead.

---

## Paper Results Tables

After running the full flow, extract metrics from reports:

### Table I: Synthesis Comparison (500 MHz)

| Architecture | Cell Count | Area (μm²) | WNS (ps) | Dynamic Power (mW) | Leakage (mW) | Total Power (mW) |
|:-------------|:-----------|:------------|:----------|:--------------------|:--------------|:------------------|
| Baseline     |            |             |           |                     |               |                   |
| PE Gated     |            |             |           |                     |               |                   |
| Row Gated    |            |             |           |                     |               |                   |
| Tile Gated   |            |             |           |                     |               |                   |
| Hierarchical |            |             |           |                     |               |                   |
| AHSA         |            |             |           |                     |               |                   |
