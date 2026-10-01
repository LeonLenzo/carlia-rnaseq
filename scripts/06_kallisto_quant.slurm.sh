#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=carlia_quant
#SBATCH --array=1-12
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

PROJECT="/scratch/pawsey1168/llenzo/carlia"
REFS="$PROJECT/refs"
TRIM="$PROJECT/trimmed"
QUANT="$PROJECT/quant"
SAMPLES="$PROJECT/metadata/samples.tsv"
IDX="$REFS/GCA_016801405.1_ASM1680140v1_cds.kallisto-0.52.0.idx"

# Pinned to the locally built 0.52.0, which is compiled with HDF5. The first run used
# `spack load kallisto`, which resolves against PAWSEY_PROJECT (fl3) rather than the
# job's account and gave a ~hdf5 build: -b was accepted and silently ignored, and every
# run_info.json reported n_bootstraps 0. See setup_kallisto_native.slurm.sh.
KALLISTO="/software/projects/pawsey1168/llenzo/kallisto/0.52.0/bin/kallisto"

THREADS=16

# Set from 06a_strand_probe.slurm.sh (job 50222835, SN15Gln1, 1M pairs): unstranded
# 86.9% pseudoaligned, --rf-stranded 85.0%, --fr-stranded 1.9%. A dUTP reverse library.
STRAND="--rf-stranded"

# Bootstraps are not used by DESeq2, which takes point estimates through tximport, but
# they keep sleuth and fishpond available. They only materialise if kallisto was built
# with HDF5; the check below refuses to run otherwise rather than repeat the silent
# no-op of the first attempt.
BOOT=100

[[ -s "$IDX" ]] || { echo "ERROR: $IDX missing, run 05_kallisto_index.slurm.sh first" >&2; exit 1; }
[[ -x "$KALLISTO" ]] || { echo "ERROR: $KALLISTO missing, run setup_kallisto_native.slurm.sh" >&2; exit 1; }

if (( BOOT > 0 )) && ! ldd "$KALLISTO" | grep -qi hdf5; then
    echo "ERROR: $KALLISTO is not linked against HDF5, so -b $BOOT would be ignored" >&2
    exit 1
fi

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
"$KALLISTO" version
echo "index:  $IDX"
echo "strand: ${STRAND:-unstranded}"

"$KALLISTO" quant \
    -i "$IDX" \
    -o "$QUANT/$SAMPLE" \
    -t "$THREADS" \
    -b "$BOOT" \
    ${STRAND:+$STRAND} \
    "$R1" "$R2"

echo "=== done: $SAMPLE ==="
grep -E 'n_processed|n_pseudoaligned|p_pseudoaligned|n_bootstraps' "$QUANT/$SAMPLE/run_info.json"

# The first run requested bootstraps and silently produced none. Fail loudly instead.
if (( BOOT > 0 )); then
    [[ -s "$QUANT/$SAMPLE/abundance.h5" ]] \
        || { echo "ERROR: no abundance.h5 written, bootstraps did not run" >&2; exit 1; }
fi
