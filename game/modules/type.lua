local typecheck = require "modules/typecheck"

return typecheck.create(
  -- main types  
  "theme", "map", "cell",
  -- hex coordinates  
  "point", "cube", "hex", "offset",
  -- sequencer
  "sequencer", "note"
)