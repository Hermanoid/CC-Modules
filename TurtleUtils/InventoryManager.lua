--InventoryManager 
-- By Lucas Niewohner (Hermanoid)

--Inventories can be fairly easily accessed via conventional methods, but those require a very brief period of wait for the turtle to change slots.  This is bad.  
-- Hence, this.  This a) provides a more intuitive inventory interface, and b) work with future projects of mine where Inventory reads aren't instantanious.

--Setting Variables
--If our inventory supports turtle.getInventory (native Turtle API does not) then this will determine how many uncertain slots are needed before the inventory update goes from individual slot polling to a full inventory transfer.
FullLoadThreshold = 3



--Test Function
function recursiveTablePrint(t, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(t) do
		if k == "__index" then
			print("-")	
		else if type(v) == "table"  then
			print(string.rep(" ",indent)..k..":  ")
			recursiveTablePrint(v,indent+4)
		else if type(v) == "boolean" then 
			local wordForm
			if v then
				wordForm = "true"
			else
				wordForm = "false"
			end
			print(string.rep(" ",indent)..k..":  "..wordForm)
		else if type(v) ~= "function" and type(v) ~= "thread" then
			print(string.rep(" ",indent)..k..":  "..v)
		end
	end
-- Uhh...  Can't say I know why my compiler wanted these, but it did, and it works now.  Huh.
end
end
end
end

function uncertainSlots(inventory)
	uncertainSlots = {}
	for i=1,16 do
		if not inventory[i]._isCertain then table.insert(uncertainSlots,inventory[i],i)
	end
	return uncertainSlots
end


Stack = {
	count = 0,
	itemData = {},
	name = "",
    --These may be added later
    friendlyName = "",
	hasValue = false,
	_isCertain = true
}

function Stack:new(itemData,o)
	o = o or { }
	itemData = itemData or { }
    setmetatable(o, self)
    self.__index = self

    --When using Stack, use count, because itemData.count isn't used or updated.
    o.count = itemData.count or 0
    --Same goes for for name
    o.name = itemData.name or ""
    --Store the original itemData away, just in case we want some original data.
    o.itemData = itemData
    --Does this Stack even contain items?  If not, it's just a placeholder, and that is determined here
    o._hasValue = itemData.count ~= 0
    return o
end

--Nullify stuff and return Stack to state of _hasValue = false
function Stack:clear()
	self = Stack:new(nil,self)
end

--Empties the Stack if quanitity == 0.  Complicated stuff
function Stack:_checkToClear()
	if self.quanitity == 0 then
		Stack:clear()
	end
end

--@param itemName is the ID of the item, not the friendly name
function Stack:verifyValue(itemName,throwError)
	if not self._hasValue then
		if throwError then
			error("This Stack has no Value!  (Is Empty!)")
		else
			return false
		end
	end
	if self.itemData.name ~= itemName then
		if throwError then
			error("This is Stack is not a "..itemName..", rather, it is a "..self.itemData.name..".  This error is generally thrown when attempting to pull an item (like dirt) from a slot that isn't the same item (like stone).")
		else
			return false
		end
	end
	return true
end


--These functions here aren't intended to be messed around with by the user.  They use the Inventory Prototype below.  
--These are just here for convenience
--@return Two Items:  1. Overflow (portion of "amount" left over after withdraw) 2. New Stack Quantity
function Stack:withdraw(itemData,amount)
	self:verifyValue(itemData.name,true)
	self.count = self.count - amount
	local Overflow = 0
	if self.count <= 0 then
		Overflow = self.count * -1
		self:clear()
	end
	return Overflow, self.count
end

--@return Two Items:  1. Overflow (portion of "amount" left over after deposit) 2. New Stack Quantity
function Stack:deposit(itemData,amount)
	self:verifyValue(itemData.name,true)
	self.count = self.count + amount
	local Overflow = 0
	if self.count>= self.itemMax then
		Overflow = self.count - self.itemMax
		self.count = self.itemMax
	end
	return Overflow, self.count
end


Inventory = {
	ti = {},
	_on = true
}
for i=1,16 do
	Inventory[i] = Stack:new()
end
--Instantiate a new Inventory, reading from a specific TURTLE INSTANCE!!  (how can that change, you ask?  Just you wait...)
function Inventory:new(turtleInstance,o)
    o = o or { }
    turtleInstance = turtleInstance or turtle --If somebody is just using a normal turtle like normal people (crazy concept), let them call Inventory:new() and not worry about passing in the turtle api.
    if turtleInstance == nil then
		error("Provided turtleInstance (arg 1) is nil, and no (normal) turtle API was found!")
    end
    setmetatable(o, self)
    self.__index = self
	o.ti = turtleInstance
	return o
end

function Inventory:on( )
	self._on = true
end
function Inventory:off()
	self._on = false
end
--Update any uncertain slots
function Inventory:update()
	uSlots = uncertainSlots(self)
	--Some forms of a turtle instance may provide an all-in-one inventory read utility, which, if avaiable, should be more efficient then individual polling.
	if self.ti.getInventory then
		if #uSlots >= FullLoadThreshold then
			for slot, value in ipairs(self.ti.getInventory()) do 
				self[slot] = Stack:new(value);
			end
		else
			for slot,_ in pairs(uSlots) do
				self[slot] = Stack:new(self.ti.getItemDetail(slot))
			end
		end
	else
		for slot,_ in pairs(uSlots) do
			self[slot] = Stack:new(self.ti.getItemDetail(slot))
		end
	end
end

--Disregard efficiency concerns and time saved via uncertain slot usage, and just completly reload inventory data, uncertain or no.
function Inventory:reload()
	if self.ti.getInventory then
		for slot, value in ipairs(self.ti.getInventory()) do 
			self[slot] = Stack:new(value);
		end
	else
		for i=1,16 do
			self[slot] = Stack:new(self.ti.getItemDetail(i))
		end
	end
end

--This function will return the slot if it's certain, and certainize it if it isn't
function Inventory:slot(slot)
	if self[slot]._isCertain then 
		return self[slot]
	else
		self[slot] = Stack:new(self.ti.getItemDetail(slot))
		return self[slot]
	end
end

--@param func is a function accepting slotNumber and slotValue as arguments
function Inventory:forEach(func)
	for i=1,16 do 
		func(i, self[i])
	end
end
--@param predicate is a function determining whether or not to include the slot in the return list (it needs to return a boolean).  It can accept slotNumber and slotValue as arguments
function Inventory:where(predicate)
	output = {}
	for i=1,16 do
		if predicate(i,self[i]) then
			table.insert(output,self[i],i)
		end
	end
	return output
end
--@param func is a function that changes each slot into a new data value.  It can accept slotNumber and slotValue as arguments.
function Inventory:select(func)
	output = {}
	for i=1,16 do
		output[i] = func(i,self[i])
	end
	return output
end
function Inventory:slots(itemName)
	return self:where(
		function(slotNumber, slotValue) 
				return slotValue.name == itemName
			end)
end
--This returns two values:  The quantity of items named itemName in this inventory, and then all slots that actually contain these items, since they need to be grabbed to calculate quantity and probably will be needed when using this function.
function Inventory:count(itemName)
	slots = self:slots(itemName)
	count = 0
	for slot,value in pairs(slots) do
		count = count + value.count
	end
	return count, slots 
end
--Checks if the Inventory has at least one slot containing an item with name itemName
function Inventory:contains(itemName)
	for i=1,16 do
		if self[i].name == itemName then return true end
	end
	return false
end

--temporary test utility
function Inventory:printAll()
	self:fill()
	for i=1,16 do
		print(i..":  "..self[i].name.." ("..self[i].count..")")
	end
end

--Ironically, I have an unfinished testing program that is called and does this.
testTurtle = { }
testTurtle.slots = {
	{name = "Cobble",count = 5},
	{name = "",count = 0},
	{name = "Dirt",count = 2},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "The secret of the universe!  (exclusive edition)",count = 1},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "",count = 0},
	{name = "Beef and Noodle Stew?",count = 36},
	{name = "",count = 0},
	{name = "A really nice steak.  Yum.",count = 1},
}
testTurtle.getItemDetail = function(slotNum)
	if slotNum then
		return testTurtle.slots[slotNum] 
	else
		return testTurtle.slots[0]
	end
end

inv = Inventory:new(testTurtle)
inv:printAll()