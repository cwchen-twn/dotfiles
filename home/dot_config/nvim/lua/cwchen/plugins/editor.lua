-- Personal additions and overrides on top of LazyVim.
return {
	"christoomey/vim-tmux-navigator", -- <C-h/j/k/l> across nvim splits and tmux panes
	"inkarkat/vim-ReplaceWithRegister", -- gr{motion}: replace with register
	{ "szw/vim-maximizer", keys = { { "<leader>sm", "<cmd>MaximizerToggle<CR>", desc = "Maximize/minimize a split" } } },
	{ "catgoose/nvim-colorizer.lua", event = { "BufReadPre", "BufNewFile" }, opts = {} },
	{ "kylechui/nvim-surround", version = "*", event = "VeryLazy", opts = {} },

	-- sessions: auto-session (<leader>wr / <leader>ws) instead of LazyVim's persistence.nvim
	{ "folke/persistence.nvim", enabled = false },
	{
		"rmagatti/auto-session",
		lazy = false,
		keys = {
			{ "<leader>wr", "<cmd>AutoSession restore<CR>", desc = "Restore session for cwd" },
			{ "<leader>ws", "<cmd>AutoSession save<CR>", desc = "Save session for cwd" },
		},
		opts = {
			auto_restore = false,
			suppressed_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
		},
	},

	-- tabs in the bufferline (we use <leader>t* for tabs)
	{ "akinsho/bufferline.nvim", opts = { options = { mode = "tabs", separator_style = "slant" } } },

	-- dashboard: keep the NEOVIM header
	{
		"goolord/alpha-nvim",
		opts = function(_, dashboard)
			dashboard.section.header.val = {
				"                                                     ",
				"  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
				"  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
				"  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
				"  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
				"  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
				"  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
				"                                                     ",
			}
		end,
	},

	-- telescope: our keys, <C-j>/<C-k> in the prompt, hidden files
	{
		"nvim-telescope/telescope.nvim",
		keys = {
			{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files in cwd" },
			{ "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
			{ "<leader>fs", "<cmd>Telescope live_grep<cr>", desc = "Find string in cwd" },
			{ "<leader>fc", "<cmd>Telescope grep_string<cr>", desc = "Find string under cursor in cwd" },
		},
		opts = function(_, opts)
			local actions = require("telescope.actions")
			opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
				path_display = { "truncate" },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			})
			local ignore = { "node_modules", "%.git/", "%.venv" }
			opts.pickers = vim.tbl_deep_extend("force", opts.pickers or {}, {
				find_files = { hidden = true, file_ignore_patterns = ignore },
				live_grep = {
					file_ignore_patterns = ignore,
					additional_args = function()
						return { "--hidden" }
					end,
				},
			})
		end,
	},

	-- completion: <C-j>/<C-k> to move through suggestions
	{
		"hrsh7th/nvim-cmp",
		opts = function(_, opts)
			local cmp = require("cmp")
			opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
				["<C-k>"] = cmp.mapping.select_prev_item(),
				["<C-j>"] = cmp.mapping.select_next_item(),
			})
		end,
	},

	-- LSP servers LazyVim's language extras don't cover (mason installs them).
	-- tombi replaces lang.toml's taplo; gh_actions_ls attaches only under .gitea/.github/.forgejo workflows.
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				html = {},
				cssls = {},
				bashls = {},
				lemminx = {},
				fish_lsp = {},
				gh_actions_ls = {},
				postgres_lsp = {},
				taplo = { enabled = false },
				tombi = {},
			},
		},
	},
	-- mason packages that are not lspconfig servers (those are auto-installed from `servers`):
	-- rust-analyzer (rustaceanvim takes it from PATH; fish puts mason/bin before ~/.cargo/bin's rustup stub),
	-- and actionlint (CI workflows). shellcheck (bashls diagnostics) comes from apt/Homebrew (ansible base role).
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"rust-analyzer",
				"actionlint",
				"tree-sitter-cli", -- LazyVim installs it on its own; declared so the Mason sync never prunes it
			},
		},
	},

	-- git graph (fugitive-based)
	{ "rbong/vim-flog", cmd = { "Flog", "Flogsplit", "Floggit" }, dependencies = { "tpope/vim-fugitive" }, keys = {
		{ "<leader>gv", "<cmd>Flog<cr>", desc = "Git graph (Flog)" },
	} },

	-- markdown preview (from LazyVim's markdown extra): open in the default browser, on localhost only
	{
		"iamcco/markdown-preview.nvim",
		keys = {
			{ "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview", ft = "markdown" },
			{ "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Stop Markdown Preview", ft = "markdown" },
		},
		init = function()
			vim.g.mkdp_auto_close = 1
			vim.g.mkdp_open_to_the_world = 0
			vim.g.mkdp_open_ip = "127.0.0.1"
			vim.g.mkdp_port = "8888"
			vim.g.mkdp_echo_preview_url = 1
			vim.g.mkdp_page_title = "${name}"
		end,
	},
}
