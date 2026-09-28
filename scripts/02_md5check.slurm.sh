#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=copy
#SBATCH --job-name=carlia_md5
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=06:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

RAW="/scratch/pawsey1168/llenzo/carlia/raw/N2628003_30-1365542355_RNA_2026-09-28/raw_data"
cd "$RAW"

# md5.md5 ships from GENEWIZ; verify every fastq against it
md5sum -c md5.md5 2>&1 | tee "$SLURM_SUBMIT_DIR/logs/md5_${SLURM_JOB_ID}.txt"

echo "=== summary ==="
grep -c ': OK$'     "$SLURM_SUBMIT_DIR/logs/md5_${SLURM_JOB_ID}.txt" || true
grep    ': FAILED'  "$SLURM_SUBMIT_DIR/logs/md5_${SLURM_JOB_ID}.txt" || echo "no failures"
