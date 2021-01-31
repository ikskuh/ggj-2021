local module = {}

local TYPE = require "modules/type"

function module.create(sound_set)
  local ui = {
    sound_set = sound_set or error("missing sound_set"),
    elements = { },
    hovered_widget = nil,
  }

  function ui:add(template)
    if template[TYPE] then error("template must be a plane table!") end

    if not tonumber(template.x) then error("template.x required!") end
    if not tonumber(template.y) then error("template.y required!") end
    if not tonumber(template.width) then error("template.width required!") end
    if not tonumber(template.height) then error("template.height required!") end

    template[TYPE] = TYPE.widget

    table.insert(self.elements, template)

    return template
  end

  function ui:update(mouse)
    local mx, my = mouse.x, mouse.y
    
    local any_hovered = false
    local any_clicked = false

    local hovered = nil
    
    for i=1,#self.elements do
      local widget = self.elements[i]

      if mx >= widget.x and my >= widget.y and mx < widget.x+widget.width and my < widget.y+widget.height then
        any_hovered = true
        hovered = widget
        widget.hovered = true

        if not any_clicked and mouse.pressed[1] then 
          any_clicked = true
        
          self.sound_set.confirm:play()

          if widget.clicked then
            widget.clicked(widget, mx, my)
          end

        end
        
      else
        widget.hovered = false
      end
    end

    if hovered and self.hovered_widget ~= hovered then
       self.sound_set.hover:play()
    end
    self.hovered_widget = hovered

    return any_hovered
  end

  function ui:draw()
    for i=1,#self.elements do
      local widget = self.elements[i]

      if widget.graphic then

        if widget.hovered then
          love.graphics.setColor(0.8,0.8,0.8)
        else
          love.graphics.setColor(1.0,1.0,1.0)
        end

        love.graphics.draw(
          widget.graphic,
          widget.x, widget.y,
          0,
          widget.width / widget.graphic:getWidth(),
          widget.height / widget.graphic:getHeight()
        )
      end

    end
  end

  return ui
end

return module