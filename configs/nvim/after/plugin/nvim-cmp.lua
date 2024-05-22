local setup_cmp, cmp = pcall(require, "cmp")
if not setup_cmp then
    return
end

local setup_snip, luasnip = pcall(require, "luasnip")
if not setup_snip then
    return
end

require("luasnip/loaders/from_vscode").lazy_load()
vim.opt.completeopt = "menu,menuone,noselect"

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      -- when selected
      ['<CR>'] = cmp.mapping.confirm({ select = false}),

      -- when not selected
      ['<A-CR>'] = cmp.mapping.confirm({ select = true}),
    }),
    sources = cmp.config.sources({
        {name = "luasnip"},
        {name = "buffer"},
        {name = "path"},
        {name = "nvim_lsp"},
    }),
})


