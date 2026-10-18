# Account deletion service

`deleteAccountData` is an authenticated, App Check protected callable in `us-central1`.
It requires a Google reauthentication within five minutes. The server derives the UID
from authentication; request payloads cannot select another account.

The callable removes cloud data, then deletes Firebase Authentication on the server.
It is idempotent: interrupted deletion must be retried while signed in. Authentication
is deliberately retained on cleanup failure so the user can retry. A retained
Admin-only accountDeletions marker blocks reads and writes from existing tokens
on every device as soon as deletion begins. The callable can still be retried
with a recently authenticated token; other app operations remain blocked.

This handles legacy helper relationships that cannot be discovered from the local
phone, removes notes authored on other people's plans, revokes invitations first,
transfers boards with remaining members, and recursively deletes owned trees.
The legacy helpers collection-group scan is appropriate for this small app; migrate
helper records to an indexed helperUid field before substantial growth.

Release status (18 October 2026): rules and the Enterprise-compatible `notes.fromUid` collection-group index were deployed to `daurfit` / database `daur`. The callable deployment was rejected because the project uses Spark. The owner chose to keep Spark, so account deletion remains unavailable on the server; no live deletion test was attempted.

Future setup:

1. Install dependencies with `npm ci` inside `functions`.
2. Select the intended Firebase project explicitly.
3. Deploy the named `daur` database rules/indexes and account-lifecycle functions.
4. Verify the callable with a disposable account and App Check enabled.

Run pure cleanup regression tests with `npm test` inside `functions`.
The callable must be deployed before the mobile account deletion flow can complete.

Explicit deployment commands, to run only after deployment is authorised:

```sh
npm --prefix functions ci
firebase deploy --project daurfit --only firestore:rules,firestore:indexes,functions:account-lifecycle
```

The `notes.fromUid` collection-group index is declared as an Enterprise `SPARSE_ANY` index in `firestore.indexes.json`; Standard-edition fieldOverrides are not supported by this database.
Wait for that index to become ready before exercising deletion. Node.js 22 and a
Firebase plan supporting Cloud Functions are required for deployment.

For web builds, register the production domain and a reCAPTCHA v3 App Check site key,
then build with `--dart-define=APPCHECK_WEB_SITE_KEY=your-public-site-key`.
Without that key, web deletion explains the missing configuration and directs the user
to the mobile app or support; server App Check enforcement remains enabled.
