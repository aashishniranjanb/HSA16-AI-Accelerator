# ASIC Experiment: Frequency Sweeps & $F_{max}$ Scaling Study

This document details the methodology for evaluating the timing margins, frequency scaling properties, and maximum operational frequency ($F_{max}$) of the **HSA16 Systolic Accelerator**. 

---

## 1. Rationale for Frequency Analysis

While standard accelerator papers compare architectures at a single unified frequency (e.g., **500 MHz**), conducting a frequency scaling study adds valuable hardware-level depth by demonstrating:
* **Worst Negative Slack (WNS) Trends:** How timing margin scales as period decreases.
* **Maximum Operational Frequency ($F_{max}$):** The physical limit of the pipelined execution path before setup timing violations occur.
* **Frequency vs. Power scaling:** The relationship between operating frequency and dynamic power dissipation.

---

## 2. Timing Sweep Methodology

To run a frequency sweep experiment in the lab, follow this manual step-by-step procedure to adjust timing constraints and collect corresponding reports:

### Step 1: Adjust constraints file
Open the constraints file at `flow/constraints/systolic16x16.sdc` and adjust the target clock period:
```sdc
# For 333 MHz target (3.0 ns)
create_clock -name clk -period 3.0 [get_ports clk]

# For 400 MHz target (2.5 ns)
# create_clock -name clk -period 2.5 [get_ports clk]

# For 500 MHz target (2.0 ns)
# create_clock -name clk -period 2.0 [get_ports clk]

# For 555 MHz target (1.8 ns)
# create_clock -name clk -period 1.8 [get_ports clk]

# For 625 MHz target (1.6 ns)
# create_clock -name clk -period 1.6 [get_ports clk]
```

### Step 2: Run Genus Synthesis
Run the standard Genus synthesis command:
```bash
genus -files flow/genus/baseline.tcl -log flow/logs/genus_baseline_sweep.log
genus -files flow/genus/adaptive.tcl -log flow/logs/genus_adaptive_sweep.log
```

### Step 3: Run Innovus Place & Route
Run the physical PnR flow to place and route the designs:
```bash
innovus -files flow/innovus/baseline.tcl -log flow/logs/innovus_baseline_sweep.log
innovus -files flow/innovus/adaptive.tcl -log flow/logs/innovus_adaptive_sweep.log
```

### Step 4: Extract Metrics
Open the resulting post-route reports under `flow/reports/innovus/` for each run and record:
* **Core Area** (from `baseline_area.rpt` / `adaptive_area.rpt`)
* **WNS Timing Slack** (from timing reports)
* **Dynamic & Leakage Power** (from power reports)

---

## 3. Finding Maximum Frequency ($F_{max}$)

To find the absolute physical performance limit ($F_{max}$) under the TSMC 28nm/45nm technology library:

1. Synthesize and PnR the design with a clock period of **1.8 ns (555 MHz)**.
2. Check the post-route **Worst Negative Slack (WNS)** in the timing reports.
3. If WNS is positive (e.g. $+30\text{ ps}$), decrease the clock period further:
   * Try **1.7 ns (588 MHz)**, **1.6 ns (625 MHz)**, and **1.5 ns (666 MHz)**.
4. If WNS becomes negative (e.g. $-45\text{ ps}$), timing is violated.
5. The highest frequency with a non-negative WNS ($WNS \ge 0$) is your design's **$F_{max}$**.

---

## 4. Experimental Results Template

Compile the gathered metrics into the following template for publication:

### Table I: Frequency vs. Timing Slack & Power Scaling

| Target Period | Target Frequency | Baseline WNS ($ps$) | AHSA WNS ($ps$) | Baseline Power ($mW$) | AHSA Power ($mW$) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **3.0 ns** | 333 MHz | | | | |
| **2.5 ns** | 400 MHz | | | | |
| **2.0 ns** | 500 MHz | | | | |
| **1.8 ns** | 555 MHz | | | | |
| **1.6 ns** | 625 MHz | | | | |

### Table II: Maximum Frequency ($F_{max}$) Limits

| Architecture | Mapped Cell Count | Post-Route Core Area ($\mu m^2$) | Maximum Frequency ($F_{max}$) | Critical Path Logic Depth |
| :--- | :--- | :--- | :--- | :--- |
| **Baseline** | | | | |
| **AHSA (Adaptive)** | | | | |
