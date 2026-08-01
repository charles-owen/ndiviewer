#!/bin/bash
set -euo pipefail

if [ -z "${NDI_DYLIB_PATH:-}" ] || [ ! -f "$NDI_DYLIB_PATH" ]; then
  echo "error: NDI_DYLIB_PATH is not configured. Run Scripts/configure-ndi.sh."
  exit 1
fi

DEST="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
mkdir -p "$DEST"
cp -f "$NDI_DYLIB_PATH" "$DEST/"
chmod 755 "$DEST/$(basename "$NDI_DYLIB_PATH")"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$DEST/$(basename "$NDI_DYLIB_PATH")"
fi
