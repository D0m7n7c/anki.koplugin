-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Card type registry. Ships one type ("offline"); more can be added as modules.
local registry = {
    offline = require("cardtypes/offline"),
}
local M = {}
function M.get(id) return registry[id] or registry.offline end
function M.default() return registry.offline end
return M
