# Cadence EDA Tools Guide & Evaluation Methodology

In modern ASIC research and hardware accelerator publications, reviewers expect silicon-credible verification and implementation metrics. This guide outlines the role, significance, and integration of the primary Cadence EDA tools for the **HSA16 Systolic Accelerator** design space exploration.

---

## 1. Tool Prioritization Taxonomy

Not all EDA tools are equally relevant for digital architecture papers. The table below ranks Cadence tools based on their impact on publication quality and implementation metrics:

| Priority | Tool Name | Academic Value / Metrics Provided | Relevancy for HSA16 |
| :--- | :--- | :--- | :--- |
| **High** (5/5) | **Genus Synthesis** | Area, Timing, dynamic/leakage power, Gate Count, Clock Gating Coverage | **Essential:** Translates RTL to gate-level standard cells. |
| **High** (5/5) | **Innovus PnR** | Floorplanning, cell placement, Clock Tree Synthesis (CTS), routing, congestion, wirelength | **Essential:** Performs physical place-and-route to generate physical layouts. |
| **High** (4/5) | **Tempus Timing** | Sign-off Static Timing Analysis (STA), setup/hold slack, worst timing paths, TNS/WNS | **Recommended:** Replaces Genus estimated timing with sign-off delay equations. |
| **High** (4/5) | **Voltus Power** | Sign-off dynamic power, power grid analysis, IR-drop verification, EM analysis | **Recommended:** Replaces static power estimations with sign-off grid power. |
| **Medium** (3/5) | **JasperGold** | Formal Verification, mathematical proof of RTL equivalence (Baseline vs. Gated) | **Nice to Have:** Proves that gating does not alter numerical behavior. |
| **Medium** (2/5) | **Conformal LEC** | Logic Equivalence Checking (RTL vs. Mapped Netlist, Netlist vs. Post-route Netlist) | **Nice to Have:** Confirms synthesis optimization did not break logic. |
| **Low** (1/5) | **Pegasus Signoff** | Physical sign-off verification (DRC: Design Rule Check, LVS: Layout vs. Schematic) | **Low Relevancy:** Only needed for tape-out GDS generation. |
| **None** (0/5) | **Spectre SPICE** | Analog circuit simulator, transistor-level transient/DC analysis, SPICE parameters | **Not Applicable:** HSA16 is a fully digital standard-cell architecture. |

---

## 2. Essential Tools (Must-Use)

### 2.1 Cadence Genus (Synthesis)
* **Purpose:** Compiles SystemVerilog RTL, targets timing constraints, and maps design registers and logic gates to foundry-specific standard cells.
* **Key Paper Metrics:**
  * **Gate Count / Area:** Core area in square micrometers ($\mu m^2$) and equivalent NAND2 gate counts. Used to prove the area overhead of AHSA's controllers is negligible.
  * **Dynamic & Leakage Power:** Static power calculations.
  * **Clock Gating Coverage:** Inferred gating cells and percentage of gated sequential bits (gated registers).
* **Usage Command:**
  ```bash
  genus -files flow/genus/<architecture>.tcl -log flow/logs/genus_<architecture>.log
  ```

### 2.2 Cadence Innovus (Physical Place & Route)
* **Purpose:** Positions standard cells on rows, routes the power grid, builds the clock tree (CTS), and routes signal wires.
* **Key Paper Metrics:**
  * **Congestion Map:** Wire density hot-spots to demonstrate route feasibility.
  * **CTS Quality:** Clock skew, latency, and tree structure sizes (`report_ccopt_clock_trees`).
  * **Post-Route Timing & Power:** Silicon-credible setup/hold slack (WNS/TNS) and dynamic power consumption back-annotated with SAIF dynamic simulation activity.
* **Usage Command:**
  ```bash
  innovus -files flow/innovus/<architecture>.tcl -log flow/logs/innovus_<architecture>.log
  ```

---

## 3. Advanced Verification Tools (Recommended Extensions)

### 3.1 Cadence Tempus (Sign-off Timing Analysis)
* **Why it matters:** Synthesis and PnR tools use simplified, fast timing delay models to accelerate runtime. Tempus performs sign-off timing analysis using high-accuracy cell delay calculations across process, voltage, and temperature (PVT) corners.
* **Paper Integration:** Allows you to state: *"Timing closure and WNS/TNS slacks were validated under sign-off conditions using Cadence Tempus."* This removes any doubts about timing violations.

### 3.2 Cadence Voltus (Power Integrity & IR Drop)
* **Why it matters:** Clock-gating and dynamic mode switching create sudden fluctuations in current draw ($dI/dt$). Voltus calculates dynamic IR drop (voltage sag on VDD/VSS rails) to verify that the power rings can support dynamic mode changes without inducing timing failure.
* **Paper Integration:** Voltus provides dynamic rail sag and electromigration (EM) profiles. This is crucial for verifying that the transition-state noise in CA-AHSA is safe.

---

## 4. Formal and Equivalence Checks (Optional)

### 4.1 JasperGold (Formal Verification)
* **Why it matters:** Instead of running millions of random simulation test vectors, JasperGold uses formal mathematical solvers to prove design properties.
* **Paper Integration:** Proves that the PE, Row, and Tile gating controllers are **100% bit-exact** equivalent to the baseline architecture across all possible inputs.

### 4.2 Conformal Logic Equivalence Checker (LEC)
* **Why it matters:** Compares two netlists (e.g., RTL vs. Genus Netlist, or Genus Netlist vs. Innovus Netlist) to guarantee that cell optimizations, scan insertion, and clock tree routing did not introduce logical bugs.
