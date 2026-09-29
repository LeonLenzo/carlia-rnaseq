#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=copy
#SBATCH --job-name=carlia_ref
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

# The copy partition is used because it is the only one with external network access.

PROJECT="/scratch/pawsey1168/llenzo/carlia"
REFS="$PROJECT/refs"
ACC="GCA_016801405.1"
ASM="ASM1680140v1"
BASE="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/016/801/405/${ACC}_${ASM}"
CDS="${ACC}_${ASM}_cds_from_genomic.fna.gz"

mkdir -p "$REFS" logs
cd "$REFS"

# Accession stays in the filename; local aliases caused duplication in the past.
curl -sSL --retry 5 --retry-delay 5 -o "$CDS" "$BASE/$CDS"
curl -sSL --retry 5 --retry-delay 5 -o md5checksums.txt "$BASE/md5checksums.txt"

echo "=== verifying against NCBI md5checksums.txt ==="
grep "$CDS" md5checksums.txt | sed 's#\./##' | md5sum -c -

echo "=== transcript count ==="
zcat "$CDS" | grep -c '^>'

ls -la "$CDS"
