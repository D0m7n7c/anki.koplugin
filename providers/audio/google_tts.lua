-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
Audio provider: Google Translate TTS (keyless, well-known endpoint).
  get(word, lang) -> { data = <mp3 bytes>, ext = "mp3" } | nil

This is the reliable fallback in the chain. Synthetic voice; for single words
it works well. Long text would need chunking (not needed for word audio).
]]

local http = require("socket.http")
local socket = require("socket")
local socketutil = require("socketutil")
local ltn12 = require("ltn12")

local function urlencode(s)
    return (s:gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

return function(word, lang)
    if not word or word == "" then return nil end
    local url = ("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=%s&q=%s")
        :format(urlencode(lang or "en"), urlencode(word))
    local sink = {}
    socketutil:set_timeout(5)
    local status = socket.skip(1, http.request{
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = "Mozilla/5.0" },
        sink = ltn12.sink.table(sink),
    })
    socketutil:reset_timeout()
    if status ~= 200 then return nil end
    local data = table.concat(sink)
    if data == "" then return nil end
    return { data = data, ext = "mp3" }
end
