local component = require("component")
local computer = require("computer")
local keyboard = require("keyboard")
local fs = require('filesystem')
local serialization = require('serialization')
local event = require("event")
local shell = require("shell") 
local sides = require("sides")
local term  = require("term")
local r = component.robot
local rs = component.redstone


---------------- init --------------------------

local sleepTime = 180
local energyFraction = 0.20
local crops = {"wood", "cactus", "sugarcane"}
local filename = "/usr/farm_specs.txt"
local plant = ""
local farm = {}
local home_x = 0
local drop_x = 2
local x, y, z, f = 0, 0, 0, 0

--- Misc

local function waitToPass(side)
  local times = 0
  while r.detect(side) and times < 10 do
    os.sleep(5)
    times = times + 1
  end
  return times < 10
end

local selectedSlot
local function cachedSelect(slot)
  if slot ~= selectedSlot then
    r.select(slot)
    selectedSlot = slot
  end
end

local function recharge()
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

local function readSpecs(plant)
  local file = io.open(filename, "r")
  local specs = serialization.unserialize(file:read("*a"))
  file:close()
  farm = specs[plant]
  farm.slots = specs.slots
  return true
end

--- Navigation ------------------

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

local function move(side, force)
  local force = force or false
  if force then
    r.swing(side)
  end
  if (side == sides.forward and r.move(side)) then
    delta[f]()
    return true
  elseif (side == sides.up and r.move(side)) then
    y = y + 1
  elseif (side == sides.down and r.move(side)) then
    y = y - 1
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
    move(sides.forward, force)
  end
  return true
end

local function goToY(ty, force)
  local force = force or true
  while y < ty do
    move(sides.up, force)
  end
  while y > ty do
    move(sides.down, force)
  end
  return true
end

local function goToZ(tz, force)
  local force = force or true
  if z > tz then
    turnTowards(2)
  elseif z < tz then
    turnTowards(0)
  end
  while z ~= tz do
    move(sides.forward, force)
  end
  return true 
end

local function uTurn(i)
  turnTowards(1)
  for i = 1, farm.row_gap do
    move(sides.forward, true)
  end
  if i % 2 == 0 then
    turnLeft()
  else
    turnRight()
  end
end

local function goToZero()
if z ~= 0 then
  if plant == "wood" then
    turnTowards(3)
    move(sides.forward, true)
    goToZ(0)
  else
    goToY(2)
    goToZ(1)
    goToY(0)
    goToZ(0)
  end
end
end

local function goHome()
  goToZero()
  goToX(home_x)
  turnTowards(0)
  return true
end


--- Maintenance -----
local function goDropOurStuff()
goToZero()
goToX(drop_x)
for slot = 1, r.inventorySize() do
  if farm.slots[slot] then 
    while r.count(slot) > farm.slots[slot] do
      cachedSelect(slot)
      r.drop(sides.down, r.count(slot) - farm.slots[slot])
    end
  else
    while r.count(slot) > 0 do
      cachedSelect(slot)
      r.drop(sides.down)
    end
  end
end
end

local function goCharge()
  goHome()
  return recharge()
  end

local function goGetSeeds()
  goToZero()
  goToX(farm.seed_x)
  cachedSelect(farm.seed_slot)
  return r.suck(sides.down, 16)
end

local function verifyGood()
  if farm.slot and (r.count(farm.slot) < 1) then
    error("\n No " .. plant .. " in slot: " .. farm.slot .. ", aborting.")
  elseif farm.seed_slot and (r.count(farm.seed_slot) < 8) then
    local status = goGetSeeds()
    if not status then
      error("\n Not enough seed items for safe operation")
    end
  elseif (computer.energy() / computer.maxEnergy()) < energyFraction then
    local status = goCharge()
    if not status then
      error("\n Energy low, check charger")
    end
  end
end

local function goToStart()
  goToZero()
  verifyGood()
  goToX(farm.start_x)
  turnTowards(0)
  move(sides.forward,true)
  goToY(farm.start_y)
  while z < farm.start_gap do
    move(sides.forward,true)
  end
end
---- Main operations -----------

local function isPlant(side,reason)
  local reason = reason or "solid" 
  if (plant == "sugarcane") and (reason == "passable") then
    return true
  end
  cachedSelect(farm.slot)
  return r.compare(side)
end

local function replant()
  if r.count(farm.seed_slot) > 1 then
    cachedSelect(farm.seed_slot)
    r.place(sides.down)
    return true
  end
  return false
end

local function doTree()
  move(sides.forward, true)
  while isPlant(sides.up) do
    move(sides.up, true)
  end
  goToY(farm.start_y)
  while isPlant(sides.down) do
      move(sides.down, true)
  end
    goToY(farm.start_x)
  if not replant() then
    goGetSeeds()
  end
  return checkBlock()
end

local function doReedLike()
  goToY(farm.start_y - 2, true)
  return goToY(farm.start_y)
end

local doPlant = {
  ["wood"] = function () return doTree() end,
  ["cactus"] = function () return doReedLike() end,
  ["sugarcane"] = function () return doReedLike() end
}

function checkBlock()
  local side = farm.check_side
local occupied, reason = r.detect(side)
  if not occupied then
    return true
  end
  if occupied then
    if isPlant(side,reason) then
      return doPlant[plant]()
    elseif reason == "solid" then
      return r.swing(side)
    elseif reason == "entity" then
      return waitToPass(side)
    end
    return false 
  end
end

local function limit(f)
  if f == 0 then
    return z < farm.row_length + farm.start_gap
  elseif f == 2 then
    return z > farm.start_gap
  end
  return true
end 

local function doRow()
  while limit(f) do
    if not checkBlock() then
      goHome()
      error("Path blocked, aborting and returning home")
    end
    move(sides.forward)
    r.suck(sides.down, 32)
  end
  return true
end

local function doRows()
  for i = 1, farm.rows - 1 do
    doRow()
    uTurn(i)
  end
    doRow()
  return true
end

local function doCrop(crop,continous)
  local continous = continous or false
  plant = crop
  readSpecs(plant)
  goToStart()
  doRows()
  goToZero()
  if not continous then
    goDropOurStuff()
    verifyGood()
    goHome()
  return true
  end
  return true
end

local function doCrops()
  for i, crop in ipairs(crops) do
    doCrop(crop, true)
  end
  goDropOurStuff()
  verifyGood()
  goHome()
end

local function printLog(runs)
  local f = io.output("/usr/farm.log")
  f:write("\n============== Farm Log ============== \n")
  f:write("Runtime (Deltas): \n \n")
  for k,v in ipairs(runs) do
    f:write("Run nr." .. k .. ": " .. v .. " seconds \n")
  end
  f:close()
end

local running = true
term.clear()
local runs = {}
while running do
  local start_time = computer.uptime()
  if #runs % 2 == 0 then
    doCrops()
  else
    doCrop("wood")
  end
  local run_time = computer.uptime() - start_time
  table.insert(runs,run_time)
  local event, address, char, code = event.pull(sleepTime, "key_down")
  if code == keyboard.keys.q then
    printLog(runs)
    return
  end
end






