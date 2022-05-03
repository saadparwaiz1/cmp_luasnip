local cmp = require("cmp")

local source = {}

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
	return "\\%([^[:alnum:][:blank:]]\\|\\w\\+\\)"
end

function source:is_available()
	return require('luasnip.session').active_choice_node ~= nil
end


function source:get_debug_name()
	return "luasnip_choice"
end

function source:complete(_, callback)
  local items = {}

  for idx,word in pairs(require('luasnip').get_current_choices()) do
    table.insert(items, {
      word = word,
      label = word,
      kind = cmp.lsp.CompletionItemKind.Snippet,
      data = {
        idx = idx
      }
    })
  end

	callback(items)
end

function source:execute(completion_item, callback)
  local idx = completion_item.data.idx
  require('luasnip').select_choice(idx)
	callback(completion_item)
end

return source
