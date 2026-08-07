-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
Anki — create Anki cards from KOReader dictionary look-ups.

Fork of Ajatt-Tools/anki.koplugin, largely rewritten (see README).

Tap "Add to Anki" in the dictionary pop-up → tag dialog → offline queue.
The active profile is chosen per book (auto by document language, with a manual
"Profile for this book" override). The AnkiConnect connection is global.
Sync sends queued notes to Anki, enriching them with translations + audio.
]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local compat = require("koreader_compat")
local Profiles = require("profiles")
local NoteBuilder = require("note_builder")
local NoteType = require("note_type")
local AnkiConnect = require("ankiconnect")
local cardtypes = require("cardtypes/init")
local TagDialog = require("ui/tag_dialog")
local Queue = require("queue")
local Sync = require("sync")
local Setup = require("ui/setup")
local Wizard = require("ui/wizard")
local Manage = require("ui/manage")

local BUTTON = {
    id = "anki_add",
    text = _("Add to Anki"),
    menu_text = _("Add to Anki"),
}

local Anki = WidgetContainer:extend{
    name = "anki",
    is_doc_only = true,
}

--- Handle a press of the "Add to Anki" button in the dictionary pop-up.
function Anki:on_add(dict_popup)
    local profile = self.profiles:effective(self.ui)
    if not profile then
        return compat.ui.toast(_("No profile yet. Create one via Anki settings → New profile."), 4)
    end

    local note = NoteBuilder.build(self.ui, dict_popup, profile)

    -- tag palette = auto-tag (pre-selected) + custom tags
    local palette, preselected = {}, {}
    if profile.auto_tag and profile.auto_tag ~= "" then
        table.insert(palette, profile.auto_tag)
        preselected[profile.auto_tag] = true
    end
    for _i, t in ipairs(profile.custom_tags or {}) do
        if t ~= profile.auto_tag then table.insert(palette, t) end
    end

    TagDialog.show({
        palette = palette,
        preselected = preselected,
        on_add = function(chosen)
            note.tags = chosen
            for _i, t in ipairs(note.extra_tags or {}) do
                table.insert(note.tags, t)
            end
            local ok, count = Queue.add(note)
            if ok then
                compat.ui.toast(_("Saved to queue") .. " (" .. count .. ")")
            else
                compat.ui.toast(_("Could not save note"))
            end
        end,
        -- on_cancel: discard entirely (nothing queued)
    })
end

function Anki:init()
    self.profiles = Profiles:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    self._has_new_dict_api = compat.dict.has_new_api(self.ui)
    self._registered = false
end

function Anki:onReaderReady()
    if self._has_new_dict_api and not self._registered and self.ui and self.ui.dictionary then
        compat.dict.register(self.ui, {
            id = BUTTON.id,
            text = BUTTON.text,
            menu_text = BUTTON.menu_text,
            on_press = function(dict_popup) self:on_add(dict_popup) end,
        })
        self._registered = true
    end
end

--- Legacy dict-popup hook for KOReader builds without addToDictButtons.
function Anki:onDictButtonsReady(dict_popup, buttons)
    if self._has_new_dict_api then return end
    table.insert(buttons, {
        compat.dict.legacy_button(dict_popup, {
            id = BUTTON.id,
            text = BUTTON.text,
            on_press = function(dp) self:on_add(dp) end,
        }),
    })
end

--- Run a sync of the offline queue and report the outcome.
function Anki:do_sync()
    local profile = self.profiles:effective(self.ui)
    if not profile then
        return compat.ui.toast(_("No profile yet. Create one via Anki settings → New profile."), 4)
    end
    local synced, failed, err, needs_setup = Sync.run(profile)
    if needs_setup then
        return self:prompt_setup(profile)
    end
    local msg
    if synced == 0 and failed > 0 and err then
        msg = _("Sync failed") .. ":\n" .. err
    else
        msg = ("%d synced, %d pending"):format(synced, failed)
        if err then msg = msg .. "\n" .. err end
    end
    compat.ui.toast(msg, 3)
end

--- Reactive prompt when the note type and/or deck don't exist in Anki yet.
function Anki:prompt_setup(profile)
    local missing_model, missing_deck = Setup.check_missing(profile)
    local parts = {}
    if missing_deck then parts[#parts + 1] = _("the deck") .. ' "' .. profile.deck .. '"' end
    if missing_model then parts[#parts + 1] = _("the note type") .. ' "' .. profile.note_type .. '"' end
    if #parts == 0 then parts = { _("the deck and note type") } end -- fallback
    local subject = table.concat(parts, " " .. _("and") .. " ")
    local plural = #parts > 1
    local msg = subject .. " " ..
        (plural and _("don't exist in the connected Anki yet.") or _("doesn't exist in the connected Anki yet.")) ..
        "\n\n" ..
        (plural and _("Create them and continue syncing?") or _("Create it and continue syncing?"))

    UIManager:show(ConfirmBox:new{
        text = msg,
        ok_text = _("Create and sync"),
        cancel_text = _("Not now"),
        ok_callback = function() self:create_and_sync(profile) end,
    })
end

--- Create the deck + note type, then sync. On a note-type field conflict, show
--- an error (the user must rename/delete the note type in Anki) and stop.
function Anki:create_and_sync(profile)
    local cardtype = cardtypes.get(profile.card_type)
    AnkiConnect.create_deck(profile.url, profile.api_key, profile.deck) -- idempotent

    local status, detail = NoteType.status(profile.url, profile.api_key, cardtype)
    if status == "missing" then
        local ok, err = NoteType.create(profile.url, profile.api_key, cardtype)
        if not ok then
            return compat.ui.toast(_("Note type error") .. ":\n" .. tostring(err), 6)
        end
    elseif status == "conflict" then
        local dialog
        dialog = ButtonDialog:new{
            title = string.format(_(
                "The note type “%s” already exists in Anki with different fields.\n\n" ..
                "Please rename or delete it in Anki, then sync again."), cardtype.note_type),
            title_align = "left",
            buttons = { { { text = _("Cancel"),
                callback = function() UIManager:close(dialog) end } } },
        }
        return UIManager:show(dialog)
    elseif status == "error" then
        return compat.ui.toast(_("Note type error") .. ":\n" .. tostring(detail), 6)
    end

    self:do_sync()
end

--- Let the user pick which profile applies to the current book.
function Anki:choose_book_profile()
    compat.ui.safe("choose_book_profile", function()
        local names = self.profiles:names()
        if #names == 0 then
            return compat.ui.toast(_("No profiles yet. Create one via New profile."), 4)
        end
        local dialog
        local rows = {}
        for _i, name in ipairs(names) do
            rows[#rows + 1] = { { text = name, callback = function()
                compat.ui.safe("set_book_profile", function()
                    UIManager:close(dialog)
                    self.profiles:set_book_profile(self.ui, name)
                    compat.ui.toast(_("Profile for this book") .. ": " .. name)
                end)
            end } }
        end
        rows[#rows + 1] = { { text = _("Cancel"), callback = function() UIManager:close(dialog) end } }
        dialog = ButtonDialog:new{
            title = _("Profile for this book"),
            title_align = "center",
            buttons = rows,
        }
        UIManager:show(dialog)
    end)
end

--- Anki menu: global connection, new profile, per-book profile, sync.
function Anki:addToMainMenu(menu_items)
    local profiles = self.profiles
    menu_items.anki = {
        text = _("Anki settings"),
        sorting_hint = "search_settings",
        sub_item_table = {
            {
                text = _("AnkiConnect settings"),
                keep_menu_open = true,
                callback = function() Setup.edit_connection(profiles) end,
            },
            {
                text = _("New profile"),
                keep_menu_open = true,
                callback = function() Wizard.start(profiles, self.ui) end,
            },
            {
                text = _("Manage profiles"),
                keep_menu_open = true,
                callback = function() Manage.list(profiles, self.ui) end,
            },
            {
                text_func = function()
                    local ok, name = pcall(function()
                        return profiles:active_name(self.ui)
                    end)
                    return _("Profile for this book") .. ": " ..
                        (ok and (name or "—") or "!")
                end,
                keep_menu_open = true,
                callback = function() self:choose_book_profile() end,
            },
            {
                text_func = function()
                    return _("Sync now") .. " (" .. Queue.count() .. ")"
                end,
                keep_menu_open = true,
                callback = function() self:do_sync() end,
            },
        },
    }
end

return Anki
