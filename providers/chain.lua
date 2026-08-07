-- SPDX-License-Identifier: AGPL-3.0-or-later
--[[
chain — run providers in order until one returns a usable result.
Each provider is a function(...) -> result | nil. First non-empty wins.
An optional cache (table) keyed by `key` avoids fetching the same thing twice.
]]

local M = {}

--- @return ok(boolean), result
function M.run(providers, cache, key, ...)
    if cache and key and cache[key] ~= nil then
        return true, cache[key]
    end
    for _i, provider in ipairs(providers) do
        local ok, res = pcall(provider, ...)
        if ok and res ~= nil and res ~= "" then
            if cache and key then cache[key] = res end
            return true, res
        end
    end
    return false, nil
end

return M
