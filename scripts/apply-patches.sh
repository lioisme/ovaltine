#!/usr/bin/env bash
#
# Apply the project patch series to a LineageOS source tree.
# Source-only: this script never invokes fastboot/adb and never writes a device.
#
set -euo pipefail

AOSP_ROOT="${AOSP_ROOT:?set AOSP_ROOT to the LineageOS source tree (e.g. /path/to/aosp)}"
PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apply_one() {
  local tree="$1"
  local patch="$2"

  if [[ ! -d "$tree/.git" ]]; then
    echo "[fail] not a git tree: $tree" >&2
    exit 1
  fi

  if git -C "$tree" apply --check "$patch" >/dev/null 2>&1; then
    git -C "$tree" apply "$patch"
    echo "[apply] ${tree#"$AOSP_ROOT"/} <- $(basename "$patch")"
  elif git -C "$tree" apply --check --reverse "$patch" >/dev/null 2>&1; then
    echo "[skip]  already applied: $(basename "$patch")"
  else
    echo "[fail]  cannot apply: $patch" >&2
    git -C "$tree" apply --check "$patch" || true
    exit 1
  fi
}

echo "== EX01 base adaptation =="
for p in "$PATCH_ROOT"/patches/ex01-adaptation/0001-ovaltine-*.patch; do
  [[ -e "$p" ]] && apply_one "$AOSP_ROOT/device/oneplus/ovaltine" "$p"
done
for p in "$PATCH_ROOT"/patches/ex01-adaptation/0001-sm8450-common-*.patch; do
  [[ -e "$p" ]] && apply_one "$AOSP_ROOT/device/oneplus/sm8450-common" "$p"
done

echo "== 2026-10-31 adaptation =="
for p in "$PATCH_ROOT"/patches/adaptation/0001-device-*.patch; do
  [[ -e "$p" ]] && apply_one "$AOSP_ROOT/device/oneplus/ovaltine" "$p"
done
for p in "$PATCH_ROOT"/patches/adaptation/0002-common-*.patch \
         "$PATCH_ROOT"/patches/adaptation/0003-common-*.patch; do
  [[ -e "$p" ]] && apply_one "$AOSP_ROOT/device/oneplus/sm8450-common" "$p"
done

# macOS-only build-system workarounds are experimental and opt-in.
if [[ "${APPLY_MAC_PATCHES:-0}" == "1" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[skip]  APPLY_MAC_PATCHES=1 but host is not Darwin"
  else
    echo "== macOS experimental patches =="
    apply_one "$AOSP_ROOT/build/soong" "$PATCH_ROOT/patches/macos-build/0001-soong-cc-config-allow-macos-sdk-26.patch"
    apply_one "$AOSP_ROOT/build/soong" "$PATCH_ROOT/patches/macos-build/0003-soong-ui-darwin-trace-top.patch"
    apply_one "$AOSP_ROOT/build/blueprint" "$PATCH_ROOT/patches/macos-build/0002-blueprint-bootstrap-skip-go-tests-on-darwin.patch"
  fi
fi

echo "== historical patches (not applied) =="
echo "patches/0001-*.patch are lineage-ovaltine-dev artifacts; they are not portable to the selected pjgowtham tree (see AUDIT_REPORT DRV-003)."

"$PATCH_ROOT/scripts/verify-tree.sh"
