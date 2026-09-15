#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/output"
SOC_VERSION="${SOC_VERSION:-ascend910b}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)}"
TARGET="install"
CLEAN=0
BUILD_PTA=0
BUILD_OP_HOST=1

usage() {
    cat <<'EOF'
Usage: ./build.sh [options]

Options:
  -s, --soc SOC          Target SoC (default: ascend910b)
  -j, --jobs N           Parallel build jobs
  -t, --target TARGET    CMake target (default: install)
      --build-type TYPE  CMake build type (default: Release)
      --clean            Remove build and output directories first
      --pta              Also build the PyTorch/torch_npu extension
      --kernel-only      Skip GE host and device-tiling libraries
  -h, --help             Show this help

Environment:
  ASCEND_HOME_PATH or ASCEND_TOOLKIT_HOME must point to the CANN toolkit.
  ASCENDC_CMAKE_DIR may override the directory containing ascendc.cmake.
EOF
}

while (($#)); do
    case "$1" in
        -s|--soc)
            SOC_VERSION="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        --build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --pta)
            BUILD_PTA=1
            shift
            ;;
        --kernel-only)
            BUILD_OP_HOST=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ((CLEAN)); then
    rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
fi

cmake_args=(
    -S "${ROOT_DIR}"
    -B "${BUILD_DIR}"
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
    -DCMAKE_INSTALL_PREFIX="${OUTPUT_DIR}"
    -DSOC_VERSION="${SOC_VERSION}"
    -DSOULBOY_BUILD_PTA="${BUILD_PTA}"
    -DSOULBOY_BUILD_OP_HOST="${BUILD_OP_HOST}"
)

if [[ -n "${ASCENDC_CMAKE_DIR:-}" ]]; then
    cmake_args+=(-DASCENDC_CMAKE_DIR="${ASCENDC_CMAKE_DIR}")
fi

cmake "${cmake_args[@]}"
cmake --build "${BUILD_DIR}" --target "${TARGET}" --parallel "${JOBS}"
