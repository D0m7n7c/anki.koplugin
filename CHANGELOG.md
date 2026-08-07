# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-07

First release of an offline-first rewrite of Ajatt-Tools/anki.koplugin.

### Added
- **Offline card capture.** The card is built entirely from KOReader's local
  dictionaries at look-up time — no translation service or network required.
- **Offline card type `KOReader Offline`** (`Word`, `Sentence`, `FrontDefinition`,
  `BackDefinition`), as a pluggable module under `cardtypes/`.
- **Dictionary roles** (Front / Back). Entries are pulled from the pop-up results
  **by dictionary name**, so it doesn't matter which dictionary was on screen when
  the word was tapped. Missing entries become placeholders and add a
  `no-dict-entry` tag.
- **Named profiles** with a **New profile** wizard (Back/Cancel navigation,
  checkbox selection confirmed with **Next**), **Manage profiles**
  (edit/rename/delete), and a global AnkiConnect connection.
- **Per-book profile selection** by document language, with a manual override.
- **Per-card tag palette** offered in a dialog on every mine.
- **Offline JSONL queue** with a **Sync now** action; duplicates are treated as
  done, other failures stay queued.
- **Reactive setup** on desktop Anki: a missing deck/note type is created on the
  first sync via a confirmation prompt.
- **Note-type conflict detection**: if a note type of the same name exists with
  different fields, the plugin reports it (rename/delete in Anki) instead of
  writing into the wrong fields.
- Project tooling: **README**, `CHANGELOG.md`, `.luacheckrc`, **busted** tests for
  the pure-logic modules, and a **luacheck + busted CI** workflow.

### Changed
- Reworked around KOReader's current `addToDictButtons` API, with the legacy
  `onDictButtonsReady` event kept as a fallback.
- All KOReader-facing calls isolated behind `koreader_compat.lua`.

### Compatibility
- Works with desktop Anki + AnkiConnect. Also works with
  [AnkiConnect Android](https://github.com/KamWithK/AnkiconnectAndroid), except
  that it cannot create note types/decks there — create `KOReader Offline` and its
  deck manually in AnkiDroid (see README).
