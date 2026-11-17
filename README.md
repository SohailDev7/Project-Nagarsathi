# NagarSathi

A Flutter application with an iOS-inspired authentication flow and in-app
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

- Sign in with an email address or phone number (segmented toggle) and password
- Forgot-password flow with email/phone recovery
- Sign-up wizard in four steps: name → email → optional phone → password and terms
- Minimal green theme: flat surfaces, hairline borders, one accent colour, no gradients or shadows
- Sign-up form with name, email, optional phone, password confirmation and terms
- Staff sign-in link below citizen sign-up, opening a separate work-email/password
  portal and staff workspace; staff sign-out returns to the staff login screen
- Green, iOS-inspired theme with reusable inputs, buttons and segmented control

Both citizen and staff flows are UI-only: they validate form input and simulate
sign-in. Citizen sign-in/sign-up opens the citizen home, while staff sign-in opens
the staff workspace. No credentials or staff roles are verified by a server yet.
Wire the submit handlers in `lib/screens/` to your authentication service and
verify staff roles on the server before granting staff access.

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
