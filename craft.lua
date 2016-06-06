-- Script to craft items. v.1.0
local component = require("component")
local computer = require("computer")
local shell = require("shell") 
local robot = require("robot")
local sides = require("sides")
local rs = component.redstone
local r = component.robot
local ic = component.inventory_controller
--------------------------------------------
local arg, option = shell.parse(...)

if #arg < 1 or option.h then
  io.write("Usage: craft [-sh] item [number] \n")
  io.write(" -s: shutdown when done \n")
  io.write(" -h: display this message \n")
  io.write(" item: the item to be crafted, ie. minecraft:stick etc")
  io.write(" number: the number of items to be crafted")
  return
end

local side = false

if #arg == 1 then
  side = sides[arg[1]]
end




-------------------- Helper functions ---------------------------

-- Format the inventory controller labels to be more manageable
local function labelFormat(label)
  local label = string.lower(label)
  label = string.gsub(label, "%s+", "_")
  return label
end

-- Convert slotnumber of inventory to corresponding 3x3 slotnumber. 
local function inventoryToGrid(slot, row_length)
  local number = math.floor(slot / row_length) * 3 + slot % row_length
  return number 
end

-- Look for the first empty slot in our inventory.
local function findEmptySlot()
  for slot = 1, r.inventorySize() do
    if slot % 4 == 0 or slot > 12 then
      if robot.count(slot) == 0 then
        return slot
      end
    end  
  end
end

-- Since robot.select() is an indirect call, we can speed things up a bit.
local selectedSlot
local function cachedSelect(slot)
  if slot ~= selectedSlot then
    r.select(slot)
    selectedSlot = slot
  end
end

-- Find the first slot with a certain label
local function findLabeledSlot(inventory, label)
  for k, item in pairs(inventory.slot) do
    if item.label==label then return k end
  end
  return nil
end

-------------------- Navigational functions ---------------------
---- needs refining, add way to verify correct starting point and orientation
-- consider to use a movelist as in miner.lua

local x, y, z, f = 0, 0, 0, 0
local f0 = f

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


------------------- Inventory management ----------------------------
local own_inventory = { slot = {}}

-- Output record of OwnInventory
local function takeOwnInventory()
  local inventory = { slots = {}, }
  inventory.size = r.inventorySize()
  for slot = 1, inventory.size do
    local info = ic.getStackInInternalSlot(slot)
    if info then
      local label = labelFormat(info.label)
      inventory.slots[slot] = {["label"] = label, ["size"] = info.size}
    end
  end 
  return inventory
end

-- Output record of external inventory
local function takeInventory(side)
  local inventory = { slots = {}}
  inventory.size = ic.getInventorySize(side)
  if inventory.size then
    for slot = 1, inventory.size do
      local info = ic.getStackInSlot(side,slot)
      if info then
        local label = labelFormat(info.label)
        inventory.slots[slot] = {["label"] = label, ["size"] = info.size}
      end
    end
  end
  return inventory
end

-- Take  items from external inventory
local function takeFromInventory(inventory_number, item, count)
-- move to inventory[inventory_number]
-- find itemslot or empty slot and item to take 
-- decrement giving inventory update OwnInventory
end

-- Give items to external inventory
local function addToInventory(inventory_number, item, count)
-- move to inventory[inventory_number]
-- find empty slot or item slot in inventory[inventory_number]
-- decrement OwnInventory update recieving inventory
end

--------------------- Recipe related ------------------------------------

local function chestRenumber(inventory)
  local recipe = { slots = {}}
  for slot, item in pairs(inventory.slots) do
    local number = inventoryToGrid(slot,9)
    recipe.slots[number] = item
  end
  return recipe
end 

local function setTable()
end

---------------------- Main thread --------------------------------------

own_inventory = takeOwnInventory()


--inventory = chestRenumber(inventory)
for key,item in pairs(own_inventory.slots) do
  io.write(key .." "..item.label.." "..item.size.."\n")
end

