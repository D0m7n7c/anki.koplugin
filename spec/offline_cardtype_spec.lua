-- Tests for the offline card type's populate() logic (pure, no KOReader deps).
package.path = "./?.lua;./?/init.lua;" .. package.path
local offline = require("cardtypes.offline")

describe("cardtypes/offline populate()", function()
  it("uses the real entries when both are found", function()
    local f, tags = offline.populate({
      word = "run", sentence = "I <b>run</b>.",
      front_def = "<div>to move fast</div>", back_def = "<div>rennen</div>",
      front_dict = "EN", back_dict = "EN-DE",
      front_assigned = true, back_assigned = true,
      front_found = true, back_found = true,
    })
    assert.are.equal("run", f.Word)
    assert.are.equal("<div>to move fast</div>", f.FrontDefinition)
    assert.are.equal("<div>rennen</div>", f.BackDefinition)
    assert.are.equal(0, #tags)
  end)

  it("shows a placeholder and tags when an assigned dict has no entry", function()
    local f, tags = offline.populate({
      word = "x", sentence = "s",
      front_dict = "EN", front_assigned = true, front_found = false,
      back_assigned = false, back_found = false,
    })
    assert.are.equal("[no entry in EN]", f.FrontDefinition)
    assert.are.equal("[no dictionary assigned]", f.BackDefinition)
    assert.are.equal("no-dict-entry", tags[1])
  end)
end)
