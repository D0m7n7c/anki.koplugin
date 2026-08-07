-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
sync — upload the offline queue to Anki.

For the offline (Stufe 1) card, notes are fully built at capture time, so sync
only sends them. Duplicates are treated as done; a "not found" error (missing
note type/deck) stops sync and signals needs_setup so the caller can offer to
create them. Later stages (translation/audio) will enrich here before sending.
]]

local AnkiConnect = require("ankiconnect")
local Queue = require("queue")

local Sync = {}

local function to_anki_note(note)
    return {
        deckName = note.deck,
        modelName = note.note_type,
        fields = note.fields,
        tags = note.tags or {},
        options = { allowDuplicate = false },
    }
end

--- Run a sync. Returns synced_count, pending_count, first_err, needs_setup.
function Sync.run(profile)
    local notes = Queue.list()
    if #notes == 0 then return 0, 0, nil, false end

    local ok, err = AnkiConnect.is_running(profile.url, profile.api_key)
    if not ok then return 0, #notes, err, false end

    local remaining, first_err, synced, needs_setup = {}, nil, 0, false
    for _i, note in ipairs(notes) do
        if needs_setup then
            remaining[#remaining + 1] = note
        else
            local _, aerr = AnkiConnect.add_note(profile.url, profile.api_key, to_anki_note(note))
            if aerr then
                local low = aerr:lower()
                if low:find("duplicate") then
                    synced = synced + 1
                elseif low:find("not found") then
                    needs_setup = true
                    remaining[#remaining + 1] = note
                else
                    first_err = first_err or aerr
                    remaining[#remaining + 1] = note
                end
            else
                synced = synced + 1
            end
        end
    end

    Queue.clear()
    for _i, n in ipairs(remaining) do Queue.add(n) end
    return synced, #remaining, first_err, needs_setup
end

return Sync
