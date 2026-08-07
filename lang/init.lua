-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
lang — optional per-language post-processing hooks.
Passthrough by default. A language module can transform the captured word,
sentence, or definition (e.g. de-inflection, script handling) before queuing.
]]

local Lang = {}

--- Return a processor for `lang_code`, or a passthrough.
function Lang.for_code(lang_code)  -- luacheck: ignore lang_code
    return {
        process = function(note) return note end,
    }
end

return Lang
