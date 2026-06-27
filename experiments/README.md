# HSA16 Gating Trade-off Evaluation (Hierarchical vs. AHSA)

This experiment workspace is configured to answer the question:
**Is Adaptive Hierarchical Sparsity-Aware Gating (AHSA) a better implementation trade-off than always-on Hierarchical Gating?**

---

## Workflow Steps

```
Step 1: Run Xrun Simulation (xrun)
        │
        ├── Runs RTL testbench for workloads
        └── Generates SAIF activity profile (using vcd2saif)
        │
Step 2: Run Genus Technology Synthesis (genus)
        │
        ├── Maps RTL to generic and standard cells (typical.lib)
        └── Outputs gate-level netlist, constraints, and reports
        │
Step 3: Run Innovus Place-and-Route (innovus)
        │
        ├── Performs floorplanning, placement, CTS, routing
        └── Outputs post-route area, timing, and dynamic power
        │
Step 4: Collect Results
        │
        └── Fill out the Paper Evaluation Tables below
```

---

## How to Run Commands

First, ensure the runner script has execute permissions:

```bash
chmod +x run.sh
```

Then run the steps from the `experiments/` directory:

### 1. Hierarchical Gating Flow

```bash
# Run simulation & dump activity profile
./run.sh hierarchical xrun

# Run synthesis (outputs netlist and genus reports)
./run.sh hierarchical genus

# Run physical place-and-route (outputs PnR layout and innovus reports)
./run.sh hierarchical innovus
```

### 2. Adaptive Gating (AHSA) Flow

```bash
# Run simulation & dump activity profile
./run.sh adaptive xrun

# Run synthesis (outputs netlist and genus reports)
./run.sh adaptive genus

# Run physical place-and-route (outputs PnR layout and innovus reports)
./run.sh adaptive innovus
```

*Note: Line endings are automatically normalized to Unix formatting on launch.*

---

## Paper Evaluation Tables

As you execute the scripts, extract the metrics from the generated reports inside `flow/reports/` and populate the comparison tables below:

### TABLE 1: RTL Workload Execution (Simulation)
*Source: `flow/reports/xrun/hierarchical.log` and `flow/reports/xrun/adaptive.log`*

| Metric | Hierarchical Gating | AHSA (Adaptive) |
| :--- | :--- | :--- |
| **Identity Matrix Pass** | [Pass/Fail] | [Pass/Fail] |
| **All-Ones Matrix Pass** | [Pass/Fail] | [Pass/Fail] |
| **Total Executed MACs (Dense)** | 4064 | 4080 |
| **Total Executed MACs (EfficientNet)** | 0 | 176 |
| **Tile skips (EfficientNet)** | 3920 | 3920 |
| **Row skips (EfficientNet)** | 128 | 0 |
| **PE skips (EfficientNet)** | 48 | 0 |

---

### TABLE 2: Synthesis Results (Genus)
*Source: `flow/reports/genus/hierarchical_*.rpt` and `flow/reports/genus/adaptive_*.rpt`*

| Metric | Hierarchical Gating | AHSA (Adaptive) |
| :--- | :--- | :--- |
| **Total Cell Area** | | |
| **Dynamic Power (vectorless)** | | |
| **Leakage Power** | | |
| **Total Leaf Instances (Cells)** | | |
| **Clock-Gating Cells Inserted** | | |
| **Worst Negative Slack (WNS)** | | |
| **Total Negative Slack (TNS)** | | |

---

### TABLE 3: Layout & Physical Results (Innovus)
*Source: `flow/reports/innovus/hierarchical_*.rpt` and `flow/reports/innovus/adaptive_*.rpt`*

| Metric | Hierarchical Gating | AHSA (Adaptive) |
| :--- | :--- | :--- |
| **Core Area ($\mu m^2$)** | | |
| **Cell Utilization (%)** | | |
| **Routing Congestion (%)** | | |
| **Buffer/Inverter Count** | | |
| **CTS Insertion Delay** | | |
| **Total Wirelength** | | |
| **Post-Route Power (SAIF Back-Annotated)** | | |
| **Post-Route Setup WNS** | | |

---

### TABLE 4: Overall Trade-Off Summary

| Metric | Winner / Best Choice | Engineering Rationale |
| :--- | :--- | :--- |
| **Dynamic Power** | | |
| **Leakage Power** | | |
| **Silicon Area** | | |
| **Routing & Congestion** | | |
| **Timing Closure ($F_{max}$)**| | |
| **Hardware Scalability** | | |
