#!/bin/bash
# Ship a new Daur build to the "Family" testers through Firebase App Distribution.
#
#   ./release.sh "What changed, in a line or two"
#
# CI does this on every merge to main (.github/workflows/release.yml); this is the same thing
# by hand. Builds a release APK (with the App Check token from dart_defines.json), uploads it,
# and emails the Family group. Testers install it with the
# Firebase App Tester app; each new release shows up there as an update.
# Add a tester: npx -y firebase-tools@latest appdistribution:testers:add someone@gmail.com --group-alias family
set -euo pipefail
cd "$(dirname "$0")"

notes="${1:?Release notes, please: ./release.sh \"What changed\"}"
app_id="1:179925532044:android:6756796d5a2804a454aaa9"

# 100 + commits on main: the same build number rule as CI (.github/workflows/release.yml),
# so a local release and a CI release never clash and Android always sees a higher number
build=$((100 + $(git rev-list --count HEAD)))
echo "Daur build ${build}"

flutter test
flutter build apk --release --build-number="$build" --dart-define-from-file=dart_defines.json

npx -y firebase-tools@latest appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$app_id" \
  --groups family \
  --release-notes "$notes" \
  --project daurfit
