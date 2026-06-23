#!/usr/bin/env python3
"""
============================================================
HSA-16 Golden Reference Model — Matrix Multiplication
============================================================

Generates test vectors for RTL verification of the 16×16
weight-stationary systolic array.

Outputs:
    .mem files (hex) for $readmemh in SystemVerilog
    .npy files for Python-side analysis

Datasets:
    identity  — A × I = A
    ones      — all-ones matrix
    dense     — random INT8 (seed=42)
    sparse50  — 50% sparsity
    sparse70  — 70% sparsity
    sparse90  — 90% sparsity
    sparse95  — 95% sparsity

Usage:
    python matmul_reference.py

Reusable for: B16, HSA-PE, HSA-ROW, HSA-TILE, HSA-DFT
"""

import numpy as np
from pathlib import Path
import sys

# ============================================================
# Configuration
# ============================================================

N = 16                                       # Array dimension
VECTOR_DIR = Path(__file__).parent.parent.parent / "vectors"

# ============================================================
# Utility Functions
# ============================================================

def int8_to_twos_complement_hex(value):
    """Convert signed int8 to 2-digit hex (two's complement)."""
    value = int(value)
    if value < 0:
        value = value & 0xFF
    return f"{value & 0xFF:02X}"


def int32_to_twos_complement_hex(value):
    """Convert signed int32 to 8-digit hex (two's complement)."""
    value = int(value)
    if value < 0:
        value = value & 0xFFFFFFFF
    return f"{value & 0xFFFFFFFF:08X}"


def save_int8_mem(matrix, filename):
    """Save INT8 matrix as hex .mem file for $readmemh."""
    with open(filename, "w") as f:
        flat = matrix.flatten()
        for value in flat:
            f.write(int8_to_twos_complement_hex(value) + "\n")
    print(f"  Saved: {filename} ({len(flat)} values)")


def save_int32_mem(matrix, filename):
    """Save INT32 matrix as hex .mem file for $readmemh."""
    with open(filename, "w") as f:
        flat = matrix.flatten()
        for value in flat:
            f.write(int32_to_twos_complement_hex(value) + "\n")
    print(f"  Saved: {filename} ({len(flat)} values)")


def save_readable(matrix, filename, label):
    """Save human-readable matrix for debugging."""
    with open(filename, "w") as f:
        f.write(f"// {label} ({matrix.shape[0]}x{matrix.shape[1]})\n")
        f.write(f"// dtype: {matrix.dtype}\n\n")
        for i in range(matrix.shape[0]):
            row_str = " ".join(f"{int(matrix[i, j]):>6d}" for j in range(matrix.shape[1]))
            f.write(f"// Row {i:2d}: {row_str}\n")


# ============================================================
# Matrix Generation
# ============================================================

def generate_dense(rng):
    """Generate dense random INT8 matrices."""
    A = rng.integers(-128, 128, size=(N, N), dtype=np.int16)
    B = rng.integers(-128, 128, size=(N, N), dtype=np.int16)
    return A.astype(np.int8), B.astype(np.int8)


def generate_sparse(rng, sparsity):
    """Generate sparse random INT8 matrices with given sparsity level."""
    A, B = generate_dense(rng)
    mask_A = rng.random((N, N)) < sparsity
    mask_B = rng.random((N, N)) < sparsity
    A[mask_A] = 0
    B[mask_B] = 0
    return A, B


def generate_identity():
    """Generate identity matrix test: A × I = A."""
    # A = sequential values in INT8 range
    A = np.zeros((N, N), dtype=np.int8)
    for i in range(N):
        for j in range(N):
            A[i, j] = np.int8(((i * N + j) % 256) - 128)

    B = np.eye(N, dtype=np.int8)
    return A, B


def generate_ones():
    """Generate all-ones test: C[i][j] = N."""
    A = np.ones((N, N), dtype=np.int8)
    B = np.ones((N, N), dtype=np.int8)
    return A, B


# ============================================================
# Golden Matrix Multiplication
# ============================================================

def compute_reference(A, B):
    """
    Compute C = A × B using INT32 arithmetic.
    Matches the RTL accumulation behavior exactly.
    """
    C = np.matmul(
        A.astype(np.int32),
        B.astype(np.int32)
    )
    return C.astype(np.int32)


# ============================================================
# Dataset Creation
# ============================================================

def create_dataset(name, A, B):
    """Save a complete test dataset (A, B, C)."""
    print(f"\n{'='*50}")
    print(f"Generating: {name}")
    print(f"{'='*50}")

    C = compute_reference(A, B)

    # Sparsity stats
    a_zeros = np.count_nonzero(A == 0)
    b_zeros = np.count_nonzero(B == 0)
    total = N * N

    print(f"  A sparsity: {a_zeros}/{total} = {100*a_zeros/total:.1f}%")
    print(f"  B sparsity: {b_zeros}/{total} = {100*b_zeros/total:.1f}%")
    print(f"  C range: [{C.min()}, {C.max()}]")

    # Create output directory
    dataset_dir = VECTOR_DIR / name
    dataset_dir.mkdir(parents=True, exist_ok=True)

    # Save hex .mem files for RTL
    save_int8_mem(A, dataset_dir / "A_matrix.mem")
    save_int8_mem(B, dataset_dir / "B_matrix.mem")
    save_int32_mem(C, dataset_dir / "C_expected.mem")

    # Save .npy for Python analysis
    np.save(dataset_dir / "A.npy", A)
    np.save(dataset_dir / "B.npy", B)
    np.save(dataset_dir / "C.npy", C)

    # Save human-readable versions
    save_readable(A, dataset_dir / "A_readable.txt", f"A matrix ({name})")
    save_readable(B, dataset_dir / "B_readable.txt", f"B matrix ({name})")
    save_readable(C, dataset_dir / "C_readable.txt", f"C = A×B ({name})")

    # Verification: double-check with element-wise computation
    C_verify = np.zeros((N, N), dtype=np.int32)
    for i in range(N):
        for j in range(N):
            for k in range(N):
                C_verify[i, j] += np.int32(A[i, k]) * np.int32(B[k, j])

    if np.array_equal(C, C_verify):
        print(f"  [OK] Golden model self-check: PASSED")
    else:
        print(f"  [FAIL] Golden model self-check: FAILED!")
        mismatches = np.sum(C != C_verify)
        print(f"    {mismatches} mismatches found")
        sys.exit(1)

    return C


# ============================================================
# Main
# ============================================================

def main():
    print("=" * 60)
    print(" HSA-16 Golden Reference Model")
    print(f" Array Size: {N}×{N}")
    print(f" Output Dir: {VECTOR_DIR.resolve()}")
    print("=" * 60)

    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    rng = np.random.default_rng(seed=42)

    # ---- Special test patterns ----

    A_id, B_id = generate_identity()
    create_dataset("identity", A_id, B_id)

    A_ones, B_ones = generate_ones()
    create_dataset("ones", A_ones, B_ones)

    # ---- Dense random ----

    A_dense, B_dense = generate_dense(rng)
    create_dataset("dense", A_dense, B_dense)

    # ---- Sparse datasets ----

    for sparsity in [0.50, 0.70, 0.90, 0.95]:
        name = f"sparse{int(sparsity * 100)}"
        A_sp, B_sp = generate_sparse(rng, sparsity)
        create_dataset(name, A_sp, B_sp)

    # ---- Real DNN Workloads ----

    dnn_workloads = {
        "alexnet": 0.4883,
        "vgg16": 0.7070,
        "resnet18": 0.8906,
        "mobilenetv2": 0.9570,
        "efficientnet_b0": 0.9800,
    }
    for name, sparsity in dnn_workloads.items():
        A_dnn, B_dnn = generate_sparse(rng, sparsity)
        create_dataset(name, A_dnn, B_dnn)

    # ---- Summary ----

    print("\n" + "=" * 60)
    print(" All datasets generated successfully.")
    print("=" * 60)
    print(f"\n Output location: {VECTOR_DIR.resolve()}")
    print(f" Datasets: identity, ones, dense, sparse50, sparse70, sparse90, sparse95, alexnet, vgg16, resnet18, mobilenetv2")
    print(f"\n Use in RTL testbench:")
    print(f'   $readmemh("vectors/<dataset>/A_matrix.mem", A_mem);')
    print(f'   $readmemh("vectors/<dataset>/B_matrix.mem", B_mem);')
    print(f'   $readmemh("vectors/<dataset>/C_expected.mem", C_expected);')
    print("")


if __name__ == "__main__":
    main()
