-- catppuccin is in LazyVim already; only our flavour/style (LazyVim's colorscheme opt is set in lazy.lua).
return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		opts = {
			flavour = "mocha", -- latte, frappe, macchiato, mocha
			transparent_background = true,
			styles = {
				keywords = { "bold" },
				functions = { "italic" },
			},
		},
	},
}
