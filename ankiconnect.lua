-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
ankiconnect — thin AnkiConnect HTTP client.

Networking (sanitize_url, with_timeout, POST, is_running, request_add_note) is
adapted from Ajatt-Tools/anki.koplugin, which is battle-tested. We add helpers
to create the note type and deck, and to store media.

No KOReader UI here; callers handle messaging. Business flow lives in sync.lua.
]]

local http = require("socket.http")
local socket = require("socket")
local socketutil = require("socketutil")
local ltn12 = require("ltn12")
local mime = require("mime")
local json = require("rapidjson")

local AnkiConnect = {}

--- Fix common URL mistakes (missing scheme, https where http meant).
function AnkiConnect.sanitize_url(url)
    local valid = url
    local _, scheme_end, scheme, ssl = url:find("^(http(s?)://)")
    if not scheme then
        valid = "http://" .. url
    elseif ssl and #ssl > 0 then
        valid = "https://" .. url:sub(scheme_end + 1)
    end
    return valid
end

local function with_timeout(timeout, func)
    socketutil:set_timeout(timeout)
    local res = { func() }
    socketutil:reset_timeout()
    return unpack(res)  -- LuaJIT: global unpack, NOT table.unpack
end

--- Low-level POST of an AnkiConnect action. Returns result, err.
function AnkiConnect.post(url, payload, api_key, timeout)
    url = AnkiConnect.sanitize_url(url)
    if api_key and api_key ~= "" then payload.key = api_key end
    local body = json.encode(payload)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #body,
    }
    -- optional http://user:pass@host basic auth
    local scheme, basic_auth, host = url:match("^(https?://)([^:]+:[^@]+)@(.+)")
    if basic_auth then
        headers["Authorization"] = "Basic " .. (mime.b64(basic_auth))
        url = scheme .. host
    end
    local sink = {}
    local req = {
        url = url,
        method = "POST",
        headers = headers,
        sink = ltn12.sink.table(sink),
        source = ltn12.source.string(body),
    }
    local status = with_timeout(timeout or 6, function()
        return socket.skip(1, http.request(req))
    end)
    if type(status) == "string" then return nil, status end          -- e.g. "timeout"
    if status ~= 200 then return nil, ("HTTP %s"):format(tostring(status)) end
    local ok, response = pcall(json.decode, table.concat(sink))
    if not ok or type(response) ~= "table" then return nil, "Bad JSON from AnkiConnect" end
    if type(response.error) == "string" then return nil, response.error end
    return response.result
end

--- Is AnkiConnect reachable? Returns true, version | false, err.
-- Uses the `version` action: implemented by BOTH desktop Anki and AnkiConnect
-- Android. (requestPermission is NOT implemented by AnkiConnect Android and
-- makes it return a malformed response — see KamWithK/AnkiconnectAndroid#105.)
function AnkiConnect.is_running(url, api_key)
    local res, err = AnkiConnect.post(url, { action = "version", version = 6 }, api_key, 4)
    if err then return false, err end
    return true, res or "ok"
end

function AnkiConnect.deck_names(url, api_key)
    return AnkiConnect.post(url, { action = "deckNames", version = 6 }, api_key)
end

function AnkiConnect.model_names(url, api_key)
    return AnkiConnect.post(url, { action = "modelNames", version = 6 }, api_key)
end

function AnkiConnect.model_field_names(url, api_key, model)
    return AnkiConnect.post(url, {
        action = "modelFieldNames", version = 6,
        params = { modelName = model },
    }, api_key)
end

function AnkiConnect.create_deck(url, api_key, deck)
    return AnkiConnect.post(url, {
        action = "createDeck", version = 6, params = { deck = deck },
    }, api_key)
end

--- Create a note type (model) with the given field names and card template.
function AnkiConnect.create_model(url, api_key, model_name, fields, front, back, css)
    return AnkiConnect.post(url, {
        action = "createModel", version = 6,
        params = {
            modelName = model_name,
            inOrderFields = fields,
            css = css or "",
            cardTemplates = { { Name = "Card 1", Front = front, Back = back } },
        },
    }, api_key)
end






--- Add a note. `note` is a fully-formed AnkiConnect note table.
function AnkiConnect.add_note(url, api_key, note)
    return AnkiConnect.post(url, {
        action = "addNote", version = 6, params = { note = note },
    }, api_key)
end

return AnkiConnect
