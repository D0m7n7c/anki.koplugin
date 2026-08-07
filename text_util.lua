-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
text_util — pure text processing. No KOReader APIs here.
  * html_to_text   : strip tags + unescape entities
  * clean_definition: turn a raw dictionary entry into card-ready text
  * core_sentence  : trim raw before/after context down to the single
                     sentence containing the word
]]

local util = require("util")

local M = {}

local ENTITIES = {
    ["&amp;"] = "&", ["&lt;"] = "<", ["&gt;"] = ">",
    ["&quot;"] = '"', ["&#39;"] = "'", ["&apos;"] = "'", ["&nbsp;"] = " ",
}

--- Strip HTML tags and unescape the common entities.
function M.html_to_text(s)
    if not s or s == "" then return "" end
    s = s:gsub("<%s*br%s*/?>", "\n")
    s = s:gsub("<[^>]+>", " ")
    s = s:gsub("&#?%w+;", function(e) return ENTITIES[e] or e end)
    s = s:gsub("[ \t]+", " ")
    s = s:gsub(" *\n *", "\n")
    s = s:gsub("\n\n+", "\n")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Raw dictionary entry -> HTML, kept as-is so Anki renders it.
-- Mirrors the upstream behaviour: keep HTML entries (best-effort tag the first
-- <div> with the dict name), wrap plain-text entries' newlines as <br>.
function M.definition_html(raw, is_html, dict_name)
    if not raw or raw == "" then return "" end
    if is_html then
        if dict_name and dict_name ~= "" then
            local tagged, n = raw:gsub("(<div)( ?)",
                string.format('%%1 dict="%s"%%2', dict_name), 1)
            if n > 0 then return tagged end
        end
        return raw
    end
    return (raw:gsub("\n", "<br>"))
end

-- Sentence-terminating characters (Latin + CJK), from the upstream plugin.
local DELIMS = {}
for _i, ch in ipairs(util.splitToChars("？」。.?!！")) do DELIMS[ch] = true end
local SKIP = { ["\n"] = true, ["\r"] = true }

--- Trim raw prev/next context down to the sentence containing `word`.
-- Returns the core sentence with the word wrapped in <b>…</b>.
function M.core_sentence(prev_text, next_text, word)
    local prev = util.splitToChars(prev_text or "")
    local next_ = util.splitToChars(next_text or "")

    -- walk backwards until a delimiter -> start of current sentence
    local pstart = #prev + 1
    for i = #prev, 1, -1 do
        local ch = prev[i]
        if SKIP[ch] then break end
        if DELIMS[ch] then break end
        pstart = i
    end
    local before = table.concat(prev, "", pstart, #prev)

    -- walk forwards, include up to and including the first delimiter
    local pend = 0
    for i = 1, #next_ do
        local ch = next_[i]
        if SKIP[ch] then break end
        pend = i
        if DELIMS[ch] then break end
    end
    local after = table.concat(next_, "", 1, pend)

    -- restore spacing lost at the word boundary. Add a space between `before`
    -- and the word unless `before` ends with whitespace or an opening
    -- bracket/quote/hyphen; add one after the word unless `after` starts with
    -- whitespace or attaching punctuation (comma, period, closing bracket…).
    -- Leaves CJK (no such punctuation at the boundary) mostly untouched.
    if #before > 0 and not before:sub(-1):match([=[[%s%(%[{"'«„%-]]=]) then
        before = before .. " "
    end
    if #after > 0 and not after:sub(1, 1):match([=[[%s,;:%.!?%)%]}"'»“]]=]) then
        after = " " .. after
    end

    local sentence = before .. "<b>" .. (word or "") .. "</b>" .. after
    return (sentence:gsub("^%s+", ""):gsub("%s+$", ""))
end

return M
