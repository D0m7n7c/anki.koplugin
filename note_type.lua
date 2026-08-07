-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
note_type — create / inspect a card type's note type in Anki.

We do NOT modify existing note types (AnkiConnect can't rename/delete cleanly,
and on-device there's no way to fix a note type anyway). On a field conflict we
just report it; the user renames or deletes the note type in Anki.
]]

local AnkiConnect = require("ankiconnect")

local NoteType = {}

local function set_of(list)
    local s = {}
    for _i, v in ipairs(list or {}) do s[v] = true end
    return s
end

--- Status of `cardtype`'s note type in Anki.
--- Returns "missing" | "ok" | "conflict" (, existing_fields) | "error" (, err)
--- "ok"  = all required fields present (extra fields tolerated).
--- "conflict" = the name exists but some required fields are missing.
function NoteType.status(url, api_key, cardtype)
    local name = cardtype.note_type
    local models, err = AnkiConnect.model_names(url, api_key)
    if err then return "error", err end
    local present = false
    for _i, m in ipairs(models or {}) do
        if m == name then present = true break end
    end
    if not present then return "missing" end
    local fields, ferr = AnkiConnect.model_field_names(url, api_key, name)
    if ferr then return "error", ferr end
    local have = set_of(fields)
    for _i, want in ipairs(cardtype.fields) do
        if not have[want] then return "conflict", fields or {} end
    end
    return "ok", fields
end

--- Create the note type. Returns true | false, err.
function NoteType.create(url, api_key, cardtype)
    local _r, err = AnkiConnect.create_model(url, api_key, cardtype.note_type,
        cardtype.fields, cardtype.front, cardtype.back, cardtype.css)
    if err then return false, err end
    return true
end

return NoteType
