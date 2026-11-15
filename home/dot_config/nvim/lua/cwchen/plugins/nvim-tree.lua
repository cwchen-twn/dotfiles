-- nvim-tree as the file explorer (<leader>ee/ef/ec/er) instead of LazyVim's snacks explorer / neo-tree.
return {
	{ "nvim-neo-tree/neo-tree.nvim", enabled = false },
	{
		"folke/snacks.nvim",
		opts = { explorer = { enabled = false } },
		keys = {
			{ "<leader>e", false },
			{ "<leader>E", false },
			{ "<leader>fe", false },
			{ "<leader>fE", false },
		},
	},
	{
		"nvim-tree/nvim-tree.lua",
		cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle" },
		keys = {
			{ "<leader>ee", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
			{ "<leader>ef", "<cmd>NvimTreeFindFileToggle<CR>", desc = "Toggle file explorer on current file" },
			{ "<leader>ec", "<cmd>NvimTreeCollapse<CR>", desc = "Collapse file explorer" },
			{ "<leader>er", "<cmd>NvimTreeRefresh<CR>", desc = "Refresh file explorer" },
		},
		init = function()
			vim.g.loaded_netrw = 1
			vim.g.loaded_netrwPlugin = 1
		end,
		opts = {
			view = { width = 35, relativenumber = true },
			renderer = {
				indent_markers = { enable = true },
				icons = { glyphs = { folder = { arrow_closed = "", arrow_open = "" } } },
			},
			actions = { open_file = { window_picker = { enable = false } } },
			filters = { custom = { ".DS_Store" } },
			git = { ignore = false },
		},
		config = function(_, opts)
			require("nvim-tree").setup(opts)
			vim.api.nvim_set_hl(0, "NvimTreeFolderArrowClosed", { fg = "#3FC5FF" })
			vim.api.nvim_set_hl(0, "NvimTreeFolderArrowOpen", { fg = "#3FC5FF" })
		end,
	},
}
