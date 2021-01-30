local module = { }

function module.create(...)
  local items = table.pack(...)
  local type = {}
  for i=1,#items do
    type[items[i]] = { upvalue = type }
  end

  function type:assert(value, type, allownil) 
    if not self[type] then
      error(tostring(type) .. " is not a valid type name!")
    end
    if not allownil and value == nil then
      error("Expected value, got nil!")
    end
    if value then
      if value[self] ~= self[type] then
        error(("Invalid type. Expected %s, found %s"):format(tostring(value[self]), type))
      end
    end
  end

  return type
end

return module