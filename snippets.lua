-- navigation functions for grid based navigation.
local component = require("component")
local sides = require("sides")
local fs = require('filesystem')
local serialization = require('serialization')
local r = component.robot

local x, y z, f = 0, 0, 0, 0

local delta = {[0] = function() z = z + 1 end, [1] = function() x = x + 1 end,
               [2] = function() z = z - 1 end, [3] = function() x = x - 1 end
}

local function setPos(tx, ty, tz)
  x, y, z = tx, ty, tz 
end

local function setFacing(tf)
  f = tf 
end

local function turnRight()
  r.turn(true)
  f = (f + 1) % 4
end

local function turnLeft()
  r.turn(false)
  f = (f - 1) % 4
end

local function turnTowards(side)
  if f == side - 1 then
    turnRight()
  else
    while f ~= side do
      turnLeft()
    end
  end
end

local function move(side,force)
  local force = force or false
  if force then
    r.swing(side)
  end
  if r.move(side) then
    delta[f]()
    return true
  end
  return false    
end

local function goToX(tx, force)
  local force = force or true
  if x > tx then
    turnTowards(3)
  elseif x < tx then
    turnTowards(1)
  end
  while x ~= tx do
    move(sides.forward,force)
  end
  return true
end

local function goToY(ty, force)
  local force = force or true
  while y < ty do
    if r.move(sides.up) then
      y = y + 1
    end
  end
  while y > ty do
    if r.move(sides.down) then
      y = y - 1
    end
  end
end

local function goToZ(tz,force)
  local force = force or true
  if z > tz then
    turnTowards(2)
  elseif z < tz then
    turnTowards(0)
  end
  while z ~= tz do
    move(sides.forward,force)
  end 
end

--- Misc

local function recharge()
  --goHome()
  rs.setOutput(sides.down, 15)
  local startTime = computer.uptime() 
  while computer.uptime() < startTime + 60 do
    while computer.energy() < (computer.maxEnergy() - 200) do
      os.sleep(1)
    end
    rs.setOutput(sides.down, 0)
    return true
  end
  rs.setOutput(sides.down, 0)
  return false
end

local selectedSlot
local function cachedSelect(slot)
  if slot ~= selectedSlot then
    r.select(slot)
    selectedSlot = slot
  end
end

local function saveSpecs(filename)
  local data = serialization.serialize(specs)
  local file = io.open(filename, "w")
  file:write(data)
  file:close()
end

local function readSpecs(plant)
  local file = io.open(filename, "r")
  local specs = serialization.unserialize(file:read("*a"))
  file:close()  
  return specs[plant]
end

local function saveTable(filename,data)
  local file = io.open(filename, "w")
  local first = true
  for k,v in pairs(data) do
    if first then
      file:write(k .."=".. serialization.serialize(v))
      first = false
    else
      file:write(",\n" .. k .."=".. serialization.serialize(v))
    end
  end
  file:close()
end

local function readTable(filename)
  local file = io.open(filename)
  local str = "{" .. file:read("*a") .. "}"
  return serialization.unserialize(str) 
end

local function readLines(sPath)
  local file = fs.open(sPath, "r")
  if file then
    local tLines = {}
    local sLine = file.readLine()
    while sLine do
      table.insert(tLines, sLine)
      sLine = file.readLine()
    end
    file.close()
    return tLines
  end
  return nil
end

local function writeLines(sPath, tLines)
  local file = fs.open(sPath, "w")
  if file then
        for _, sLine in ipairs(tLines) do
          file.writeLine(sLine)
        end
        file.close()
  end
end
