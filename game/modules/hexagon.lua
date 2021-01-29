
local module = {}

function module.Point(x, y) 
  return { x=x, y=y }
end

function module.Cube(x, y, z)
  return { x=x, y=y, z=z }
end

function module.Hex(q, r)
  return { q=q, r=r }
end

function module.OffsetCoord(col, row)
  return { col=col, row=row }
end

function module.cubeToOddq(cube)
  local col = cube.x
  local row = cube.z + (cube.x - (cube.x%2)) / 2
  return module.OffsetCoord(col, row)
end

function module.oddqToCube(hex)
  local x = hex.col
  local z = hex.row - (hex.col - (hex.col%2)) / 2
  local y = -x-z
  return module.Cube(x, y, z)
end

function module.flatHexCorner(center, size, i)
  local angle_deg = 60 * i
  local angle_rad = math.pi / 180 * angle_deg
  return center.x + size * math.cos(angle_rad), center.y + size * math.sin(angle_rad)
end

function module.cubeToAxial(cube)
  local q = cube.x
  local r = cube.z
  return module.Hex(q, r)
end

function module.axialToCube(hex)
  local x = hex.q
  local z = hex.r
  local y = -x-z
  return module.Cube(x, y, z)
end

function module.pixelToFlatHex(point, size)
  local q = ( 2.0/3.0 * point.x                               ) / size
  local r = (-1.0/3.0 * point.x + math.sqrt(3.0)/3.0 * point.y) / size
  return module.hexRound(module.Hex(q, r))
end

function module.hexRound(hex)
  return module.cubeToAxial(module.cubeRound(module.axialToCube(hex)))
end

function module.cubeRound(cube)
  local rx = math.floor(cube.x + 0.5)
  local ry = math.floor(cube.y + 0.5)
  local rz = math.floor(cube.z + 0.5)

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

return module