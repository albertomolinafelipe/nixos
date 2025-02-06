-- Vimtex configuration
vim.g.vimtex_compiler_latexmk = {
  options = {
    "-pdf",
    "-outdir=build",
    "-interaction=nonstopmode",
    "-synctex=1",
    "-file-line-error",
  }
}

-- Specify the PDF viewer
vim.g.vimtex_view_method = 'general'
vim.g.vimtex_view_general_viewer = 'evince'
vim.g.vimtex_view_general_options = '@pdf'
