local module = { }
local TYPE = require("modules/type")

function module.create(theme, sequence)
  local seq = {
    [TYPE] = TYPE.sequencer,
    bpm = tonumber(theme.track.bpm) or error("missing bpm"),
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

  function seq:stopCurrent()
  
    if self.index > 0 then
      local cell = self.sequence[self.index]
      if cell.note then
        self.theme.notes[cell.note]:stop()
      end
      self:invokeCallback("onNoteEnd", self.sequence[self.index], self.index)
    end
  end

  function seq:nextNote()
    self:stopCurrent()
    self.time = 0
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

  function seq:stop()
    if self.index > 0 then
      self:stopCurrent()
    end
    self.index = #self.sequence + 1
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