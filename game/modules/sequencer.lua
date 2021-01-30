local module = { }

function module.create(bpm, theme, sequence)
  local seq = {
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

  function seq:start()
    self.index = 1
    self.time = 0

    local cell = self.sequence[self.index]
    cell.active = true
    if cell.note then
      self.theme.notes[cell.note]:play()
    end
    self:invokeCallback("onNote", cell, self.index)
  end

  function seq:update(dt)
    if self:isDone() then
      return 
    end
    if self.time >= 60 / self.bpm then
      if self.index < #self.sequence then
        self.time = 0
        self.sequence[self.index].active = false
        self.index = self.index + 1
        local cell = self.sequence[self.index]
        cell.active = true
        if cell.note then
          self.theme.notes[cell.note]:stop()
          self.theme.notes[cell.note]:play()
        end
        self:invokeCallback("onNote", cell, self.index)
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