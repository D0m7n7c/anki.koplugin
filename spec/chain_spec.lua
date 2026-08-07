-- Tests for the provider fallback chain.
package.path = "./?.lua;./?/init.lua;" .. package.path
local chain = require("providers.chain")

describe("providers/chain run()", function()
  it("returns the first non-empty result", function()
    local ok, res = chain.run({ function() return nil end, function() return "hi" end })
    assert.is_true(ok); assert.are.equal("hi", res)
  end)

  it("caches by key", function()
    local cache, calls = {}, 0
    local p = function() calls = calls + 1; return "x" end
    chain.run({ p }, cache, "k"); chain.run({ p }, cache, "k")
    assert.are.equal(1, calls)
  end)

  it("returns false when all providers fail", function()
    local ok = chain.run({ function() return nil end })
    assert.is_false(ok)
  end)
end)
