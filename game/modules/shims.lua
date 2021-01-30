
function table.pack(...)
  return {n = select('#', ...), ...}
end

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

function table.contains(tab, item)
  for i,v in ipairs(tab) do 
    if v == item then
      return i
    end
  end
  return nil
end