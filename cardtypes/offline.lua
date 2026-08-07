-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
Card type: "offline" — the zero-dependency foundation card.

Front: sentence (with the marked word) + the Front dictionary entry.
Back:  the Back dictionary entry.
Everything is captured offline from local dictionaries; no translation, no audio.

populate(src) fills the Anki fields and returns any extra tags. Three cases per
dictionary field:
  * assigned + found        → the real HTML entry
  * assigned + not found    → "[no entry in <dict>]"  (+ tag "no-dict-entry")
  * not assigned            → "[no dictionary assigned]"
]]

local M = {}

M.id = "offline"
M.note_type = "KOReader Offline"
M.fields = { "Word", "Sentence", "FrontDefinition", "BackDefinition" }

M.front = [[
<div class="sentence">{{Sentence}}</div>
<hr>
<div class="front-def">{{FrontDefinition}}</div>
]]

M.back = [[
{{FrontSide}}
<hr id="answer">
<div class="back-def">{{BackDefinition}}</div>
]]

M.css = [[
.card { font-family: serif; font-size: 20px; color: black; background: white; text-align: left; }
.sentence { font-size: 22px; margin-bottom: 10px; }
.sentence b { font-weight: bold; }
.front-def { color: #333; }
.back-def { color: #222; }
]]

local function entry(assigned, found, html, dict_name)
    if not assigned then return "[no dictionary assigned]" end
    if not found then return "[no entry in " .. (dict_name or "?") .. "]" end
    return html or ""
end

--- @param src table with word, sentence, front/back _def/_dict/_assigned/_found
--- @return fields_table, extra_tags
function M.populate(src)
    local fields = {
        Word = src.word or "",
        Sentence = src.sentence or "",
        FrontDefinition = entry(src.front_assigned, src.front_found, src.front_def, src.front_dict),
        BackDefinition = entry(src.back_assigned, src.back_found, src.back_def, src.back_dict),
    }
    local tags = {}
    if (src.front_assigned and not src.front_found)
        or (src.back_assigned and not src.back_found) then
        tags[#tags + 1] = "no-dict-entry"
    end
    return fields, tags
end

return M
