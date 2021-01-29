



function love.update()

  if love.keyboard.isDown("escape") then
    love.event.quit()
  end 

end


function love.draw()
  love.graphics.setColor(0, 1, 0)
  love.graphics.print("Team Green!", 10, 10)
end

