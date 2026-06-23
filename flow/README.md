# HSA16 ASIC Implementation Lab Guide

This guide details the execution of the **HSA16 AI Accelerator** design space exploration across all six architectures. Follow these steps in the Cadence lab to generate silicon-credible, SAIF-backed power and timing reports for your paper.

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
├── xrun/               # Simulation VCD and SAIF activity files
├── run_flow.sh         # Unified flow runner script (runs single architecture)
├── run_all.sh          # Master sweep runner script (runs all architectures)
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

## Cadence Lab Quickstart & Tool Setup

Before launching the flows on CentOS/RHEL lab systems, verify your environment configurations.

### 1. Verify Cadence Environment Paths

Ensure all standard Cadence binaries are available in your PATH by executing:

```bash
which xrun
which genus
which innovus
which vcd2saif
```

Expected paths should look like:

* `/tools/cadence/XCELIUM/bin/xrun`
* `/tools/cadence/GENUS/bin/genus`
* `/tools/cadence/INNOVUS/bin/innovus`
* `/tools/cadence/bin/vcd2saif`

If any return `command not found`, load them using your lab's module loader, for example:

```bash
module load cadence/xcelium
module load cadence/genus
module load cadence/innovus
```

### 2. Physical Design Licenses Verification

Innovus runs can fail silently or hang if standard physical implementation licenses are checked out. Test license availability by spawning Innovus in command-line mode:

```bash
innovus -nowin
```

If it successfully loads the console without errors, type `exit` to close it.

---

## Troubleshooting common CentOS/Linux environment issues

### Issue A: Windows Line Endings (CRLF)

If files were checked out or copied from a Windows environment, they may contain hidden carriage return (`\r`) characters. This will cause shell script executions to fail with:

```text
/bin/bash^M: bad interpreter: No such file or directory
```

Fix all scripts using `dos2unix` or `sed`:

```bash
# Option 1: Using dos2unix
dos2unix flow/*.sh

# Option 2: Using sed regex fallback
sed -i 's/\r$//' flow/*.sh
```

### Issue B: Script Execution Permissions

Always ensure shell scripts have execution rights assigned:

```bash
chmod +x flow/run_flow.sh
chmod +x flow/run_all.sh
```

---

## Running the Flow

### Method 1: Execute Single Architecture (Recommended for first run)

Launch the unified runner script providing the target architecture name:

```bash
./flow/run_flow.sh <architecture>
```

Supported names: `baseline`, `pe_gating` (or `pe`), `row_gating` (or `row`), `tile_gating` (or `tile`), `hierarchical`, `adaptive`.

Example:

```bash
./flow/run_flow.sh adaptive
```

This automates the entire flow: compiles and runs the simulator $\rightarrow$ measures simulator runtime $\rightarrow$ dumps VCD toggling activity $\rightarrow$ converts VCD to SAIF $\rightarrow$ runs Genus synthesis $\rightarrow$ runs Innovus physical design $\rightarrow$ logs all step runtimes.

### Method 2: Master Sweep Runner

To execute all six architectures sequentially:

```bash
./flow/run_all.sh
```

If any sub-flow fails, the master script terminates immediately (`set -e`) to prevent bad netlists from cascading into PnR.

---

## Alternative: Direct SAIF Generation via Xcelium

If the `vcd2saif` utility is missing on your lab machine, you can generate the SAIF activity file directly during simulation, removing the VCD translation step.

Add these system task blocks inside your testbench files:

```systemverilog
// Start activity profiling at the top of testbench execution
initial begin
    $set_toggle_region(<testbench_module_name>.dut);
    $toggle_start();
end

// Dump the SAIF report at the end of the simulation
final begin
    $toggle_stop();
    $toggle_report("flow/xrun/<architecture>.saif", 1.0e-9, "<testbench_module_name>.dut");
end
```

Xcelium will automatically generate `<architecture>.saif` inside `flow/xrun/` when simulation terminates, which Genus and Innovus will read directly.

---

## Professional Comparison Tables

After running the full flow, extract metrics from the report files to fill out these tables for your paper.

### Table I: Synthesis and Physical Implementation Comparison (Target: 500 MHz / 2.0 ns)

Extract area from `<architecture>_post_route_area.rpt`, timing (WNS/TNS) from the timing directory, and power from `<architecture>_post_route_power.rpt`.

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
