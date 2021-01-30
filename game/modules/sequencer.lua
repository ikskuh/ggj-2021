local module = { }
local TYPE = require("modules/type")

function module.create(bpm, theme, sequence)
  local seq = {
    [TYPE] = TYPE.sequencer,
    bpm = tonumber(bpm) or error("missing bpm"),
    theme = theme or error("missing theme"),
    sequence = sequence or error("missing sequence"),
    index = 1,
    time = 0,
  }

  function seq:invokeCallback(cb, ...)
    if self[cb] then
      return self[cb](...)
    else
      print("callback", cb, "not found!")
    end
  end

  function seq:nextNote()
    self.time = 0
    if self.index > 0 then
      self:invokeCallback("onNoteEnd", self.sequence[self.index], self.index)
    end
    self.index = self.index + 1
    if self.index <= #self.sequence then
      local cell = self.sequence[self.index]
      if cell.note then
        self.theme.notes[cell.note]:stop()
        self.theme.notes[cell.note]:play()
      end
      self:invokeCallback("onNote", cell, self.index)
    end
  end

  function seq:start()
    self.index = 0
    self:nextNote()
  end

  function seq:update(dt)
    if self:isDone() then
      return 
    end
    local len = self.sequence[self.index].len or 1
    if self.time >= len * 60 / self.bpm then
      if self.index < #self.sequence then
        self:nextNote()
      else
        self:invokeCallback("onNoteEnd", self.sequence[self.index], self.index)
        self.index = self.index + 1
      end
    else
      self.time = self.time + dt
    end
  end

  function seq:isDone()
    return self.index > #self.sequence
  end

  return seq
end


return module