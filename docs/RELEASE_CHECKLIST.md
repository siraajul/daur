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

- [ ] Provision a production upload keystore and secure credentials outside source control.
- [ ] Build with `DAUR_PRODUCTION_RELEASE=true` and no App Check debug token.
- [ ] Register signing fingerprints and configure Play Integrity in Firebase/Google Play; verify authentication and AI requests on a distribution build.
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
