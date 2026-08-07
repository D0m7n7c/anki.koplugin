-- luacheck configuration for the KOReader Anki plugin
std = "luajit"                        -- KOReader runs on LuaJIT (5.1 semantics)
globals = { "G_reader_settings" }     -- KOReader global settings object
read_globals = { "utf8" }
max_line_length = false

ignore = {
  "212",  -- unused argument (KOReader callbacks pass args we don't always use)
  "213",  -- unused loop variable
  "231",  -- variable never accessed
  "311",  -- value assigned to a local variable is unused (early returns)
  "542",  -- empty if branch
}

-- busted test globals
files["spec/"] = { std = "+busted" }
