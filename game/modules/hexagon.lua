local module = {}

local TYPE = require("modules/type")

function module.Point(x, y) 
  return {
    [TYPE] = TYPE.point,
    x=tonumber(x) or error("expected x"),
    y=tonumber(y) or error("expected y")
  }
end

function module.Cube(x, y, z)
  return {
    [TYPE] = TYPE.cube,
    x=tonumber(x) or error("expected x"), 
    y=tonumber(y) or error("expected y"), 
    z=tonumber(z) or error("expected z") 
  }
end

function module.Hex(q, r)
  return {
    [TYPE] = TYPE.hex,
    q=tonumber(q) or error("expected q"),
    r=tonumber(r) or error("expected r") 
  }
end

function module.OffsetCoord(col, row)
  return {
    [TYPE] = TYPE.offset,
    col=tonumber(col) or error("expected col"),
    row=tonumber(row) or error("expected row") 
  }
end

function module.cubeToOddq(cube)
  TYPE:assert(cube, "cube")
  local col = cube.x
  local row = cube.z + (cube.x - math.rem(cube.x, 2)) / 2
  return module.OffsetCoord(col, row)
end

function module.oddqToCube(hex)
  TYPE:assert(hex, "offset")
  local x = hex.col
  local z = hex.row - (hex.col - math.rem(hex.col, 2)) / 2
  local y = -x-z
  return module.Cube(x, y, z)
end

function module.flatHexCorner(center, size, i)
  TYPE:assert(center, "point")
  local angle_deg = 60 * i
  local angle_rad = math.pi / 180 * angle_deg
  return center.x + size * math.cos(angle_rad), center.y + size * math.sin(angle_rad)
end

function module.cubeToAxial(cube)
  TYPE:assert(cube, "cube")
  local q = cube.x
  local r = cube.z
  return module.Hex(q, r)
end

function module.axialToCube(hex)
  TYPE:assert(hex, "hex")
  local x = hex.q
  local z = hex.r
  local y = -x-z
  return module.Cube(x, y, z)
end

function module.pixelToFlatHex(point, size)
  TYPE:assert(point, "point")
  local q = ( 2.0/3.0 * point.x                               ) / size
  local r = (-1.0/3.0 * point.x + math.sqrt(3.0)/3.0 * point.y) / size
  return module.hexRound(module.Hex(q, r))
end

function module.flatHexToPixel(hex, size)
  TYPE:assert(hex, "hex")
  local x = size * (          3./2 * hex.q                    )
  local y = size * (math.sqrt(3)/2 * hex.q  +  math.sqrt(3) * hex.r)
  return module.Point(x, y)
end

function module.oddqOffsetToPixel(hex, size)
  TYPE:assert(hex, "offset")
  local x = size * 3/2 * hex.col
  local y = size * math.sqrt(3) * (hex.row + 0.5 * math.rem(hex.col, 2))
  return module.Point(x, y)
end

function module.hexRound(hex)
  TYPE:assert(hex, "hex")
  return module.cubeToAxial(module.cubeRound(module.axialToCube(hex)))
end

function module.cubeRound(cube)
  TYPE:assert(cube, "cube")
  local rx = math.round(cube.x)
  local ry = math.round(cube.y)
  local rz = math.round(cube.z)

  local x_diff = math.abs(rx - cube.x)
  local y_diff = math.abs(ry - cube.y)
  local z_diff = math.abs(rz - cube.z)

  if x_diff > y_diff and x_diff > z_diff then
      rx = -ry-rz
  elseif y_diff > z_diff then
      ry = -rx-rz
  else
      rz = -rx-ry
  end

  return module.Cube(rx, ry, rz)
end

local oddq_directions = {
  [0] = { { 1,  0}, { 1, -1}, { 0, -1}, {-1, -1}, {-1,  0}, { 0, 1 } },
  [1] = { { 1,  1}, { 1,  0}, { 0, -1}, {-1,  0}, {-1,  1}, { 0, 1 } },
}

function module.oddqOffsetNeighbor(hex, direction)
  TYPE:assert(hex, "offset")
  local parity = math.rem(hex.col, 2)
  local dir = oddq_directions[parity][direction]
  return module.OffsetCoord(hex.col + dir[1], hex.row + dir[2])
end

local axial_directions = {
  module.Hex( 1, 0), module.Hex( 1, -1), module.Hex(0, -1), 
  module.Hex(-1, 0), module.Hex(-1,  1), module.Hex(0,  1), 
}

function module.hexDirection(direction)
  return axial_directions[direction]
end

function module.hexNeighbor(hex, direction)
  TYPE:assert(hex, "hex")
  local dir = module.hexDirection(direction)
  return module.Hex(hex.q + dir.q, hex.r + dir.r)
end

local cube_directions = {
  module.Cube( 1, -1, 0), module.Cube( 1, 0, -1), module.Cube(0,  1, -1), 
  module.Cube(-1,  1, 0), module.Cube(-1, 0,  1), module.Cube(0, -1,  1), 
}

function module.cubeDirection(direction)
  return cube_directions[direction]
end

function module.cubeNeighbor(cube, direction)
  TYPE:assert(cube, "cube")
  return module.cubeAdd(cube, module.cubeDirection(direction))
end

function module.cubeAdd(a, b)
  TYPE:assert(a, "cube")
  TYPE:assert(b, "cube")
  return module.Cube(
    a.x + b.x,
    a.y + b.y,
    a.z + b.z
  )
end

return module