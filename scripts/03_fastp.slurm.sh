#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=carlia_fastp
#SBATCH --array=1-12
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

PROJECT="/scratch/pawsey1168/llenzo/carlia"
RAW="$PROJECT/raw/N2628003_30-1365542355_RNA_2026-09-28/raw_data"
TRIM="$PROJECT/trimmed"
QC="$PROJECT/qc/fastp_reports"
SAMPLES="$PROJECT/metadata/samples.tsv"

THREADS=16
QUALITY=30      # per-base qualified phred, matches the ada1 run
MIN_LEN=50      # 150 bp reads, so anything shorter is not worth aligning

module load fastp/0.23.4-5dugkew

mkdir -p "$TRIM" "$QC" logs

# Row N+1 of the sample sheet, skipping the header
SAMPLE=$(awk -v n="$SLURM_ARRAY_TASK_ID" 'NR==n+1 {print $1}' "$SAMPLES")
R1=$(awk  -v n="$SLURM_ARRAY_TASK_ID" 'NR==n+1 {print $9}' "$SAMPLES")
R2=$(awk  -v n="$SLURM_ARRAY_TASK_ID" 'NR==n+1 {print $10}' "$SAMPLES")

if [[ -z "$SAMPLE" || -z "$R1" || -z "$R2" ]]; then
    echo "ERROR: could not read sample sheet row $SLURM_ARRAY_TASK_ID" >&2
    exit 1
fi
for f in "$RAW/$R1" "$RAW/$R2"; do
    [[ -s "$f" ]] || { echo "ERROR: missing or empty $f" >&2; exit 1; }
done

echo "=== $SAMPLE ==="
echo "R1: $R1"
echo "R2: $R2"

fastp \
    -i "$RAW/$R1" \
    -I "$RAW/$R2" \
    -o "$TRIM/${SAMPLE}_R1.trim.fq.gz" \
    -O "$TRIM/${SAMPLE}_R2.trim.fq.gz" \
    -q "$QUALITY" \
    --length_required "$MIN_LEN" \
    --detect_adapter_for_pe \
    --trim_poly_g \
    --thread "$THREADS" \
    --html "$QC/${SAMPLE}.fastp.html" \
    --json "$QC/${SAMPLE}.fastp.json"

echo "=== done: $SAMPLE ==="
