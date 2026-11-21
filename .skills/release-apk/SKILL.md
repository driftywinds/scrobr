# Release APK workflow

Tag pushes (`v*`) run `.github/workflows/release-all-abis.yml`, not the plain
`.github/workflows/release.yml` (which is now manual-only).

- **push tag** `v*`: the tag name is the version; the release is a pre-release
  by default and publishes split + universal APKs.
- **workflow_dispatch**: `version` is optional and falls back to the selected
  tag; the `prerelease` checkbox defaults to on.

Both workflows run on Ubuntu, set up Flutter stable, run `flutter pub get` and
`flutter test`. The all-ABI workflow builds:

```sh
flutter build apk --release --split-per-abi ...
flutter build apk --release ...
```

and publishes `armeabi-v7a`, `arm64-v8a`, `x86_64` and universal APKs to the
GitHub Release tagged `v${VERSION}`.

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
