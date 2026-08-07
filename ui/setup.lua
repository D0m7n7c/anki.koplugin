-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
setup — the GLOBAL AnkiConnect connection dialog (URL + optional API key).
Everything else now lives in named profiles (see ui/wizard.lua).
]]

local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local compat = require("koreader_compat")
local AnkiConnect = require("ankiconnect")
local NoteType = require("note_type")

local Setup = {}

--- Which of the profile's note type / deck are missing? Returns missing_model, missing_deck.
function Setup.check_missing(profile)
    local models = AnkiConnect.model_names(profile.url, profile.api_key) or {}
    local decks = AnkiConnect.deck_names(profile.url, profile.api_key) or {}
    local has_model, has_deck = false, false
    for _i, m in ipairs(models) do if m == profile.note_type then has_model = true end end
    for _i, d in ipairs(decks) do if d == profile.deck then has_deck = true end end
    return not has_model, not has_deck
end


--- Test a connection and report. `conn` = { url, api_key }.
function Setup.test(conn)
    if not conn.url or conn.url == "" then
        return compat.ui.toast(_("Set the AnkiConnect URL first."), 3)
    end
    local ok, ver = AnkiConnect.is_running(conn.url, conn.api_key)
    if ok then
        compat.ui.toast(_("Connected to Anki") .. " (v" .. tostring(ver) .. ")", 3)
    else
        compat.ui.toast(_("Connection failed") .. ":\n" .. tostring(ver), 4)
    end
end

--- Edit the GLOBAL connection (URL + optional API key), with an in-dialog Test.
function Setup.edit_connection(profiles)
    local conn = profiles:connection()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("AnkiConnect settings"),
        fields = {
            {
                text = conn.url or "",
                description = _("AnkiConnect URL"),
                hint = "http://192.168.1.xxx:8765",
            },
            {
                text = conn.api_key or "",
                description = _("API key (optional)"),
                hint = _("Leave blank if unused"),
            },
        },
        buttons = { {
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("Test"),
                callback = function()
                    local f = dialog:getFields()
                    Setup.test({ url = f[1], api_key = f[2] })
                end,
            },
            {
                text = _("Save"),
                callback = function()
                    local f = dialog:getFields()
                    profiles:set_connection(f[1], f[2])
                    UIManager:close(dialog)
                    compat.ui.toast(_("Saved."))
                end,
            },
        } },
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then dialog:onShowKeyboard() end
end

return Setup
