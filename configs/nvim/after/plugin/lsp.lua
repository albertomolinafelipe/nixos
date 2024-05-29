
local lsp_zero = require('lsp-zero')

lsp_zero.on_attach(function(client, bufnr)
  -- see :help lsp-zero-keybindings
  -- to learn the available actions
  lsp_zero.default_keymaps({buffer = bufnr})
end)

require('mason').setup({})
require('mason-lspconfig').setup({
  ensure_installed = {},
  handlers = {
    lsp_zero.default_setup,
  },
})

lsp_zero.setup({
  cmd = { "/nix/store/xkf4p6bkcsvpxr49882w0vc9ckaf7zl9-rustup-1.26.0/bin/rust-analyzer" }
})

