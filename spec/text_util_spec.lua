-- Tests for sentence extraction / spacing. Stubs KOReader's "util".
package.path = "./?.lua;./?/init.lua;" .. package.path
package.loaded["util"] = {
  -- UTF-8 aware split that works on any Lua (no utf8 library needed)
  splitToChars = function(s)
    local t = {}
    for c in (s or ""):gmatch("[\1-\127\194-\244][\128-\191]*") do t[#t + 1] = c end
    return t
  end,
}
local tu = require("text_util")

describe("text_util.core_sentence", function()
  it("restores the space after a comma before the word", function()
    local s = tu.core_sentence("Extreme positions in sociology,", " to which", "according")
    assert.are.equal("Extreme positions in sociology, <b>according</b> to which", s)
  end)

  it("restores the space at a letter boundary", function()
    local s = tu.core_sentence("opposite position of", "collectivism.", "methodological")
    assert.are.equal("opposite position of <b>methodological</b> collectivism.", s)
  end)

  it("keeps a comma attached to the word (no space before it)", function()
    local s = tu.core_sentence("I like", ", and more.", "reading")
    assert.are.equal("I like <b>reading</b>, and more.", s)
  end)
end)

describe("text_util.html_to_text", function()
  it("strips tags", function()
    assert.are.equal("hello world", tu.html_to_text("<b>hello</b> world"))
  end)
end)
