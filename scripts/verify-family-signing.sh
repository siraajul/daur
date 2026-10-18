#!/usr/bin/env bash
# Refuse an update that would require testers to uninstall and lose local data.
set -euo pipefail
apk="${1:?Pass the Family APK path}"
expected="278c623f742d89569045a35d5b680d51df034680c9557abd4bf316c6b39ae37f"
if command -v apksigner >/dev/null 2>&1; then
  signer="$(command -v apksigner)"
else
  sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
  signer="$(find "$sdk/build-tools" -name apksigner -type f | sort | tail -n 1)"
fi
if [[ -z "$signer" || ! -x "$signer" ]]; then
  echo 'Android SDK apksigner is required.' >&2
  exit 1
fi
certificate="$("$signer" verify --print-certs "$apk")"
actual="$(printf '%s\n' "$certificate" | sed -n 's/^.*certificate SHA-256 digest: //p' | tr '[:upper:]' '[:lower:]' | tr -d ':' | sort -u)"
if [[ "$actual" != "$expected" ]]; then
  echo 'Family signing mismatch: this APK cannot update the current tester build safely.' >&2
  echo "Expected SHA-256: $expected" >&2
  echo "Actual SHA-256:   $actual" >&2
  echo 'Use the same private key as tester build 112. Do not uninstall testers apps.' >&2
  exit 1
fi
echo 'Family APK certificate matches tester build 112.'
