# Scrob for Android

A native Flutter client for [Scrob](https://github.com/ellite/scrob) — the
self-hosted media tracker (Letterboxd + Trakt for your own library).

The app talks to the Scrob backend through the same `/api/proxy` surface the
PWA uses. It supports JWT username/password sessions, optional API-key sessions,
and the main browsing, tracking, social and settings flows of the web UI.

## Run

```sh
flutter pub get
flutter run
```

The default server is `https://scrob.003274.xyz`; change it from the login
screen or in Settings.

## Build

```sh
flutter build apk --release --dart-define=SCROB_SERVER=https://scrob.003274.xyz
```

Release builds are currently signed with the debug key so they are directly
installable. Add a keystore and signing config before publishing.

## Release workflow

`.github/workflows/release.yml` builds a release APK on:

- `workflow_dispatch` with a version tag input (defaults to the ref name), or
- a pushed tag such as `v1.2.3`.

The tag version is passed to Flutter as `--build-name`; the workflow uploads the
APK as a build artifact and attaches it to a GitHub release for tag pushes.

## API notes

The backend OpenAPI document is admin-only (`GET /openapi.json`). It is kept
locally under `.tmp/` and ignored by git. See `.skills/scrob-api/SKILL.md` for
the API workflow and `.skills/flutter-android/SKILL.md` for the local toolchain.
