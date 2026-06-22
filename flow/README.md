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
├── run_frequency_sweep.sh # Sweep automation script
└── logs/               # Run logs
```

---

## Benchmark Workload Suites
To validate the design, we evaluate the systolic array against a progression of representative AI workloads:
1. **Dense (0%):** Absolute worst-case workload.
2. **Sparse 50% / 70% / 90% / 95%:** Uniformly-distributed synthetic sparsity sweeps.
3. **AlexNet:** Early CNN benchmark demonstrating coarse/moderate patterns.
4. **VGG16:** Dense convolutional layers with localized zero clusters.
5. **ResNet18:** Residual blocks featuring high activation sparsity.
6. **MobileNetV2:** Lightweight mobile-optimized depthwise separable convolutions.
7. **EfficientNet-B0:** Modern, highly optimized efficient CNN architecture targeting edge AI.

---

## Execution Flow (Per Architecture)

For **each** of the six architectures, perform the following stages:

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

### Stage 5: Cadence Genus Synthesis
Synthesize the RTL design, map it to the 45nm library, check design rules, analyze clock gating, and back-annotate the SAIF file.

Run Genus from the project root:
```bash
genus -files flow/genus/<architecture>.tcl -log flow/logs/genus_<architecture>.log
```

### Stage 6 & 7: Cadence Innovus Place & Route (PnR)
Import the synthesized netlist and timing constraint, create the floorplan, build power rings, place standard cells, run Clock Tree Synthesis (CTS), perform routing, and execute timing verification.

Run Innovus from the project root:
```bash
innovus -files flow/innovus/<architecture>.tcl -log flow/logs/innovus_<architecture>.log
```

### Stage 8: Post-Route Timing and SAIF-Based Power Analysis
Innovus automatically checks for SAIF files in `flow/saif/<architecture>.saif` to perform **dynamic post-route power analysis** and outputs it to `flow/reports/innovus/<architecture>_power.rpt`.

---

## Frequency Sweep Automation

To evaluate frequency-power scaling and identify the **Maximum Achievable Clock Frequency ($F_{max}$)** without manual configuration:

1. Give the automation script execution permissions:
   ```bash
   chmod +x flow/run_frequency_sweep.sh
   ```
2. Run the script from the project root:
   ```bash
   ./flow/run_frequency_sweep.sh
   ```
This script exports the `CLK_PERIOD` environment variable dynamically to scale constraints in both Genus and Innovus. Mapped netlists and reports will be saved with period suffixes (e.g. `baseline_synth_1.8ns.v`, `baseline_power_1.8ns.rpt`).

---

## Professional Comparison Tables

After running the full flow, extract metrics from the report files to fill out these tables for your paper.

### Table I: Synthesis and Physical Implementation Comparison (Target: 500 MHz / 2.0 ns)
Extract area from `<architecture>_area.rpt`, timing (WNS/TNS) from the timing directory, and power from `<architecture>_power.rpt`.

| Architecture | Cell Count | Core Area ($\mu m^2$) | WNS ($ps$) | TNS ($ps$) | Clock Gating Cells | Dynamic Power ($mW$) | Leakage Power ($mW$) | Total Power ($mW$) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | | | | | | | | |
| **PE Gated** | | | | | | | | |
| **Row Gated** | | | | | | | | |
| **Tile Gated** | | | | | | | | |
| **Hierarchical** | | | | | | | | |
| **AHSA** | | | | | | | | |

* **Area Overhead Check:**
  $$\text{AHSA Area Overhead} = \frac{\text{AHSA Area} - \text{Baseline Area}}{\text{Baseline Area}} \times 100\%$$
* **Clock Gating Efficiency:** Check `<architecture>_clock_gating.rpt` to verify register coverage.

---

### Table II: Workload Sparsity Evaluation Matrix (Measured Dynamic Power @ 500 MHz)
Dynamic power consumption ($mW$) extracted from post-route reports with SAIF back-annotation:

| Architecture | Dense (0%) | Sparse 50% | Sparse 70% | Sparse 90% | Sparse 95% | AlexNet | VGG16 | ResNet18 | MobileNetV2 | EfficientNet-B0 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | | | | | | | | | | |
| **PE Gated** | | | | | | | | | | |
| **Row Gated** | | | | | | | | | | |
| **Tile Gated** | | | | | | | | | | |
| **Hierarchical** | | | | | | | | | | |
| **AHSA (Adaptive)** | | | | | | | | | | |

---

### Table III: Frequency-Power Scaling (Baseline vs. AHSA)
Report dynamic post-route power scaling ($mW$) and timing slack across target frequencies.

| Clock Period | Target Frequency | Baseline Power | AHSA Power | Baseline WNS ($ps$) | AHSA WNS ($ps$) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **3.0 ns** | 333 MHz | | | | |
| **2.5 ns** | 400 MHz | | | | |
| **2.0 ns** | 500 MHz | | | | |
| **1.8 ns** | 555 MHz | | | | |
| **1.6 ns** | 625 MHz | | | | |

* **Identifying $F_{max}$:** Run smaller period decrements (e.g. `1.7ns`, `1.5ns`) to identify the boundary where Worst Negative Slack (WNS) setup transitions below zero. Report the last passing frequency as $F_{max}$.
