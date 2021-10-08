require("cmp").register_source("luasnip", require("cmp_luasnip").new())

vim.api.nvim_exec(
	[[
  augroup cmp_luasnip
    au!
    autocmd User LuasnipCleanup lua require'cmp_luasnip'.clear_cache()
    autocmd User LuasnipSnippetsAdded lua require'cmp_luasnip'.refresh()
  augroup END
]],
	false
)
