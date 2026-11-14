# Scrob Android parity

Target instance: `https://scrob.003274.xyz` (Scrob 2.38.0). The app is a native
Flutter client over `/api/proxy`; it does not embed the web UI.

## Native screens

| Web area | Android |
| --- | --- |
| `/login`, `/register`, `/forgot-password` | Password login, TOTP/backup-code challenge, registration, reset email; `AutofillGroup` hints |
| `/` dashboard | Continue watching, Next Up, Airing Today, Now Playing, Recently Added, Trending |
| `/discover`, `/movies`, `/shows` | Discover rows and native Explore with Popular/Top Rated/Trending plus genre, year, rating, watch, list and my-rating filters |
| `/search` | Movies, shows, people |
| `/trending/movies`, `/trending/shows` | Native browse pages |
| `/history`, `/continue-watching` | Native with filters, manual scrobble, delete, session clear |
| `/next-up` | Native, hidden Next Up toggle |
| `/calendar` | Native day range |
| `/lists`, `/list/{id}` | Native CRUD, add/remove, reorder, privacy |
| `/profile`, `/profile/{id}` | Native stats, follow, top-rated/recent “see all”, language/genre profile fields |
| `/stats` | Native watch time, activity, ratings, weekdays, genres |
| `/progress`, `/dropped` | Native |
| movie/episode/show/season/person/network/studio/collection pages | Native detail, cast, recommendations, comments, Trakt comments, ratings, watch state, lists, requests |
| `/settings`, `/user-settings` | Preferences, API key, password/email/2FA, connected apps, native ZIP export/import |
| `/connections` | Native list/sync/push/toggles/schedules/library selection; **linking is web-only by requirement** |
| `/admin` | Native settings, users (create/reset/disable 2FA/delete), requests, cache, metadata heal, database backup/restore |
| `/about` | Native About with server/version/source links |

## Deliberate exclusions (per product direction)

- OIDC/SSO and OIDC identities.
- In-app video playback.
- Provider/account linking: opens the web UI; the app manages existing
  connections only.
- Localization: the Android UI is English-only.
- TVDB-only titles without a TMDB id open the matching web detail page.
- Public poster wall and anonymous browsing are not exposed natively because
  the app requires a session.

## Image authentication

`/media/image/...` requires a JWT (Authorization header, `?token=`, or the
`token` cookie) even though posters contain no private data. An API key is not
accepted. The app sends `Authorization` on all own-proxy image requests; Dart
strips it on cross-origin redirects to TMDB/TVDB, so it cannot leak. Poster
widgets also fall back to the public TMDB/TVDB URL if the proxy fails.

## Data

- Native export: `GET /export/data` ZIP, shared via Android.
- Native import: `.zip` picker → `POST /export/import`.
- Native admin backup/restore: `.bak` file.

## Signing / release

See `README.md` and `.skills/release-apk/SKILL.md`. CI decodes
`ANDROID_KEYSTORE_BASE64` into `android/app/release.keystore`, writes the ignored
`android/key.properties`, and falls back to debug signing when the secret is
absent.
