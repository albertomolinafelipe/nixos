local mason_status_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_status_ok then
	vim.notify("Couldn't load Mason-LSP-Config" .. mason_lspconfig, "error")
	return
end

mason_lspconfig.setup({})

local lspconfig_status_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status_ok then
	vim.notify("Couldn't load LSP-Config" .. lspconfig, "error")
	return
end

local opts = {
	on_attach = require("lsp-zero").on_attach,
	capabilities = require("lsp-zero").capabilities,
}

mason_lspconfig.setup_handlers({
	-- The first entry (without a key) will be the default handler
	-- and will be called for each installed server that doesn't have
	-- a dedicated handler.
	function(server_name) -- Default handler (optional)
		lspconfig[server_name].setup({
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
		})
	end,

	-- Override for rust_analyzer
	["rust_analyzer"] = function()
		lspconfig.rust_analyzer.setup({
			cmd = { "/run/current-system/sw/bin/rust-analyzer" },
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
		})
	end,
	["terraformls"] = function()
		lspconfig.terraformls.setup({
			cmd = { "/run/current-system/sw/bin/terraform-ls" },
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
		})
	end,
	["gopls"] = function()
		lspconfig.gopls.setup({
			on_attach = function(client, bufnr)
				opts.on_attach(client, bufnr)

				-- Format on save
				if client.server_capabilities.documentFormattingProvider then
					vim.api.nvim_create_autocmd("BufWritePre", {
						group = vim.api.nvim_create_augroup("GoFormat", { clear = true }),
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ async = false })
						end,
					})
				end
			end,
			capabilities = opts.capabilities,
			settings = {
				gopls = {
					gofumpt = true, -- stricter formatting
				},
			},
		})
	end,
})
