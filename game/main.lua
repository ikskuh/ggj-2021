
require "modules/shims"
local hexagon = require "modules/hexagon"
local sequencer = require "modules/sequencer"
local TYPE = require "modules/type"

setmetatable(_G, {
  __index = function (t,k)
    error(tostring(k) .. " does not exist!")
  end,
  __newindex = function (t,k,v)
    error(tostring(k) .. " does not exist!")
  end,

})

local function loadTheme(name)
  local theme = {
    [TYPE] = TYPE.theme,
    notes = {
      [1] = love.audio.newSource("sounds/" .. name .. "/note-01.ogg", "static"),
      [2] = love.audio.newSource("sounds/" .. name .. "/note-02.ogg", "static"),
      [3] = love.audio.newSource("sounds/" .. name .. "/note-03.ogg", "static"),
      [4] = love.audio.newSource("sounds/" .. name .. "/note-04.ogg", "static"),
      [5] = love.audio.newSource("sounds/" .. name .. "/note-05.ogg", "static"),
      [6] = love.audio.newSource("sounds/" .. name .. "/note-06.ogg", "static"),
      [7] = love.audio.newSource("sounds/" .. name .. "/note-07.ogg", "static"),
    },

    graphics = {
      [1] = love.graphics.newImage("graphics/" .. name .. "/cell-01.png"),
      [2] = love.graphics.newImage("graphics/" .. name .. "/cell-02.png"),
      [3] = love.graphics.newImage("graphics/" .. name .. "/cell-03.png"),
      [4] = love.graphics.newImage("graphics/" .. name .. "/cell-04.png"),
      [5] = love.graphics.newImage("graphics/" .. name .. "/cell-05.png"),
      [6] = love.graphics.newImage("graphics/" .. name .. "/cell-06.png"),
      [7] = love.graphics.newImage("graphics/" .. name .. "/cell-07.png"),
    },
    
    backdrop = love.graphics.newImage("graphics/backdrops/" .. name .. ".png"),
    ambient = love.audio.newSource("music/ambient/" .. name .. ".ogg", "stream"),

    track = love.filesystem.load("tracks/" .. name .. ".lua")(),
  }

  for i=1,#theme.track do
    theme.track[i][TYPE] = TYPE.note
  end

  return theme
end

local function createMap(w, h)
  local map = {
    [TYPE] = TYPE.map,
    width = tonumber(w),
    height = tonumber(h),
    tiles = { },
    tile_size = 56,
  }

  for y=1,h do
    map.tiles[y] = {}
  end

  function map:validPos(x, y)
    return not (x < 1 or y < 1 or x > self.width or y > self.height)
  end

  function map:set(x, y, cell)

    x = tonumber(x) or error("x must be a number!")
    y = tonumber(y) or error("y must be a number!")
    TYPE:assert(cell, "cell", true)

    if not map:validPos(x, y) then
      error(tostring(x)..","..tostring(y).." is out of bounds!")
    end

    local row = self.tiles[y]
    if not row then
      row = { }
      self.tiles[y] = row
    end
    row[x] = cell

    if cell then
      cell.x = x
      cell.y = y
    end

    return cell
  end

  function map:get(x,y)
    local row = self.tiles[y]
    if row then
      return row[x]
    else
      return nil
    end
  end

  return map
end

local state = { }

local kbd = { pressed = {}, released = {} }
local mouse = { pressed = {}, released = {},x=0, y=0, dx=0, dy=0 }

local function createCell(note)
  TYPE:assert(note, "note", true)
  local cell = {
    [TYPE] = TYPE.cell,
    note = note,
    active = false,
    brightness = 0.0,
  }
  function cell:update(dt)
    local dst = self.active and 1 or 0
    self.brightness = math.lerp(self.brightness, dst, 0.15)
  end
  return cell
end

function love.load()

  love.math.setRandomSeed(love.timer.getTime())

  state.theme = loadTheme("meadow")
  state.theme.ambient:setVolume(0.5)
  state.theme.ambient:play()

  state.map = createMap(15, 6)

  for x=1,state.map.width-1 do
    for y=1,state.map.height do
      local n = love.math.random(7)-1
      local note = {[TYPE]=TYPE.note, len = love.math.random(6)}
      if n > 0 then
        note.note = n
      end
      state.map:set(x, y, createCell(note))
    end
  end

  do
    local seq = state.theme.track

    if #seq < state.map.width - 1 then
      error("sequence too short, min. 14 elements required!")
    end

    local prev_cell = nil
    local previous_pos = hexagon.OffsetCoord(0, 4)
    for i=1,#seq do

      local next = nil
      local tries = 0
      while true do
        next = hexagon.oddqOffsetNeighbor(previous_pos, love.math.random(2))
        if state.map:validPos(next.col, next.row) then
          break
        else
          tries = tries + 1
          if tries > 30 then
            error("failed to find a proper path")
          end
        end
      end

      previous_pos = next
      local cell = state.map:set(next.col, next.row, createCell(seq[i]))
      
      if prev_cell then
        prev_cell.next = cell
      end
      prev_cell = cell
    end
  end
  state.start_cell = createCell()
  state.start_cell.x = 0
  state.start_cell.y = 4
  state.start_cell.next = state.map:get(1,3)

  state.end_cells = { }
  do
    table.insert(state.end_cells, state.map:set(15,1,createCell()))
    table.insert(state.end_cells, state.map:set(15,2,createCell()))
    table.insert(state.end_cells, state.map:set(15,3,createCell()))
    table.insert(state.end_cells, state.map:set(15,4,createCell()))
    table.insert(state.end_cells, state.map:set(15,5,createCell()))
  end

  local active_cells = { state.start_cell }
  for x=1,state.map.width do
    for y=1,state.map.height do
      local cell = state.map:get(x,y)
      if cell then
        assert(cell.x, "cell is missing coordinate!")
        assert(cell.y, "cell is missing coordinate!")
        table.insert(active_cells, cell)
      end
    end
  end
  state.active_cells = active_cells

  state.bird = {
    frame = 1,
    x = 0,
    y = 0,
    cell = state.start_cell,
    love.graphics.newImage("graphics/bird/schwalbe1.png"),
    love.graphics.newImage("graphics/bird/schwalbe2.png"),
    love.graphics.newImage("graphics/bird/schwalbe3.png"),
    love.graphics.newImage("graphics/bird/schwalbe4.png"),
    love.graphics.newImage("graphics/bird/schwalbe5.png"),
    love.graphics.newImage("graphics/bird/schwalbe6.png"),
    love.graphics.newImage("graphics/bird/schwalbe7.png"),
    love.graphics.newImage("graphics/bird/schwalbe8.png"),
    love.graphics.newImage("graphics/bird/schwalbe9.png"),
  }

  state.scroll_offset = {
    x = 4,
    y = 0,
  }

  love.window.setMode(1280, 720, {
    vsync = true,
    msaa = 4,
    resizable = false,
    centered = true,
  })
end

local function structuralEqual(a, b)
  for k in pairs(a) do
    if a[k] ~= b[k] then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] ~= b[k] then
      return false
    end
  end
  return true
end

function love.update(dt)

  if kbd.pressed.escape then
    love.event.quit()
  elseif kbd.pressed.space then
    if state.start_cell.next then
      local iter = state.start_cell.next or error("no")
      local seq = { }
      while iter do
        if iter.note then
          iter.note.cell = iter
          seq[#seq + 1] = iter.note
        end
        iter = iter.next
      end
      
      state.sequence = sequencer.create(120, state.theme, seq)
      
      state.sequence.onNote = function(note, index)
        state.bird.cell = note.cell
        state.active_cell = note.cell
      end
      state.sequence.onNoteEnd = function(note, index)
        state.active_cell = nil
      end

      state.sequence:start()
    end
  end 


  -- Do mouse input
  do
    local mx, my = love.mouse.getPosition()

    local flat_hex = hexagon.pixelToFlatHex(hexagon.Point(mx - state.scroll_offset.x, my - state.scroll_offset.y), state.map.tile_size)

    local flat_oddq = hexagon.cubeToOddq(hexagon.cubeRound(hexagon.Cube(flat_hex.q, -flat_hex.q-flat_hex.r, flat_hex.r)))

    state.focused_cell = state.map:get(flat_oddq.col, flat_oddq.row)
  end

  -- Update current music sequencer

  if state.sequence then
    state.sequence:update(dt)

    if state.sequence:isDone() then
      state.sequence = nil
    end
  end

  -- Allow bird movement only durching non-playback
  if state.sequence == nil then

    -- Move bird backwards if possible
    if mouse.pressed[2] then
      
      local previous = state.start_cell
      while previous.next do
        if previous.next == state.bird.cell then
          previous.next = nil
          state.bird.cell = previous
          break
        end
        previous = previous.next
      end

    end

    -- Move bird forward when mouse was clicked
    if mouse.pressed[1] and state.focused_cell then

      local is_neighbour = false
      do
        local center = hexagon.OffsetCoord(state.bird.cell.x, state.bird.cell.y)
        for i=1,6 do
          local n = hexagon.oddqOffsetNeighbor(center, i)
          if state.focused_cell == state.map:get(n.col, n.row) then
            is_neighbour = true
            break
          end
        end
      end

      if state.focused_cell.next == nil and is_neighbour then
        if state.bird.cell then
          state.bird.cell.next = state.focused_cell
        end
        state.bird.cell = state.focused_cell
        if state.focused_cell.note and state.focused_cell.note.note then
          state.theme.notes[state.focused_cell.note.note]:stop()
          state.theme.notes[state.focused_cell.note.note]:play()
        end
      end
    end
  end

  -- Animate cells
  for _,cell in ipairs(state.active_cells) do
    cell.active = (cell == state.active_cell)
    cell:update(dt)
  end

  -- Animate and move bird 
  do
    state.bird.frame = state.bird.frame + 9.0 * dt
    if state.bird.frame >= #state.bird + 1.0 then
      state.bird.frame = 1
    end

    local center = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(state.bird.cell.x,state.bird.cell.y), state.map.tile_size)

    state.bird.x = math.lerp(state.bird.x, center.x, 0.1)
    state.bird.y = math.lerp(state.bird.y, center.y, 0.1)
  end




  kbd.pressed = {}
  kbd.released = {}
  mouse.pressed = {}
  mouse.released = {}
  mouse.dx=0
  mouse.dy=0
end

local function drawCell(map, pos)
  TYPE:assert(map, "map")
  TYPE:assert(pos, "offset")
  local center = hexagon.oddqOffsetToPixel(pos, map.tile_size)
 
  love.graphics.setLineWidth(1.5)
  for i=1,6 do
    local x0, y0 = hexagon.flatHexCorner(center, map.tile_size, i)
    local x1, y1 = hexagon.flatHexCorner(center, map.tile_size, i + 1)
    love.graphics.line(x0, y0, x1, y1)
  end
end

local function fillCell(map, pos)
  TYPE:assert(map, "map")
  TYPE:assert(pos, "offset")
  local center = hexagon.oddqOffsetToPixel(pos, map.tile_size)
 
  local list = { }

  for i=1,6 do
    local x0, y0 = hexagon.flatHexCorner(center, map.tile_size, i)
    table.insert(list, x0)
    table.insert(list, y0)
  end

  love.graphics.polygon("fill", list)
end

local function drawMap(map)

  local size = map.tile_size

  local width = 2 * size

  local dx = 3 * width / 4
  local dy = math.sqrt(3) * size

  local function paintCell(cell)
    local color = nil

    local offset_pos = hexagon.OffsetCoord(cell.x, cell.y)
      
    local center = hexagon.oddqOffsetToPixel(offset_pos, size)

    if cell.brightness > 0 then
      love.graphics.setColor(1, 1, 1, 0.75 * cell.brightness)
      fillCell(map, offset_pos)
    end

    if cell.note and cell.note.note then
      local img = state.theme.graphics[cell.note.note]
      local scale = 0.3
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(
        img,
        center.x, center.y,
        0,
        scale, scale,
        img:getWidth() / 2,
        img:getHeight() / 2
      )
    end
    
    color = {0,1,0,0.1}

    if color then
      love.graphics.setColor(color)
      drawCell(map, offset_pos)
    end

    if cell.next then
      local diff = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(cell.next.x, cell.next.y), size)

      love.graphics.setColor{1,0,0}
      love.graphics.setLineWidth(5)
      love.graphics.line(
        math.lerp(center.x, diff.x, 0.1),
        math.lerp(center.y, diff.y, 0.1),
        math.lerp(center.x, diff.x, 0.9),
        math.lerp(center.y, diff.y, 0.9)
      )
    end
  end

  for y=1,map.height do
    for x=1,map.width do
      local cell = map:get(x, y)

      if cell then
        paintCell(cell)
      end
    end
  end

  paintCell(state.start_cell)

  for _,cell in ipairs(state.end_cells) do
    paintCell(cell)
  end

  if state.focused_cell then
    local flat_oddq = hexagon.OffsetCoord(state.focused_cell.x, state.focused_cell.y)
    love.graphics.print(("%d %d"):format(flat_oddq.col, flat_oddq.row), 10, 10)

    love.graphics.setColor(1,0,0,0.5)
    drawCell(state.map, flat_oddq)
  end
end




function love.draw(dt)

  love.graphics.reset()

  do
    local sw, sh = love.graphics.getDimensions()
    local iw, ih = state.theme.backdrop:getDimensions()

    local scale = math.max(sw / iw, sh / ih)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(
      state.theme.backdrop,
      0, 0, 
      0,
      scale, scale
    )
  end

  love.graphics.translate(state.scroll_offset.x, state.scroll_offset.y)

  if state.map then
    drawMap(state.map)
  end

  do
    local scale = 1.0
    local img = state.bird[math.floor(state.bird.frame)]
    love.graphics.setColor(1,1,1)
    love.graphics.draw(
      img,
      state.bird.x, state.bird.y,
      0,
      scale, scale,
      img:getWidth() / 2,
      img:getHeight() / 2
    )
  end

  love.graphics.reset()
  if state.focused_cell then
    love.graphics.print(
      ("%d %d"):format(state.focused_cell.x, state.focused_cell.y),
      10,
      10
    )
  end
end

function love.keypressed(key, scancode, isrepeat)
  kbd.pressed[key] = true
end

function love.keyreleased(key, scancode)
  kbd.released[key] = true
end

function love.mousepressed(x, y, button)
  mouse.pressed[button] = true
end

function love.mousereleased	(x, y, button)
  mouse.released[button] = true
end

function love.mousemoved(x, y, dx, dy)
  mouse.x = x
  mouse.y = y
  mouse.dx = mouse.dx + dx
  mouse.dy = mouse.dy + dy
end