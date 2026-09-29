#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=copy
#SBATCH --job-name=spack_kallisto
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=06:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

# Installs kallisto into the pawsey1168 software allocation.
#
# Two things drive the choices here:
#
# 1. The copy partition, not work. Spack's only configured mirror is the public
#    https://mirror.spack.io, so fetching sources needs external network access, and
#    copy is the only partition that has it. This keeps the build off the login node.
#
# 2. PAWSEY_PROJECT defaults to fl3 on this account, which is why the existing kallisto
#    sits under /software/projects/fl3/. Spack's install tree root is literally
#    $PAWSEY_PROJECT/$USER/..., expanded at runtime, so overriding the variable before
#    loading the module redirects the install. Both must be set before `module load`.

export PAWSEY_PROJECT=pawsey1168
export MYSOFTWARE="/software/projects/pawsey1168/llenzo"

mkdir -p "$MYSOFTWARE/setonix/2025.08" logs

# +hdf5 is deliberate. The variant defaults to false, which is why the fl3 build cannot
# write abundance.h5 and so cannot produce bootstraps. Bootstraps are what give
# technical variance for sleuth and for bootstrapped DE, and they cannot be recovered
# later without requantifying everything.
SPEC="kallisto@0.50.1 +hdf5"

module load spack/0.23.1 >/dev/null 2>&1

echo "=== resolved spec ==="
spack spec -I $SPEC

echo "=== installing ==="
spack install -j "${SLURM_CPUS_PER_TASK:-8}" $SPEC

echo "=== where it landed ==="
spack location -i $SPEC

echo "=== verifying ==="
spack load $SPEC
kallisto version
command -v kallisto
