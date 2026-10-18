#!/usr/bin/env bash
# Refuse an update that would require testers to uninstall and lose local data.
set -euo pipefail
apk="${1:?Pass the APK path}"
channel="${2:-family}"
case "$channel" in
  family)
    expected="278c623f742d89569045a35d5b680d51df034680c9557abd4bf316c6b39ae37f"
    package="com.siraj.daur"
    ;;
  preview)
    expected="9939df1696b3ca76447117e5d2a9608fc8e140deef16ed519884337dbf5a9fd3"
    package="com.siraj.daur.preview"
    ;;
  *) echo 'Unknown release channel' >&2; exit 2 ;;
esac
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
if command -v apksigner >/dev/null 2>&1; then
  signer="$(command -v apksigner)"
else
  signer="$(find "$sdk/build-tools" -name apksigner -type f | sort | tail -n 1)"
fi
if [[ -z "$signer" || ! -x "$signer" ]]; then
  echo 'Android SDK apksigner is required.' >&2
  exit 1
fi
certificate="$("$signer" verify --print-certs "$apk")"
actual="$(printf '%s\n' "$certificate" | sed -n 's/^.*certificate SHA-256 digest: //p' | tr '[:upper:]' '[:lower:]' | tr -d ':' | sort -u)"
if [[ "$actual" != "$expected" ]]; then
  echo "$channel signing mismatch: refusing distribution." >&2
  echo "Expected SHA-256: $expected" >&2
  echo "Actual SHA-256:   $actual" >&2
  echo 'Keep the installed app and its data; use the correct channel signing key.' >&2
  exit 1
fi
aapt="$(find "$sdk/build-tools" -name aapt2 -type f | sort | tail -n 1)"
[[ -n "$aapt" && -x "$aapt" ]] || { echo 'Android SDK aapt2 is required.' >&2; exit 1; }
actual_package="$("$aapt" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
[[ "$actual_package" == "$package" ]] || { echo "Wrong package for $channel: $actual_package" >&2; exit 1; }
echo "$channel APK certificate and package verified."
