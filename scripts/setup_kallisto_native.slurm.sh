#!/bin/bash --login
#SBATCH --account=pawsey1168
#SBATCH --partition=work
#SBATCH --job-name=kallisto_build
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

# Build kallisto from source with HDF5 enabled.
#
# Why not spack: the spack recipe tops out at 0.50.1 and defaults to hdf5=false, and
# `spack load kallisto` resolves against PAWSEY_PROJECT (fl3), not the account the job
# runs under, so it silently picked a build without HDF5 and quant produced no
# bootstraps. Upstream also defaults USE_HDF5 to OFF, so the prebuilt release binaries
# on GitHub cannot bootstrap either. It has to be compiled.

VERSION="0.52.0"
SRC="/software/projects/pawsey1168/llenzo/src"
PREFIX="/software/projects/pawsey1168/llenzo/kallisto/$VERSION"
TARBALL="$SRC/kallisto-${VERSION}.tar.gz"
BUILD="$SRC/kallisto-${VERSION}/build"

[[ -s "$TARBALL" ]] || { echo "ERROR: $TARBALL missing" >&2; exit 1; }

module load hdf5/1.14.3-api-v112

mkdir -p logs "$SRC"
cd "$SRC"
rm -rf "kallisto-${VERSION}"
tar xzf "$TARBALL"
mkdir -p "$BUILD"
cd "$BUILD"

# /usr/bin/cmake is 3.28; the cmake/3.30.5 module refuses this project, which still
# declares cmake_minimum_required(VERSION 3.0.0).
/usr/bin/cmake .. \
    -DUSE_HDF5=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"

make -j"${SLURM_CPUS_PER_TASK:-8}"
make install

echo "=== installed ==="
"$PREFIX/bin/kallisto" version
ls -la "$PREFIX/bin/kallisto"

echo "=== HDF5 linkage (must list libhdf5) ==="
ldd "$PREFIX/bin/kallisto" | grep -i hdf5 || { echo "ERROR: not linked against HDF5" >&2; exit 1; }

echo "=== build complete ==="
