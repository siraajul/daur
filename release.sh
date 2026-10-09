#!/bin/bash
# Ship a new Daur build to the "Family" testers through Firebase App Distribution.
#
#   ./release.sh "What changed, in a line or two"
#
# Bumps the build number in pubspec.yaml, builds a release APK (with the App Check token from
# dart_defines.json), uploads it, and emails the Family group. Testers install it with the
# Firebase App Tester app; each new release shows up there as an update.
# Add a tester: npx -y firebase-tools@latest appdistribution:testers:add someone@gmail.com --group-alias family
set -euo pipefail
cd "$(dirname "$0")"

notes="${1:?Release notes, please: ./release.sh \"What changed\"}"
app_id="1:179925532044:android:6756796d5a2804a454aaa9"

# 1.0.0+7 → 1.0.0+8: Android installs an update only when this number goes up
version=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *//')
name=${version%+*}
build=$(( ${version#*+} + 1 ))
sed -i '' -E "s/^version: .*/version: ${name}+${build}/" pubspec.yaml
echo "Daur ${name} (${build})"

flutter test
flutter build apk --release --dart-define-from-file=dart_defines.json

npx -y firebase-tools@latest appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$app_id" \
  --groups family \
  --release-notes "$notes" \
  --project daurfit
