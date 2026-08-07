-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
queue — the offline note queue.

Notes captured while reading are appended here (one JSON object per line).
Phase 1 will drain this queue to Anki via AnkiConnect; Phase 2 will enrich
each note with translations + audio first.

Modelled on Ajatt-Tools/anki.koplugin, which stores unsynced notes as
newline-separated JSON in the settings dir.
]]

local DataStorage = require("datastorage")
local json = require("rapidjson")
local logger = require("logger")

local Queue = {}

local function path()
    return DataStorage:getSettingsDir() .. "/anki_koplugin_queue.jsonl"
end

--- Append one note (a plain Lua table) to the queue. Returns ok, new_count.
function Queue.add(note)
    local line = json.encode(note)
    local f, err = io.open(path(), "a")
    if not f then
        logger.err("anki.koplugin: cannot open queue file:", err)
        return false, Queue.count()
    end
    f:write(line)
    f:write("\n")
    f:close()
    return true, Queue.count()
end

--- Number of notes currently queued.
function Queue.count()
    local f = io.open(path(), "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        if line ~= "" then n = n + 1 end
    end
    f:close()
    return n
end

--- Return all queued notes as a list of tables (skips malformed lines).
function Queue.list()
    local out = {}
    local f = io.open(path(), "r")
    if not f then return out end
    for line in f:lines() do
        if line ~= "" then
            local ok, note = pcall(json.decode, line)
            if ok and note then table.insert(out, note) end
        end
    end
    f:close()
    return out
end

--- Remove all queued notes (called by sync once they are safely in Anki).
function Queue.clear()
    os.remove(path())
end

return Queue
