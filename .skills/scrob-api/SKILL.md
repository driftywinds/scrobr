# Scrob API workflow

Scrob backend + PWA: <https://github.com/ellite/scrob>. This app talks to the
web origin's proxy: `https://<host>/api/proxy/<backend-path>`.

## Auth

- `Authorization: Bearer <JWT>` for a normal login (`POST /auth/login`,
  form-urlencoded `username`, `password`, optional `remember`).
- **Native clients must also send a non-secret `X-Api-Key` header** (the app
  uses `scrob-native-client`) on every `/api/proxy/...` request. The web
  middleware skips its cookie gate when that header is present; the backend
  still enforces the JWT/API key. Without it, login and all JWT calls get a
  302 to `/login`.
- `X-Api-Key: <key>` (or `?api_key=`) works only on endpoints that use
  `get_current_user_or_api_key`: media, history, lists, ratings, comments,
  calendar, profile reads, export, etc. Account/security and `/admin/*`
  endpoints require a real JWT admin session.
- `/docs`, `/redoc`, `/openapi.json` are admin-JWT only, not API-key. The live
  schema is kept at `.tmp/openapi.json` (gitignored); do not commit it.
- Login can return `{requires_2fa, temp_token}`; finish with
  `POST /auth/2fa/verify-login {temp_token, code}`.

## Live instance

`https://scrob.003274.xyz` currently runs Scrob `2.38.0`. Test keys are in
`.tmp/scrob.env` (gitignored). Never commit keys.

- Admin key belongs to user id 1 (`drifty`), useful for read-only data.
- Base user key belongs to id 2 (`test`), use it for mutation tests.
- Public data sample: `GET /api/proxy/media/trending/movies`,
  `GET /api/proxy/profile/1`, `GET /api/proxy/history?page=1`.

## Shapes worth remembering

- Poster/backdrop fields are absolute TMDB URLs (`https://image.tmdb.org/t/p/...`).
  The proxy accepts `/api/proxy/media/image/{size}/{path}` and 302s/caches.
  Relative profile avatars look like `/profile/avatar/{id}`.
- Paginated lists: `{page, page_size, total_pages, total_results, results}`.
- Media: `tmdb_id`, `type` (`movie` / `series` / `episode` / `person`),
  `in_library`, `watched`, `in_lists`, `user_rating`, `collection_pct`,
  `watch_pct`, `show_tmdb_id` (episodes).
- Movie detail: `GET /media/movie/{tmdb_id}` — cast, crew, release_dates,
  collection, recommendations at `/media/{type}/{id}/recommendations`.
- Show: `GET /shows/{tmdb_id}` (`seasons_meta`, `season_states`, `rewatch`);
  season `GET /shows/{id}/season/{n}`; episode
  `GET /shows/{id}/season/{n}/{e}`.
- History events: `{id, media, watched_at, progress_percent, completed, source}`.
- Watch: `POST /history {tmdb_id, media_type, watched_at?, completed?}`,
  `DELETE /history/item?tmdb_id&media_type`.
- Rating: `POST /ratings` with `RatingIn` (inspect OpenAPI), comments at
  `/comments`, lists at `/lists`, calendar at `/calendar`.

## Useful probes

```sh
node .tmp/sample_api.mjs     # saves live JSON to .tmp/samples
py .tmp/params.py            # key endpoint parameters
py .tmp/schemas.py           # UserSettings / profile schemas
```

Prefer `fetch` from Node or Python `urllib` for HTTPS: schannel/curl.exe is
broken in this sandbox (`SEC_E_NO_CREDENTIALS`), while Node/Python TLS works.
Git needs `-c http.sslBackend=openssl` for the same reason.
