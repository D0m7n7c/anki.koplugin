-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
profiles — global connection + named profiles + per-book selection.

Model:
  * connection (global): { url, api_key } — one for the whole plugin.
  * profiles (named): name -> per-profile data (deck, note type, languages,
    dictionary, definition/audio, tags). Created by the "New profile" wizard.
  * book_overrides: book path -> profile name (manual per-book choice).

The active profile for the current book is chosen automatically by matching the
document language to a profile's target language, unless a manual override exists.
`effective(ui)` returns defaults + the chosen profile + the global connection.

Robust: never errors on load; a missing store falls back to empty structures.
]]

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")
local defaults = require("config_defaults")

local Profiles = {}

local function store_path()
    return DataStorage:getSettingsDir() .. "/anki_koplugin.lua"
end

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

local function book_key(ui)
    return ui and ui.document and ui.document.file or nil
end

function Profiles:init()
    local ok, s = pcall(function() return LuaSettings:open(store_path()) end)
    if ok then
        self.settings = s
    else
        logger.warn("anki.koplugin: could not open settings, using memory only")
        self.settings = nil
    end
    local function read(key, fallback)
        return (self.settings and self.settings:readSetting(key)) or fallback
    end
    self._connection = read("connection", { url = "", api_key = "" })
    self.profiles = read("profiles", {})
    self.book_overrides = read("book_overrides", {})
    self.last_profile = read("last_profile", nil)
    return self
end

function Profiles:_flush()
    if not self.settings then return end
    self.settings:saveSetting("connection", self._connection)
    self.settings:saveSetting("profiles", self.profiles)
    self.settings:saveSetting("book_overrides", self.book_overrides)
    self.settings:saveSetting("last_profile", self.last_profile)
    self.settings:flush()
end

----------------------------------------------------------- connection --------

function Profiles:connection() return self._connection end

function Profiles:has_connection()
    return self._connection.url ~= nil and self._connection.url ~= ""
end

function Profiles:set_connection(url, api_key)
    self._connection = { url = url or "", api_key = api_key or "" }
    self:_flush()
end

-------------------------------------------------------- named profiles -------

function Profiles:names()
    local out = {}
    for name in pairs(self.profiles) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Profiles:exists(name) return self.profiles[name] ~= nil end

function Profiles:get_profile(name) return self.profiles[name] end

function Profiles:save_profile(name, data)
    self.profiles[name] = data
    self.last_profile = name
    self:_flush()
end

--- Delete a profile and any book overrides pointing to it.
function Profiles:delete_profile(name)
    self.profiles[name] = nil
    for k, v in pairs(self.book_overrides) do
        if v == name then self.book_overrides[k] = nil end
    end
    if self.last_profile == name then self.last_profile = nil end
    self:_flush()
end

--- Rename a profile; move its book overrides too. Returns true on success.
function Profiles:rename_profile(old, new)
    if not self.profiles[old] or self.profiles[new] then return false end
    self.profiles[new] = self.profiles[old]
    self.profiles[old] = nil
    for k, v in pairs(self.book_overrides) do
        if v == old then self.book_overrides[k] = new end
    end
    if self.last_profile == old then self.last_profile = new end
    self:_flush()
    return true
end

------------------------------------------------------- book selection --------

function Profiles:set_book_profile(ui, name)
    local k = book_key(ui)
    if k then
        self.book_overrides[k] = name
        self.last_profile = name
        self:_flush()
    end
end

--- Name of the active profile for the current book (may be nil if none exist).
function Profiles:active_name(ui)
    local k = book_key(ui)
    if k and self.book_overrides[k] and self.profiles[self.book_overrides[k]] then
        return self.book_overrides[k]
    end
    -- auto-match by document language
    local doc_lang = require("koreader_compat").doc.language(ui)
    if doc_lang and doc_lang ~= "" then
        for name, data in pairs(self.profiles) do
            local tl = data.target_lang
            if tl and tl ~= "" and doc_lang:lower():find(tl:lower(), 1, true) then
                return name
            end
        end
    end
    if self.last_profile and self.profiles[self.last_profile] then
        return self.last_profile
    end
    return self:names()[1]
end

--- Effective profile for the current book: defaults + profile + connection.
--- Returns nil if no profile exists yet.
function Profiles:effective(ui)
    local name = self:active_name(ui)
    if not name then return nil end
    local eff = merge(defaults, self.profiles[name])
    eff.url = self._connection.url
    eff.api_key = self._connection.api_key
    eff._name = name
    return eff
end

return Profiles
