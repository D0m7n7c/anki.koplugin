# Anki Card Mining — KOReader plugin

![KOReader plugin](https://img.shields.io/badge/KOReader-plugin-blue)
[![CI](https://github.com/D0m7n7c/anki.koplugin/actions/workflows/ci.yml/badge.svg)](https://github.com/D0m7n7c/anki.koplugin/actions/workflows/ci.yml)
![License: AGPL-3.0-or-later](https://img.shields.io/badge/license-AGPL--3.0--or--later-green)

Mine Anki flashcards from KOReader dictionary look-ups — **offline first**. Tap a
word while reading, tap **Add to Anki**, and the plugin builds a complete card
from the sentence and your local dictionaries without any network. Cards wait in
a queue and are pushed to Anki over AnkiConnect when you sync.

> **About this plugin.** This plugin was developed end-to-end with Anthropic's
> Claude Opus 4.8. There is no active human maintainer behind it — it was built
> to solve a personal need and is shared as-is, without warranty. Contributions
> and maintainers are very welcome: if you'd like to improve or take over the
> project, please open an issue or pull request.

> Requires a recent **KOReader** build. It supports both the current
> dictionary-button API (`addToDictButtons`) and the older `onDictButtonsReady`
> event, so the **Add to Anki** button works on old *and* new KOReader.

## Features

- **"Add to Anki" button in the dictionary pop-up** — look a word up, tap the button.
- **Fully offline capture** — the card is built entirely from KOReader's local
  dictionaries; no translation service, no network, no dependencies.
- **Per-card tags** — a tag palette (defined per profile) is offered each time you mine.
- **Named profiles, chosen per book** — the right profile is picked automatically
  by matching the book's language, with a manual override per book.
- **Offline queue** — mined cards are stored on-device and pushed to Anki on sync.
- **Reactive setup** — on desktop Anki, a missing deck/note type is created for
  you on the first sync.

## The card

Everything comes from dictionaries KOReader already has locally:

| Side | Field | Source |
| --- | --- | --- |
| Front | `Sentence` | the sentence, with the looked-up word marked |
| Front | `FrontDefinition` | your **Front dictionary** (typically monolingual, target language) |
| Back | `BackDefinition` | your **Back dictionary** (typically bilingual, target → native) |

If a role has no dictionary assigned, or the word isn't in it, the field gets a
clear placeholder (`[no dictionary assigned]` / `[no entry in <dict>]`) and the
note is tagged `no-dict-entry`, so incomplete cards are easy to find in Anki.

The card type is a pluggable module (`cardtypes/`); this is the offline
foundation that later stages build on (see [Roadmap](#roadmap)).

## Requirements

- An e-reader or device running a reasonably recent **KOReader** (e.g. Tolino, Kobo, PocketBook, Android).
- **Anki** with the **AnkiConnect** add-on (desktop), reachable from your device.
- At least one **StarDict** dictionary installed in KOReader for each role you use.

### AnkiConnect on Android

The plugin also works with
[AnkiConnect Android](https://github.com/KamWithK/AnkiconnectAndroid), with one
caveat: it **cannot create note types or decks** (`createModel`/`createDeck` are
not implemented there). Create the note type **`KOReader Offline`** manually in
AnkiDroid once — with exactly the fields `Word`, `Sentence`, `FrontDefinition`,
`BackDefinition` — plus a matching deck. On desktop Anki this is automatic.

## Installation

1. Download this repository as a ZIP (`Code ▸ Download ZIP`), or clone it.
2. Copy the contents into a folder named exactly `anki.koplugin`
   (the folder name **must** end in `.koplugin`).
3. Place that folder inside your KOReader `plugins` directory. On Android this is
   usually:
   ```
   /storage/emulated/0/koreader/plugins/anki.koplugin/
   ```
4. Restart KOReader. The plugin appears in the search/tools menu as **Anki settings**.

## Setup

1. **Anki settings ▸ AnkiConnect settings** — enter the AnkiConnect URL
   (e.g. `http://127.0.0.1:8765` on the same machine, or the host's LAN IP), then **Test**.
2. **Anki settings ▸ New profile** — a short wizard: name, deck, languages,
   **Front dictionary**, **Back dictionary**, tags. Every step is confirmed with
   **Next**; where a real choice is required, nothing is pre-selected.

Profiles are chosen per book automatically by matching the document language to a
profile's target language. **Anki settings ▸ Profile for this book** overrides it,
and **Manage profiles** edits, renames or deletes profiles.

## Usage

- **Mine:** look a word up, tap **Add to Anki**, pick any tags, tap **Add**. The
  note goes to an offline queue (the count shows next to **Sync now**).
- **Sync:** **Anki settings ▸ Sync now**. On desktop Anki, if the deck or note
  type is missing, the plugin offers to create them and continue.

You can reposition or hide the pop-up button via KOReader's
**Dictionary settings ▸ Customize buttons**.

## Troubleshooting

- **The card is created but the dictionary fields are empty.**
  The note type in Anki doesn't have the fields `FrontDefinition` / `BackDefinition`
  (e.g. an old note type with the same name). Rename or delete it in Anki so the
  plugin can create `KOReader Offline` with the right fields. On AnkiConnect
  Android, create that note type manually (see above).
- **"Connection failed" against AnkiConnect Android.**
  Make sure you are on a recent plugin version; the connection check uses the
  `version` action, which AnkiConnect Android supports.
- **Sync says "Couldn't get model ID".**
  The note type doesn't exist in AnkiDroid and AnkiConnect Android can't create it
  — add it manually as described under *AnkiConnect on Android*.
- **The "Add to Anki" button is missing.**
  Make sure you run this plugin (not an older copy) and restart KOReader fully.

## Roadmap

Extensions are planned as additional card-type modules on top of the offline one:

- **Translation** — a machine translation of the sentence (online, on sync).
- **Audio** — pronunciation audio (online, on sync).

## Development

Pure-logic modules are unit-tested with
[busted](https://lunarmodules.github.io/busted/); everything is linted with
[luacheck](https://github.com/lunarmodules/luacheck).

```bash
luarocks install busted luacheck   # once
busted                             # run the tests
luacheck .                         # lint
```

CI runs the same on every push (see `.github/workflows/ci.yml`). KOReader-facing
code lives behind `koreader_compat.lua`; the rest is plain Lua that runs — and is
tested — outside KOReader.

## Contributing

Issues and pull requests are welcome. Please keep commits in
[Conventional Commits](https://www.conventionalcommits.org/) style and update
`CHANGELOG.md`.

## Credits

- Forked from **[Ajatt-Tools/anki.koplugin](https://github.com/Ajatt-Tools/anki.koplugin)**
  — the original KOReader Anki mining plugin, here largely rewritten around an
  offline-first, profile-based design. (AGPL-3.0)

## License

[AGPL-3.0-or-later](./LICENSE). This license is inherited from the upstream
project and preserved here.
