# NagarSathi email OTP worker

Cloudflare Worker that emails a 6-digit code and, once it is verified, mints a
Firebase custom token so the app can call `signInWithCustomToken`.

## Endpoints

| Endpoint | Body | Response |
| --- | --- | --- |
| `POST /request-email-otp` | `{ "email": "..." }` | `{ expiresInSeconds, remainingResends }` |
| `POST /verify-email-otp` | `{ "email": "...", "otp": "123456" }` | `{ verified: true, token, verificationToken }` |
| `POST /admin/delete-staff-account` | `{ "uid"?, "email"? }` | `{ deleted, uid }` |
| `POST /admin/send-staff-invite` | `{ "email", "name", "ward", "tempPassword" }` | `{ sent: true }` |
| `POST /delete-citizen-profile` | `{ "confirm": true, "immediate"?: true }` | `{ status: "deactivated" \| "deleted", deleteAt, emailStatus }` |
| `POST /cancel-citizen-deletion` | `{ "confirm": true }` | `{ status: "active" }` |
| `POST /request-data-export` | `Authorization: Bearer <firebaseIdToken>`, `{ "locale": "en\|ne", "demo"?: true }` | `{ exportId, status, email, formats, reportCount, commentCount, requestedAt, expiresAt }` |
| `GET /data-export/download?token=...` | Encrypted AES-256-GCM token (`&format=zip\|json\|pdf`) | Encrypted-at-rest ZIP (JSON + PDF), JSON, or PDF download; expires in 48 hours |

The two `/admin/*` endpoints require an `Authorization: Bearer <Firebase ID token>`
header from a verified super-admin (or an active staff manager) and are used by
the Ward Officer Management screen.

`/delete-citizen-profile` performs the US-13 profile deletion. It needs the
service account secret (`FIREBASE_SERVICE_ACCOUNT`) and the citizen's freshly
verified ID token: the app reauthenticates first, then sends the token. The
worker derives the account from that token and refuses staff/administrator
accounts.

Confirming now **deactivates** the account instead of removing it:

- `users/{uid}` gets `deletionStatus: "deactivated"`,
  `deletionRequestedAt` and `deletionScheduledFor` (epoch milliseconds). The app
  reads those fields on sign-in and shows the deletion notice, so the citizen is
  told about the deletion and can keep the account.
- A `citizen_deletions` row holds the 30-day deadline and the confirmation
  address. The worker emails the date once and drops the address from D1.
- The account keeps working and can sign in during the window.
  `POST /cancel-citizen-deletion` sets the row to `cancelled` and the profile
  back to `active`, which the dialog's "Keep my account" option calls.
- When the deadline passes, the hourly cron (or `immediate: true` in the
  request) runs the final purge: disable and revoke, anonymize reports and
  comments, delete the `users/{uid}` document tree, remove the Firebase OTP
  challenge and the Auth account. A failed purge stays queued and is retried
  every hour.

The worker creates `citizen_deletions` and its index on first use
(`CREATE TABLE IF NOT EXISTS`), so a database whose schema predates this
endpoint cannot fail the request with a missing table. Cloud Functions were not used because
the Firebase project is on the Spark plan, which cannot deploy them. `delete-staff-account` removes the Firebase
Auth account so an email can be reused after an officer is deleted;
`send-staff-invite` emails the officer their temporary password through the
Gmail Apps Script endpoint.

`token` is the Firebase custom token. It is `null` when the worker has no
service account configured — the code is still verified, but the app cannot
open a session from it and falls back to the password/reset message.

## First-time setup

1. **Create the D1 database** (already configured in `wrangler.toml`):

   ```bash
   npx wrangler d1 create nagarsathi-otp
   npx wrangler d1 execute nagarsathi-otp --remote --file=schema.sql
   ```

2. **Apply the schema** (creates `citizen_deletions` as well):

   ```bash
   npm run d1:init
   ```

3. **Set the existing secrets**: `OTP_PEPPER`, `GMAIL_MAIL_ENDPOINT`,
   `GMAIL_MAIL_SECRET`.

   ```bash
   npx wrangler secret put OTP_PEPPER
   npx wrangler secret put GMAIL_MAIL_ENDPOINT
   npx wrangler secret put GMAIL_MAIL_SECRET
   ```

4. **Create a Firebase service account key**

   Firebase console → Project settings → **Service accounts** → *Generate new
   private key*. Download the JSON file.

   Store the whole JSON (it includes `project_id`, `client_email` and
   `private_key`) as a single secret:

   ```bash
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT
   # paste the JSON file contents when prompted
   ```

   Alternatively set the three parts separately:

   ```bash
   npx wrangler secret put FIREBASE_PROJECT_ID
   npx wrangler secret put FIREBASE_CLIENT_EMAIL
   npx wrangler secret put FIREBASE_PRIVATE_KEY   # paste with \n escapes intact
   ```

5. **Deploy**

   ```bash
   npx wrangler deploy
   ```

   Point the app at the deployed URL (defaults to
   `https://nagarsathi-otp.sohailk2064.workers.dev`):

   ```bash
   flutter run --dart-define=OTP_WORKER_URL=https://your-worker.workers.dev
   ```

## How sign-in works

1. The app asks the worker to email a code.
2. The worker stores only `sha256(pepper:email:code)` in D1, with a 5-minute TTL
   and attempt/resend limits.
3. On verify, the worker:
   - looks up the Firebase Auth user for the email (Admin REST),
   - signs a Firebase custom token for that uid (RS256, 1 hour TTL).
4. The app exchanges the token with `signInWithCustomToken`, so the citizen lands
   in a normal Firebase session with the same uid as password sign-in.

The worker never creates accounts: sign-up verifies the code through the same
endpoint and then creates the account with a password, so creating a passwordless
user during verification would make sign-up fail. If no account owns the email,
`token` is `null` and `tokenReason` is `"user-not-found"`.

Because the uid is shared, the `users/{uid}` Firestore profile, ward location
and remember-me state all continue to work for code sign-in.
