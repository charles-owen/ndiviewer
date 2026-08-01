#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/Config/NDIConfig.xcconfig"

CANDIDATES=(
  "/Library/NDI SDK for Apple"
  "$HOME/Library/NDI SDK for Apple"
  "/Library/NDI SDK for macOS"
  "$HOME/Library/NDI SDK for macOS"
)

SDK=""
for candidate in "${CANDIDATES[@]}"; do
  if [ -f "$candidate/include/Processing.NDI.Lib.h" ]; then
    SDK="$candidate"
    break
  fi
done

if [ -z "$SDK" ]; then
  echo "NDI SDK not found. Install it, then edit Config/NDIConfig.xcconfig manually."
  exit 1
fi

LIB=""
for candidate in \
  "$SDK/lib/macOS/libndi.dylib" \
  "$SDK/lib/macOS/libndi_advanced.dylib" \
  "$SDK/lib/libndi.dylib"; do
  if [ -f "$candidate" ]; then
    LIB="$candidate"
    break
  fi
done

if [ -z "$LIB" ]; then
  echo "NDI header found at $SDK, but no macOS NDI dylib was found."
  exit 1
fi

LIBDIR="$(dirname "$LIB")"
LIBNAME="$(basename "$LIB")"
LINKNAME="${LIBNAME#lib}"
LINKNAME="${LINKNAME%.dylib}"

cat > "$CONFIG" <<CFG
NDI_SDK_DIR = $SDK
HEADER_SEARCH_PATHS = \$(inherited) "\$(NDI_SDK_DIR)/include"
LIBRARY_SEARCH_PATHS = \$(inherited) "$LIBDIR"
OTHER_LDFLAGS = \$(inherited) -l$LINKNAME
LD_RUNPATH_SEARCH_PATHS = \$(inherited) @executable_path/../Frameworks
NDI_DYLIB_PATH = $LIB
CFG

echo "Configured NDI SDK: $SDK"
echo "Configured runtime: $LIB"
