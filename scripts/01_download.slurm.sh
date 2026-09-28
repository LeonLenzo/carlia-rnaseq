#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=copy
#SBATCH --job-name=carlia_dl
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

SRC="genewiz:gwasia/2026.9/30-1365542355/"
DEST="/scratch/pawsey1168/llenzo/carlia/raw"

module load rclone/1.68.1
export RCLONE_CONFIG="$HOME/.config/rclone/genewiz.conf"

mkdir -p "$DEST" logs

rclone copy "$SRC" "$DEST" \
    --transfers 8 \
    --checkers 16 \
    --multi-thread-streams 4 \
    --retries 5 \
    --low-level-retries 20 \
    --stats 5m \
    --stats-one-line \
    --log-level INFO \
    --log-file "logs/rclone_${SLURM_JOB_ID}.log"

echo "=== transfer finished, checking counts ==="
rclone check "$SRC" "$DEST" --size-only --log-level NOTICE
