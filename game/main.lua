
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
  }

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

  function map:set(x, y, cell)

    x = tonumber(x) or error("x must be a number!")
    y = tonumber(y) or error("y must be a number!")
    TYPE:assert(cell, "cell", true)

    if x < 1 or y < 1 or x > self.width or y > self.height then
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

local function createCell(i)
  return {
    [TYPE] = TYPE.cell,
    note = i and tonumber(i) > 0 and tonumber(i),
    active = false,
  }
end

function love.load()

  state.theme = loadTheme("default")

  local seq = { 5, 2, 3, 6, 0, 3, 2, 0, 3, 5, 6, 2, 0, 3 }

  local prev_cell = nil
  state.map = createMap(14, 6)

  for x=1,state.map.width do
    for y=1,state.map.height do
      state.map:set(x, y, createCell(math.random(7)-1))
    end
  end

  for i=1,#seq do
    local cell = state.map:set(i, 1, createCell(seq[i]))
    if prev_cell then
      prev_cell.next = cell
    end
    prev_cell = cell
  end
  state.start_cell = createCell()
  state.start_cell.x = 0
  state.start_cell.y = 4
  state.start_cell.next = state.map:get(1,1)

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
      local seq = { state.start_cell.next or error("no") }
      while seq[#seq].next do
        seq[#seq + 1] = seq[#seq].next
      end
      
      state.sequence = sequencer.create(120, state.theme, seq)
      
      state.sequence.onNote = function(cell, index)
        state.bird.cell = cell
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
      if state.focused_cell.note then
        state.theme.notes[state.focused_cell.note]:stop()
        state.theme.notes[state.focused_cell.note]:play()
      end
    end
  end

  -- Update current music sequencer

  if state.sequence then
    state.sequence:update(dt)

    if state.sequence:isDone() then
      state.sequence = nil
    end
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

local function drawMap(map)

  local size = map.tile_size

  local width = 2 * size

  local dx = 3 * width / 4
  local dy = math.sqrt(3) * size

  for y=1,map.height do
    for x=1,map.width do
      local offset_pos = hexagon.OffsetCoord(x, y)

      local center = hexagon.oddqOffsetToPixel(offset_pos, size)

      local cell = map:get(x, y)

      if cell then
        if cell.note then
          local img = state.theme.graphics[cell.note]
          love.graphics.setColor(1, 1, 1)
          love.graphics.draw(
            img,
            center.x, center.y,
            0,
            1, 1,
            img:getWidth() / 2,
            img:getHeight() / 2
          )
        end
        
        if cell.active then
          love.graphics.setColor({1,1,0})
        else
          love.graphics.setColor({0,1,0})
        end
      else
        love.graphics.setColor(0.3, 0.5, 0.3)
      end

      drawCell(map, hexagon.OffsetCoord(x, y))

      if cell and cell.next then
        local diff = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(cell.next.x, cell.next.y), size)

        love.graphics.setColor{1,0,0}
        love.graphics.setLineWidth(5)
        love.graphics.line(
          center.x,
          center.y,
          math.lerp(center.x, diff.x, 0.75),
          math.lerp(center.y, diff.y, 0.75)
        )

      end

      -- local cube = hexagon.oddqToCube(hexagon.OffsetCoord(x, y))
      -- local hex = hexagon.cubeToAxial(cube)
      -- local cube2 = hexagon.axialToCube(hex)
      -- local off = hexagon.cubeToOddq(cube2)

      -- love.graphics.setColor(1, 0, 1)
      -- love.graphics.print(
      --   ("%d %d\n%d %d %d\n%d %d\n%d %d %d\n%d %d\n"):format(
      --       x, y, 
      --       cube.x, cube.y, cube.z, 
      --       hex.q, hex.r,
      --       cube2.x, cube2.y, cube2.z, 
      --       off.col, off.row),
      --   center.x - 20,
      --   center.y - 30
      -- )
    end
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