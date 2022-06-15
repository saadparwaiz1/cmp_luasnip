local cmp = require("cmp")
local util = require("vim.lsp.util")

local source = {}

local defaults = {
	use_show_condition = true,
}

-- the options are being passed via cmp.setup.sources, e.g.
-- require('cmp').setup { sources = { { name = 'luasnip', opts = {...} } } }
local function init_options(params)
	params.option = vim.tbl_deep_extend("keep", params.option, defaults)
	vim.validate({
		use_show_condition = { params.option.use_show_condition, "boolean" },
	})
end

local snip_cache = {}
local doc_cache = {}

source.clear_cache = function()
	snip_cache = {}
	doc_cache = {}
end

source.refresh = function()
	local ft = require("luasnip.session").latest_load_ft
	snip_cache[ft] = nil
	doc_cache[ft] = nil
end

local function get_documentation(snip, data)
	local header = (snip.name or "") .. " _ `[" .. data.filetype .. "]`\n"
	local docstring = { "", "```" .. vim.bo.filetype, snip:get_docstring(), "```" }
	local documentation = { header .. "---", (snip.dscr or ""), docstring }
	documentation = util.convert_input_to_markdown_lines(documentation)
	documentation = table.concat(documentation, "\n")

	doc_cache[data.filetype] = doc_cache[data.filetype] or {}
	doc_cache[data.filetype][data.snip_id] = documentation

	return documentation
end

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
	-- This should probably be more descerning, but I'm not sure what it should be
	return [[.]]
end

function source:is_available()
	local ok, _ = pcall(require, "luasnip")
	return ok
end

function source:get_debug_name()
	return "luasnip"
end

function source:complete(params, callback)
	local line = require("luasnip.util.util").get_current_line_to_cursor()
	init_options(params)

	local filetypes = require("luasnip.util.util").get_snippet_filetypes()
	local items = {}

	for i = 1, #filetypes do
		-- Right now, we need to update the regTrig snips on every keypress
		-- potentially, but we should avoid that if we can
		local ft = filetypes[i]
		-- if not snip_cache[ft] then
		-- ft not yet in cache.
		local ft_items = {}
		local ft_table = require("luasnip").get_snippets(ft, { type = "snippets" })
		if ft_table then
			for j, snip in pairs(ft_table) do
				if not snip.hidden then
					local stored_snip = {
						word = snip.trigger,
						label = snip.trigger,
						kind = cmp.lsp.CompletionItemKind.Snippet,
						data = {
							filetype = ft,
							snip_id = snip.id,
							show_condition = snip.show_condition,
						},
						isIncomplete = false,
					}
					if snip.regTrig then
						local expand_params = snip:matches(params.context.cursor_before_line)
						if expand_params then
							stored_snip.word = expand_params.trigger
							stored_snip.label = expand_params.trigger
						else
							stored_snip.isIncomplete = true
						end
					end
					table.insert(ft_items, stored_snip)
				end
			end
			snip_cache[ft] = ft_items
		end
		-- end
		vim.list_extend(items, snip_cache[ft])
	end

	if params.option.use_show_condition then
		local line_to_cursor = params.context.cursor_before_line
		items = vim.tbl_filter(function(i)
			-- check if show_condition exists in case (somehow) user updated cmp_luasnip but not luasnip
			return not i.data.show_condition or i.data.show_condition(line_to_cursor)
		end, items)
	end

	callback(items)
end

function source:resolve(completion_item, callback)
	local item_snip_id = completion_item.data.snip_id
	local snip = require("luasnip").get_id_snippet(item_snip_id)
	local documentation
	if doc_cache[completion_item.data.filetype] and doc_cache[completion_item.data.filetype][item_snip_id] then
		documentation = doc_cache[completion_item.data.filetype][item_snip_id]
	else
		documentation = get_documentation(snip, completion_item.data)
	end
	completion_item.documentation = {
		kind = cmp.lsp.MarkupKind.Markdown,
		value = documentation,
	}
	callback(completion_item)
end

function source:execute(completion_item, callback)
	local snip = require("luasnip").get_id_snippet(completion_item.data.snip_id)

	local cursor = vim.api.nvim_win_get_cursor(0)
	-- get_cursor returns (1,0)-indexed position, clear_region expects (0,0)-indexed.
	cursor[1] = cursor[1] - 1

	-- text cannot be cleared before, as TM_CURRENT_LINE and
	-- TM_CURRENT_WORD couldn't be set correctly.
	local args = {
		-- clear word inserted into buffer by cmp.
		-- cursor is currently behind word.
		clear_region = {
			from = {
				cursor[1],
				cursor[2] - #completion_item.word,
			},
			to = cursor,
		},
	}
	if snip.regTrig then
		local line = require("luasnip.util.util").get_current_line_to_cursor()
		args.expand_params = snip:matches(line)
	end

	require("luasnip").snip_expand(snip, args)
	callback(completion_item)
end

return source
