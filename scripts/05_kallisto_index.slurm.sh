#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=carlia_kidx
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

PROJECT="/scratch/pawsey1168/llenzo/carlia"
REFS="$PROJECT/refs"
ACC="GCA_016801405.1"
ASM="ASM1680140v1"
CDS="$REFS/${ACC}_${ASM}_cds_from_genomic.fna.gz"
IDX="$REFS/${ACC}_${ASM}_cds.kallisto.idx"

[[ -s "$CDS" ]] || { echo "ERROR: $CDS missing, run 04_fetch_reference.slurm.sh first" >&2; exit 1; }

# kallisto is a spack package, not a plain module. Do not pipe `module load`:
# it is a shell function, so a pipe puts it in a subshell and the PATH change is lost.
module load spack/0.23.1 >/dev/null 2>&1
spack load kallisto

kallisto version
kallisto index -i "$IDX" -t 8 "$CDS"

echo "=== index built ==="
ls -la "$IDX"
