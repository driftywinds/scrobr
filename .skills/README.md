# Local skills

Reusable notes for working on this repo. These are for humans/agents, not part
of the Flutter build.

- [scrob-api](scrob-api/SKILL.md) — auth model, live endpoints, image URLs,
  and the admin-only OpenAPI document.
- [flutter-android](flutter-android/SKILL.md) — local SDK paths, env overrides,
  analyzer/build commands.
- [release-apk](release-apk/SKILL.md) — tag/manual release workflow behavior.

## Machine-local values

`local/` is gitignored. Put instance URLs, account notes and machine paths in
`.skills/local/*.md`; never in these tracked files. A fresh clone does not
include that directory, so keep a separate backup (password manager, private
notes repo, or encrypted archive).
