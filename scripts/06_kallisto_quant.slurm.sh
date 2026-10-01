#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=carlia_quant
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
REFS="$PROJECT/refs"
TRIM="$PROJECT/trimmed"
QUANT="$PROJECT/quant"
SAMPLES="$PROJECT/metadata/samples.tsv"
IDX="$REFS/GCA_016801405.1_ASM1680140v1_cds.kallisto.idx"

THREADS=16

# Set from 06a_strand_probe.slurm.sh (job 50222835, SN15Gln1, 1M pairs): unstranded
# 86.9% pseudoaligned, --rf-stranded 85.0%, --fr-stranded 1.9%. A dUTP reverse library.
STRAND="--rf-stranded"

# Bootstraps are not used by DESeq2, which takes point estimates through tximport. They
# cost little here (small fungal transcriptome) and keep sleuth and fishpond available.
BOOT=100

[[ -s "$IDX" ]] || { echo "ERROR: $IDX missing, run 05_kallisto_index.slurm.sh first" >&2; exit 1; }

# kallisto is a spack package, not a plain module. Do not pipe `module load` or
# `spack load`: both are shell functions, so a pipe puts them in a subshell and the
# PATH change is lost.
module load spack/0.23.1 >/dev/null 2>&1
spack load kallisto

mkdir -p "$QUANT" logs

# Row N+1 of the sample sheet, skipping the header. The tr strips any stray CR:
# a CRLF sheet silently appends \r to the last field, which makes the path invalid
# while still printing identically in an error message.
row=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$SAMPLES" | tr -d '\r')
SAMPLE=$(echo "$row" | cut -f1)

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: could not read sample sheet row $SLURM_ARRAY_TASK_ID" >&2
    exit 1
fi

R1="$TRIM/${SAMPLE}_R1.trim.fq.gz"
R2="$TRIM/${SAMPLE}_R2.trim.fq.gz"
for f in "$R1" "$R2"; do
    [[ -s "$f" ]] || { echo "ERROR: missing or empty $f" >&2; exit 1; }
done

echo "=== $SAMPLE ==="
kallisto version
echo "index:  $IDX"
echo "strand: ${STRAND:-unstranded}"

kallisto quant \
    -i "$IDX" \
    -o "$QUANT/$SAMPLE" \
    -t "$THREADS" \
    -b "$BOOT" \
    ${STRAND:+$STRAND} \
    "$R1" "$R2"

echo "=== done: $SAMPLE ==="
grep -E 'n_processed|n_pseudoaligned|p_pseudoaligned' "$QUANT/$SAMPLE/run_info.json"
