# Release APK workflow

`.github/workflows/release.yml` supports both release triggers:

- **workflow_dispatch**: `version` input (e.g. `v1.2.3`); falls back to the
  selected ref's tag/name, then `0.0.0`.
- **push tag** `v*`: the tag name is the version.

It runs on Ubuntu, sets up Flutter stable, runs `flutter pub get` and
`flutter test`, then builds:

```sh
flutter build apk --release --build-name "${VERSION#v}" --build-number "$GITHUB_RUN_NUMBER"
```

and uploads `build/app/outputs/flutter-apk/app-release.apk` as an artifact. On
tag pushes it also creates/updates a GitHub Release with that APK.

## Signing with a base64 keystore

Set these repository secrets:

- `ANDROID_KEYSTORE_BASE64` — base64 of the `.jks`/`.keystore` (no data URI
  prefix). PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow writes `android/app/release.keystore` and an ignored
`android/key.properties`; `android/app/build.gradle.kts` loads that file and
uses the release signing config. If no keystore secret is set, the build falls
back to the debug key so local/manual builds still work.

Local equivalent:

```powershell
flutter build apk --release --build-name 1.2.3 --build-number 1
```
