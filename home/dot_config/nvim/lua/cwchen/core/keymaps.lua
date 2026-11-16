-- Leader is <Space> (set by LazyVim before plugins load). Loaded on VeryLazy via lua/config/keymaps.lua.

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------

-- use jk to exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

---------------------
-- LSP (in addition to LazyVim's gd/gr/gI/gy/K/<leader>ca/<leader>cr)
keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", { desc = "LSP references" })
keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { desc = "LSP implementations" })
keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", { desc = "LSP type definitions" })
keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", { desc = "Diagnostics in file" })
keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Diagnostics on line" })
keymap.set("n", "<leader>rs", "<cmd>LspRestart<CR>", { desc = "Restart LSP" })

---------------------
-- git hunks (gitsigns; LazyVim also maps ]h/[h and <leader>gh*)
local function gs(fn, ...)
	local args = { ... }
	return function()
		require("gitsigns")[fn](unpack(args))
	end
end
keymap.set("n", "<leader>hs", gs("stage_hunk"), { desc = "Stage/unstage hunk" })
keymap.set("n", "<leader>hr", gs("reset_hunk"), { desc = "Reset hunk" })
keymap.set("v", "<leader>hs", function()
	require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { desc = "Stage/unstage selection" })
keymap.set("v", "<leader>hr", function()
	require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { desc = "Reset selection" })
keymap.set("n", "<leader>hS", gs("stage_buffer"), { desc = "Stage buffer" })
keymap.set("n", "<leader>hR", gs("reset_buffer"), { desc = "Reset buffer" })
keymap.set("n", "<leader>hp", gs("preview_hunk"), { desc = "Preview hunk" })
keymap.set("n", "<leader>hb", gs("blame_line", { full = true }), { desc = "Blame line" })
keymap.set("n", "<leader>hd", gs("diffthis"), { desc = "Diff against index" })
keymap.set("n", "<leader>hD", gs("diffthis", "~"), { desc = "Diff against last commit" })
keymap.set("n", "<leader>tb", gs("toggle_current_line_blame"), { desc = "Toggle line blame" })

---------------------
-- cheat sheet generated from the live keymaps (lua/cwchen/cheatsheet.lua)
vim.api.nvim_create_user_command("Cheatsheet", function()
	require("cwchen.cheatsheet").open()
end, { desc = "Regenerate the keymap cheat sheet and open it" })
keymap.set("n", "<leader>ch", "<cmd>Cheatsheet<CR>", { desc = "Cheat sheet (keymaps)" })
