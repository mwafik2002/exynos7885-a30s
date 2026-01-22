#!/usr/bin/env bash
set -euo pipefail

# ===== User config =====
DEFCONFIG="exynos7885-a30s_defconfig"
ARCH=arm64
OUT=out
JOBS="${JOBS:-$(nproc)}"

# Toolchain
# We will use proton-clang by default (set TOOLCHAIN_DIR env if you want another)
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$PWD/toolchain}"

export ARCH="$ARCH"
export SUBARCH="$ARCH"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-ci}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github}"

export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# Basic sanity
command -v clang >/dev/null 2>&1 || { echo "clang not found in PATH"; exit 1; }

mkdir -p "$OUT"

# Config + build
make O="$OUT" "$DEFCONFIG"

# If the kernel tree needs LLVM=1 style, keep both; harmless if unused
make -j"$JOBS" O="$OUT" \
  CC=clang \
  LD=ld.lld \
  AR=llvm-ar \
  NM=llvm-nm \
  OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump \
  STRIP=llvm-strip \
  LLVM=1 LLVM_IAS=1

echo "Build done."

# Collect outputs
mkdir -p dist
cp -f "$OUT/arch/arm64/boot/Image" dist/ || true
cp -f "$OUT/arch/arm64/boot/zImage" dist/ 2>/dev/null || true

# dtb/dtbo (if produced)
if [ -f "$OUT/arch/arm64/boot/dtbo.img" ]; then
  cp -f "$OUT/arch/arm64/boot/dtbo.img" dist/
fi

# Copy DTBs if exist
if compgen -G "$OUT/arch/arm64/boot/dts/**/*.dtb" > /dev/null; then
  mkdir -p dist/dtb
  rsync -a --prune-empty-dirs --include '*/' --include '*.dtb' --exclude '*' \
    "$OUT/arch/arm64/boot/dts/" dist/dtb/
fi

ls -lah dist || true
