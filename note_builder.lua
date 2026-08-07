-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
note_builder — turn the current dictionary look-up into a complete, offline
note using the profile's card type.

The Front/Back dictionary entries are pulled from the pop-up's results BY NAME
(the roles set in the profile), so it doesn't matter which dictionary was on
screen when the word was tapped. Missing entries become placeholders and add a
"no-dict-entry" tag (handled by the card type's populate()).
]]

local compat = require("koreader_compat")
local text_util = require("text_util")
local cardtypes = require("cardtypes/init")

local NoteBuilder = {}

-- returns def_html(string|nil), found(bool)
local function role_entry(dict_popup, dict_name)
    local e = compat.dict.entry_by_name(dict_popup, dict_name)
    if not e then return nil, false end
    return text_util.definition_html(e.definition, e.is_html), true
end

function NoteBuilder.build(ui, dict_popup, profile)
    local word = dict_popup.word
    local prev_c, next_c = compat.doc.selected_word_context(ui, profile.context_size)
    local sentence = text_util.core_sentence(prev_c, next_c, word)

    local front_def, front_found = role_entry(dict_popup, profile.front_dict)
    local back_def, back_found = role_entry(dict_popup, profile.back_dict)

    local cardtype = cardtypes.get(profile.card_type)
    local fields, extra_tags = cardtype.populate({
        word = word,
        sentence = sentence,
        front_def = front_def,
        back_def = back_def,
        front_dict = profile.front_dict,
        back_dict = profile.back_dict,
        front_assigned = profile.front_dict ~= nil and profile.front_dict ~= "",
        back_assigned = profile.back_dict ~= nil and profile.back_dict ~= "",
        front_found = front_found,
        back_found = back_found,
    })

    return {
        fields = fields,             -- Anki field name -> value (ready to send)
        note_type = cardtype.note_type,
        deck = profile.deck,
        tags = {},                   -- per-card tags chosen in the tag dialog
        extra_tags = extra_tags,     -- e.g. { "no-dict-entry" }
        meta = { word = word, doc_language = compat.doc.language(ui), created = os.time() },
    }
end

return NoteBuilder
