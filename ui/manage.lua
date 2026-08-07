-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
manage — "Manage profiles": list, direct-edit, rename, delete.

Direct-edit reuses the same editors as the wizard, but each field is edited
on its own and saved immediately (no step chaining). Deleting a profile also
removes any book overrides pointing to it (handled in profiles.lua).
]]

local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local compat = require("koreader_compat")
local E = require("ui/editors")

local Manage = {}

local function update(profiles, name, updates)
    local data = profiles:get_profile(name) or {}
    for k, v in pairs(updates) do data[k] = v end
    profiles:save_profile(name, data)
end


--- The per-profile direct-edit menu.
function Manage.edit(profiles, ui, name)
    local d = profiles:get_profile(name)
    if not d then return end
    local reopen = function() Manage.edit(profiles, ui, name) end

    local rows = {}
    local function item(text, on_pick)
        rows[#rows + 1] = { { text = text, callback = function() on_pick() end } }
    end

    item(_("Deck") .. ": " .. tostring(d.deck or "—"), function()
        E.deck(profiles, d.deck, {
            on_done = function(deck) update(profiles, name, { deck = deck }); reopen() end,
            on_cancel = reopen })
    end)
    item(_("Languages") .. ": " .. tostring(d.target_lang) .. " → " .. tostring(d.native_lang), function()
        E.languages(d.target_lang, d.native_lang, nil, nil, {
            on_done = function(t, n)
                update(profiles, name, { target_lang = t, native_lang = n }); reopen()
            end, on_cancel = reopen })
    end)
    item(_("Front dictionary") .. ": " .. (d.front_dict ~= "" and d.front_dict or "—"), function()
        E.dictionary(_("Front dictionary (monolingual, target language)"), d.front_dict, ui, {
            on_done = function(dict) update(profiles, name, { front_dict = dict }); reopen() end,
            on_cancel = reopen })
    end)
    item(_("Back dictionary") .. ": " .. (d.back_dict ~= "" and d.back_dict or "—"), function()
        E.dictionary(_("Back dictionary (bilingual, target → native)"), d.back_dict, ui, {
            on_done = function(dict) update(profiles, name, { back_dict = dict }); reopen() end,
            on_cancel = reopen })
    end)
    item(_("Tags") .. ": " .. (#(d.custom_tags or {}) > 0
        and table.concat(d.custom_tags, ", ") or (d.auto_tag or "—")), function()
        local function edit_tags(a, p)
            E.tags(a, p, {
                on_done = function(auto, palette)
                    E.source_tag(d.source_tag_enabled, {
                        on_done = function(source)
                            update(profiles, name, { auto_tag = auto, custom_tags = palette,
                                source_tag_enabled = source })
                            reopen()
                        end,
                        on_back = function() edit_tags(auto, palette) end,
                        on_cancel = reopen })
                end,
                on_cancel = reopen })
        end
        edit_tags(d.auto_tag, d.custom_tags)
    end)
    item(_("Rename"), function()
        E.name(profiles, name, name, _("Rename profile"), {
            on_done = function(newname)
                if newname ~= name then profiles:rename_profile(name, newname) end
                Manage.edit(profiles, ui, newname)
            end, on_cancel = reopen })
    end)
    item(_("Delete"), function()
        local dlg
        dlg = ButtonDialog:new{
            title = _("Delete profile") .. " “" .. name .. "”?",
            title_align = "center",
            buttons = {
                { { text = _("Delete"), callback = function()
                    UIManager:close(dlg)
                    profiles:delete_profile(name)
                    compat.ui.toast(_("Deleted") .. ": " .. name)
                    Manage.list(profiles, ui)
                end } },
                { { text = _("Cancel"), callback = function() UIManager:close(dlg); reopen() end } },
            },
        }
        UIManager:show(dlg)
    end)

    rows[#rows + 1] = { { text = _("Back"), callback = function() Manage.list(profiles, ui) end } }

    local dialog
    for _i, r in ipairs(rows) do
        local cb = r[1].callback
        r[1].callback = function() UIManager:close(dialog); cb() end
    end
    dialog = ButtonDialog:new{
        title = _("Edit profile") .. ": " .. name,
        title_align = "center",
        buttons = rows,
    }
    UIManager:show(dialog)
end

--- The profile list.
function Manage.list(profiles, ui)
    local names = profiles:names()
    if #names == 0 then
        return compat.ui.toast(_("No profiles yet. Create one via New profile."), 4)
    end
    local dialog
    local rows = {}
    for _i, name in ipairs(names) do
        rows[#rows + 1] = { { text = name, callback = function()
            UIManager:close(dialog); Manage.edit(profiles, ui, name)
        end } }
    end
    rows[#rows + 1] = { { text = _("Cancel"), callback = function() UIManager:close(dialog) end } }
    dialog = ButtonDialog:new{
        title = _("Manage profiles"),
        title_align = "center",
        buttons = rows,
    }
    UIManager:show(dialog)
end

return Manage
