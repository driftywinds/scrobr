# Release APK workflow

`.github/workflows/release.yml` supports both release triggers:

- **workflow_dispatch**: `version` input (e.g. `v1.2.3`); falls back to the
  selected ref's tag/name, then `0.0.0`.
- **push tag** `v*`: the tag name is the version.

It runs on Ubuntu, sets up Flutter stable, runs `flutter pub get`, builds:

```sh
flutter build apk --release --build-name "${VERSION#v}" --build-number "$GITHUB_RUN_NUMBER"
```

and uploads `build/app/outputs/flutter-apk/app-release.apk` as an artifact. On
tag pushes it also creates/updates a GitHub Release with that APK.

Release builds use the debug signing config from the Flutter template, so they
install directly but are not Play Store-ready. To sign properly, add a keystore
and signing config, then pass the secrets in the workflow.

Local equivalent:

```powershell
flutter build apk --release --build-name 1.2.3 --build-number 1
```
