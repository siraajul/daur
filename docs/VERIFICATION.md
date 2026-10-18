# Local verification · 18 October 2026

Implemented on `codex/fitness-hardening`. Firestore rules and the Enterprise-compatible index were deployed to `daurfit` / `daur`; the index is READY. A separate Daur Preview `1.0.0 (121)` was distributed to the three-person Family group; the original app was not replaced.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --timeout 45s` | 84 tests passed |
| Firestore emulator suite | 121 checks passed, 0 failed |
| Account cleanup unit tests | 3 tests passed |
| `flutter build web` | Passed; corrected desktop setup visually verified |
| `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json` | Passed; same-key update restored normal app on Pixel without uninstalling |
| Physical Pixel 7a setup suite | 11 tests passed using memory-only data and mocked authentication |
| Production Android AAB | Built; upload certificate/signature verified; Family debug token absent from native libraries |
| `flutter build ios --simulator` | Passed after final native localization changes |
| Swift widget syntax, Android XML, Xcode project syntax | Passed |
| Browser visual review | Onboarding light/dark; comparison panel and responsive spacing |

New regressions cover corrupt storage recovery, malformed/future backup rejection, import undo, account-safe import, local erasure including pending writes/recovery copies, preference persistence, training history preservation, programme archival, account link release, cloud conflict recovery, concurrent edits during backup, cancellation after account change, guided onboarding, resumable drafts, direct weight validation, 320×640 layout at 200% text, and rendered dark action text.

Colour pair tests cover body/secondary/action/error text on background, container and sheet surfaces; essential outlines; and button labels in both appearances. These token checks do not certify every rendered component or establish medical comfort.

## Remaining external verification

- Account deletion callable deployment is blocked by Spark. The owner chose to keep Spark. Rules/index deployment succeeded, but deletion remains unavailable; the app explains failure and does not use partial client cleanup. A disposable live deletion test remains pending.
- Upload signing key created, SHA-1/SHA-256 registered, signed AAB verified. Existing Play Integrity/App Attest provider configs inspected. Google Play linkage/distribution attestation and web site key are still pending. Family APK signing must match build 112; see [release checklist](RELEASE_CHECKLIST.md).
- Pixel setup/rendering checks passed; real Google sign-in, health consent/import, reminders/widgets/live updates, and cross-device sync remain separate device checks. Physical iPhone testing was blocked by disabled Developer Mode; the owner chose to leave it pending. No iPhone app was installed.
- Verify consent-controlled Crashlytics delivery and symbolication in Firebase. Simulator compilation does not prove delivery or a signed App Store archive.
- Complete store policy/support URLs and disclosures before public release.
- Bangla now covers core screens, tracking, coaching/sharing, spending, generated reminders/live status and native widget captions. Names, codes, user/trainer-authored text, some saved historical descriptions and serving descriptions retain their original language. Native caption compilation was checked; full device visual review of every translated surface remains pending.

Android compilation emits upstream Kotlin-plugin compatibility and Android SDK metadata warnings. Both are documented build-tooling warnings; they did not fail the current build. The screenshot gallery in README predates the selected ivory/teal theme.

## Tester login configuration

Build 112's actual signing certificate was missing from Firebase. Its public SHA-1
and SHA-256 were registered; refreshed Google SDK configuration confirms the matching
Android OAuth client. Google provider is enabled, and published web-client/app IDs
match the server. Tester sign-in must still be retried to establish end-to-end success.
The new signing guard passed against the downloaded build 112 APK and rejected the
local differently-signed APK. No private key or App Check token was printed by those checks.

## Preview distribution · 18 October 2026

- Separate package `com.siraj.daur.preview`, labeled Daur Preview, published as `1.0.0 (121)`.
- 84 normal tests and 13 Preview/setup tests passed; analysis found no issues.
- The APK passed package, signature, launcher and native Firebase identity checks.
- A real App Check token exchange succeeded; its token value was not logged.
- Pixel confirmed original and Preview packages coexist with distinct UIDs.
- Firebase CLI upload/distribution succeeded for Family (3 testers). Backend release metadata and notes were read back.
- Source: `53b8215`; APK SHA-256: `7c8701d2a6b3fd228e0e4325c9873565d8b171d32e003ffd75eb93a0441c5a53`.

[Install Preview](https://appdistribution.firebase.google.com/testerapps/1:179925532044:android:48c933d60808134954aaa9/releases/7ddng4fcqardg). Phone data remains separate; Google sign-in shares the existing Daur cloud account.
