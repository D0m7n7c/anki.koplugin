-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
tag_dialog — the dialog shown after tapping "Add to Anki".

Pure tap interaction, no keyboard: toggle tags from the profile palette,
then Add or Cancel. Cancel discards the note entirely (nothing is queued).
The auto-tag (if set) is pre-selected. The dialog always appears — even with
an empty palette — so Cancel is always available (our replacement for an undo).

ButtonDialog has no "update buttons" call, so a toggle rebuilds the dialog.
]]

local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local TagDialog = {}

--- @param opts { palette=list, preselected=set, on_add=function(chosen), on_cancel=function()? , title=string? }
function TagDialog.show(opts)
    local palette = opts.palette or {}
    local selected = {}
    for tag, on in pairs(opts.preselected or {}) do selected[tag] = on end

    local dialog

    local function chosen_list()
        local out = {}
        for _i, tag in ipairs(palette) do
            if selected[tag] then out[#out + 1] = tag end
        end
        return out
    end

    local function build()
        local rows = {}
        for _i, tag in ipairs(palette) do
            local mark = selected[tag] and "[x] " or "[ ] "
            rows[#rows + 1] = { {
                text = mark .. tag,
                callback = function()
                    selected[tag] = not selected[tag]
                    UIManager:close(dialog)
                    build()
                end,
            } }
        end
        rows[#rows + 1] = {
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    if opts.on_cancel then opts.on_cancel() end
                end,
            },
            {
                text = _("Add"),
                callback = function()
                    UIManager:close(dialog)
                    opts.on_add(chosen_list())
                end,
            },
        }
        dialog = ButtonDialog:new{
            title = opts.title or _("Add to Anki"),
            title_align = "center",
            buttons = rows,
        }
        UIManager:show(dialog)
    end

    build()
end

return TagDialog
