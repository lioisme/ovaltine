#!/usr/bin/env bash
#
# Verify an extracted vendor tree against the committed SHA-256 manifest.
# Read-only: no build, no device, no partition writes.
#
set -euo pipefail

VENDOR_ROOT="${VENDOR_ROOT:?set VENDOR_ROOT to the extracted vendor root (e.g. scratch/vendor)}"
MANIFEST="${MANIFEST:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/artifacts/blob-manifest.sha256}"

if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest not found: $MANIFEST" >&2
  exit 1
fi
if [[ ! -d "$VENDOR_ROOT" ]]; then
  echo "vendor root not found: $VENDOR_ROOT" >&2
  exit 1
fi

cd "$VENDOR_ROOT"
echo "Verifying $VENDOR_ROOT against $MANIFEST"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$MANIFEST"
else
  shasum -a 256 -c "$MANIFEST"
fi
