local cmp = require("cmp")
local util = require("vim.lsp.util")

local source = {}

local defaults = {
	use_show_condition = false,
}

local function init_options(params)
	params.option = vim.tbl_deep_extend('keep', params.option, defaults)
	vim.validate({
		use_show_condition = { params.option.use_show_condition, 'boolean' },
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
	doc_cache[data.filetype][data.ft_indx] = documentation
	return documentation
end

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
	return "\\%([^[:alnum:][:blank:]]\\|\\w\\+\\)"
end

function source:is_available()
	local ok, _ = pcall(require, "luasnip")
	return ok
end

function source:get_debug_name()
	return "luasnip"
end

local function get_snippet_item_filter()
	local line_to_cursor = require('luasnip.util.util').get_current_line_to_cursor()
	return function(item)
		return not item.data.show_condition or item.data.show_condition(line_to_cursor)
	end
end

function source:complete(params, callback)
	init_options(params)

	local filetypes = require("luasnip.util.util").get_snippet_filetypes(params.context.filetype)
	local items = {}
	local snip_filter

	for i = 1, #filetypes do
		local ft = filetypes[i]
		if not snip_cache[ft] then
			-- ft not yet in cache.
			local ft_items = {}
			local ft_table = require("luasnip").snippets[ft]
			if ft_table then
				for j, snip in pairs(ft_table) do
					if not snip.hidden then
						ft_items[#ft_items + 1] = {
							word = snip.trigger,
							label = snip.trigger,
							kind = cmp.lsp.CompletionItemKind.Snippet,
							data = {
								filetype = ft,
								ft_indx = j,
								show_condition = snip.show_condition,
							},
						}
					end
				end
			end
			snip_cache[ft] = ft_items
		end
		local snips = snip_cache[ft]
		if params.option.use_show_condition then
			-- to minimize overhead of get_current_line_to_cursor() when use_show_condition=false
			snip_filter = snip_filter or get_snippet_item_filter()
			snips = vim.tbl_filter(snip_filter, snips)
		end
		vim.list_extend(items, snips)
	end
	callback(items)
end

function source:resolve(completion_item, callback)
	local snip = require("luasnip").snippets[completion_item.data.filetype][completion_item.data.ft_indx]
	local documentation
	if
		doc_cache[completion_item.data.filetype]
		and doc_cache[completion_item.data.filetype][completion_item.data.ft_indx]
	then
		documentation = doc_cache[completion_item.data.filetype][completion_item.data.ft_indx]
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
	local snip = require("luasnip").snippets[completion_item.data.filetype][completion_item.data.ft_indx]
	if snip.regTrig then
		-- if trigger is a pattern, expand "pattern" instead of actual snippet.
		snip = snip:get_pattern_expand_helper()
	else
		snip = snip:copy()
	end
	snip:trigger_expand(require("luasnip").session.current_nodes[vim.api.nvim_get_current_buf()])
	callback(completion_item)
end

return source
