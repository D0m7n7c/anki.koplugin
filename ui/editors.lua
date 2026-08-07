-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
editors — reusable single-field editors, used by BOTH the wizard (chained,
with Back/Cancel) and Manage-profiles (direct edit).

Each editor takes its current value(s) plus a `nav` table:
  nav.on_done(value...)   required — called with the new value(s)
  nav.on_back()           optional — adds a Back button that calls this
  nav.on_cancel()         optional — Cancel action (defaults to just closing)
No profile is written here; the caller decides what to do with the result.
]]

local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local compat = require("koreader_compat")
local AnkiConnect = require("ankiconnect")

local E = {}

local function toast(t, s) compat.ui.toast(t, s or 3) end

local function split_tags(s)
    local out = {}
    for tag in (s or ""):gmatch("[^,]+") do
        tag = tag:gsub("^%s+", ""):gsub("%s+$", "")
        if tag ~= "" then out[#out + 1] = tag end
    end
    return out
end

-- build a [Back?] [Cancel] [extra...] button row; `close` closes the dialog
local function nav_row(nav, close, extra)
    local row = {}
    if nav.on_back then
        row[#row + 1] = { text = _("Back"),
            callback = function() close(); nav.on_back() end }
    end
    row[#row + 1] = { text = _("Cancel"), id = "close",
        callback = function()
            close()
            if nav.on_cancel then nav.on_cancel() end
        end }
    for _i, b in ipairs(extra or {}) do row[#row + 1] = b end
    return row
end

-- Single-select with checkboxes + always a Next button.
-- options: { {text=, value=}, ... } and optionally { text=, action=fn } (action
-- rows have no checkbox and run immediately). `selected` is the pre-checked
-- value (nil = nothing checked). Next with nothing checked shows an error.
-- Calls nav.on_done(value) on Next.
local function select_one(title, options, selected, nav)
    local sel = selected
    local dialog
    local function close() UIManager:close(dialog) end
    local function rebuild()
        local rows = {}
        for _i, opt in ipairs(options) do
            if opt.action then
                rows[#rows + 1] = { { text = opt.text,
                    callback = function() close(); opt.action() end } }
            else
                local mark = (opt.value == sel) and "[x] " or "[ ] "
                rows[#rows + 1] = { { text = mark .. opt.text, callback = function()
                    sel = opt.value; close(); rebuild()
                end } }
            end
        end
        local next_btn = { text = _("Next"), callback = function()
            if sel == nil then return toast(_("Please select an option.")) end
            close(); nav.on_done(sel)
        end }
        rows[#rows + 1] = nav_row(nav, close, { next_btn })
        dialog = ButtonDialog:new{ title = title, title_align = "center", buttons = rows }
        UIManager:show(dialog)
    end
    rebuild()
end

----------------------------------------------------------------- name --------

function E.name(profiles, current, allow_current, title, nav)
    local dialog
    local function close() UIManager:close(dialog) end
    local next_btn = { text = _("Next"), callback = function()
        local name = dialog:getInputText()
        if name == "" then return toast(_("Please enter a name.")) end
        if name ~= allow_current and profiles:exists(name) then
            return toast(_("A profile with that name already exists."))
        end
        close(); nav.on_done(name)
    end }
    dialog = InputDialog:new{
        title = title or _("Profile name"),
        input = current or "",
        input_hint = _("e.g. English"),
        buttons = { nav_row(nav, close, { next_btn }) },
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then dialog:onShowKeyboard() end
end

----------------------------------------------------------- connection --------

function E.connection(profiles, nav)
    local c = profiles:connection()
    local dialog
    local function close() UIManager:close(dialog) end
    local test_btn = { text = _("Test"), callback = function()
        local f = dialog:getFields()
        local ok, ver = AnkiConnect.is_running(f[1], f[2])
        toast(ok and (_("Connected") .. " (v" .. tostring(ver) .. ")")
            or (_("Failed") .. ": " .. tostring(ver)), 3)
    end }
    local save_btn = { text = _("Save"), callback = function()
        local f = dialog:getFields()
        profiles:set_connection(f[1], f[2])
        close(); nav.on_done()
    end }
    dialog = MultiInputDialog:new{
        title = _("AnkiConnect settings"),
        fields = {
            { text = c.url or "", description = _("AnkiConnect URL"),
              hint = "http://192.168.1.xxx:8765" },
            { text = c.api_key or "", description = _("API key (optional)"),
              hint = _("Leave blank if unused") },
        },
        buttons = { nav_row(nav, close, { test_btn, save_btn }) },
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then dialog:onShowKeyboard() end
end

----------------------------------------------------------------- deck --------

function E.deck(profiles, current, nav)
    local c = profiles:connection()
    local decks, err = AnkiConnect.deck_names(c.url, c.api_key)
    if err then return toast(_("Could not list decks") .. ": " .. err, 4) end
    local options = {}
    for _i, d in ipairs(decks or {}) do
        options[#options + 1] = { text = d, value = d }
    end
    options[#options + 1] = { text = _("+ Create new deck…"), action = function()
        local dlg
        dlg = InputDialog:new{
            title = _("New deck (:: for subdecks)"),
            input = "", input_hint = "Language::English",
            buttons = { {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
                { text = _("Create"), callback = function()
                    local name = dlg:getInputText()
                    UIManager:close(dlg)
                    if name ~= "" then
                        AnkiConnect.create_deck(c.url, c.api_key, name)
                        nav.on_done(name)
                    end
                end },
            } },
        }
        UIManager:show(dlg); if dlg.onShowKeyboard then dlg:onShowKeyboard() end
    end }
    select_one(_("Deck"), options, current, nav) -- current nil = nothing pre-checked
end

------------------------------------------------------------ languages --------

function E.languages(target, native, doc_lang, ui_lang, nav)
    local dialog
    local function close() UIManager:close(dialog) end
    local next_btn = { text = _("Next"), callback = function()
        local f = dialog:getFields()
        close(); nav.on_done(f[1], f[2])
    end }
    dialog = MultiInputDialog:new{
        title = _("Languages"),
        fields = {
            { text = (target and target ~= "") and target or (doc_lang or ""),
              description = _("Target language (from the book)"), hint = "en" },
            { text = (native and native ~= "") and native or (ui_lang or ""),
              description = _("Native language"), hint = "de" },
        },
        buttons = { nav_row(nav, close, { next_btn }) },
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then dialog:onShowKeyboard() end
end

--------------------------------------------------------- dictionary role -----

-- pick a dictionary for a role (front/back), from enabled dicts + "None".
-- `current` nil = nothing pre-checked (must choose); "" = None pre-checked.
function E.dictionary(title, current, ui, nav)
    local names = compat.dict.enabled_names(ui)
    if #names == 0 then toast(_("No dictionaries enabled in KOReader."), 4) end
    local options = { { text = _("— None —"), value = "" } }
    for _i, name in ipairs(names or {}) do
        options[#options + 1] = { text = name, value = name }
    end
    select_one(title, options, current, nav)
end

----------------------------------------------------------------- tags --------

-- auto-tag + comma palette only; on_done(auto, palette_list)
function E.tags(auto, palette_list, nav)
    local dialog
    local function close() UIManager:close(dialog) end
    local next_btn = { text = _("Next"), callback = function()
        local f = dialog:getFields()
        close()
        nav.on_done(f[1], split_tags(f[2]))
    end }
    dialog = MultiInputDialog:new{
        title = _("Tags"),
        fields = {
            { text = auto or "", description = _("Auto-tag (blank = none)"), hint = "KOReader" },
            { text = table.concat(palette_list or {}, ", "),
              description = _("Tag palette, comma-separated"), hint = "idiom, hard" },
        },
        buttons = { nav_row(nav, close, { next_btn }) },
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then dialog:onShowKeyboard() end
end

-- source (book:<title>) tag on/off; on_done(bool)
function E.source_tag(source_bool, nav)
    local cur = source_bool
    if cur == nil then cur = false end -- sensible default: No
    select_one(_("Add a book:<title> tag?"), {
        { text = _("No"), value = false },
        { text = _("Yes — tag each card with its book"), value = true },
    }, cur, nav)
end

E.split_tags = split_tags
return E
