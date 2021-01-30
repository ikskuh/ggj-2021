
local hexagon = require "modules/hexagon"
local sequencer = require "modules/sequencer"

-- tag identities
local TYPE = {
  theme = {},
  map = {},
  cell = {},
} 

function math.sign(x)
  if x < 0 then
    return -1
  elseif x > 0 then
    return 1
  else
    return 0
  end
end

function math.rem(a, b)
  return math.abs(math.mod(a, b))
end

function math.round(value)  
  return math.sign(value) * math.floor(math.abs(value) + 0.5)
end

function math.lerp(a, b, f)
  return (1.0-f)*a + (f*b)
end

for i=-20,20 do
  print(0.1 * i, math.round(0.1 * i))
end

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

    if cell and cell[TYPE] ~= TYPE.cell then
      error("expected cell")
    end
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

local function createCell(i)
  return {
    [TYPE] = TYPE.cell,
    note = tonumber(i) > 0 and tonumber(i),
    active = false,
  }
end

function love.load()

  state.theme = loadTheme("default")

  local seq = { 5, 2, 3, 6, 0, 3, 2, 0, 3, 5, 6, 2, 0, 3 }

  local prev_cell = nil
  state.map = createMap(14, 6)
  for i=1,#seq do
    local cell = state.map:set(i, 1, createCell(seq[i]))
    if prev_cell then
      prev_cell.next = cell
    end
    prev_cell = cell
  end

  state.bird = {
    frame = 1,
    x = 0,
    y = 0,
    target_x = 0,
    target_y = 0,
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

  love.window.setMode(1280, 720, {
    vsync = true,
    msaa = 4,
    resizable = false,
    centered = true,
  })
end









function love.update(dt)

  if love.keyboard.isDown("escape") then
    love.event.quit()
  elseif love.keyboard.isDown("space") then
    local seq = { state.map:get(1,1) }
    while seq[#seq].next do
      seq[#seq + 1] = seq[#seq].next
    end
    
    state.sequence = sequencer.create(120, state.theme, seq)
    
    state.sequence.onNote = function(cell, index)

      local center = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(cell.x, cell.y), state.map.tile_size)

      state.bird.target_x = center.x
      state.bird.target_y = center.y
    end

    state.sequence:start()
  end 

  -- Update current music sequencer

  if state.sequence then
    state.sequence:update(dt)

    if state.sequence:isDone() then
      state.sequence = nil
    end
  end

  -- Animate and move bird 
  
  state.bird.frame = state.bird.frame + 9.0 * dt
  if state.bird.frame >= #state.bird + 1.0 then
    state.bird.frame = 1
  end

  state.bird.x = math.lerp(state.bird.x, state.bird.target_x, 0.1)
  state.bird.y = math.lerp(state.bird.y, state.bird.target_y, 0.1)

end

local function drawMap(map)

  local size = map.tile_size

  local width = 2 * size

  local dx = 3 * width / 4
  local dy = math.sqrt(3) * size

  for y=1,map.height do
    for x=1,map.width do
      local center = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(x, y), size)

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
          love.graphics.setColor(1, 1, 0)
        else
          love.graphics.setColor(0, 1, 0)
        end
      else
        love.graphics.setColor(0.3, 0.5, 0.3)
      end

      for i=1,6 do
        local x0, y0 = hexagon.flatHexCorner(center, size, i)
        local x1, y1 = hexagon.flatHexCorner(center, size, i + 1)
        love.graphics.line(x0, y0, x1, y1)
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

  do
    local mx, my = love.mouse.getPosition()

    local flat_hex = hexagon.pixelToFlatHex(hexagon.Point(mx - 4, my - 0), size)

    local flat_oddq = hexagon.cubeToOddq(hexagon.cubeRound(hexagon.Cube(flat_hex.q, -flat_hex.q-flat_hex.r, flat_hex.r)))

    local cell = map:get(flat_oddq.col, flat_oddq.row)

    if cell then

      local center = hexagon.oddqOffsetToPixel(flat_oddq, size)

      -- love.graphics.print(("%d %d"):format(flat_hex.q, flat_hex.r), 10, 10)

      love.graphics.setColor(1, 0, 0)
      for i=1,6 do
        local x0, y0 = hexagon.flatHexCorner(center, size, i)
        local x1, y1 = hexagon.flatHexCorner(center, size, i + 1)
        love.graphics.line(x0, y0, x1, y1)
      end
    end

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

  love.graphics.translate(4, 0)

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