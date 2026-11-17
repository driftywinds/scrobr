# Flutter Android toolchain in .tmp

The SDK is local to this workspace and gitignored. Machine-specific paths
(including the JDK) are in `.skills/local/flutter-android.md`; if it is missing,
locate a JDK 17 install and set `JAVA_HOME` before continuing.

- Flutter 3.50.0 / Dart 3.14.0: `.tmp/flutter`
- Android SDK 36 + build-tools 36 + platform-tools: `.tmp/android-sdk`
- Pub cache: `.tmp/pub-cache`

## Environment for every Flutter command

The sandbox blocks writes to `%APPDATA%`, `%LOCALAPPDATA%` and `%TEMP%`; redirect
them into the workspace. Run from the repo root:

```powershell
$repo = (Get-Location).Path
if (-not $env:JAVA_HOME) { throw 'Set JAVA_HOME to a JDK 17 installation first' }
$env:APPDATA="$repo\.tmp\appdata"
$env:LOCALAPPDATA="$repo\.tmp\localappdata"
$env:PUB_CACHE="$repo\.tmp\pub-cache"
$env:HOME="$repo\.tmp\home"
$env:TEMP="$repo\.tmp\temp"; $env:TMP=$env:TEMP
$env:ANDROID_HOME="$repo\.tmp\android-sdk"
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:GRADLE_USER_HOME="$repo\.tmp\gradle"
$env:ANDROID_USER_HOME="$repo\.tmp\android-user"
$env:JAVA_TOOL_OPTIONS="-Duser.home=$repo\.tmp\home"
.tmp\flutter\bin\flutter.bat <command>
```

`GRADLE_USER_HOME` is required: otherwise Gradle writes to
`C:\Users\<user>\.gradle`, which this sandbox cannot create.
`ANDROID_USER_HOME` + `user.home` keep the debug keystore out of
`C:\Users\<user>\.android`. Do not also set `ANDROID_PREFS_ROOT` — AGP rejects
the duplicate preference path.

Flutter 3.50 moved Material out of the framework: import
`package:material_ui/material_ui.dart`, not `package:flutter/material.dart`.
The `material_ui` dependency is already in `pubspec.yaml`.

## Rebuild the toolchain

```powershell
# Flutter stable zip (check releases_windows.json for the current stable)
# https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_<ver>-stable.zip
# Android commandline tools
# https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip
# then:
sdkmanager --sdk_root=$env:ANDROID_HOME --licenses
sdkmanager --sdk_root=$env:ANDROID_HOME platform-tools "platforms;android-36" "build-tools;36.0.0"
```

## Build/analyze

```powershell
flutter analyze
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The first release build auto-installs the Flutter NDK (`28.2.13676358`) and
platform 35 through Gradle; this is a multi-GB one-time download. Release lint
is disabled in `android/app/build.gradle.kts` because AGP's lint crashes on this
toolchain; app code still passes `flutter analyze` (only style infos remain).

If any command fails opening `%TEMP%` or `%APPDATA%`, the env block above was
not applied. Git clones need `git -c http.sslBackend=openssl`.
