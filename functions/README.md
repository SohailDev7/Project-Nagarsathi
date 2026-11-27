# Citizen profile deletion (US-13)

The citizen avatar menu opens a confirmation screen. Password accounts must
re-enter their password; phone accounts verify an SMS code sent to their
Firebase-verified phone. Google and Facebook accounts reauthenticate with
their linked provider. The app refreshes the Firebase ID token before calling
`deleteCitizenProfile`; passwords and SMS codes never enter the deletion API.

The server accepts only a confirmed request from a citizen with verification
less than five minutes old. It derives the account ID and confirmation address
from Firebase, blocks staff accounts, and ignores caller-supplied identity.

A private `citizenDeletions/{uid}` marker prevents stale ID tokens from reading,
updating, or recreating the profile. The server disables the account and revokes
refresh tokens, anonymizes its reports and comments, recursively removes
`users/{uid}` and private subcollections, removes its Firebase OTP challenge,
and deletes its Firebase Auth account. It sends the confirmation email only
after cleanup finishes. The app clears cached identity and its remembered
session, and prevents navigation back into the signed-in home.

`retryCitizenDeletions` resumes interrupted cleanup and email delivery every
hour. A short transaction lease prevents concurrent requests from processing
the same job twice. Email is removed from the job after successful delivery,
or after 30 days if delivery remains unavailable. The permanent marker retains
only deletion status and timestamps. Phone-only accounts without an email
address are shown an on-screen confirmation without claiming an email was sent.

## Deployment

Firebase Functions and the hourly scheduler require the Blaze plan. Install
the function dependencies from the project root:

```sh
npm ci --prefix functions
```

The confirmation mail uses the same SMTP secrets as the existing email OTP
functions. If they have not already been configured, set them interactively:

```sh
firebase functions:secrets:set GMAIL_USER
firebase functions:secrets:set GMAIL_APP_PASSWORD
```

Deploy the profile protection rules and contribution indexes first, and wait
for the indexes to become ready before deploying the deletion functions:

```sh
firebase deploy --only "firestore:rules,firestore:indexes"
firebase deploy --only "functions:deleteCitizenProfile,functions:retryCitizenDeletions"
```

Deploy the OTP worker as well so its hourly schedule physically removes expired
D1 OTP challenges, including their email addresses:

```sh
npm --prefix otp-worker run deploy
```

The app shows an unavailable message if the callable has not been deployed.
It shows **Deletion requested** if cleanup is queued, and **Profile deleted**
only when the server confirms completion.

## Public contribution data

The current home feed uses static examples; it does not store live reports or
comments yet. Firestore-backed reports and comments must use `authorId` for the
author's Firebase UID and store identifying attribution in the `author` map
(and optional `authorName`, `authorEmail`, `authorPhone`, `authorPhotoUrl`,
or `authorPhotoURL` fields). The cleanup queries the `reports` and `comments`
collection groups, including nested comments, detaches `authorId`, replaces
the attribution with **Deleted citizen**, and removes the identifying fields.
Issue details and comment content are preserved.

New citizen-owned collections or attribution fields must be added to cleanup
when their data model is introduced. Future citizen write rules must also
check the deletion marker so revoked sessions cannot create new contributions.

## Validation

These checks use fake accounts and mail delivery:

```sh
node --test functions/test/citizen_deletion.test.js
flutter test --no-pub test/delete_profile_test.dart test/profile_deletion_service_test.dart test/home_tabs_test.dart
```
