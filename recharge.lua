-- Script to charge up a robot. v.1.1
local component = require("component")
local computer = require("computer")
local shell = require("shell") 
local robot = require("robot")
local sides = require("sides")
local rs = component.redstone
local r = component.robot
--------------------------------------------
local arg, option = shell.parse(...)


if #arg > 1 or option.h then
  io.write("Usage: recharge [-sh] [side] \n")
  io.write(" -s: shutdown when done \n")
  io.write(" -h: display this message \n")
  io.write(" side: the side where the charger is  <optional>")
  return
end

local side = false

if #arg == 1 then
  side = sides[arg[1]]
end


local function checkForcharger()
  for side = 0,5 do
    info = component.geolyzer.analyze(side) 
    if info and info.name == "OpenComputers:charger" then
      return side 
    end
  end
  return false
end

local function charge(side)
  rs.setOutput(side,15)
  os.sleep(5)
end

--- Main thread
if not side then
  if component.isAvailable("geolyzer") then
    side = checkForcharger()
    if not side then
    io.write("No charger nearby!")
    return
    end
  else
  io.write("No geolyzer installed, call with <side> argument")
  return  
  end
end

while computer.energy() / computer.maxEnergy() < 0.995 do
  local start_value = computer.energy()
  charge(side)
  if start_value > computer.energy() then
    io.write("Charger out of power!")
    break
  end
end
rs.setOutput(side,0)

if option.s then
    computer.shutdown()
end
