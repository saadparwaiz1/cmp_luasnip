local M = {}
local magic = {
	["("] = true,
	[")"] = true,
	["."] = true,
	["%"] = true,
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["?"] = true,
	["["] = true,
	["]"] = true,
	["^"] = true,
	["$"] = true,
	a = "a",
	c = "\t",
	d = "0",
	l = "a",
	p = ",",
	s = " ",
	u = "A",
	w = "A",
	x = "0",
}

-- Create a Parser Object
--- @param trigger string
M.new = function(trigger)
	local obj = setmetatable({}, { __index = M })
	obj.iterator = trigger:gmatch(".")
	return obj
end

function M:handle_perct()
	local cur_itm = self.iterator()
	return magic[cur_itm] == true and cur_itm or magic[cur_itm]
end

function M:handle_char()
	local remove_previous = nil
	local cur_itm = self.iterator()
	local invert = cur_itm == "^"
	if invert then
		cur_itm = self.iterator()
	end
	local cases = {}

	while cur_itm ~= "]" do
		if cur_itm == "%" then
			table.insert(cases, self:handle_perct())
		elseif cur_itm == "-" then
			if remove_previous then
				cases[#cases] = nil
			end
			table.insert(cases, self.iterator())
			remove_previous = false
		else
			remove_previous = true
			table.insert(cases, cur_itm)
		end
		cur_itm = self.iterator()
	end
	-- TODO handle invert case
	-- return the first case for non-invert case
	return cases
end

--- @param prefix string
---@param trigger string
local function match_partially(prefix, trigger)
	-- TODO consume as much of trigger as possible with prefix
	local _, e = trigger:find(prefix)
	return trigger:sub(e + 1)
end

local function construct_label(prefix, pattern)
	-- TODO use prefix and pattern to construct a label
	return prefix .. table.concat(pattern)
end

-- construct labek for regex trigger
---@param prefix  string
---@param trigger string
local function construct(prefix, trigger)
	if prefix:match(trigger) then
		return prefix
	end
	local skip = { ["+"] = true, ["-"] = true, ["*"] = true, ["?"] = true, ["("] = true, [")"] = true }

	trigger = match_partially(prefix, trigger)
	print(trigger)
	local parser = M.new(trigger)
	local pattern = {}
	for i in parser.iterator do
		if i == "%" then
			table.insert(pattern, parser:handle_perct())
		elseif skip[i] then
			-- Skip
		elseif i == "[" then
			table.insert(pattern, parser:handle_char())
		else
			table.insert(pattern, i)
		end
	end
	print(vim.inspect(pattern))
	return construct_label(prefix, pattern)
end

print(construct("lor", "lorem(%d*)"))

return construct
