#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=carlia_strand
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

# Which strandedness to use in 06_kallisto_quant.slurm.sh. The delivery paperwork does
# not state the library protocol, so determine it from the data rather than assume it.
#
# One sample, 1M read pairs, quantified three ways. For an unstranded library all three
# pseudoalign a similar fraction. For a dUTP (reverse) library --rf-stranded matches the
# unstranded rate and --fr-stranded collapses; a forward library is the mirror image.

PROJECT="/scratch/pawsey1168/llenzo/carlia"
REFS="$PROJECT/refs"
TRIM="$PROJECT/trimmed"
IDX="$REFS/GCA_016801405.1_ASM1680140v1_cds.kallisto.idx"
OUT="$PROJECT/qc/strand_probe"
SAMPLE="SN15Gln1-LJJ17311"
READS=1000000

[[ -s "$IDX" ]] || { echo "ERROR: $IDX missing, run 05_kallisto_index.slurm.sh first" >&2; exit 1; }

# kallisto is a spack package, not a plain module. Do not pipe `module load` or
# `spack load`: both are shell functions, so a pipe puts them in a subshell and the
# PATH change is lost.
module load spack/0.23.1 >/dev/null 2>&1
spack load kallisto

mkdir -p "$OUT" logs
cd "$OUT"

# head closes the pipe early, which makes zcat exit non-zero under pipefail.
set +o pipefail
zcat "$TRIM/${SAMPLE}_R1.trim.fq.gz" | head -n $((READS * 4)) | gzip > sub_R1.fq.gz
zcat "$TRIM/${SAMPLE}_R2.trim.fq.gz" | head -n $((READS * 4)) | gzip > sub_R2.fq.gz
set -o pipefail

for mode in unstranded fr-stranded rf-stranded; do
    case "$mode" in
        unstranded)  flag="" ;;
        fr-stranded) flag="--fr-stranded" ;;
        rf-stranded) flag="--rf-stranded" ;;
    esac
    echo "=== $mode ==="
    kallisto quant -i "$IDX" -o "$mode" -t 8 $flag sub_R1.fq.gz sub_R2.fq.gz
done

echo
echo "=== summary: $SAMPLE, $READS pairs ==="
printf '%-14s %14s %14s\n' mode n_pseudoaligned p_pseudoaligned
for mode in unstranded fr-stranded rf-stranded; do
    n=$(grep -o '"n_pseudoaligned": *[0-9]*' "$mode/run_info.json" | grep -o '[0-9]*$')
    p=$(grep -o '"p_pseudoaligned": *[0-9.]*' "$mode/run_info.json" | grep -o '[0-9.]*$')
    printf '%-14s %14s %14s\n' "$mode" "$n" "$p"
done

rm -f sub_R1.fq.gz sub_R2.fq.gz
