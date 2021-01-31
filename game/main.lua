
require "modules/shims"
local hexagon = require "modules/hexagon"
local sequencer = require "modules/sequencer"
local ui = require "modules/ui"
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
  local path = "tracks/" .. name
  local theme = {
    [TYPE] = TYPE.theme,
    
    backdrop = love.graphics.newImage(path.."/backdrop.png"),
    ambient = love.audio.newSource(path.."/ambient.ogg", "stream"),
    final = love.audio.newSource(path.."/final.ogg", "stream"),

    track = assert(love.filesystem.load(path.."/sequence.lua"))(),

    notes = {},
    graphics = {},
  }

  local max = 1
  for i=1,#theme.track do
    theme.track[i][TYPE] = TYPE.note
    max = math.max(max, theme.track[i].note or 1)
  end

  for i=1,max do
    theme.notes[i]    = love.audio.newSource((path.."/note-%02d.ogg"):format(i), "static")
    theme.graphics[i] = love.graphics.newImage((path.."/cell-%02d.png"):format(i))
  end

  return theme
end

local function loadStory(index)
  local path = ("story/Story_%02d"):format(index)
  local story = {
    voiceover = love.audio.newSource(path..".ogg", "stream"),
    strings = assert(love.filesystem.load(path..".lua"))(),
  }
  return story
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

local globals


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

local function undoBirdMovement()
  if state.sequence then
    return
  end
  local previous = state.start_cell
  while previous.next do
    if previous.next == state.current_cell then
      previous.next = nil
      state.current_cell = previous
      state.bird.cell = previous
      break
    end
    previous = previous.next
  end
end

local function playBirdPath()
  if state.sequence then
    return
  end

  if state.start_cell.next then
    local iter = state.start_cell.next or error("no")
    local seq = { }
    local end_cell = iter
    while iter do
      if iter.note then
        iter.note.cell = iter
        seq[#seq + 1] = iter.note
      end
      end_cell = iter
      iter = iter.next
    end

    local success = false
    if #seq == #state.theme.track then
      success = (end_cell.x == state.map.width)
      for i=1,#state.theme.track do
        success = success and (seq[i].note == state.theme.track[i].note)
      end
    end
    
    state.sequence = sequencer.create(state.theme, seq)
    
    state.sequence.onNote = function(note, index)
      state.bird.cell = note.cell
      state.active_cell = note.cell
    end
    state.sequence.onNoteEnd = function(note, index)
      state.active_cell = nil

      if index == #seq and success then
        state.success = true
        state.theme.final:stop()
        state.theme.final:play()
      end
    end

    state.sequence:start()
  end

end

local function playTruePath()

  if state.sequence then
    return
  end

  state.sequence = sequencer.create(state.theme, state.theme.track)
  
  state.sequence.onNote = function(note, index)
    --state.bird.cell = note.cell
    state.active_cell = note.cell
  end
  state.sequence.onNoteEnd = function(note, index)
    state.active_cell = nil
  end

  state.sequence:start()

end

local function stopPlayback()

  if not state.sequence then
    return
  end

  state.sequence:stop()
  state.sequence = nil
  state.bird.cell = state.current_cell

end

local function loadLevel(index)

  if state then
    if state.mode == "gameplay" then
      state.theme.ambient:stop()
    elseif state.mode == "story" then
      state.story.voiceover:stop()
    end
  end

  local level = index and globals.levels[index]
  if level ~= nil then
    state.mode = level.type
    if level.type == "story" then
      state = { mode="story" }

      state.story = level.story or error("story requires story!")
      state.story.voiceover:play()

      state.time = 0

    elseif level.type == "gameplay" then

      state = { mode="gameplay" }
      state.theme = level.theme or error("gameplay requires theme!")
      state.theme.ambient:setVolume(0.5)
      state.theme.ambient:play()

      state.buttons = {
        sequence = {},
        gameplay = {},
      }

      state.ui = ui.create(globals.sounds)
      state.buttons.gameplay[1] = state.ui:add {
        x = 496,
        y = 624,
        width = 96,
        height = 96,
        graphic = globals.graphics.menu_button_undo,
        clicked = undoBirdMovement,
      }
      state.buttons.gameplay[2] = state.ui:add {
        x = 592,
        y = 624,
        width = 96,
        height = 96,
        graphic = globals.graphics.menu_button_listen,
        clicked = playTruePath,
      }
      state.buttons.gameplay[3] = state.ui:add {
        x = 688,
        y = 624,
        width = 96,
        height = 96,
        graphic = globals.graphics.menu_button_play,
        clicked = playBirdPath,
      }

      state.buttons.sequence[1] = state.ui:add {
        x = 592,
        y = 624,
        width = 96,
        height = 96,
        graphic = globals.graphics.menu_button_stop,
        clicked = stopPlayback,
      }

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

      -- Generate path through the level
      do
        local seq = state.theme.track

        if #seq < state.map.width - 1 then
          error("sequence too short, min. 14 elements required!")
        end

        local prev_cell = nil
        local previous_pos = hexagon.OffsetCoord(0, 4)

        local n_horizontals = #seq - 14
        local horizontals = {} 
        if n_horizontals > 0 then
          local temp = {}
          for i=1,state.map.width-1 do
            temp[i] = { n=i, weight = love.math.random() }
          end
          table.sort(temp, function(a,b) return a.weight < b.weight end)
          for i=n_horizontals+1,#temp do
            temp[i] = nil
          end

          for i=1,#temp do
            local n = temp[i].n
            horizontals[n] = true
          end

        end

        for i=1,#seq do

          local next = nil

          if horizontals[previous_pos.col] then
            horizontals[previous_pos.col] = nil
            
            local tries = 0
            while true do
              next = hexagon.OffsetCoord(previous_pos.col, previous_pos.row + (love.math.random() >= 0.5 and 1 or -1))
              if state.map:validPos(next.col, next.row) then
                break
              else
                tries = tries + 1
                if tries > 30 then
                  break
                end
              end
            end
            if tries > 30 then
              break
            end

          else
            local tries = 0
            while true do
              next = hexagon.oddqOffsetNeighbor(previous_pos, love.math.random(2))
              if state.map:validPos(next.col, next.row) then
                break
              else
                tries = tries + 1
                if tries > 30 then
                  break
                end
              end
            end
            if tries > 30 then
              break
            end
          end

          previous_pos = next
          local cell = state.map:set(next.col, next.row, createCell(seq[i]))

          seq[i].cell = cell
          
          if prev_cell then
            -- prev_cell.next = cell
          end
          prev_cell = cell

          -- state.current_cell = cell
        end
      end
      state.start_cell = createCell()
      state.start_cell.x = 0
      state.start_cell.y = 4
      -- state.start_cell.next = state.map:get(1,4)

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
      state.current_cell = state.start_cell

      state.bird = {
        frame = 1,
        x = 0,
        y = 0,
        cell = state.start_cell,
        frames = globals.bird_frames,
      }

      state.scroll_offset = {
        x = 4,
        y = 0,
      }
    else 
      error("invalid level type!")
    end
  else
    state = { mode="menu" }

    state.ui = ui.create(globals.sounds)

    state.ui:add{
      x = 705,
      y = 121,
      width = 272,
      height = 145,
      graphic = globals.graphics.menu_button_start,
      clicked = function() loadLevel(1) end
    }

    state.ui:add{
      x = 686,
      y = 216,
      width = 290,
      height = 135,
      graphic = globals.graphics.menu_button_credits,
    }

    state.ui:add{
      x = 724,
      y = 348,
      width = 242,
      height = 105,
      graphic = globals.graphics.menu_button_quit,
      clicked = function() love.event.quit() end
    }

  end

  state.level_index = level and tonumber(index) 
end

local function SoundGroup(items)
  local group = {
    elements = items,
  }
  function group:play() 
    local i = love.math.random(#self.elements)
    self.elements[i]:stop()
    self.elements[i]:play()
  end
  return group
end

function love.load()

  love.window.setTitle("A Melody Called Home")
  love.window.setMode(1280, 720, {
    vsync = true,
    msaa = 4,
    resizable = false,
    centered = true,
  })

  love.math.setRandomSeed(love.timer.getTime())

  globals = {
    levels = {
      { type = "story", story = loadStory(1) },
      { type = "gameplay", theme = loadTheme("meadow") },
      { type = "story", story = loadStory(2) },
      { type = "gameplay", theme = loadTheme("harbour") },
      { type = "story", story = loadStory(3) },
      { type = "gameplay", theme = loadTheme("graveyard") },
      { type = "story", story = loadStory(4) },
    },
    bird_frames = {
      love.graphics.newImage("graphics/bird/schwalbe1.png"),
      love.graphics.newImage("graphics/bird/schwalbe2.png"),
      love.graphics.newImage("graphics/bird/schwalbe3.png"),
      love.graphics.newImage("graphics/bird/schwalbe4.png"),
      love.graphics.newImage("graphics/bird/schwalbe5.png"),
      love.graphics.newImage("graphics/bird/schwalbe6.png"),
      love.graphics.newImage("graphics/bird/schwalbe7.png"),
      love.graphics.newImage("graphics/bird/schwalbe8.png"),
      love.graphics.newImage("graphics/bird/schwalbe9.png"),
    },
    graphics = {
      menu_button_start    = love.graphics.newImage("graphics/start.png"),
      menu_button_credits  = love.graphics.newImage("graphics/credits.png"),
      menu_button_quit     = love.graphics.newImage("graphics/quit.png"),

      menu_button_listen   = love.graphics.newImage("graphics/listen.png"),
      menu_button_play     = love.graphics.newImage("graphics/play.png"),
      menu_button_undo     = love.graphics.newImage("graphics/undo.png"),
      menu_button_stop     = love.graphics.newImage("graphics/stop.png"),

      menu_background      = love.graphics.newImage("graphics/home.png"),

      cell_arrow           = love.graphics.newImage("graphics/arrow.png"),
    },
    fonts = {
      default = love.graphics.newFont("graphics/YuseiMagic-Regular.ttf", 26)
    },
    sounds = {
      hover = SoundGroup {
        love.audio.newSource("sounds/hover_01.ogg", "static"),
        love.audio.newSource("sounds/hover_02.ogg", "static"),
        love.audio.newSource("sounds/hover_03.ogg", "static"),
      },
      confirm = SoundGroup { 
        love.audio.newSource("sounds/confirm.ogg", "static"),
      },
    }
  }

  loadLevel(nil)
end

local function doGameplay(dt, prevent_mouse_input)
-- Update current music sequencer

  if state.sequence then
    state.sequence:update(dt)

    if state.sequence:isDone() then
      state.sequence = nil
    end
  end

  local sequence_active = (state.sequence ~= nil)

  for i=1,#state.buttons.gameplay do
    state.buttons.gameplay[i].visible = not sequence_active
  end

  for i=1,#state.buttons.sequence do
    state.buttons.sequence[i].visible = sequence_active
  end

  -- Do mouse input
  do
    local mx, my = love.mouse.getPosition()

    local flat_hex = hexagon.pixelToFlatHex(hexagon.Point(mx - state.scroll_offset.x, my - state.scroll_offset.y), state.map.tile_size)

    local flat_oddq = hexagon.cubeToOddq(hexagon.cubeRound(hexagon.Cube(flat_hex.q, -flat_hex.q-flat_hex.r, flat_hex.r)))

    if not prevent_mouse_input then
      state.focused_cell = state.map:get(flat_oddq.col, flat_oddq.row)
    else
      state.focused_cell = nil
    end
  end

  -- Allow bird movement only durching non-playback
  if state.sequence == nil then

    if kbd.pressed.p then
      playTruePath()
    end

    -- Run the sequence when we started
    if kbd.pressed.space then
      playBirdPath()
    end 

    -- Move bird backwards if possible
    if not prevent_mouse_input and  mouse.pressed[2] then
      
      undoBirdMovement()

    end

    -- Move bird forward when mouse was clicked
    if not prevent_mouse_input and mouse.pressed[1] and state.focused_cell then

      local is_neighbour = false
      do
        local center = hexagon.OffsetCoord(state.current_cell.x, state.current_cell.y)
        for i=1,6 do
          local n = hexagon.oddqOffsetNeighbor(center, i)
          if state.focused_cell == state.map:get(n.col, n.row) then
            is_neighbour = true
            break
          end
        end
      end

      if state.focused_cell.next == nil and is_neighbour then
        if state.current_cell then
          state.current_cell.next = state.focused_cell
        end
        state.current_cell = state.focused_cell
        state.bird.cell = state.focused_cell
        if state.focused_cell.note and state.focused_cell.note.note then
          state.theme.notes[state.focused_cell.note.note]:stop()
          state.theme.notes[state.focused_cell.note.note]:play()
        end
      end
    end
  else
    if kbd.pressed.space then
      stopPlayback()
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
    if state.bird.frame >= #state.bird.frames + 1.0 then
      state.bird.frame = 1
    end

    local center = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(state.bird.cell.x,state.bird.cell.y), state.map.tile_size)

    state.bird.x = math.lerp(state.bird.x, center.x, 0.1)
    state.bird.y = math.lerp(state.bird.y, center.y, 0.1)
  end
end

function love.update(dt)
  
  if kbd.pressed.escape then
    loadLevel(nil)
  end

  if kbd.pressed["1"] then
    loadLevel(1)
  elseif kbd.pressed["2"] then
    loadLevel(2)
  elseif kbd.pressed["3"] then
    loadLevel(3)
  elseif kbd.pressed["4"] then
    loadLevel(4)
  elseif kbd.pressed["5"] then
    loadLevel(5)
  elseif kbd.pressed["6"] then
    loadLevel(6)
  elseif kbd.pressed["7"] then
    loadLevel(7)
  elseif kbd.pressed["8"] then
    loadLevel(8)
  end

  local prevent_mouse_input = false
  if state.ui then
    prevent_mouse_input = state.ui:update(mouse)
  end

  if state.mode == "gameplay" then
    if state.success then
      if not state.theme.final:isPlaying() then
        loadLevel(state.level_index + 1)
      end
    else
      doGameplay(dt, prevent_mouse_input)
    end
  elseif state.mode == "story" then

    state.time = state.time + dt

    if not state.story.voiceover:isPlaying() then
      loadLevel(state.level_index + 1)
    end

  elseif state.mode == "menu" then

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
      local scale = 0.8 * 96 / img:getWidth()
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

    if cell.x == map.width then
      local img = globals.graphics.cell_arrow
      local scale = 0.8 * 96 / img:getWidth()
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(
        img,
        center.x - 20, center.y + 5,
        0,
        scale, scale,
        img:getWidth() / 2,
        img:getHeight() / 2
      )
    end
    
    color = state.theme.track.cell_color or error("missing cell_color in theme.")

    if color then
      love.graphics.setColor(color)
      drawCell(map, offset_pos)
    end

    if cell.next then
      local diff = hexagon.oddqOffsetToPixel(hexagon.OffsetCoord(cell.next.x, cell.next.y), size)

      love.graphics.setColor(state.theme.track.path_color or error("missing path_color in theme."))
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
    -- love.graphics.print(("%d %d"):format(flat_oddq.col, flat_oddq.row), 10, 10)

    love.graphics.setColor(1,0,0,0.5)
    drawCell(state.map, flat_oddq)
  end
end




function love.draw(dt)

  love.graphics.reset()

  love.graphics.setFont(globals.fonts.default)

  if state.mode == "gameplay" then

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

    if not state.success then

      love.graphics.translate(state.scroll_offset.x, state.scroll_offset.y)

      if state.map then
        drawMap(state.map)
      end

      do
        local scale = 1.0
        local img = state.bird.frames[math.floor(state.bird.frame)]
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

    love.graphics.reset()
    -- if state.focused_cell then
    --   love.graphics.print(
    --     ("%d %d"):format(state.focused_cell.x, state.focused_cell.y),
    --     10,
    --     10
    --   )
    -- end
  elseif state.mode == "story" then

    for _, string in ipairs(state.story.strings) do
      if state.time >= string.start and state.time <= string.stop then

        local a0 = math.clamp((state.time - string.start) / 0.5, 0, 1)
        local a1 = math.clamp((string.stop - state.time) / 0.5, 0, 1)

        local a = math.min(a0, a1)

        love.graphics.setColor(1,1,1,a)
        love.graphics.printf(
          string[1],
          10,
          (love.graphics.getHeight() - love.graphics.getFont():getHeight()) / 2,
          love.graphics.getWidth() - 20,
          "center"
        )
      end
    end
  elseif state.mode == "menu" then
    do
      local sw, sh = love.graphics.getDimensions()
      local iw, ih = globals.graphics.menu_background:getDimensions()

      local scale = math.max(sw / iw, sh / ih)
      love.graphics.setColor(1,1,1)
      love.graphics.draw(
        globals.graphics.menu_background,
        0, 0, 
        0,
        scale, scale
      )
    end
  end

  love.graphics.reset()

  if state.ui then
    state.ui:draw()
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