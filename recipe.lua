local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local shell = require("shell") 
local robot = require("robot")
local sides = require("sides")
local rs = component.redstone
local r = component.robot
local ic = component.inventory_controller
--------------------------------------------
local arg, option = shell.parse(...)

local recipefile = "/usr/recipes.txt"
local recipelist = "/usr/recipe.list"

if option.h then
  io.write("\nUsage: Recipe [-hcd] \n")
  io.write(" -h: display this message \n")
  io.write(" -c: craft once and record output after that\n")
  io.write(" -d: record dummy recipes for complexity calculations\n")
  return
end

local recipe = {} --- Container for the current recipe

-------------------------- Helper functions ---------------------------
-- Format the inventory controller labels to be more manageable
local function labelFormat(label)
  local label = string.lower(label)
  label = string.gsub(label, "%s+", "_")
  label = string.gsub(label, "[%(%)]", "")
  label = string.gsub(label, "^%d", "_%0")
  return label
end

-- Convert slotnumber of inventory to corresponding 3x3 slotnumber. 
local function inventoryToGrid(slot, row_length)
  local number = math.floor(slot / row_length) * 3 + slot % row_length
  return number 
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
  return true
end

local function saveSortedTable(filename,data)
  local a = {}
  for k in pairs(data) do table.insert(a, k) end
  table.sort(a)
  local file = io.open(filename, "w")
  for i,k in ipairs(a) do
    if i == 1 then
      file:write(k .."=".. serialization.serialize(data[k]))
    else
      file:write(",\n" .. k .."=".. serialization.serialize(data[k]))
    end
  end
  file:close()
  return true
end

local function readTable(filename)
  local file = io.open(filename)
  local str = "{" .. file:read("*a") .. "}"
  file:close()
  return serialization.unserialize(str) 
end

local function promptComplexity(message)
  io.write("\n" .. message)
  io.flush()
  local complexity = tonumber(io.read())
  if (type(complexity) == "number") then
    return complexity 
  end
  
  return promptComplexity(message)
end

-------------------------- Recipe management -----------------------------

local recipes = readTable(recipefile) -- Loads all older recipes into memory

local recipeComplexity

local function getComplexity(label)
  local complexity = false
  if not recipes[label] then
    local message ="No recipe for component \"".. label .. "\" please provide complexity value: "
    complexity = promptComplexity(message)
    if complexity == 0 then
      recipes[label] = {1,0,{}}
      saveSortedTable(recipefile,recipes)
      return 0
    end
  elseif not (type(recipes[label][2]) == "number") then
    complexity = recipeComplexity(recipes[label][2])
    if complexity then
      table.insert(recipes[label],2,complexity)
      saveSortedTable(recipefile,recipes)
      return complexity
    end
  else
    return recipes[label][2]
  end
  return complexity
end

function recipeComplexity(grid)
  local ingredients = {}
  rComplexity = -1
  for k,v in pairs(grid) do
      if not ingredients[v] then
        ingredients[v] = true
        local complexity = getComplexity(v)
        if not complexity then
          error("\n unable to get complexity of " .. v .. " aborting.\n")
        end
         if complexity >= rComplexity then
            rComplexity = complexity + 1
         end
      end
  end
  return rComplexity
end

local function readOutput()
  local info = ic.getStackInInternalSlot(4)
  recipe.amount, recipe.label = info.size, labelFormat(info.label)
  return true
end

local function readGrid()
  recipe.grid = {}
  local slot = 0
  while slot < 12 do
    slot = slot + 1
    if slot % 4 ~= 0 then
      local info = ic.getStackInInternalSlot(slot)
      if info then
        local number = inventoryToGrid(slot, 4)
        recipe.grid[number] = labelFormat(info.label)
      end
    end
  end
  return true
end

local function readComplexity()
  if not recipe.grid then
    return false
  end
  recipe.complexity = recipeComplexity(recipe.grid)
  return true
end

local function recordRecipe()
  if (recipe.label and next(recipe.grid)) or (recipe.label and option.d) then
    if not recipes[recipe.label] then
      recipes[recipe.label] = {recipe.amount,recipe.complexity,recipe.grid}
      saveSortedTable(recipefile,recipes)
    end
    return true, recipe.label
  end
  return false
end

------------------------------------ Main thread ------------------------
r.select(4)
if option.c then
  readGrid()
  readComplexity()
  if component.crafting.craft(1) then
  readOutput()
  local status, label = recordRecipe()
  print(status, label)
  end
elseif option.d and (r.count(4) > 0) then
  readOutput()
  --print(recipe.label)
  recipe.complexity = getComplexity(recipe.label)
  recipe.grid = {}
  recordRecipe()
elseif (component.crafting.craft(0) and (r.count(4) > 0)) then
    readOutput()
    readGrid()
    readComplexity()
    local status, label = recordRecipe()
    print(status, label)
else
    print("Not a valid recipe")
end

