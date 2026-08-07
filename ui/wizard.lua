-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
wizard — the "New profile" assistant: a driver over the reusable editors.

Steps are an ordered list; each step calls an editor with a nav table:
  on_done  → advance to the next step (saving into ctx.data/ctx.name)
  on_back  → previous step (values preserved in ctx)
  on_cancel→ confirm discard (only once something was entered)
The connection step is included only if no global connection is saved yet.
]]

local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local compat = require("koreader_compat")
local E = require("ui/editors")
local cardtypes = require("cardtypes/init")

local Wizard = {}

-- each step: function(ctx, nav, advance) that opens an editor
local function step_name(ctx, nav, advance)
    E.name(ctx.profiles, ctx.name, nil, _("New profile — name"), {
        on_done = function(name) ctx.name = name; ctx.dirty = true; advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_connection(ctx, nav, advance)
    E.connection(ctx.profiles, {
        on_done = function() advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_deck(ctx, nav, advance)
    E.deck(ctx.profiles, ctx.data.deck, {
        on_done = function(deck) ctx.data.deck = deck; advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_languages(ctx, nav, advance)
    E.languages(ctx.data.target_lang, ctx.data.native_lang, ctx.doc_lang, ctx.ui_lang, {
        on_done = function(t, n)
            ctx.data.target_lang = t; ctx.data.native_lang = n; advance()
        end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_front_dict(ctx, nav, advance)
    E.dictionary(_("Front dictionary (typically monolingual, target language)"),
        ctx.data.front_dict, ctx.ui, {
        on_done = function(name) ctx.data.front_dict = name; advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_back_dict(ctx, nav, advance)
    E.dictionary(_("Back dictionary (typically bilingual, target → native)"),
        ctx.data.back_dict, ctx.ui, {
        on_done = function(name) ctx.data.back_dict = name; advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_tags(ctx, nav, advance)
    E.tags(ctx.data.auto_tag, ctx.data.custom_tags, {
        on_done = function(auto, palette)
            ctx.data.auto_tag = auto
            ctx.data.custom_tags = palette
            advance()
        end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

local function step_source_tag(ctx, nav, advance)
    E.source_tag(ctx.data.source_tag_enabled, {
        on_done = function(source) ctx.data.source_tag_enabled = source; advance() end,
        on_back = nav.on_back, on_cancel = nav.on_cancel,
    })
end

function Wizard.show_step(ctx, idx)
    if idx < 1 then return end
    if idx > #ctx.steps then return Wizard.finish(ctx) end
    ctx.idx = idx
    local nav = {
        on_back = (idx > 1) and function() Wizard.show_step(ctx, idx - 1) end or nil,
        on_cancel = function() Wizard.confirm_cancel(ctx) end,
    }
    ctx.steps[idx](ctx, nav, function() Wizard.show_step(ctx, idx + 1) end)
end

function Wizard.confirm_cancel(ctx)
    if not ctx.dirty and not ctx.name then return end -- nothing entered
    local dialog
    dialog = ButtonDialog:new{
        title = _("Discard this profile?"),
        title_align = "center",
        buttons = {
            { { text = _("Keep editing"), callback = function()
                UIManager:close(dialog); Wizard.show_step(ctx, ctx.idx)
            end } },
            { { text = _("Discard"), callback = function()
                UIManager:close(dialog)
            end } },
        },
    }
    UIManager:show(dialog)
end

function Wizard.finish(ctx)
    ctx.profiles:save_profile(ctx.name, ctx.data)
    ctx.profiles:set_book_profile(ctx.ui, ctx.name)
    local d = ctx.data
    local palette = (#(d.custom_tags or {}) > 0) and table.concat(d.custom_tags, ", ") or _("none")
    local summary = table.concat({
        _("Profile created:") .. " " .. ctx.name,
        _("Deck") .. ": " .. tostring(d.deck),
        _("Languages") .. ": " .. tostring(d.target_lang) .. " → " .. tostring(d.native_lang),
        _("Front dictionary") .. ": " .. (d.front_dict ~= "" and d.front_dict or _("none")),
        _("Back dictionary") .. ": " .. (d.back_dict ~= "" and d.back_dict or _("none")),
        _("Tags") .. ": " .. palette,
    }, "\n")
    local dialog
    dialog = ButtonDialog:new{
        title = summary, title_align = "left",
        buttons = { { { text = _("Done"), callback = function()
            UIManager:close(dialog); compat.ui.toast(_("Profile created successfully."), 2)
        end } } },
    }
    UIManager:show(dialog)
end

function Wizard.start(profiles, ui)
    local ctx = { profiles = profiles, ui = ui, data = {}, dirty = false }
    -- card type is fixed for now (offline); recorded so sync/create know it
    ctx.data.card_type = cardtypes.default().id
    ctx.data.note_type = cardtypes.default().note_type
    ctx.doc_lang = compat.doc.language(ui)
    ctx.ui_lang = compat.doc.ui_language()
    local steps = { step_name }
    if not profiles:has_connection() then steps[#steps + 1] = step_connection end
    for _i, s in ipairs({ step_deck, step_languages, step_front_dict,
                          step_back_dict, step_tags, step_source_tag }) do
        steps[#steps + 1] = s
    end
    ctx.steps = steps
    Wizard.show_step(ctx, 1)
end

return Wizard
