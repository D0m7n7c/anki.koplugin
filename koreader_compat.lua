-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
koreader_compat — the ONLY module that touches KOReader APIs.

Rule: thin adapters only, NO business logic. If a KOReader API changes
(as the dict-button API did), this is the single file to fix.

Grounded in the proven calls of Ajatt-Tools/anki.koplugin:
  * popup_dict.word                         -> looked-up word
  * popup_dict.results[popup_dict.dict_index] -> the selected dictionary entry
      (.dict = name, .definition, .is_html, .ifo_lang)
  * ui.highlight:getSelectedWordContext(n)  -> raw text before/after the word

Internal namespaces: compat.dict / compat.doc / compat.net / compat.ui
]]

local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local DataStorage = require("datastorage")

local compat = {
    dict = {},
    doc = {},
    net = {},
    ui = {},
}

------------------------------------------------------------------- dict ------

--- Does this KOReader build have the new dict-button registration API?
function compat.dict.has_new_api(ui)
    return ui and ui.dictionary
        and type(ui.dictionary.addToDictButtons) == "function"
end

--- Register a button in the dictionary pop-up via the NEW API.
-- spec = { id, text, menu_text, on_press = function(dict_popup) ... end }
function compat.dict.register(ui, spec)
    ui.dictionary:addToDictButtons({
        id = spec.id,
        text = spec.text,
        menu_text = spec.menu_text or spec.text,
        callback = function(dict_popup)
            spec.on_press(dict_popup)
            dict_popup:onClose()
        end,
    })
end

--- Build the legacy button table for KOReader builds WITHOUT the new API.
-- Called from the plugin's onDictButtonsReady event handler.
function compat.dict.legacy_button(dict_popup, spec)
    return {
        id = spec.id,
        text = spec.text,
        callback = function()
            spec.on_press(dict_popup)
            dict_popup:onClose()
        end,
    }
end

--- Read the dictionary entry the user currently has selected in the pop-up.
-- Returns a plain table: { word, dict_name, ifo_lang, definition, is_html }.
function compat.dict.selected_entry(dict_popup)
    local entry = dict_popup.results[dict_popup.dict_index]
    return {
        word = dict_popup.word,
        dict_name = entry and entry.dict,
        ifo_lang = entry and entry.ifo_lang,
        definition = entry and entry.definition,
        is_html = entry and entry.is_html or false,
    }
end

--- Find the result from a SPECIFIC dictionary (by name), regardless of which
-- one is currently displayed. Returns { definition, is_html } or nil.
function compat.dict.entry_by_name(dict_popup, dict_name)
    if not dict_name or dict_name == "" then return nil end
    for _i, r in ipairs(dict_popup.results or {}) do
        if r.dict == dict_name then
            return { definition = r.definition, is_html = r.is_html or false }
        end
    end
    return nil
end

-------------------------------------------------------------------- doc ------

--- Raw text immediately before/after the selected word (crengine).
-- Returns prev_text, next_text (either may be "").
function compat.doc.selected_word_context(ui, size)
    if ui and ui.highlight and ui.highlight.getSelectedWordContext then
        local ok, prev_c, next_c = pcall(function()
            return ui.highlight:getSelectedWordContext(size)
        end)
        if ok then
            return prev_c or "", next_c or ""
        end
    end
    return "", ""
end

--- The document's language, if KOReader knows it. May be nil.
function compat.doc.language(ui)
    local doc = ui and ui.document
    if not doc then return nil end
    -- crengine exposes the document language via props/getProps
    if doc.getProps then
        local ok, props = pcall(function() return doc:getProps() end)
        if ok and props and props.language and props.language ~= "" then
            return props.language
        end
    end
    return nil
end

--- KOReader's UI language code (for pre-filling the native language). May be nil.
function compat.doc.ui_language()
    if G_reader_settings then
        return G_reader_settings:readSetting("language")
    end
    return nil
end

--- Names of the currently enabled dictionaries (for the monolingual role).
function compat.dict.enabled_names(ui)
    if ui and ui.dictionary and ui.dictionary.enabled_dict_names then
        return ui.dictionary.enabled_dict_names
    end
    return {}
end

--- Open KOReader's document/settings screen so the user can set the language.
-- Best-effort: returns true if a dialog was opened. (Verify on device.)
function compat.doc.open_language_setting(ui)
    -- TODO(phase 0 measurement): confirm the correct entry point on device.
    if ui and ui.menu and ui.menu.onShowMenu then
        ui.menu:onShowMenu()
        return true
    end
    return false
end

-------------------------------------------------------------------- net ------

function compat.net.is_online()
    return NetworkMgr:isConnected()
end

--- Run `func` now if online, otherwise once connectivity returns.
function compat.net.when_online(func)
    if NetworkMgr:willRerunWhenOnline(func) then
        return false -- deferred
    end
    return true -- ran (or will run immediately by caller)
end

--------------------------------------------------------------------- ui ------

function compat.ui.toast(text, timeout)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout or 2 })
end

--- Append an error + traceback to a file readable via `adb shell cat`.
function compat.ui.log_error(label, err)
    local path = DataStorage:getDataDir() .. "/anki_crash.txt"
    local f = io.open(path, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S "), tostring(label), "\n",
            tostring(err), "\n----\n")
        f:close()
    end
    return path
end

--- Run fn; on error, log the traceback to file and show a toast (never crash).
function compat.ui.safe(label, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        local path = compat.ui.log_error(label, err)
        compat.ui.toast(tostring(label) .. " error — see\n" .. path, 6)
    end
    return ok
end

return compat
