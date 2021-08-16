local cmp = require('cmp')
local luasnip = require('luasnip')
local util = require('vim.lsp.util')

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
  return '\\%(\\w\\+\\|[^[:alnum:]]\\)'
end

function source:get_debug_name()
  return 'luasnip'
end

function source:complete(request, callback)
  local filetypes = { request.context.filetype, 'all' }
  local items = {}

  for i = 1, #filetypes do
    local ft_table = luasnip.snippets[filetypes[i]]
    if ft_table then
      for j, snip in ipairs(ft_table) do
        items[#items+1] = {
          word = snip.trigger,
          label = snip.trigger,
          kind = cmp.lsp.CompletionItemKind.Snippet,
          data = {
            filetype = filetypes[i],
            ft_indx = j
          }
        }
      end
    end
  end
  callback(items)
end

function source:resolve(completion_item, callback)
  local item = completion_item
  local snip = luasnip.snippets[item.data.filetype][item.data.ft_indx]
  local header = (snip.name or "") .. " _ `[" .. completion_item.data.filetype .. ']`\n'
  local documentation = { header .. string.rep('=', string.len(header) - 3), "", (snip.dscr or "")}
  documentation = util.convert_input_to_markdown_lines(documentation)
  documentation = table.concat(documentation, '\n')
  completion_item.documentation = {
    kind = cmp.lsp.MarkupKind.Markdown,
    value =  documentation
  }
  callback(completion_item)
end

function source:execute(completion_item, callback)
  local item = completion_item
  local snip = luasnip.snippets[item.data.filetype][item.data.ft_indx]:copy()
  snip:trigger_expand(Luasnip_current_nodes[vim.api.nvim_get_current_buf()])
  callback(completion_item)
end

return source
