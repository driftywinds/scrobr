<h1>
  <img src="assets/scrobr-app-dark.svg" width="56" alt="Scrobr logo" align="middle">
  Scrobr
</h1>

Scrobr is a native Flutter client for [Scrob](https://github.com/ellite/scrob) — the
self-hosted media tracker (Letterboxd + Trakt for your own library).

The app talks to the Scrob backend through the same `/api/proxy` surface the
PWA uses. It supports JWT username/password sessions, optional API-key sessions,
and the main browsing, tracking, social and settings flows of the web UI.

**Tested against Scrob 2.39.1**, the current upstream release. Scrobr talks only
to the public `/api/proxy` endpoints the PWA uses, so it does not bundle or
require a specific Scrob server version.

[Privacy policy](PRIVACY.md) · [GNU AGPL v3](LICENSE)

[![Downloads](https://img.shields.io/github/downloads/driftywinds/scrobr/total?style=for-the-badge)](https://img.shields.io/github/downloads/driftywinds/scrobr/total?style=for-the-badge) [![Latest Release Downloads](https://img.shields.io/github/downloads/driftywinds/scrobr/latest/total?style=for-the-badge)](https://img.shields.io/github/downloads/driftywinds/scrobr/latest/total?style=for-the-badge) 

[<img src="https://raw.githubusercontent.com/driftywinds/driftywinds/refs/heads/main/Images/custom_badge_obtainium.png"
    alt="Get it on Obtanium"
    height="75">](https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/driftywinds/scrobr) [<img src="assets/google-play-badge.png"
    alt="Get it on Google Play"
    height="75">](https://play.google.com/store/apps/details?id=com.dw.scrobr)

## Screenshots

| Home | Calendar |
| --- | --- |
| <img src="play-store/01-home.jpg" width="300" alt="Scrobr home screen"> | <img src="play-store/02-calendar.jpg" width="300" alt="Scrobr release calendar"> |
| **Progress** | **Discover movies** |
| <img src="play-store/03-progress.jpg" width="300" alt="Scrobr show progress"> | <img src="play-store/04-discover-movies.jpg" width="300" alt="Scrobr discover movies"> |
| **Discover shows** | **History** |
| <img src="play-store/05-discover-shows.jpg" width="300" alt="Scrobr discover shows"> | <img src="play-store/06-history.jpg" width="300" alt="Scrobr watch history"> |
| **Profile** | **Settings** |
| <img src="play-store/07-profile.jpg" width="300" alt="Scrobr profile and stats"> | <img src="play-store/08-settings.jpg" width="300" alt="Scrobr settings and appearance"> |

## Features

- First launch asks for your own Scrob server URL and verifies it before saving.
  Password login with TOTP/backup-code challenge, "stay logged in", registration
  and API-key sign-in.
- Home: swipeable Shows | Movies tabs, per-tab sorting (last watched, recently
  added, title, TMDB rating, my rating, year and random), and a customisable
  quick-shortcut row.
- Optimistic watch actions from Home: mark several episodes without waiting for
  each server sync; the row advances to the next real episode and the queued
  marks flush after 5 seconds of inactivity. A sync icon shows pending, sending
  and last-batch state.
- Discover: trending, now playing / on air, upcoming / new episodes, top rated,
  for you, hidden gems and streaming rows for movies and shows.
- Follow movies and shows into a private "Following · Calendar" list.
  Followed shows/movies are merged into the Calendar without being collected,
  and the calendar window can be set from 7 to 90 days.
- Explore screen for movies/shows: popular, top rated and trending categories
  with genre, year, rating, watch-state and list filters.
- Optional Library tab (off by default; enable in Settings) for movies and shows
  with sort, watched/rating/list/year/genre filters, saved presets and infinite
  scrolling.
- Search across TMDB movies, shows and people, plus Scrob user search.
- Movie, show, season, episode, person, collection and studio/company pages
  with cast, crew, recommendations, release dates and where-to-watch.
- Trending trailer row on Discover.
- Actions: mark watched/unwatched (item, season or show), 1–10 ratings,
  comments with spoilers, Trakt community comments (when enabled), add to list,
  collect/request, drop/undrop, rewatch, trailer launch and timed manual
  watching sessions.
- Watch history with date grouping, filters, per-entry delete and unwatch.
- Lists (watchlist, private/friends/public), create/edit/delete, per-list
  sorting and add/remove toggles with membership checks.
- Profiles with follow/unfollow, top rated and recently watched rows with
  paginated “see all” pages, stats charts (watch time, activity, ratings,
  weekdays, genres) and public profiles.
- Calendar, progress, dropped, existing connection management (toggles,
  schedules, push/sync controls) and About.
- Settings: preferences, API-key regeneration, password/email/2FA, connected
  apps, native ZIP data export/import, manage-on-web links for
  providers/integrations and an admin panel for settings, users, requests,
  maintenance and database backup/restore.
- Appearance: system or Allo font, gradient/solid accent colours, and a time
  zone override with the full IANA list. The default follows the phone zone.
- Release APK workflows: `v*` tags publish pre-release split + universal APKs
  through the all-ABI workflow; the universal-only workflow is manual.

## Run

```sh
flutter pub get
flutter run
```

On first launch the app asks for your own Scrob server URL, verifies it, and
then saves it. No server is bundled or assumed.

## Build

```sh
flutter build apk --release
```

Release builds are currently signed with the debug key so they are directly
installable. Add a keystore and signing config before publishing.

See [PARITY.md](PARITY.md) for the web-to-native feature map and deliberate
exclusions.

## Engineering

- Artwork is disk-cached through `cached_network_image` with the session
  headers; public TMDB/TVDB URLs are the fallback.
- Bottom tabs are built lazily on first visit.
- API calls time out after 20 seconds; binary and multipart calls share the
  same 401 handling as normal requests.
- Home watch actions are optimistic and queued locally; the queue flushes after
  5 seconds of inactivity and is not persisted across a force-close.
- Timestamps are rendered in the phone time zone by default, or an optional
  IANA override, using the bundled `timezone` database.
- CI runs `flutter analyze --no-fatal-infos` and `flutter test` on pull requests
  and pushes to `main` (`.github/workflows/ci.yml`).

## Release workflow

Pushing a `v*` tag runs `.github/workflows/release-all-abis.yml`. It builds four
APKs and publishes them as a **pre-release**:

- `scrobr-<version>-universal.apk`
- `scrobr-<version>-arm64-v8a.apk`
- `scrobr-<version>-armeabi-v7a.apk`
- `scrobr-<version>-x86_64.apk`

The all-ABI workflow can also be run manually. Its `version` input is optional
(falling back to the selected tag), and `prerelease` defaults to on.

`.github/workflows/release.yml` is now **manual-dispatch only**. It builds the
universal APK and is useful for a one-off test build; it no longer runs on tag
pushes.

`.github/workflows/release-bundle.yml` is manual-dispatch only and requires a
version tag. It builds a signed `scrobr-<version>.aab` for Google Play, uploads
it as a workflow artifact, and attaches it to the GitHub release as a
pre-release.

### Signing

The workflow signs with a keystore supplied as repository secrets; without
them it falls back to the debug key so the build still succeeds.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of the `.jks`/`.keystore` file |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

On Windows, produce the base64 value with:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))
```

The workflow decodes it to `android/app/release.keystore`, writes the ignored
`android/key.properties`, builds, and signs the release APK with it.

## API notes

The backend OpenAPI document is admin-only (`GET /openapi.json`). A local
snapshot can be regenerated under the ignored `.tmp/` directory when needed.
See `.skills/scrob-api/SKILL.md` for the API workflow and
`.skills/flutter-android/SKILL.md` for the local toolchain. The app is
developed against **Scrob 2.39.1**; the server and its API remain fixed. Build outputs,
Flutter/Gradle caches and `.tmp/` are disposable and are not committed.

API keys can read/write data endpoints, but account, comments, connections and
`/admin/*` need a real JWT session. The app shows an API-key session as such and
opens the password-only screens when you sign in normally.

Deliberately out of scope: OIDC/SSO login and in-app video playback. Provider
linking (Jellyfin/Plex/Emby/Nuvio/Stremio/ARVIO and the cloud trackers) is done
in the Scrob web UI; the app opens that page and manages existing connections.


## Fonts

The optional **Allo 1.1.0** typeface is by Josh Puckett and is bundled under the
SIL Open Font License 1.1. See [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt).
