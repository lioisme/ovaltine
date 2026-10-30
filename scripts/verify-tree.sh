#!/usr/bin/env bash
#
# Static verification of the selected baseline after patches.
# Read-only: no build, no device, no partition writes.
#
set -euo pipefail

AOSP_ROOT="${AOSP_ROOT:?set AOSP_ROOT to the LineageOS source tree (e.g. /path/to/aosp)}"
DEVICE="$AOSP_ROOT/device/oneplus/ovaltine"
COMMON="$AOSP_ROOT/device/oneplus/sm8450-common"
FAIL=0

check_file() {
  if [[ -f "$1" ]]; then
    echo "[ok]   file: ${1#"$AOSP_ROOT"/}"
  else
    echo "[fail] missing: $1" >&2
    FAIL=1
  fi
}

check_grep() {
  local pattern="$1" file="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "[ok]   $label"
  else
    echo "[fail] $label (missing '$pattern' in ${file#"$AOSP_ROOT"/})" >&2
    FAIL=1
  fi
}

check_not_grep() {
  local pattern="$1" file="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "[fail] $label (found '$pattern' in ${file#"$AOSP_ROOT"/})" >&2
    FAIL=1
  else
    echo "[ok]   $label"
  fi
}

check_file "$DEVICE/lineage_ovaltine.mk"
check_file "$DEVICE/BoardConfig.mk"
check_file "$DEVICE/proprietary-files.txt"
check_file "$COMMON/init/init.oplus.rc"
check_file "$COMMON/extract-files.py"
check_file "$COMMON/overlay/OPlusFrameworksResCommon/res/values/config.xml"

check_grep "PRODUCT_MODEL := CPH2415" "$DEVICE/lineage_ovaltine.mk" "device model is CPH2415"
check_grep "BuildFingerprint=OnePlus/CPH2415/OP5552L1:15/" "$DEVICE/lineage_ovaltine.mk" "device fingerprint is CPH2415/Android 15"
check_not_grep "CPH2417" "$DEVICE/lineage_ovaltine.mk" "no stale CPH2417 identity"
check_not_grep "BOARD_ONEPLUS_DYNAMIC_PARTITIONS_SIZE" "$DEVICE/BoardConfig.mk" "no dead dynamic-partition variable"

check_grep "chmod 0000 /sys/kernel/oplus_display/hbm" "$COMMON/init/init.oplus.rc" "HBM node denied to vendor HAL"
check_not_grep "chown system system /sys/kernel/oplus_display/hbm" "$COMMON/init/init.oplus.rc" "HBM node is not chowned to system"

check_grep "android.sensor.light" "$COMMON/extract-files.py" "wise-light name replacement present"
check_grep "config_displayLightSensorType" "$COMMON/overlay/OPlusFrameworksResCommon/res/values/config.xml" "rear-ALS config present"
check_grep "qti.sensor.light_rear" "$COMMON/overlay/OPlusFrameworksResCommon/res/values/config.xml" "rear-ALS sensor type set"

# EX01 adaptation must be applied before this script.
check_grep "manifest_oplus_fingerprint_aidl.xml" "$DEVICE/proprietary-files.txt" "EX01 fingerprint AIDL manifest"
check_not_grep "manifest_oplus_fingerprint.xml|" "$DEVICE/proprietary-files.txt" "old fingerprint manifest unpinned"
check_grep "^# odm/bin/hw/vendor.pixelworks.hardware.display.iris-service" "$COMMON/proprietary-files.txt" "EX01 Pixelworks service removal"

if [[ "$FAIL" -ne 0 ]]; then
  echo "VERIFY FAILED" >&2
  exit 1
fi

echo "VERIFY OK"
