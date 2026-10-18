# Release checklist

This checklist records required evidence; unchecked items are not verified by source review.

## Automated checks

- [ ] `flutter pub get`, `flutter analyze`, and `flutter test` pass; record the actual output and test count for this commit.
- [ ] Firestore emulator tests pass using the versions pinned in `.github/workflows/release.yml`.
- [ ] Android release APK/AAB builds with the intended signing identity; inspect its certificate.
- [ ] `flutter build web` succeeds and the primary browser journey is verified.
- [ ] iOS builds/archive successfully with the intended capabilities and signing profile.

PR CI runs analysis, Flutter tests, account-cleanup function tests, and Firestore rules tests. Family distribution runs only from main after those checks pass. Platform builds, native permission checks, and live backend operations require their own evidence.

Account deletion deployment: [service setup and commands](../functions/README.md). Web deletion also requires the public App Check site key described there.

## Account and data journeys

- [ ] Sign in, cancel sign-in, and retry a failed sign-in on actual supported devices.
- [ ] Join as trainer, family helper, and partner; confirm permitted reads and denied private reads.
- [ ] Revoke sharing and verify from the former helper's device that access stops.
- [ ] Delete a disposable account and verify owned documents and shared access are removed.
- [ ] Test offline changes, concurrent changes from two devices, and conflict recovery without silent overwrite.
- [ ] Export/import a backup; reject malformed data and restore a previous good copy.
- [ ] Finish, pause, and restart a programme while retaining previous history.

## Public Android distribution

- [x] Provision a production upload keystore and secure credentials outside source control. Local ignored `android/upload-keystore.jks` and `android/key.properties` are mode 600. Keep an encrypted offline backup before relying on this key for publication.
- [ ] Build with `DAUR_PRODUCTION_RELEASE=true` and no App Check debug token.
- [ ] Production upload SHA-1/SHA-256 registered in Firebase; existing Android Play Integrity and iOS App Attest configs inspected. Google Play linkage, eventual Play App Signing certificate registration, and real distribution attestation/authentication/AI remain unverified.
- [ ] Preserve the existing Family key for Family updates; changing it can force uninstall and loss of local data.
- [ ] Complete store privacy/data-safety disclosures, policy/support URLs, and health-permission declarations.

## Crash reporting

- [ ] Enable Crashlytics for the intended Firebase apps and confirm the native build configuration resolves.
- [ ] iOS: resolve Firebase Swift packages and archive successfully. The final Runner phase uploads dSYMs using the Firebase SPM script (with a CocoaPods fallback). Release/Profile builds fail if the script is missing; Debug builds explicitly skip upload. Verify symbolicated reports in Firebase before declaring iOS ready.
- [ ] Verify reporting is disabled before consent and after opting out, including across app restarts.
- [ ] On a disposable test installation, opt in, trigger a controlled test error/crash, restart, and verify symbolicated delivery in the Firebase console. Remove any temporary crash trigger before distribution.
- [ ] Do not attach health records, meal data, names, emails, or raw backup content to custom logs/keys/errors.

## Device and interface checks

- [ ] Onboarding: complete, go back, cancel optional connections, close/resume, and review targets for every supported role.
- [ ] Verify Today, meal correction, workout completion, and progress at small screen sizes and large text settings.
- [ ] Verify supported light/dark themes and localisation; document any untranslated surfaces.
- [ ] Exercise Health Connect/HealthKit permission refusal, partial permission, later revocation, and successful import.
- [ ] Verify reminders, widgets, and live activities while the app is backgrounded and after restart.

Setup references: [Firebase Flutter Crashlytics](https://firebase.google.com/docs/crashlytics/flutter/get-started), [opt-in collection](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports), [Android plugin setup](https://firebase.google.com/docs/crashlytics/android/get-started).

## Physical setup smoke suite

`flutter test integration_test/onboarding_device_test.dart -d <device-id> --no-pub`
runs setup regressions with in-memory preferences and mocked authentication. It does not
attach cloud sync, schedule reminders, modify widgets, or write the installed user’s records.
Verify the installed signing certificate first. Restore the normal app entry point with a
same-key, data-preserving update after testing; never uninstall the user's app.

Build platform targets sequentially. After device tests, use `flutter build appbundle --release`
(without `--no-pub`) so Flutter regenerates release-mode plugin registration and excludes
test-only native dependencies. `--no-pub` skips this regeneration in the installed SDK
and can retain the debug/test registration in a release build. Physical setup tests do not verify real Google sign-in, cloud
conflicts, health permission consent, widget updates, or Crashlytics delivery.

## Upload certificate (public metadata)

Registered in Firebase Android app `1:179925532044:android:6756796d5a2804a454aaa9` on 18 October 2026:

- SHA-1: `3787FD2A7D58235DD37D6E5DE1F80CD144E90692`
- SHA-256: `3C0D61A1FA449584F4E53596D05F82610E50A73AFB21C231E567B734487B9243`

This is the upload identity. If Google Play App Signing supplies a different distribution
certificate, register that certificate too. Existing Family debug-key fingerprints were preserved.

The owner chose to keep Firebase Spark and leave physical iPhone testing pending. Do not
mark account cleanup or iPhone device checks complete until those constraints change.

## Internal tester login correction

The actual latest Firebase App Distribution APK (build 112, uploaded 10 October 2026)
was downloaded read-only and inspected. Its SHA-1 `bcb6bc320c1ff258eee76d49933557fcbb097942`
and SHA-256 `278c623f742d89569045a35d5b680d51df034680c9557abd4bf316c6b39ae37f`
were absent from Firebase. Both were registered on 18 October. Refreshed SDK metadata
now includes an Android OAuth client for this certificate; the distributed APK's web
client ID and Firebase app ID match the enabled Google provider. The existing Family
App Check token is present in the published code (token value was not logged).

Tester confirmation is still required: close/reopen the installed app and retry sign-in.
No reinstall or new distribution is required for this server configuration correction.

The local Mac debug key is DIFFERENT from build 112's key. Family uploads now run
`scripts/verify-family-signing.sh` and refuse a mismatched key. The GitHub
`ANDROID_SIGNING_KEYSTORE` secret must contain build 112's matching private key;
its availability has not been verified. If that key cannot be recovered, plan an
explicit backup/migration with testers before changing their install identity.
No tester release was uploaded or sent during this work.
