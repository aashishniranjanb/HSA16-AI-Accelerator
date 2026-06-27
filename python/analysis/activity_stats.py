#!/usr/bin/env python3
"""
============================================================
HSA-16 Activity Statistics — MAC Toggle Analysis
============================================================

Analyzes MAC operation activity across different workloads
to quantify the opportunity for sparsity-based gating.

For a 16×16 weight-stationary systolic array computing C = A × B:
  - Total MACs per matrix multiply = N × N × N = 4096
  - A zero MAC occurs when act_in == 0 OR weight_in == 0
  - Useful (active) MACs = total - zero MACs
  - Gating ratio = zero MACs / total MACs

Outputs:
    docs/results/activity_stats.csv
    Console summary table

Usage:
    python python/analysis/activity_stats.py
"""

import numpy as np
from pathlib import Path
import csv
import sys

# ============================================================
# Configuration
# ============================================================

N = 16  # Array dimension
PROJECT_ROOT = Path(__file__).parent.parent.parent
VECTOR_DIR = PROJECT_ROOT / "vectors"
RESULTS_DIR = PROJECT_ROOT / "docs" / "results"

# DNN workload sparsity levels (for synthetic generation)
DNN_WORKLOADS = {
    "AlexNet":      0.4883,
    "VGG16":        0.7070,
    "ResNet18":     0.8906,
    "MobileNetV2":  0.9570,
}

# ============================================================
# MAC Activity Analysis
# ============================================================

def analyze_mac_activity(A, B):
    """
    Analyze MAC operations for C = A × B on a 16×16 systolic array.

    In weight-stationary dataflow:
      - PE[k][j] computes: psum += A[i][k] * B[k][j]
      - For each output row i, all N×N PEs perform one MAC
      - Total MACs = N (output rows) × N (PE rows) × N (PE cols) = N³

    A MAC is "zero" (gatable) if either operand is zero:
      - act_in (A[i][k]) == 0, OR
      - weight_in (B[k][j]) == 0

    Returns:
        dict with activity statistics
    """
    total_macs = 0
    zero_macs = 0
    act_zero_macs = 0
    weight_zero_macs = 0
    both_zero_macs = 0

    # For each output row i of C
    for i in range(N):
        # For each PE position [k][j]
        for k in range(N):
            for j in range(N):
                total_macs += 1
                a_val = int(A[i, k])
                b_val = int(B[k, j])

                a_is_zero = (a_val == 0)
                b_is_zero = (b_val == 0)

                if a_is_zero or b_is_zero:
                    zero_macs += 1

                if a_is_zero and b_is_zero:
                    both_zero_macs += 1
                elif a_is_zero:
                    act_zero_macs += 1
                elif b_is_zero:
                    weight_zero_macs += 1

    active_macs = total_macs - zero_macs
    useful_ratio = active_macs / total_macs if total_macs > 0 else 0.0
    gating_ratio = zero_macs / total_macs if total_macs > 0 else 0.0

    return {
        "total_macs": total_macs,
        "active_macs": active_macs,
        "zero_macs": zero_macs,
        "act_zero_only": act_zero_macs,
        "weight_zero_only": weight_zero_macs,
        "both_zero": both_zero_macs,
        "useful_ratio": useful_ratio,
        "gating_ratio": gating_ratio,
    }


def compute_sparsity(matrix):
    """Compute sparsity (fraction of zeros) in a matrix."""
    total = matrix.size
    zeros = np.count_nonzero(matrix == 0)
    return zeros / total


# ============================================================
# Workload Processing
# ============================================================

def process_vector_dataset(name, dataset_dir):
    """Process a single vector dataset and return activity stats."""
    a_path = dataset_dir / "A.npy"
    b_path = dataset_dir / "B.npy"

    if not a_path.exists() or not b_path.exists():
        print(f"  [SKIP] {name}: .npy files not found in {dataset_dir}")
        return None

    A = np.load(a_path)
    B = np.load(b_path)

    stats = analyze_mac_activity(A, B)

    # Add sparsity info
    stats["a_sparsity"] = compute_sparsity(A)
    stats["b_sparsity"] = compute_sparsity(B)
    stats["combined_sparsity"] = (stats["a_sparsity"] + stats["b_sparsity"]) / 2.0

    return stats


def generate_dnn_workload(name, sparsity, rng):
    """
    Generate synthetic matrices with specified sparsity level
    to simulate DNN workload characteristics.
    """
    A = rng.integers(-128, 128, size=(N, N), dtype=np.int16).astype(np.int8)
    B = rng.integers(-128, 128, size=(N, N), dtype=np.int16).astype(np.int8)

    # Apply sparsity to both matrices
    mask_A = rng.random((N, N)) < sparsity
    mask_B = rng.random((N, N)) < sparsity
    A[mask_A] = 0
    B[mask_B] = 0

    return A, B


# ============================================================
# Output Formatting
# ============================================================

def print_summary_table(results):
    """Print formatted summary table to console."""
    print("\n" + "=" * 100)
    print(f"{'Workload':<15} {'Total MACs':>12} {'Active MACs':>12} {'Idle MACs':>12} "
          f"{'Useful Ratio':>13} {'Gating Ratio':>13} {'A Sparsity':>11} {'B Sparsity':>11}")
    print("=" * 100)

    for name, stats in results:
        print(f"{name:<15} {stats['total_macs']:>12,} {stats['active_macs']:>12,} "
              f"{stats['zero_macs']:>12,} {stats['useful_ratio']:>12.2%} "
              f"{stats['gating_ratio']:>12.2%} {stats['a_sparsity']:>10.2%} "
              f"{stats['b_sparsity']:>10.2%}")

    print("=" * 100)


def save_csv(results, output_path):
    """Save results to CSV file."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "Workload",
            "Total MACs",
            "Active MACs",
            "Idle MACs",
            "Useful MAC Ratio",
            "Gating Ratio",
            "A Sparsity",
            "B Sparsity",
            "Activation-Zero MACs",
            "Weight-Zero MACs",
            "Both-Zero MACs",
        ])

        for name, stats in results:
            writer.writerow([
                name,
                stats["total_macs"],
                stats["active_macs"],
                stats["zero_macs"],
                f"{stats['useful_ratio']:.4f}",
                f"{stats['gating_ratio']:.4f}",
                f"{stats['a_sparsity']:.4f}",
                f"{stats['b_sparsity']:.4f}",
                stats["act_zero_only"],
                stats["weight_zero_only"],
                stats["both_zero"],
            ])

    print(f"\n  Saved: {output_path}")


# ============================================================
# Main
# ============================================================

def main():
    print("=" * 60)
    print(" HSA-16 MAC Activity Statistics")
    print(f" Array Size: {N}×{N}")
    print(f" Total MACs per matmul: {N**3}")
    print("=" * 60)

    results = []

    # Name mapping for clean output
    NAME_MAPPING = {
        "dense": "Dense",
        "sparse50": "Sparse50",
        "sparse70": "Sparse70",
        "sparse90": "Sparse90",
        "sparse95": "Sparse95",
        "alexnet": "AlexNet",
        "vgg16": "VGG16",
        "resnet18": "ResNet18",
        "mobilenetv2": "MobileNetV2",
        "efficientnet_b0": "EfficientNet-B0"
    }

    # ---- Process existing vector datasets ----

    existing_datasets = [
        "dense", "sparse50", "sparse70", "sparse90", "sparse95",
        "alexnet", "vgg16", "resnet18", "mobilenetv2", "efficientnet_b0"
    ]

    for dataset_name in existing_datasets:
        dataset_dir = VECTOR_DIR / dataset_name
        if dataset_dir.exists():
            print(f"\n  Processing: {dataset_name}")
            stats = process_vector_dataset(dataset_name, dataset_dir)
            if stats:
                display_name = NAME_MAPPING.get(dataset_name, dataset_name.capitalize())
                results.append((display_name, stats))

    # ---- Output ----

    print_summary_table(results)

    output_csv = RESULTS_DIR / "activity_stats.csv"
    save_csv(results, output_csv)

    # ---- Key Insight Summary ----

    print("\n" + "-" * 60)
    print(" KEY INSIGHT: Sparsity Gating Opportunity")
    print("-" * 60)

    for name, stats in results:
        if stats["gating_ratio"] > 0.01:
            savings_pct = stats["gating_ratio"] * 100
            print(f"  {name:15s}: {savings_pct:5.1f}% of MACs can be gated")

    print("\n  These numbers directly justify PE-level zero-operand gating.")
    print("  Paper Section V: PE Gating uses this data as motivation.")
    print()


if __name__ == "__main__":
    main()
