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

# Build kallisto from source with HDF5 enabled, so `quant -b` produces bootstraps.
#
# Why not spack: the spack recipe tops out at 0.50.1 and defaults to hdf5=false, and
# `spack load kallisto` resolves against PAWSEY_PROJECT (fl3), not the account the job
# runs under, so it silently picked a build without HDF5 and quant produced no
# bootstraps. Upstream also defaults USE_HDF5 to OFF, so the prebuilt release binaries
# on GitHub cannot bootstrap either. It has to be compiled.
#
# Two things about this source tree need working around:
#
#  1. src/CMakeLists.txt links Bifrost by bare file path with no add_dependencies(), so
#     a parallel make races: the kallisto target reaches the link step before the
#     Bifrost ExternalProject has written libbifrost.a and make stops with "No rule to
#     make target". Build the bifrost target to completion first.
#
#  2. find_package(HDF5) is commented out at src/CMakeLists.txt:45, so HDF5_LIBRARIES
#     and HDF5_INCLUDE_DIRS are empty even with USE_HDF5=ON, and the link fails on
#     undefined H5* symbols. Pass both in explicitly.

VERSION="0.52.0"
SRC="/software/projects/pawsey1168/llenzo/src"
PREFIX="/software/projects/pawsey1168/llenzo/kallisto/$VERSION"
TARBALL="$SRC/kallisto-${VERSION}.tar.gz"
BUILD="$SRC/kallisto-${VERSION}/build"

[[ -s "$TARBALL" ]] || { echo "ERROR: $TARBALL missing" >&2; exit 1; }

module load hdf5/1.14.3-api-v112

: "${PAWSEY_HDF5_HOME:?hdf5 module did not set PAWSEY_HDF5_HOME}"
HDF5_INC="$PAWSEY_HDF5_HOME/include"
HDF5_LIB="$PAWSEY_HDF5_HOME/lib/libhdf5.so"
[[ -s "$HDF5_LIB" ]] || { echo "ERROR: $HDF5_LIB missing" >&2; exit 1; }

# Bake the HDF5 dependency chain into the binary so it runs without the module loaded.
RPATH="$PAWSEY_HDF5_HOME/lib"
for d in $(tr ':' '\n' <<< "${LD_LIBRARY_PATH:-}" | grep -E 'libszip|zlib-ng'); do
    RPATH="$RPATH:$d"
done

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
    -DHDF5_INCLUDE_DIRS="$HDF5_INC" \
    -DHDF5_LIBRARIES="$HDF5_LIB" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_RPATH="$RPATH" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON

JOBS="${SLURM_CPUS_PER_TASK:-8}"
make -j"$JOBS" bifrost          # must complete before anything links against it
[[ -s "$SRC/kallisto-${VERSION}/ext/bifrost/build/src/libbifrost.a" ]] \
    || { echo "ERROR: libbifrost.a was not produced" >&2; exit 1; }
make -j"$JOBS"
make install

echo "=== installed ==="
"$PREFIX/bin/kallisto" version
ls -la "$PREFIX/bin/kallisto"

echo "=== HDF5 linkage (must list libhdf5) ==="
ldd "$PREFIX/bin/kallisto" | grep -i hdf5 || { echo "ERROR: not linked against HDF5" >&2; exit 1; }

echo "=== resolves without the hdf5 module loaded ==="
module unload hdf5/1.14.3-api-v112
ldd "$PREFIX/bin/kallisto" | grep -i "not found" && { echo "ERROR: unresolved libraries" >&2; exit 1; }
echo "all libraries resolve"

echo "=== build complete ==="
