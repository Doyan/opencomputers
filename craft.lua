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

---------------------- Helper functions ---------------------------

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
local function findEmptySlot(bulk)
  local bulk = false or bulk 
  for slot = 1, r.inventorySize() do
    if robot.count(slot) == 0 then
      return slot
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
  for k, item in ipairs(inventory) do
    if item.label==label then return k end
  end
  return false
end

-------------------- Navigational functions ---------------------
---- needs refining, add way to verify correct starting point and orientation

-- Table to translate characters to moves.
local action = {
  [string.byte("F")] = function () return r.move(sides.forward) end,
  [string.byte("R")] = function () return r.turn(true) end,
  [string.byte("L")] = function () return r.turn(false) end,
  [string.byte("U")] = function () return r.move(sides.up) end,
  [string.byte("D")] = function () return r.move(sides.down) end,
  [string.byte("B")] = function () return r.move(sides.back) end
}

--- table to invert moves
local oppositeBytes = {
 [string.byte("F")] = string.byte("B"),
 [string.byte("R")] = string.byte("L"),
 [string.byte("L")] = string.byte("R"),
 [string.byte("U")] = string.byte("D"),
 [string.byte("D")] = string.byte("U"),
 [string.byte("B")] = string.byte("F")
}

local moved = "" -- string to hold movements

-- Reverse a given path string
local function reversePath(path)
  local str = string.reverse(path)
  local new_path = "" 
  for idx = 1, #str do
    local byte = str:byte(idx)
    new_path = new_path .. string.char(oppositeBytes[byte])
  end
  return new_path
end

-- Traverse a given path string
local function goAlong(path)
  local bytes = {}
  for idx = 1, #path do
    local num = path:byte(idx)
    if not action[num]() then
      print("path blocked")
      local tries = 0
      repeat
        os.sleep(1)
        state = action[num]()
        tries = tries + 1
      until state or tries > 10
      if not state then
        print("stopping, help me!")
        return false
      end
    end
  end
  moved = moved .. path
  return true
end

-- Traverse inverted movestring resetting moves.
local function goHome()
  local path = reversePath(moved)
  if goAlong(path) then
  moved = ""
  return true
  end
  return false 
end

------------------- Inventory management ----------------------------
local own = {}

local inventory = {
 [1] = {["path"] = "RF",    ["side"] = sides.forward},
 [2] = {["path"] = "RFRF",  ["side"] = sides.left}
 }
 
-- record contents OwnInventory, slot-wise and ingredient-wise
local function takeOwnInventory()
  own.size = r.inventorySize()
  for slot = 1, own.size do
    local info = ic.getStackInInternalSlot(slot)
    if info then
      local label = labelFormat(info.label)
      own[slot] = {
        ["slot"] = slot,
        ["label"] = label,
        ["size"] = info.size,
        ["maxSize"] = info.maxSize
      }
      if not own[label] then
        own[label] = {}
        own[label].total = 0
      end
      table.insert(own[label],own[slot])
      own[label].total = own[label].total + own[slot].size
    end
  end 
  return true
end

-- record contents of external inventory, slot-wise and ingredient-wise
local function takeInventory(num)
  local side = inventory[num].side or sides.forward()
  inventory[num].size = ic.getInventorySize(side)
  if inventory[num].size then
    for slot = 1, inventory[num].size do
      local info = ic.getStackInSlot(side,slot)
      if info then
        local label = labelFormat(info.label)
        inventory[num][slot] = {
          ["inventory"] = num,
          ["slot"] = slot,
          ["label"] = label,
          ["size"] = info.size,
          ["maxSize"] = info.maxSize
        }
        if not inventory[label] then
          inventory[label] = {}
          inventory[label].total = 0
        end
        table.insert(inventory[label],inventory[num][slot])
        inventory[label].total = inventory[label].total + inventory[num][slot].size
      end
    end
  end
  return true
end

-- Move to selected inventory and record its contents
local function goTakeInventory(num)
  goAlong(inventory[num].path)
  takeInventory(num)
  goHome()
end

local function organiseOwn()

-- remove stuff from grid
end

-- Take  items from external inventory
local function takeFromInventory(inventory_number, item, count)
  local num = inventory_number
  goAlong(inventory[num].path)
  
-- find empty slot and item to take 
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
-- verify empty grid
-- place ingredients
end


-- Function for testing
local function showInventory(num)
  local inventory = inventory[num] or own
  if num then
    io.write("\n Showing inventory nr " .. num .. ": \n")
  else
    io.write("\n Showing own inventory: \n")
  end
  for slot = 1, inventory.size  do
    if inventory[slot] then
      io.write("\n slot " .. slot .. ": " .. inventory[slot].size .. " " .. inventory[slot].label)
    end
  end
end

-- Function for testing
local function showItem(label)
  local total = 0
  if own[label] then
    io.write("\n" .. own[label].total .. " ".. label .. "(s) in own inventory: \n")
    for k,v in ipairs(own[label]) do
      io.write("\n" .. v.size .. " in slot " .. v.slot) 
    end
  total = total + own[label].total  
  end
  if inventory[label] then
    io.write("\n \n" .. inventory[label].total .. " " .. label .. "(s) in external inventories: \n")
    for k,v in ipairs(inventory[label]) do
    io.write("\n" .. v.size .. " in slot " .. v.slot .. " of inventory " .. v.inventory)
    end
  total = total + inventory[label].total
  end
  io.write("\n -------------------------------------------- \n")
  io.write("For a total of " .. total .. " " .. label .. "(s) \n")
end

---------------------- Main thread --------------------------------------
takeOwnInventory()
goTakeInventory(1)
showInventory()
showItem("furnace")

