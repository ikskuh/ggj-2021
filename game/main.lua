
local hexagon = require "modules/hexagon"

local notes = {}
local sequence = { 5, 2, 3, 6, 0, 3, 2, 0, 3, 5, 6, 2, 0, 3, }

local function loadTheme(name)
  local theme = {
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
    }
  }

  return theme
end

function createMap(w, h)
  local map = {
    width = tonumber(w),
    height = tonumber(h),
    tiles = { },
  }

  for y=1,h do
    map.tiles[y] = {}
  end

  function map:set(x,y,v)
    self.tiles[y][x] = v
    return v
  end

  function map:get(x,y)
    return self.tiles[y][x]
  end

  return map
end

function love.load()

  current_theme = loadTheme("default")

  current_map = createMap(14, 6)

  current_map:set(1, 1, 1)
  current_map:set(1, 2, 2)
  current_map:set(2, 1, 3)

  love.window.setMode(1280, 720, {
    vsync = true,
    msaa = 4,
    resizable = false,
    centered = true,
  })
end







local state = {
  current_note = 1,
  current_time = nil,
  current_bpm = 120,
}


function love.update(dt)

  if love.keyboard.isDown("escape") then
    love.event.quit()
  elseif love.keyboard.isDown("space") then
    state.current_note = 1
    state.current_time = 0
    current_theme.notes[sequence[state.current_note]]:play()
  end 

  if state.current_time then
    if state.current_time >= 60 / state.current_bpm then
      if state.current_note < #sequence then
        state.current_time = 0
        state.current_note = state.current_note + 1
        local seq = sequence[state.current_note]
        if seq > 0 then
          current_theme.notes[seq]:stop()
          current_theme.notes[seq]:play()
        end
      else
        state.current_note = 1
        state.current_time = nil
      end
    else
      state.current_time = state.current_time + dt
    end
  end

  print(state.current_time, state.current_note, state.current_bpm)
  
end

function love.draw(dt)
  if current_map then
    drawMap(current_map)
  end
end

function drawMap(map)

  local size = 56

  local width = 2 * size

  local dx = 3 * width / 4
  local dy = math.sqrt(3) * size

  local off_x = -10
  local off_y = -40


  for y=1,map.height do
    for x=1,map.width do
      local center = hexagon.Point(dx * x + off_x, dy * y + off_y)

      if (x%2) == 0 then
        center.y = center.y + 0.5 * dy
      end

      local ind = map:get(x, y) or 1

      if ind then
        local img = current_theme.graphics[ind]
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
          img,
          center.x, center.y,
          0,
          1, 1,
          img:getWidth() / 2,
          img:getHeight() / 2
        )

        love.graphics.setColor(0, 1, 0)
        for i=1,6 do
          local x0, y0 = hexagon.flatHexCorner(center, size, i)
          local x1, y1 = hexagon.flatHexCorner(center, size, i + 1)
          love.graphics.line(x0, y0, x1, y1)
        end
      end
    end
  end

  do
    local mx, my = love.mouse.getPosition()

    local flat_hex = hexagon.pixelToFlatHex(
      hexagon.Point(mx - off_x, my - off_y + dy),
      size
    )

    local flat_oddq = hexagon.cubeToOddq(hexagon.cubeRound(hexagon.Cube(flat_hex.q, -flat_hex.q-flat_hex.r, flat_hex.r)))

    local center = hexagon.Point(dx * flat_oddq.col + off_x, dy * flat_oddq.row + off_y)
    if (flat_oddq.col%2) == 0 then
      center.y = center.y + 0.5 * dy
    end

    love.graphics.setColor(1, 0, 0)
    for i=1,6 do
      local x0, y0 = hexagon.flatHexCorner(center, size, i)
      local x1, y1 = hexagon.flatHexCorner(center, size, i + 1)
      love.graphics.line(x0, y0, x1, y1)
    end

  end
  

end

