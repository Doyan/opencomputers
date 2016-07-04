-- Script to craft items. v.1.0
local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local shell = require("shell") 
local robot = require("robot")
local sides = require("sides")
local rs = component.redstone
local r = component.robot
local ic = component.inventory_controller
--------------------------------------------)
local arg, option = shell.parse(...)

if #arg < 1 or option.h then
  io.write("Usage: craft [-sh] item [number] \n")
  io.write(" -s: shutdown when done \n")
  io.write(" -h: display this message \n")
  io.write(" item: the item to be crafted, ie. minecraft:stick etc")
  io.write(" number: the number of items to be crafted")
  return
end

local recipefile = "/usr/recipes.txt"
local inventoryfile = "/usr/inventory.txt" 

----------------------- Init --------------------------------------
local own = {["path"] = ""} -- own inventory
own.size = r.inventorySize()
own["empty"] = {["total"] = own.size }
local ext = {} -- external ingredient listing

-- Inventories
local inventory = {
  [0] = own,
  [1] = {["path"] = "RF",    ["side"] = sides.forward},
  [2] = {["path"] = "RFU",  ["side"] = sides.forward},
  [3] = {["path"] = "RFUU", ["side"] = sides.forward},
  [4] = {["path"] = "L",  ["side"] = sides.forward}
 }

local moved = "" -- string to hold movements

---------------------- Helper functions ---------------------------

-- Format the inventory controller labels to be more manageable
local function labelFormat(label)
  local label = string.lower(label)
  label = string.gsub(label, "%s+", "_")
  label = string.gsub(label, "[%(%)]", "")
  label = string.gsub(label, "^%d", "_%0")
  return label
end

local function gridToGrid(slot, rows_a, rows_b)
  local number = math.floor(slot / rows_a) * rows_b + slot % rows_a
  return number 
end

local function gridToInventory(number)
  local slot = math.floor(number / 3) * 4 + number % 3
  return slot 
end

-- Since robot.select() is an indirect call, we can speed things up a bit.
local selectedSlot
local function cachedSelect(slot)
  if slot ~= selectedSlot then
    r.select(slot)
    selectedSlot = slot
  end
end

-- Save table, with newline at the first level of a nested structure
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

-- Read table saved according to saveTable's rules
local function readTable(filename)
  local file = io.open(filename)
  local str = "{" .. file:read("*a") .. "}"
  file:close()
  return serialization.unserialize(str) 
end

-- Set the default value of a table
function setDefault (t, d)
  local mt = {__index = function () return d end}
  setmetatable(t, mt)
end
------------------- Navigational functions ---------------------
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

-- Determine if we need to move based on path and movestring
local function needMove(path)
  if path == moved then
    return false
  end
  goHome() -- Hotfix until string comparison method is done
  local new_path = path
  return true, new_path
end

-- Go to a specific inventory
local function goToInventory(num)
  local state, path = needMove(inventory[num].path)
  if state then
    return goAlong(path)
  end
  return true
end

------------------- Inventory management -------------------------------
local nolabel_mt = {
  __index = function () return {["total"] = 0} end,
  }
local noslot_mt = {
  __index = function () return { ["slot"] = false, ["size"] = 0} end}
set

local function incrementTotal(label, amount)
  own[label].total = 
end

local function decrementTotal(label, amount)
  
end

local function defineSlot(num,slot,label, size)
  if not inventory[num] then
    io.write("\nNo inventory with that number\n")
    return false
  elseif num == 0 then
    incrementTotal(true,label,size)
    table.insert(own[label],{["slot"] = slot, ["size"] = size})
  else
    incrementTotal(false,label,size)
    ext[label][num] = {[slot] = size}
  end
end

local function isEmpty(num, slot, empty)
  if not inventory[num] then
    io.write("\nNo inventory with that number\n")
    return false
  elseif num == 0 then
    if empty then
      defineSlot(num,slot,"empty",1)
    else
      own["empty"][slot] = nil
      decrementTotal(true,"empty",1)
    end
  else
    if empty then
      defineSlot(num,slot,"empty",1)
    else
      ext["empty"][slot] = nil
      decrementTotal(false,"empty",1)
    end
  end
end


local function decrementSlot(num, slot, label, amount)
   if not inventory[num] then
    io.write("\nNo inventory with that number\n")
    return false
  elseif num == 0 then
    own[label][slot] = own[label][slot] - amount
    if own[label][slot] < 1 then
      own[label][slot] = nil
      isEmpty(num,slot,true)
    end
  else
    own[label][slot] = own[label][slot] - amount
    if ext[label][slot] < 1 then
      ext[label][slot] = nil
      isEmpty(num,slot,true)
    end
  end
end

local function listOwnInventory()
  for slot = 1, own.size do
    local info = ic.getStackInInternalSlot(slot)
    if info then
      local label = labelFormat(info.label)
      defineSlot(0,slot,label,info.size)
      isEmpty(0,slot,false)
      if own[label].maxSize == 0 then
        own[label].maxSize = info.maxSize
      end
    else
      isEmpty(0,slot,true)
    end
  end
  return true
end

local function listInventory(num)
  if not inventory[num] then
    io.write("\nNo inventory with that number\n")
    return false
  elseif num == 0 then
    listOwnInventory()
  elseif (moved == inventory[num].path) then
    local side = inventory[num].side or sides.forward()
    inventory[num].size = ic.getInventorySize(side)
    for slot = 1, inventory[num].size  do
      local info = ic.getStackInSlot(side, slot)
      if info then
        local label = labelFormat(info.label)
        defineSlot(num,slot,label,info.size)
        isEmpty(num,slot,false)
      else
        isEmpty(num,slot,true)
      end
    end
  else
    io.write("\nNot at inventory " .. num .. ", aborting.\n")
    return false
  end
  os.sleep(0)
end

local function findEmptyNonGrid()
  for slot in pairs(own["empty"]) do
    if slot > 11 or slot == 8 then
      return slot
    end
  end
  return false  
end

-- Find the first empty slot in numbered inventory.
local function findEmptySlot(num)
  local num = num or 0
  if num == 0 then
   return findEmptyNonGrid()
  else
    local slot = next(ext["empty"])
    if slot and (ext["empty"].total > 2) then
      return slot
    end
  end
end

local function internalTransfer(fromSlot, toSlot, amount)
  local label = own[fromSlot]
  local amount = amount or own[label][fromSlot]
  print(label,fromSlot,toSlot)
  local transferred = math.min(amount,own[label][fromSlot],own[label].maxSize - own[label][toSlot])
  local remaining = amount - transferred
  cachedSelect(fromSlot)
  if r.transferTo(toSlot, amount) then
    defineSlot(0,toSlot,label,transferred)
    decrementSlot(0, fromSlot, label, transferred)
    return true, remaining
  end
  return false, remaining
end

local function clearOwnSlot(slot)
  local status, remaining = true, 0
  if own["empty"][slot] == 0 then
    status, remaining = internalTransfer(slot, findEmptyNonGrid())
    while (remaining > 0) and status do
      status, remaining = internalTransfer(slot, findEmptyNonGrid())
    end
  end
  return status
end

local function clearGrid()
  local slot = 0
  while slot < 12 do
    slot = slot + 1
    if slot % 4 ~= 0 then
      local info = ic.getStackInInternalSlot(slot)
      if info then
        if not clearOwnSlot(slot) then
          return false
        end
      end
    end
  end
  return true
end

local function fillUpSlot(slot, label, amount)
  if amount > own[label].maxSize then
    io.write("amount is bigger than max size: ".. own[label].maxSize .."\n")
    return false
  end
  if own[label][slot] == amount then
    return true
  end
  if own[slot] and (own[label][slot] == 0) then
    clearOwnSlot(slot)
  end
  local i = 0
  while (own[label][slot] < amount) and (i < 10) do
    i = i + 1
    print(label, own[label])
    internalTransfer(own[label][#label], slot, amount - own[label][slot])
  end
  return own[label][slot] >= amount
end


local function giveToInventory(num, label, amount)
  -- prel checks
  -- transfer
  -- update inventories
  -- return remaining
end

local function takeFromInventory(num, label, amount)
  -- prel checks
  -- transfer
  -- update inventories
  -- return remaining
end

---------------------------- Crafting ---------------------------------
local queue = {}
local reserved = {}
local needs = {}
local recipes = {}

setDefault(reserved, 0)
 
local function requestItem(label, amount)
  needs[label] = needs[label] or 0
  needs[label] = needs[label] + amount
  return true
end

local function checkOffItem(label, amount)
  if needs[label] then
    needs[label] = needs[label] - amount
    if needs[label] < 1 then
      needs[label] = nil
    end
  end
  return true
end

local function reserveItem(label, amount)
  reserved[label] = reserved[label] + amount
  checkOffItem(label, amount)
  return reserved[label] < own[label].total
end

local function addToQueue(label, amount)
  queue[label] = queue[label] or 0
  queue[label] = math.ceil(queue[label] + amount / recipes[label][1])
  checkOffItem(label, amount)
  return true
end

local function readRecipe(label)
  if not recipes[label] then 
    local rTable = readTable(recipefile)
    if rTable[label] then
      recipes[label] = rTable[label]
      return true
    end
  end
  return false
end

local function getCost(label, amount)
  local cost = {}
  if not recipes[label] then
    if not readRecipe(label) then
      io.write("No recipe for item " .. label .. " aborting.")
      return false
    end
  end
  local recipe = recipes[label]
  local times = math.ceil(amount / recipe[1]) 
  for _,v in pairs(recipe[3]) do
    if not cost[v] then
      cost[v] = 1 * times
    else
      cost[v] = cost[v] + 1 * times
    end
  end
  return cost
end

local function compareCost(cost)
  local status = true
  for k,v in pairs(cost) do
    if not own[k] then
      status = false
      requestItem(k,v)
    elseif own[k].total - reserved[k] < v then
      status = false
      requestItem(k,v - own[k].total + reserved[k])
    else
      reserveItem(k, v)
    end
  end
  return status
end

local function handleRequests()
  local label, amount = next(needs)
  while label do
    local cost = getCost(label, amount)
    if not cost then
      return false
    end
    compareCost(cost)
    addToQueue(label, amount)
    os.sleep(0)
    label, amount = next(needs)
  end
end

local function orderByComplexity(recipes,item_1, item_2)
  return recipes[item_1][2] < recipes[item_2][2]
end

local function orderQueue()
  local labels = {}
  for label in pairs(queue) do labels[#labels+1] = label end
  table.sort(labels, function (a,b) return orderByComplexity(recipes, a,b) end)
  for n,label in ipairs(labels) do
    labels[n] = {label, queue[label], recipes[label][2]}
  end
  return labels
end

local function makeQueue(label, amount)
  requestItem(label,amount)
  handleRequests()
  queue = orderQueue()
end

local function setTable(label, times)
  local grid = recipes[label][3]
  local slot = 0
  while slot < 12 do
   slot = slot + 1
   local number = gridToGrid(slot, 4, 3)
    if slot % 4 ~= 0 then
      if not grid[number] then
        clearOwnSlot(slot)
      else
        print(grid[number])
        fillUpSlot(slot, grid[number], times)
      end
    end
  end
end

local function craft(label, amount)
  -- setTable
  -- select output slot
  -- craft
  -- return remaining
end

local function doQueue()
  setTable(queue)
end
------------------------------ Functions for testing ------------------

local function showInventory(num)
  local num = num or 0
  if num == 0 then
    io.write("\n Showing own inventory: \n")
  else
    io.write("\n Showing inventory nr " .. num .. ": \n")
  end
  for slot = 1, inventory[num].size do
    if inventory[num][slot] then
      if not inventory[num][slot].label then
        io.write("\nInventory is empty\n")
      else
        io.write("\n slot " .. slot .. ": " .. inventory[num][slot].size .. " " .. inventory[num][slot].label)
      end
    end
  end
  os.sleep(0)
end


------------------------------------ Main loop -------------------------
local label, amount = arg[1], tonumber(arg[2])
listInventory(0)
makeQueue(label,amount)
setTable(label,amount)
--for k,v in pairs(ext) do print(k,v.total) end
--doQueue()
--cachedSelect(4)
--component.crafting.craft(1)


