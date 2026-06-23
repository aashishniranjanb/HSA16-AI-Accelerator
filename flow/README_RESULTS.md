# HSA16 Gating Architectures Evaluation & Paper Results

This document presents the implementation block diagram and post-synthesis / post-route characterization results of the HSA16 Systolic Accelerator for our paper.

---

## 1. Accelerator Architecture Diagram

The block diagram below illustrates the design layout, detailing the connection from the Host/Testbench down to the individual Processing Elements (PEs) and gating blocks:

```text
┌───────────────────────────────────────────────────────────┐
│                 Host / Testbench Interface                │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────────┐
│                  AHSA Runtime Controller                  │
│                                                           │
│  • Sparsity Estimator                                     │
│  • Effective Sparsity Calculator                          │
│  • Gating FSM                                             │
│      IDLE → LOAD → ESTIMATE → SELECT → RUN                │
│  • Mode Selection Logic                                   │
└──────────────┬──────────────────────────────┬─────────────┘
               │                              │
               │ Gating Control Signals       │
               ▼                              ▼
      ┌─────────────────────────────────────────────┐
      │         Hierarchical Gating Network         │
      │                                             │
      │  PE Gating                                  │
      │  Row Gating                                 │
      │  Tile Gating                                │
      └───────────────┬─────────────────────────────┘
                      │
                      ▼
┌───────────────────────────────────────────────────────────┐
│                 16×16 Systolic Array Core                 │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌────┬────┬────┬────┬────┬────┬────┬────┐               │
│  │PE00│PE01│PE02│... │... │... │... │PE15│               │
│  ├────┼────┼────┼────┼────┼────┼────┼────┤               │
│  │PE10│PE11│PE12│... │... │... │... │PE1F│               │
│  ├────┼────┼────┼────┼────┼────┼────┼────┤               │
│  │ .. │ .. │ .. │    16×16 Array     ... │               │
│  ├────┼────┼────┼────┼────┼────┼────┼────┤               │
│  │PEF0│PEF1│PEF2│... │... │... │... │PEFF│               │
│  └────┴────┴────┴────┴────┴────┴────┴────┘               │
│                                                           │
└───────────────┬───────────────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────────────┐
│                  Accumulator / Output Buffer              │
└───────────────┬───────────────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────────────┐
│                    Verification Framework                 │
├───────────────────────────────────────────────────────────┤
│ • Dense Workloads                                         │
│ • Sparse50 / Sparse70 / Sparse90 / Sparse95               │
│ • AlexNet                                                 │
│ • VGG16                                                   │
│ • ResNet18                                                │
│ • MobileNetV2                                             │
│ • EfficientNet-B0                                         │
│ • NumPy Golden Model Comparison                           │
└───────────────────────────────────────────────────────────┘
```

---

## 2. IEEE-Style Evaluation Tables

### TABLE I
### BASELINE SYNTHESIS RESULTS OF THE 16×16 SYSTOLIC ARRAY

| Metric | Value |
| :--- | :--- |
| Processing Elements | 256 |
| Array Dimensions | 16 × 16 |
| Operating Frequency | 500 MHz |
| Clock Period | 2 ns |
| Worst Negative Slack (WNS) | 62.9 ps |
| Total Negative Slack (TNS) | 0 ps |
| Sequential Cell Count | 43,496 |
| Combinational Cell Count | 73,729 |
| Total Leaf Instances | 117,225 |
| Dynamic Power | 500.32 mW |
| Leakage Power | 0.0525 mW |
| Total Power | 500.37 mW |

---

### TABLE II
### WORKLOAD SPARSITY CHARACTERIZATION

| Workload | Sparsity (%) | Description |
| :--- | :--- | :--- |
| Dense | 0.00 | Baseline dense workload |
| Sparse50 | 50.00 | Synthetic sparse matrix |
| Sparse70 | 70.00 | Synthetic sparse matrix |
| Sparse90 | 90.00 | Synthetic sparse matrix |
| Sparse95 | 95.00 | Synthetic sparse matrix |
| AlexNet | 48.83 | CNN convolution layer |
| VGG16 | 70.70 | CNN convolution layer |
| ResNet18 | 89.06 | Residual CNN layer |
| MobileNetV2 | 95.70 | Depthwise convolution layer |
| EfficientNet-B0 | 98.40 | Edge-optimized CNN layer |

---

### TABLE III
### DYNAMIC POWER COMPARISON OF STATIC GATING TECHNIQUES

| Workload | Baseline (mW) | PE Gating (mW) | Row Gating (mW) | Tile Gating (mW) | Hierarchical (mW) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Dense | 500.4 | 499.0 | 498.8 | 500.4 | **498.1** |
| AlexNet | 500.4 | 366.5 | 416.0 | 432.8 | **240.1** |
| VGG16 | 500.4 | 341.7 | 409.7 | 419.3 | **172.5** |
| ResNet18 | 500.4 | 326.5 | 405.0 | 401.3 | **88.6** |
| MobileNetV2 | 500.4 | 325.4 | 405.0 | 393.4 | **58.3** |
| EfficientNet-B0 | 500.4 | 325.0 | 404.8 | 385.2 | **45.2** |

*(Bold values indicate the minimum power consumed per workload row)*

---

### TABLE IV
### ADAPTIVE HIERARCHICAL SPARSITY-AWARE (AHSA) RESULTS

| Workload | Effective Sparsity (%) | Selected Mode | Estimated Dynamic Power (mW) |
| :--- | :--- | :--- | :--- |
| Dense | 0.39 | PE Gating | 499.7 |
| Sparse50 | 50.59 | Row Gating | 476.9 |
| Sparse70 | 70.51 | Row Gating | 386.2 |
| Sparse90 | 88.87 | Tile Gating | 169.6 |
| Sparse95 | 95.51 | Tile Gating | 111.6 |
| AlexNet | 51.56 | Row Gating | 456.6 |
| VGG16 | 69.92 | Row Gating | 386.2 |
| ResNet18 | 90.62 | Tile Gating | 180.2 |
| MobileNetV2 | 97.27 | Tile Gating | 76.4 |
| EfficientNet-B0 | 98.44 | Tile Gating | 60.5 |

---

### TABLE V
### PE GATING ACTIVITY REDUCTION

| Workload | Gated MAC Operations | Percentage (%) |
| :--- | :--- | :--- |
| Dense | 32 | 0.78 |
| Sparse50 | 3064 | 74.80 |
| Sparse70 | 3726 | 90.97 |
| Sparse90 | 4051 | 98.90 |
| Sparse95 | 4091 | 99.88 |
| AlexNet | 3132 | 76.46 |
| VGG16 | 3711 | 90.60 |
| ResNet18 | 4068 | 99.32 |
| MobileNetV2 | 4094 | 99.95 |
| EfficientNet-B0 | 4095 | 99.98 |

---

### TABLE VI
### AHSA RUNTIME GATING BREAKDOWN

| Workload | PE Gated | Row Gated | Tile Gated | Executed MACs |
| :--- | :--- | :--- | :--- | :--- |
| Dense | 16 | 0 | 0 | 4080 |
| Sparse50 | 0 | 240 | 0 | 3856 |
| Sparse70 | 0 | 1168 | 0 | 2928 |
| Sparse90 | 0 | 0 | 3008 | 1088 |
| Sparse95 | 0 | 0 | 3536 | 560 |
| AlexNet | 0 | 448 | 0 | 3648 |
| VGG16 | 0 | 1168 | 0 | 2928 |
| ResNet18 | 0 | 0 | 2912 | 1184 |
| MobileNetV2 | 0 | 0 | 3856 | 240 |
| EfficientNet-B0 | 0 | 0 | 3968 | 128 |

---

## 3. Paper Figure Captions & Data References

### Figure 3. Dynamic Power Comparison Across DNN Workloads

Observed dynamic power consumption ($mW$) across evaluated gating architectures (Baseline, PE-gated, Row-gated, Tile-gated, and Hierarchical gating):

| Workload | Baseline | PE Gating | Row Gating | Tile Gating | Hierarchical |
| :--- | :--- | :--- | :--- | :--- | :--- |
| AlexNet | 500.4 | 366.5 | 416.0 | 432.8 | 240.1 |
| VGG16 | 500.4 | 341.7 | 409.7 | 419.3 | 172.5 |
| ResNet18 | 500.4 | 326.5 | 405.0 | 401.3 | 88.6 |
| MobileNetV2 | 500.4 | 325.4 | 405.0 | 393.4 | 58.3 |
| EfficientNet-B0 | 500.4 | 325.0 | 404.8 | 385.2 | 45.2 |

> **Figure 3 Caption**: Dynamic power comparison of various gating methodologies across representative DNN workloads. The hierarchical architecture consistently achieves the lowest power consumption, with increasing benefits at higher sparsity levels.

---

### Figure 4. Sparsity Characteristics of Evaluated DNN Workloads

Sparsity profiles loaded during validation and characterization:

| Workload | Sparsity (%) |
| :--- | :--- |
| Dense | 0.00 |
| Sparse50 | 50.00 |
| Sparse70 | 70.00 |
| Sparse90 | 90.00 |
| Sparse95 | 95.00 |
| AlexNet | 48.83 |
| VGG16 | 70.70 |
| ResNet18 | 89.06 |
| MobileNetV2 | 95.70 |
| EfficientNet-B0 | 98.40 |

> **Figure 4 Caption**: Sparsity distribution of synthetic and real-world DNN workloads. Modern edge-oriented architectures such as MobileNetV2 and EfficientNet-B0 exhibit extremely high sparsity, motivating aggressive runtime gating techniques.

---

### Figure 5. AHSA Runtime Mode Selection vs Effective Sparsity

Mode selection thresholds configured within the FSM controller:

| Effective Sparsity Range | Selected Mode |
| :--- | :--- |
| **< 50%** | PE Gating Mode |
| **50% – 80%** | Row Gating Mode |
| **> 80%** | Tile Gating Mode |

> **Figure 5 Caption**: AHSA dynamic runtime execution mode mapping logic based on dynamic zero-coefficient counts. Hysteresis loops filter transients on boundary conditions.
