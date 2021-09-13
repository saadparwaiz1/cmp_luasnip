augroup cmp_luasnip
	au!
	autocmd User LuasnipCleanup lua require'cmp_luasnip'.clear_cache()
augroup END
