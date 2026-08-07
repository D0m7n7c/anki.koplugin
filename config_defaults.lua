-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Per-PROFILE default values. The AnkiConnect connection (url/api_key) is
-- global and lives outside profiles (see profiles.lua).
return {
    -- which card type this profile builds (see cardtypes/)
    card_type = "offline",
    note_type = "KOReader Offline", -- Anki note type name (from the card type)
    deck = "Default",

    -- languages: target = language being learned (also used to auto-pick the
    -- profile for a book); native kept for later stages (translation).
    target_lang = "",
    native_lang = "de",

    -- dictionary roles (offline). Empty = none assigned → placeholder on the card.
    front_dict = "",          -- typically monolingual, target language (front)
    back_dict = "",           -- typically bilingual, target → native (back)

    -- tags
    auto_tag = "",          -- applied to every note; empty = none (default)
    custom_tags = {},         -- palette offered per card in the tag dialog
    source_tag_enabled = false,

    -- how much raw context to pull around the word before trimming to a sentence
    context_size = 200,
}
