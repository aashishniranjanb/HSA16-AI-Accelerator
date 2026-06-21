# HSA16 ASIC Implementation Lab Guide

This guide details the sequential execution of the **HSA16 AI Accelerator** design space exploration across all six architectures. Follow these steps in the Cadence lab to generate silicon-credible, SAIF-backed power and timing reports for your paper.

---

## Recommended Directory Structure
Verify that the `flow` directory has the following layout before proceeding:
```text
flow/
├── constraints/
│   └── systolic16x16.sdc
├── genus/
│   ├── baseline.tcl
│   ├── pe_gating.tcl
│   ├── row_gating.tcl
│   ├── tile_gating.tcl
│   ├── hierarchical.tcl
│   └── adaptive.tcl
├── innovus/
│   ├── baseline.tcl
│   ├── pe_gating.tcl
│   ├── row_gating.tcl
│   ├── tile_gating.tcl
│   ├── hierarchical.tcl
│   └── adaptive.tcl
├── reports/
│   ├── genus/          # Area, Timing, Power, Design Rules, Clock Gating reports
│   └── innovus/        # Congestion, CTS trees, verify reports, dynamic power reports
├── netlists/           # Mapped Verilog, SDF, and SDC from Genus
├── saif/               # Dynamic activity SAIF files from simulation
└── logs/               # Run logs
```

---

## Execution Flow (Per Architecture)

For **each** of the six architectures, perform the following eight stages in order:

### Stage 1 & 2: RTL Simulation & Verification
Compile and run the corresponding testbench to verify bit-exact functional correctness.

* **Baseline:**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/baseline/pe_baseline.sv rtl/baseline/systolic16x16_baseline.sv tb/baseline/tb_b16.sv
  ```
* **PE Gating:**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/pe_gating/pe_gated.sv rtl/pe_gating/systolic16x16_pe_gated.sv tb/pe_gating/tb_b16_pe_gated.sv
  ```
* **Row Gating:**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/row_gating/pe_row_gated.sv rtl/row_gating/systolic16x16_row_gated.sv tb/row_gating/tb_b16_row_gated.sv
  ```
* **Tile Gating:**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/tile_gating/pe_tile_gated.sv rtl/tile_gating/systolic16x16_tile_gated.sv tb/tile_gating/tb_b16_tile_gated.sv
  ```
* **Hierarchical Gating:**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/hierarchical_gating/pe_hierarchical.sv rtl/hierarchical_gating/systolic16x16_hierarchical.sv tb/hierarchical_gating/tb_b16_hierarchical.sv
  ```
* **Adaptive Gating (AHSA):**
  ```bash
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common rtl/adaptive_gating/sparsity_estimator.sv rtl/adaptive_gating/gating_controller.sv rtl/adaptive_gating/pe_adaptive.sv rtl/adaptive_gating/systolic16x16_adaptive.sv tb/adaptive_gating/tb_b16_adaptive.sv
  ```

---

### Stage 3 & 4: VCD Dump and SAIF Generation
To generate dynamic activity data for back-annotation:

1. Ensure your testbenches include the VCD dumping system task:
   ```systemverilog
   initial begin
       $dumpfile("flow/logs/<architecture>.vcd");
       $dumpvars(0, <testbench_module_name>);
   end
   ```
2. Run the simulation to completion.
3. Convert the generated VCD file to SAIF format using the `vcd2saif` tool:
   ```bash
   vcd2saif -input flow/logs/<architecture>.vcd -output flow/saif/<architecture>.saif
   ```

---

### Stage 5: Cadence Genus Synthesis
Synthesize the RTL design, map it to the 45nm library, check design rules, analyze inferred clock gating, and back-annotate the SAIF file for measured dynamic power estimation.

Run Genus from the project root:
```bash
genus -files flow/genus/<architecture>.tcl -log flow/logs/genus_<architecture>.log
```
*Outputs generated:*
- **Netlist:** `flow/netlists/<architecture>_synth.v`
- **Timing Constraint:** `flow/netlists/<architecture>_synth.sdc`
- **SDF Delays:** `flow/netlists/<architecture>_synth.sdf`
- **Reports:** `flow/reports/genus/<architecture>_area.rpt`, `_timing.rpt`, `_power.rpt`, `_qor.rpt`, `_gates.rpt`, `_clock_gating.rpt`, `_design_rules.rpt`

---

### Stage 6 & 7: Cadence Innovus Place & Route (PnR)
Import the synthesized netlist and timing constraint, create the floorplan, build power rings, place standard cells, run Clock Tree Synthesis (CTS), perform routing, and execute timing verification.

Run Innovus from the project root:
```bash
innovus -files flow/innovus/<architecture>.tcl -log flow/logs/innovus_<architecture>.log
```
*Outputs generated:*
- **Database:** `flow/innovus_db/<architecture>_final.enc`
- **Reports:** `flow/reports/innovus/<architecture>_congestion.rpt`, `_clock_trees.rpt`, `_geom.rpt`, `_conn.rpt`, and timing folders under `flow/reports/innovus/timing_reports_<architecture>/`.

---

### Stage 8: Post-Route Timing and SAIF-Based Power Analysis
During PnR execution, the Innovus script automatically checks for SAIF files in `flow/saif/<architecture>.saif` to perform **dynamic post-route power analysis**.

If the SAIF file is available:
- **Measured Dynamic Power** is output to: `flow/reports/innovus/<architecture>_power.rpt`

---

## Professional Comparison Tables

After running the full flow, extract metrics from the report files to fill out these tables for your paper.

### Table I: Synthesis and Physical Implementation Comparison
Extract area from `<architecture>_area.rpt`, timing (WNS/TNS) from `<architecture>_timing.rpt` or the timing directory, and power from `<architecture>_power.rpt`.

| Architecture | Cell Count | Core Area ($\mu m^2$) | WNS ($ps$) | TNS ($ps$) | Clock Gating Cells | Dynamic Power ($mW$) | Leakage Power ($mW$) | Total Power ($mW$) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | | | | | 0 (None) | | | |
| **PE Gated** | | | | | | | | |
| **Row Gated** | | | | | | | | |
| **Tile Gated** | | | | | | | | |
| **Hierarchical** | | | | | | | | |
| **AHSA** | | | | | | | | |

* **Area Overhead Verification:** Compare the core area of **AHSA** against **Baseline** to quantify the hardware penalty of the sparsity estimators, FSMs, and controllers.
* **Clock Gating Efficiency:** Read `<architecture>_clock_gating.rpt` to verify the percentage of gated registers and clock-gating cells inferred by Genus.

---

### Table II: Workload Sparsity Evaluation Matrix (Measured Dynamic Power)
To demonstrate the adaptivity of the controller, run the dynamic simulations across all 9 workloads, generate their respective SAIFs, and synthesize/PnR to report the dynamic power consumption ($mW$):

| Architecture | Dense (0%) | Sparse 50% | Sparse 70% | Sparse 90% | Sparse 95% | AlexNet | VGG16 | ResNet18 | MobileNetV2 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | | | | | | | | | |
| **PE Gated** | | | | | | | | | |
| **Row Gated** | | | | | | | | | |
| **Tile Gated** | | | | | | | | | |
| **Hierarchical** | | | | | | | | | |
| **AHSA (Adaptive)** | | | | | | | | | |
