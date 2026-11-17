# Showly backup import — implementation blueprint

Status: **design only, not implemented**  
Last verified: 2026-11-17 against Showly `master` and a real Showly v2 export.

## Goal

Import a Showly JSON backup into the logged-in Scrob account from the Scrobr app, with three user-selectable modes:

1. **Add missing** — default, non-destructive.
2. **Merge** — import everything, allowing duplicate watch events.
3. **Replace** — wipe the imported data types, then import the backup.

The app must process the Showly file locally and use existing Scrob APIs. No server changes are required for the basic version, though a server-side bulk endpoint is strongly preferred for speed and atomicity.

## Showly export format (confirmed from source)

Top level:

```json
{
  "version": 2,
  "platform": "android",
  "createdAt": "…",
  "shows": {},
  "movies": {},
  "lists": {}
}
```

Relevant Showly source:

- [`BackupScheme.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/model/BackupScheme.kt)
- [`BackupShows.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/model/BackupShows.kt)
- [`BackupMovies.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/model/BackupMovies.kt)
- [`BackupLists.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/model/BackupLists.kt)
- [`BackupImportShowsRunner.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/features/import_/runners/BackupImportShowsRunner.kt)
- [`BackupImportMoviesRunner.kt`](https://github.com/trakt/showly/blob/master/ui-backup/src/main/java/com/michaldrabik/ui_backup/features/import_/runners/BackupImportMoviesRunner.kt)

### Shows

| Key | Showly meaning | Shape |
|---|---|---|
| `cH` | Collection history — “My Shows” | `BackupShow` |
| `cW` | Collection watchlist | `BackupShow` |
| `cHid` | Hidden/archived shows | `BackupShow` |
| `pEp` | Watched episodes | `BackupEpisode` |
| `pSe` | Watched/completed seasons | `BackupSeason` |
| `pP` | Pinned show Trakt IDs | `List<Long>` |
| `pOH` | On-hold show Trakt IDs | `List<Long>` |
| `rS` | Show ratings | `BackupShowRating` |
| `rSe` | Season ratings | `BackupSeasonRating` |
| `rEp` | Episode ratings | `BackupEpisodeRating` |

`BackupShow`:

```json
{
  "id": 245,
  "tmId": 246,
  "t": "Title",
  "a": "2021-02-11T10:25:30Z",
  "u": "2021-02-11T10:25:30Z"
}
```

`id` is the Showly/Trakt show ID. **Scrob needs `tmId` (TMDB).**

`BackupEpisode`:

```json
{
  "id": 15663,
  "sId": 245,
  "stmId": 13535,
  "eN": 1,
  "sN": 1,
  "a": "2021-02-11T10:25:30Z"
}
```

- `sId` = Showly/Trakt show ID; resolve to the show’s `tmId` using `cH`/`cW`/`cHid`.
- `stmId` = **episode TMDB ID**.
- `a` = watched date, nullable.
- `sN` / `eN` = season and episode numbers.

`BackupSeason`:

```json
{ "id": 893, "sId": 245, "stmId": 246, "sN": 1 }
```

`stmId` is the **show** TMDB ID, not a season TMDB ID.

### Movies

| Key | Showly meaning | Shape |
|---|---|---|
| `cH` | Collection/history — “My Movies” | `BackupMovie` |
| `cW` | Collection watchlist | `BackupMovie` |
| `cHid` | Hidden/archived movies | `BackupMovie` |
| `pP` | Pinned movie Trakt IDs | `List<Long>` |
| `rM` | Movie ratings | `BackupMovieRating` |

`BackupMovie` has `id`, `tmId`, `t`, `a` (added/watched date).

### Lists

```json
{
  "id": 1,
  "tId": 30504524,
  "sId": "list-slug",
  "n": "List name",
  "d": "Description",
  "p": "private",
  "ic": 100,
  "c": "createdAt",
  "u": "updatedAt",
  "it": [
    {
      "id": 1,
      "lId": 1,
      "tId": 212307,
      "tmId": 324786,
      "t": "movie",
      "r": 1,
      "l": "listedAt",
      "c": "createdAt",
      "u": "updatedAt"
    }
  ]
}
```

List item `t` is `movie` or `show`; map `show` to Scrob `series`.

## Confirmed mapping to Scrob

| Showly | Scrob action |
|---|---|
| `shows.cH` | Add show to **collection/library** (`POST /media/collect`, `media_type: "series"`). Do not create watch events from the show-level entry. |
| `shows.pEp` | `POST /history` for each episode. |
| `shows.pSe` | Fallback only: mark a season watched when there are no `pEp` entries for that season. |
| `shows.cW` | Add to **watchlist**. |
| `shows.cHid` | Optional: map to dropped shows. |
| `shows.pOH` | Optional: map to dropped shows. |
| `shows.pP` | No equivalent; skip. |
| `shows.rS` / `rSe` / `rEp` | Scrob ratings. |
| `movies.cH` | **Watch history** for the movie at `a`. Showly’s “My Movies” has no separate watched flag. |
| `movies.cW` | Add to **watchlist**. |
| `movies.cHid` | Optional: map to dropped movies. |
| `movies.pP` | No equivalent; skip. |
| `movies.rM` | Movie rating. |
| `lists.l` | Create Scrob lists and add their items. |

### Watch event payloads

Episode:

```json
{
  "media_type": "episode",
  "tmdb_id": 13535,
  "series_tmdb_id": 246,
  "season_number": 1,
  "episode_number": 1,
  "watched_at": "2021-02-11T10:25:30Z",
  "completed": true,
  "source": "showly"
}
```

Movie:

```json
{
  "media_type": "movie",
  "tmdb_id": 722913,
  "watched_at": "2021-02-11T13:52:55Z",
  "completed": true,
  "source": "showly"
}
```

This was tested on a disposable account: both requests were accepted and the dates were preserved. The entries were then deleted.

### Collection

```http
POST /media/collect
{ "tmdb_id": 246, "media_type": "series" }
```

Use `media_type: "movie"` for movie collection if that is ever imported.

### Season fallback

```http
POST /history/season
{ "series_tmdb_id": 246, "season_number": 1 }
```

Scrob creates the episode history itself. This loses Showly’s season date; use only as a fallback.

### Watchlist

- `GET /lists/watchlist` returns the watchlist list.
- Add items with `POST /lists/{watchlistId}/items`:

```json
{ "tmdb_id": 246, "media_type": "series" }
```

Use `media_type: "movie"` for movies.

### Ratings

- Movie: `{ "media_type": "movie", "tmdb_id": …, "rating": 1–10 }`
- Show: `{ "media_type": "series", "tmdb_id": …, "rating": … }`
- Season: `{ "media_type": "series", "tmdb_id": showTmdb, "season_number": …, "rating": … }`
- Episode: `{ "media_type": "episode", "tmdb_id": episodeTmdb, "rating": … }`

Scrob does not accept Showly’s `rA` rating date; it will use the current time.

### Lists

1. `POST /lists` with `name`, `description`, `privacy_level` (`private`/`public`).
2. `POST /lists/{listId}/items` with `tmdb_id` and `media_type` (`series` for show items).
3. Preserve order only if a reorder endpoint is added later; rank is otherwise lost.

## Import modes

### 1. Add missing

Build local snapshots first:

- **Watched history**: page through `GET /history?page=…&page_size=100` until `total_pages`. Build keys from `media_type + media.tmdb_id` (episode key uses episode TMDB ID; movie uses movie TMDB ID).
- **Collection**: use the library query already used by `LibraryScreen` (`/media` and `/shows` with `in_library`), or per-item detail checks if no bulk filter is reliable.
- **Watchlist**: `GET /lists/watchlist`.
- **Ratings**: `GET /ratings`.
- **Lists**: `GET /lists` and each list’s items.

Then:

- Skip movies/episodes already present in history.
- Skip library/watchlist/rating/list items already present.
- Never delete anything.
- Report skipped counts.

Do not rely on Scrob’s `force:false` duplicate guard for “add missing”: that guard is a short recent-event window, not an all-time watched check.

### 2. Merge

- Post every movie and episode event with `"force": true`.
- Duplicate watch events are allowed by design.
- Ratings overwrite existing values.
- Collection/watchlist/list additions are idempotent; skip items that already exist.
- Preserve all existing Scrob data.

### 3. Replace

Destructive; requires a typed confirmation such as `REPLACE`.

Before clearing:

- Download a local Scrob ZIP via `GET /export/data` as a rollback file.
- Refuse to continue if that backup fails.

Clear only user content, never the account/profile/settings:

- `DELETE /history`
- `DELETE /media/collect/all`
- Clear watchlist items (do not delete the watchlist list itself).
- Delete every rating individually via `DELETE /ratings` (there is no “clear all ratings” endpoint).
- Delete custom lists, but preserve the app-managed **`Following · Calendar`** list (description contains `Calendar follows created by Scrobr.`).
- Optionally clear dropped shows/movies if hidden/on-hold are being imported.
- Do not delete the special Watchlist list.

Then import the selected data types.

There is no multi-endpoint transaction. A failure mid-replace can leave a partial account. The importer must show a clear warning and a resumable/retry path. A server-side replace endpoint would be much safer.

## Edge cases found in the real export

- `version` must be `2`; reject unknown versions.
- Some `pEp.a` dates are `1970-01-01T00:00:00Z` — treat as missing/null, not a real date.
- Some show IDs can be missing from `cH`/`cW`/`cHid`, leaving `sId` unresolved. Report and skip those rows.
- `pSe` without a matching `pEp` uses the season fallback; it loses the original date.
- `cH` and `cW` are disjoint; do not infer watched status from watchlist.
- Managed recommendation lists (description/slug says Couchmoney) should be **skipped by default**; 250+ imported items otherwise.
- Showly `pP` is pinned, not playback progress; skip.
- `cHid` and `pOH` are not exact Scrob concepts; make them opt-in and map to dropped.
- Showly lists may be private/public; map privacy.
- Showly “history” for movies is the watched list; do not also add them to collection unless explicitly selected.

## Data-volume / performance

A full export can contain:

- ~7,650 episode history rows
- ~631 movie history rows
- ~400 collected shows
- ~500 season progress rows
- multiple ratings and lists

That is roughly **8,000+ HTTP writes**. App-only import with 2–3 concurrent requests can take tens of minutes and is not atomic.

Recommended:

- **Preferred:** add a server-side `POST /import/showly` job. The app uploads the JSON, the server parses and bulk-inserts in one job, and the app polls `/sync/status` (or a new import job endpoint). This also makes Replace atomic and fast.
- **Fallback:** app-side import with a persisted resume cursor, progress UI, cancel, and a detailed skipped/error report. Use a foreground service/WorkManager for long imports.

## UI flow

Settings → Import → **Showly backup**:

1. Pick `.json` with `FilePicker`.
2. Parse/validate locally.
3. Preview:
   - X shows in collection
   - X movies watched
   - X episodes watched
   - X seasons fallback
   - X watchlist items
   - X ratings
   - X lists / X items
   - X unresolved rows
4. Choose mode: **Add missing / Merge / Replace**.
5. Choose data types (history, library, watchlist, ratings, lists, hidden/on-hold).
6. Add missing or Merge: start immediately.
7. Replace: show warning, require typed confirmation, download ZIP backup.
8. Progress screen with processed/total, skipped, errors, cancel.
9. Completion summary and link to History/Library.

## Testing plan

Use only a disposable account.

- Verified a disposable test account on the test server was empty after cleanup.
- Sample test already passed:
  - one episode (`tmdb_id` episode + series TMDB + season/episode + date) → accepted
  - one movie with date → accepted
  - both deleted afterward
- Next tests:
  1. Add missing with a 10-item subset; run twice; second run should skip everything.
  2. Merge same subset; verify duplicate watch events are created.
  3. Add rating/list/watchlist tests.
  4. Replace on a fresh throwaway account; verify Following list survives.
  5. Full export; check duration/errors.
- Never run Replace against a real account.

## Open decisions before implementation

1. **App-only importer or server-side bulk job?** Server-side is strongly recommended.
2. **Replace scope:** confirm it clears history + collection + watchlist + ratings + custom lists + dropped, while preserving `Following · Calendar` and the Watchlist container.
3. **Default selections:** skip managed Couchmoney lists? Skip `cHid`/`pOH`/`pP` unless explicitly enabled?
4. **Movie collection:** import `movies.cH` only as watched history, or also add to Scrob collection?
5. **Season fallback:** use `/history/season` when no episode rows exist, accepting current-date history?

## Do not commit

- Real Showly exports or personal watch data.
- Test account credentials.
- API keys/tokens.
