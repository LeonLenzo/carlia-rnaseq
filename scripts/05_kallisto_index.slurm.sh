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

# Pinned to the locally built 0.52.0. Do not go back to `spack load kallisto`: it
# resolves against PAWSEY_PROJECT (fl3), not the job's account, and the fl3 build is
# compiled without HDF5, which silently disables bootstrapping. See
# setup_kallisto_native.slurm.sh.
KALLISTO="/software/projects/pawsey1168/llenzo/kallisto/0.52.0/bin/kallisto"
IDX="$REFS/${ACC}_${ASM}_cds.kallisto-0.52.0.idx"

[[ -s "$CDS" ]] || { echo "ERROR: $CDS missing, run 04_fetch_reference.slurm.sh first" >&2; exit 1; }

[[ -x "$KALLISTO" ]] || { echo "ERROR: $KALLISTO missing, run setup_kallisto_native.slurm.sh" >&2; exit 1; }

"$KALLISTO" version
"$KALLISTO" index -i "$IDX" -t 8 "$CDS"

echo "=== index built ==="
ls -la "$IDX"
