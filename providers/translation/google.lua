-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
Translation provider: KOReader's built-in Translator (online Google endpoint).
Reused from the original plugin's approach.
  translate(text, to_lang, from_lang) -> string | nil
]]

local Translator = require("ui/translator")

return function(text, to_lang, from_lang)
    if not text or text == "" then return nil end
    local ok, res = pcall(function()
        return Translator:translate(text, to_lang, from_lang)
    end)
    if ok and type(res) == "string" and res ~= "" then
        return res
    end
    return nil
end
