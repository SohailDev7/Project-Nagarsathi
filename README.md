# NagarSathi

A Flutter application with a playful green civic authentication flow and in-app
updates (GitHub releases for APKs, Shorebird for Dart-only patches).

## Requirements

- Flutter 3.47.0 or newer (stable channel)
- Dart SDK `^3.13.4`
- Android device/emulator (in-app APK installs are Android-only)
- JDK 17 or newer for Android builds (Android Studio's bundled JDK 25 is supported)

Android builds are verified with Flutter 3.50.0 using Gradle 9.3.1, Android Gradle
Plugin 9.1.1 and Kotlin 2.4.10. These versions meet Flutter 3.50's minimum Android
build requirements.

## Getting started

```sh
flutter pub get
flutter run
```

### Building an APK

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. For
smaller per-architecture APKs use `--split-per-abi`.

The Android SDK 34 install on this machine is incomplete and `open_filex`
declares `compileSdk 34`, so `android/build.gradle.kts` bumps plugin modules to
the installed SDK 36 instead of triggering a download. Once SDK 34 is installed
properly (Android Studio SDK Manager), that block can be removed.

## Authentication UI

- Sign in with a single email-or-phone field (the field detects `@` for email and
  digits for phone, showing an inline EMAIL/PHONE badge) plus a password
- **Continue with Google** opens the native Android account picker (Credential
  Manager) and signs in through Firebase Auth. There is no web/browser fallback.
- Compact single-viewport layout: brand and the always-visible **Staff portal**
  entry sit in a pinned top bar, so no auth action needs scrolling on a small phone
- Forgot-password flow that sends a reset link to an email or phone number
- Four-step sign-up: name → email → optional phone → password, confirm password
  and terms (phone can be skipped without skipping the password step)
- Separate staff sign-in with a work-email/password portal, staff badge and staff
  workspace; staff sign-out returns to the staff login screen
- Shared green theme: vivid lime actions, forest ink and cream paper, bundled
  Nunito in 400–900 weights, chunky depth buttons and inputs, springy entrance
  animations, haptics and one-shot confetti (all motion honours reduced-motion)

### Firebase accounts

Citizen sign-up, sign-in and password resets are wired to Firebase:

- `lib/services/firebase_bootstrap.dart` initializes Firebase once and never
  blocks start-up. If the project is not configured, the app stays in **offline
  demo mode** and the UI behaves exactly as before.
- `lib/services/auth_service.dart` creates accounts with Firebase Authentication
  and writes a `users/{uid}` profile (`name`, `email`, `phone`, `role: citizen`,
  timestamps) to Cloud Firestore.
- Sign-in refreshes that profile document; password resets use
  `sendPasswordResetEmail`.
- Citizen passwordless sign-in ("Try another way" → **Sign in with an email
  link**) uses Firebase Authentication email links. The app stores the requested
  email locally and completes the link when it opens on Android.
- Sign-up email verification still uses the Cloudflare Worker in `otp-worker/`.
  See [`otp-worker/README.md`](otp-worker/README.md) for deployment details.

Configure a project once:

```bash
dart pub global activate flutterfire_cli
flutterfire configure            # writes lib/firebase_options.dart
```

`lib/firebase_options.dart` and `android/app/google-services.json` are
**git-ignored** because they contain the Firebase client API key. Create them
locally with `flutterfire configure`; a fresh clone still builds and runs in
offline demo mode without them. In CI or on another machine, either recreate
both files from secure storage or skip them entirely and pass dart-defines:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

> **API key note:** the key committed earlier is still present in git history.
> Firebase client keys are not secrets by themselves, but restrict yours in
> Google Cloud Console (APIs & Services → Credentials): limit the Android key to
> package `com.softwarica.nagarsathi.projectnagarsathi` plus your signing
> SHA-1/SHA-256, and limit the allowed APIs. Purge the old commits separately if
> you want the string gone from history.
In the Firebase console, enable **Email/Password**, **Email link (passwordless
sign-in)**, and **Phone** under Authentication. Add the Android app's SHA-1 and
SHA-256 fingerprints, and create a Cloud Firestore database. The email-link
flow uses the project's default Firebase Hosting domain
(`nagar-sathi-23080.firebaseapp.com`) and an Android App Link for
`/__/auth/links`; configure the fingerprints for every signing certificate
(debug and release) so Android can verify the link and open the installed app.
Deploy the included rules with
`firebase deploy --only firestore:rules`.

Provision each staff member in the `staff` collection:

```text
staff/{firebaseAuthUid}
  role: "staff"
  active: true
  email: "ward.staff@example.gov.np"
  phone: "+9779841234567"
```

The document ID must be the Firebase Auth UID for email/password staff. Phone
OTP lookup uses the normalized `phone` field, which must include Nepal's `+977`
country code. Staff documents are read-only from the app; create and update
them only from a trusted admin environment.

The verified Firebase accounts `admin@nagarsathi.app` and
`freefuzxcoj2@gmail.com` and `sohail@nagarsathi.app` are granted super-admin
access to ward-officer management by both the staff sign-in flow and Firestore
rules. Their Firebase Auth emails must be verified; the rules do not trust a
client-side email check alone.
### Google sign-in

Across Authentication → Sign-in method, enable **Google**. It opens the built-in
Android account picker; the app never redirects to a browser.

Register the Android signing certificate so Google can verify the app. For this
machine's debug build, add both values under Project settings → Your apps
(Android, package `com.softwarica.nagarsathi.projectnagarsathi`):

- SHA-1: `62:57:33:C5:36:43:6D:DF:12:A1:74:43:A6:23:36:8A:F6:5E:AE:09`
- SHA-256: `D8:08:F2:F2:8D:B7:CB:40:76:4C:65:9B:F4:90:9A:15:DD:90:54:4D:62:CC:D5:C7:F1:0C:64:F1:32:AC:78:B2`

Add your release keystore's fingerprints too before shipping. After enabling
Google, re-run `flutterfire configure` (or re-download `google-services.json`
into `android/app/`, where it stays git-ignored) so the file contains a web
OAuth client (`client_type: 3`) next to the Android client. If you keep the JSON
outside the app, pass the Web client ID with
`--dart-define=GOOGLE_SERVER_CLIENT_ID=...` instead.

### Location & ward

The citizen home asks for location permission once, reverse geocodes the fix
with the device geocoder (`geolocator` + `geocoding`) and asks the citizen to
confirm the result:

> Are you from **KMC WARD -16?**

Tapping **Yes, that's me** saves the confirmed ward on their profile:

```text
users/{uid}
  location: { latitude, longitude, municipality, ward }
```

The label uses the municipality initials (`Kathmandu Metropolitan City` →
`KMC`), and the saved value is reused on every later launch. If the geocoder
cannot read a ward, the app keeps the pill on "Set your location", explains why
and retries when the citizen taps it. Android needs the
`ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` permissions declared in
`android/app/src/main/AndroidManifest.xml`; the system prompt is shown at
runtime.


## Updates

The app has two independent update channels.

### 1. GitHub release updates (full APK)

`lib/services/update_service.dart` reads the public releases of
`SohailDev7/Project-Nagarsathi` and compares the newest release tag with
`version` + `build number` from `pubspec.yaml`.

Behaviour:

| Situation | Result |
| --- | --- |
| Normal release | Dialog with **Later** (snoozes 24h) and **Update** (download + install) |
| Tag ends in `-priority` or `+priority` | Blocking dialog with only **Update now**; back button and outside taps do nothing |
| Tapping outside / pressing back on a normal update | Dialog closes, no snooze is stored |

- Checks run on startup and when the app returns to the foreground.
- Automatic checks are throttled to once every 30 minutes (`UpdateConfig.checkInterval`).
- Only non-draft, non-prerelease releases that contain a `.apk` asset are considered.
- The APK is downloaded to the temp directory and handed to the Android package
  installer via `open_filex`; the first install requires the user to allow
  **Install unknown apps** for NagarSathi.

#### Tag format

```
v1.2.3            major.minor.patch
1.2.3+4           optional build number
v1.2.3-priority   optional priority/forced-update marker
v1.2.3+4+priority
```

Anything else (e.g. `v1.2`, `v1.2.3-beta`) is ignored so a stray tag cannot
trigger a bogus update prompt.

#### Publishing a release

1. Bump `version` in `pubspec.yaml` (for example `1.1.0+2`). Keep the version
   part identical to the release tag — the app compares its own `versionName`
   against the tag, so an APK built as `1.0.0` will keep offering `v1.0.1`
   forever, even after it is installed.
2. Build the APK:

   ```sh
   flutter build apk --release
   ```

3. Create a GitHub release using a tag that follows the format above and attach
   `build/app/outputs/flutter-apk/app-release.apk` (rename it with `.apk`).
4. For a forced update, suffix the tag with `-priority`.

The release body is shown in the dialog under "What's new". To change it, edit
the release description on GitHub — no new build is needed, the app reads it
from the API. Keep it short; the dialog shows the first few lines.

The app validates a downloaded file (size and ZIP/APK signature) before opening
the installer. A corrupted or partial download is rejected with a retry prompt
instead of Android's "There was a problem parsing the package" error.

#### Signing

Android only installs an APK signed with the same key as the installed build. The
default template uses debug signing, which is fine for local testing but will
block updates for users who installed a release-signed build (and vice versa).
Configure a stable release keystore in `android/app/build.gradle.kts` before
shipping.

#### Optional overrides

```sh
flutter build apk --release \
  --dart-define=GITHUB_REPO_OWNER=your-user \
  --dart-define=GITHUB_REPO_NAME=your-repo \
  --dart-define=GITHUB_TOKEN=ghp_xxx
```

`GITHUB_TOKEN` is only needed for private repositories or to avoid API rate
limits. Never commit a token; pass it at build time.

### 2. Shorebird over-the-air patches

`lib/services/shorebird_service.dart` wraps `shorebird_code_push` and runs on
startup. When a patch is downloaded the app shows a snackbar asking the user to
restart; the patch then applies on the next launch.

Patches only work in builds produced by the Shorebird CLI. In debug builds or
normal `flutter build apk` output the updater reports `unavailable` and the check
is skipped silently.

One-time setup (requires a Shorebird account):

```sh
shorebird login
shorebird init
```

`shorebird init` writes `shorebird.yaml` with the app id used to fetch patches.
Commit that file.

Shipping a release and its patches:

```sh
shorebird release android
shorebird patch android
```

Patches only carry Dart/asset changes. Anything touching native code, plugins or
the app version needs a new `shorebird release android` plus a GitHub release.

## Checks

```sh
flutter analyze
flutter test
```

## Project structure

```
lib/main.dart                 App entry point and root widget
lib/config/update_config.dart GitHub repo, intervals and build-time overrides
lib/models/app_update.dart    Release tag parsing, priority detection
lib/services/                 GitHub release + Shorebird patch handling
lib/screens/                  Login, sign up, forgot password and home screens
lib/theme/                    Green palette and app theme
lib/utils/                    Form validators
lib/widgets/                  Shared inputs, buttons, update dialog and gate
test/smoke_test.dart          Auth flow smoke test
test/staff_auth_test.dart     Staff navigation, validation and sign-out tests
test/update_version_test.dart Release tag parsing tests
```
