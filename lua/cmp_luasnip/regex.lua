	local magic = {
		["("] = "(",
		[")"] = ")",
		["."] = ".",
		["%"] = "%",
		["+"] = "+",
		["-"] = "-",
		["*"] = "*",
		["?"] = "?",
		["["] = "[",
		["]"] = "]",
		["^"] = "^",
		["$"] = "$",
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

local function handle_char(iterator)
	local cur_itm = iterator()
	local invert = cur_itm == "^"
	if invert then
		cur_itm = iterator()
	end
	local cases = {
    ranges = {},
    classes = {},
    characters = {}
  }

	while cur_itm ~= "]" do
		if cur_itm == "%" then
			table.insert(cases.classes, iterator())
		elseif cur_itm == "-" then
      local previous_item = cases.characters[#cases.characters]
      cases.characters[#cases.characters] = nil
			table.insert(cases.ranges, {previous_item, iterator()})
		else
			table.insert(cases.characters, cur_itm)
		end
		cur_itm = iterator()
	end
  if not invert then
    if #cases.characters ~= 0 then
      return cases.characters[1]
    end

    if #cases.classes ~= 0 then
      return magic[cases.classes[1]]
    end

    if #cases.ranges ~= 0 then
      return cases.ranges[1][1]
    end
  end
  -- TODO Handle Invert Case
	return cases
end

--- @param prefix string
---@param trigger string
local function match_partially(prefix, trigger)
	local _, e = trigger:find(prefix)
	return trigger:sub(e + 1)
end

-- construct label for regex trigger
---@param prefix  string
---@param trigger string
local function construct(prefix, trigger)
	if prefix:match(trigger) then
		return prefix
	end
	trigger = match_partially(prefix, trigger)
	local iterator = trigger:gmatch(".")
	for i in iterator do
		if i == "%" then
      prefix = prefix .. magic[iterator()]
		elseif i == "[" then
			prefix = prefix .. handle_char(iterator)
    elseif i == '$' then
      return prefix
    elseif i == '^' then
      prefix = ''
		elseif i ~= '+' and i ~= '-' and i ~= '*' and i ~= "?" and i ~= "(" and i ~= ")" then
      prefix = prefix .. i
	  end
  end
	return prefix
end

return construct
