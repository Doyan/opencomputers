-- Script to dig out a rectangular prism
local component = require("component")
local computer = require("computer")
local robot = require("robot")
local shell = require("shell")
local sides = require("sides")
local fs = require("filesystem")
local serialization = require("serialization")
local nav = component.navigation
local r = component.robot
--------------------------------------------
local arg, option = shell.parse(...)


local checkedDrop, moveTo, rescueFlag -- forward declaration
-- some parameters available for configuration ------------
local setDurability = 0.08
local energyLimit = 0.1
local filename = "/usr/interrupt.txt"
-----------------------------------------------------------

local dropping = false
if option.d then
  dropping=true
end

-- table to convert sides API to real f values 
local fSides = {
	[sides.south] = 0,
	[sides.west] = 1,
	[sides.north] = 2,
	[sides.east] = 3
}

local resume = false

local function yesNo()
  print("Continue on last excavation(Y/N)?")
  local answer = io.read()
  while( not (answer == "Y" or answer == "N") ) do
        io.write("Invalid Answer! Try again (Y/N): ")
        answer = io.read()
  end
  if answer == "Y" then
    return true  
  else 
    return false
  end  
end

if fs.exists(filename) then
    resume = yesNo()
elseif #arg < 3 and not resume then
  io.write("Usage: excavate [-uad] xf yf zf \n")
  io.write(" -u: start from underneath\n")
  io.write(" -a: start from above\n")
  io.write(" -d: drop when full\n")
return
end


--- Init
local p = {
  x = arg[1] + 0,
  y = arg[2] + 0,
  z = arg[3] + 0,
  x0 = 0,
  y0 = 0,
  z0 = 0,
}

local x, y, z, f = 0, 0, 0, 0
local f0 = f


--------------- Functions for navigation -------------
local delta = {[0] = function() z = z + 1 end, [1] = function() x = x - 1 end,
               [2] = function() z = z - 1 end, [3] = function() x = x + 1 end}

local function turnRight()
  robot.turnRight()
  f = (f + 1) % 4
end

local function turnLeft()
  robot.turnLeft()
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

local function turn(i)
  if i % 2 == 1 then
    turnRight()
  else
    turnLeft()
  end
end

local function clearBlock(side, cannotRetry)
  while r.suck(side) do
  checkedDrop()
  end
  local status, reason = r.swing(side)
  if status then
    checkedDrop()
  else
    if cannotRetry and reason ~= "air" and reason ~= "entity" then
      return false
    end
  end
  return true
end

local function tryMove(side)
  side = side or sides.forward
  local tries = 5
  clearBlock(side, true)
  while not r.move(side) do
    tries = tries - 1
    if not clearBlock(side, tries < 1) then
      print("Could not break block, please check equipped tool")
      return false
    end
  end
  if side == sides.down then
    y = y - 1
  elseif side == sides.up then
    y = y + 1
  else
    delta[f]()
  end
  return true
end

function moveTo(tx, ty, tz, backwards)
  local axes = {
    function()
      while y < ty do
        tryMove(sides.up)
      end
      while y > ty do
        tryMove(sides.down)
      end
    end,
    function()
      if x < tx then
        turnTowards(3)
        repeat tryMove() until x == tx
      elseif x > tx then
        turnTowards(1)
        repeat tryMove() until x == tx
      end
    end,
    function()
      if z > tz then
        turnTowards(2)
        repeat tryMove() until z == tz
      elseif z < tz then
        turnTowards(0)
        repeat tryMove() until z == tz
      end
    end
  }
  if backwards then
    for axis = 3, 1, -1 do
      axes[axis]()
    end
  else
    for axis = 1, 3 do
      axes[axis]()
    end
  end
end

local function returnTostartPoint()
  if option.u then
    moveTo(0, -1, 0, true)
  elseif option.a then
    moveTo(0, 1, 0, true)  
  else
    if f0 == 0 then
      moveTo(0, 0, -1)
    elseif f0 == 1 then
      moveTo(1, 0, 0)
    elseif f0 == 2 then
      moveTo(0, 0, 1)
    elseif f0 == 3 then
      moveTo(-1, 0, 0)
    else
      moveTo(0, 0, 0)
    end
  end  
end

--- Initialisation

local function goTostartPoint()
local tries = 0
	if option.u then
		repeat 
      r.swing(sides.up) 
      tries = tries + 1 
    until r.move(sides.up) or tries > 5    
	elseif option.a then
    repeat 
      r.swing(sides.down) 
      tries = tries + 1 
      until r.move(sides.down) or tries > 5 
	else
    repeat 
      r.swing(sides.forward) 
      tries = tries + 1
      until r.move(sides.forward) or tries > 5 
	end
  if tries > 5 then
    error("Could not break block, please check equipped tool.")
    return false
  end
end

local function rotate(destination)
  local target = {y=destination.y}
  if math.abs(destination.x) > math.abs(destination.z) then
    if destination.x < 0 then
      turnLeft()
      target.x = destination.z
      target.z = -destination.x
    else
      turnRight()
      target.x = -destination.z
      target.z = destination.x
    end 
  else
    if destination.z < 0 then
      turnLeft()
      turnLeft()
      target.x = -destination.x
      target.z = -destination.z
    else
      target.x = destination.x
      target.z = destination.z
    end
  end
return target
end

--- Maintenance
function checkedDrop(force)
  local energyFraction = computer.energy() / computer.maxEnergy() 
  local maintenance = false

  if r.durability == nil or (r.durability() < setDurability) or (energyFraction < energyLimit) then
    maintenance = true
  end
  
  local empty = 0
  for slot = 1, 16 do
    if robot.count(slot) == 0 then
      empty = empty + 1
    end
  end
  
  if not dropping and empty == 0 or force and empty < 16 or maintenance then
    local ox, oy, oz, of = x, y, z, f
    dropping = true
    returnTostartPoint()
    if maintenance then
      computer.shutdown()    
    else
      turnTowards((f0 - 1) % 4)
      for slot = 1, 16 do
        if robot.count(slot) > 0 then
          robot.select(slot)
          local wait = 1
          repeat
            if not robot.drop() then
              os.sleep(wait)
              wait = math.min(10, wait + 1)
            end
          until robot.count(slot) == 0
        end
      end
      robot.select(1)
      dropping = false    
      moveTo(ox, oy, oz, true)
      turnTowards(of)
    end  
  end
end


--- Dig functions

local function uTurn(target,i)
  if target.x > 0 then
    turn(i)
    tryMove()
    turn(i)
  elseif target.x < 0 then
    turn(i+1)
    tryMove()
    turn(i+1)
  end
end

local function digLayer(target)
  if target.x ~= 0 then
    for i = 1, math.abs(target.x) do 
      for j = 1, target.z do
        tryMove()
      end
      uTurn(target,i)
    end
  end
  for j = 1, target.z do
    tryMove()
  end
end

local function findNext(target)
  local destination = {y = target.y}
  if  target.x % 2 == 0 then
    destination.x = -target.x
    destination.z = -target.z
  else
    destination.x = target.x
    destination.z = -target.z
  end
  return destination  
end

local function excavate()
  local p = p
  local t = rotate(p)
  digLayer(t)
  if p.y ~= 0 then  
    p = findNext(t)
    if option.a then
      for i = 1, -p.y  do
        tryMove(sides.down)
        t = rotate(p)
        digLayer(t)
        p = findNext(t)
      end 
    else 
      for i = 1, p.y do
        tryMove(sides.up)
        t = rotate(p)
        digLayer(t)
        p = findNext(t)
      end
    end
  end
end

------ Main thread
goTostartPoint()
excavate()
returnTostartPoint()
checkedDrop(true)
turnTowards(f0)
