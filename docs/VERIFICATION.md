# Local verification · 18 October 2026

Implemented on `codex/fitness-hardening`. No production deployment or distribution was performed.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --timeout 45s` | 72 tests passed |
| Firestore emulator suite | 121 checks passed, 0 failed |
| Account cleanup unit tests | 3 tests passed |
| `flutter build web --no-pub` | Passed |
| `flutter build apk --debug --no-pub` | Passed |
| `flutter build ios --simulator --no-pub` | Passed |
| Swift widget syntax, Android XML, Xcode project syntax | Passed |
| Browser visual review | Onboarding light/dark; comparison panel and responsive spacing |

New regressions cover corrupt storage recovery, malformed/future backup rejection, import undo, account-safe import, local erasure including pending writes/recovery copies, preference persistence, training history preservation, programme archival, account link release, cloud conflict recovery, concurrent edits during backup, cancellation after account change, guided onboarding, resumable drafts, direct weight validation, 320×640 layout at 200% text, and rendered dark action text.

Colour pair tests cover body/secondary/action/error text on background, container and sheet surfaces; essential outlines; and button labels in both appearances. These token checks do not certify every rendered component or establish medical comfort.

## Remaining external verification

- Deploy the authenticated deletion callable, named database rules and indexes following [functions setup](../functions/README.md). Test with a disposable live account before distributing. The client does not fall back to incomplete deletion.
- Configure App Check web site key and production native attestation/signing. Existing Family builds keep their established signing key.
- Verify Google sign-in, permissions, HealthKit/Health Connect, widgets, reminders, live activities, and cross-device behaviour on physical devices.
- Verify consent-controlled Crashlytics delivery and symbolication in Firebase. Simulator compilation does not prove delivery or a signed App Store archive.
- Complete store policy/support URLs and disclosures before public release.
- English/Bangla switching currently covers navigation and preferences; tracking screens are not fully translated. Family-helper content retains its existing Bangla/English support.

Android compilation emits upstream Kotlin-plugin compatibility and Android SDK metadata warnings. Both are documented build-tooling warnings; they did not fail the current build. The screenshot gallery in README predates the selected ivory/teal theme.
