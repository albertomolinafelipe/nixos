local setup, lualine = pcall(require, "lualine")
if not setup then
    return
end
local new_colors = {
    normal = "#9ca9c8",
    insert = "#7da69e",
    visual = "#9289a7",
}

local lualine_kanagawa = require("lualine.themes.auto")
lualine_kanagawa.normal.a.bg = new_colors.normal
lualine_kanagawa.insert.a.bg = new_colors.insert
lualine_kanagawa.visual.a.bg = new_colors.visual
lualine.setup({
    options = {
        theme = lualine_kanagawa
    }
})
