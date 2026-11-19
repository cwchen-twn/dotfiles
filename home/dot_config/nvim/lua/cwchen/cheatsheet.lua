-- Cheat sheet generated from the live config: every mapping that has a description (LazyVim's, the plugins' and
-- ours), grouped by which-key's groups, plus the LSP keys and the nvim-tree panel keys. Nothing is hand-written, so it
-- can't go stale.
--   :Cheatsheet          regenerate from this session and open it in the browser   (<leader>ch)
--   headless (chezmoi):  nvim --headless -c 'lua require("cwchen.cheatsheet").headless()'
local M = {}

M.path = vim.fn.stdpath("data") .. "/cheatsheet.html"

local function esc(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- " ff" -> "Space f f", "<C-h>" -> "Ctrl-h", "]d" -> "] d"
local function pretty(lhs)
	local leader = vim.g.mapleader or "\\"
	local out, i = {}, 1
	while i <= #lhs do
		local special = lhs:match("^<[^>]+>", i)
		if special then
			local s = special:sub(2, -2)
			s = s:gsub("^[Cc]%-", "Ctrl-"):gsub("^[Mm]%-", "Alt-"):gsub("^[Aa]%-", "Alt-"):gsub("^[Ss]%-", "Shift-")
			s = s:gsub("^[Ll]eader$", "Space")
				:gsub("^[Cc][Rr]$", "Enter")
				:gsub("^[Ee]sc$", "Esc")
				:gsub("^[Tt]ab$", "Tab")
			s = s:gsub("^[Bb][Ss]$", "Backspace"):gsub("^[Ss]pace$", "Space")
			table.insert(out, s)
			i = i + #special
		else
			local c = lhs:sub(i, i)
			table.insert(out, c == leader and "Space" or c)
			i = i + 1
		end
	end
	return table.concat(out, " ")
end

-- Comparable form of an lhs: special keys lowercased, <leader>/<Space> -> " " ("<Space>ff" == "<leader>ff" == " ff")
local function norm(lhs)
	return (
		lhs:gsub("<[^>]+>", function(t)
			t = t:lower()
			return (t == "<space>" or t == "<leader>") and " " or t
		end)
	)
end

-- which-key group prefixes (" f" -> "file/find")
local function groups()
	local res = {}
	local ok, cfg = pcall(require, "which-key.config")
	if not ok or not cfg.mappings then
		return res
	end
	for _, m in ipairs(cfg.mappings) do
		if m.group and m.lhs and m.desc and m.desc ~= "" then
			res[norm(m.lhs)] = m.desc
		end
	end
	return res
end

local function category(lhs, grp)
	lhs = norm(lhs)
	for n = #lhs - 1, 1, -1 do
		local g = grp[lhs:sub(1, n)]
		if g then
			return g
		end
	end
	local first = lhs:sub(1, 1)
	if first == " " then
		return "leader"
	end
	return ({ g = "goto / g-commands", ["["] = "prev", ["]"] = "next", z = "folds / view" })[first] or "general"
end

local MODES = { n = "normal", x = "visual", i = "insert", t = "terminal" }

local function collect(bufnr)
	local grp, rows, seen = groups(), {}, {}
	local function add(m, mode, origin)
		local desc = m.desc
		if not desc or desc == "" or m.lhs:find("^<Plug>") or m.lhs:find("^<SNR>") then
			return
		end
		-- noise: Neovim's built-in defaults (":help v_#-default") and auto-pair insert behavior (mini.pairs)
		if desc:find("^:help ") or desc:find("action for .* pair$") or desc:find("^MiniPairs") then
			return
		end
		local key = mode .. "\0" .. m.lhs
		if seen[key] then
			return
		end
		seen[key] = true
		local cat = origin == "lsp" and "code (language server)" or category(m.lhs, grp)
		table.insert(rows, { cat = cat, mode = MODES[mode], key = pretty(m.lhs), desc = desc })
	end
	for mode in pairs(MODES) do
		if bufnr then -- buffer-local first: LSP and git hunk keys override globals of the same name
			for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
				add(m, mode, #vim.lsp.get_clients({ bufnr = bufnr }) > 0 and "lsp" or nil)
			end
		end
		for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
			add(m, mode)
		end
	end
	return rows
end

local function tree_keys()
	local ok, km = pcall(function()
		require("lazy").load({ plugins = { "nvim-tree.lua" } })
		local k = require("nvim-tree.keymap")
		return (k.get_keymap and k.get_keymap()) or k.get_keymap_default()
	end)
	local rows = {}
	if ok and km then
		for _, m in ipairs(km) do
			if m.desc and m.desc ~= "" then
				table.insert(rows, { key = pretty(m.lhs), desc = (m.desc:gsub("^nvim%-tree: ", "")) })
			end
		end
		table.sort(rows, function(a, b)
			return a.desc < b.desc
		end)
	end
	return rows
end

local function lazyvim_version()
	local ok, lock = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
	end)
	local dir = vim.fn.stdpath("data") .. "/lazy/LazyVim"
	local tag = vim.fn.systemlist({ "git", "-C", dir, "describe", "--tags", "--abbrev=0", "--match", "v*" })[1]
	return (vim.v.shell_error == 0 and tag) or (ok and lock.LazyVim and lock.LazyVim.commit:sub(1, 8)) or "?"
end

local CSS = [[
:root{--bg:#171426;--panel:#22162f;--text:#d6e2f5;--muted:#8b9bbd;--accent:#5c729d;--key:#b7cef1;--line:#2e2a45}
@media (prefers-color-scheme: light){:root{--bg:#f6f7fb;--panel:#fff;--text:#1d2233;--muted:#5b6478;--accent:#3d5a8f;--key:#24324f;--line:#dde2ee}}
*{box-sizing:border-box}body{margin:0;padding:24px 16px;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,sans-serif}
header{max-width:1400px;margin:0 auto 16px}h1{margin:0 0 4px;font-size:22px}.meta{color:var(--muted);font-size:12px}
input{width:100%;max-width:420px;margin-top:12px;padding:8px 10px;border-radius:8px;border:1px solid var(--line);background:var(--panel);color:var(--text);font-size:14px}
main{max-width:1400px;margin:0 auto;columns:3 360px;column-gap:16px}
section{break-inside:avoid;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin:0 0 16px}
h2{margin:0 0 6px;font-size:13px;text-transform:uppercase;letter-spacing:.06em;color:var(--accent)}
table{width:100%;border-collapse:collapse}td{padding:3px 0;vertical-align:top;border-top:1px solid var(--line)}tr:first-child td{border-top:0}
td.k{white-space:nowrap;padding-right:10px;width:1%}kbd{font:12px/1.2 ui-monospace,monospace;color:var(--key);background:var(--bg);border:1px solid var(--line);border-radius:4px;padding:1px 5px}
.m{color:var(--muted);font-size:11px;margin-left:4px}.intro{max-width:1400px;margin:0 auto 16px;color:var(--muted)}
@media print{body{background:#fff;color:#000;padding:0;font-size:10px}input,.intro{display:none}main{columns:3}section{border:1px solid #ccc}kbd{color:#000;background:#fff}}
]]

local JS = [[
document.getElementById('q').addEventListener('input',e=>{const q=e.target.value.toLowerCase();
document.querySelectorAll('section').forEach(s=>{let any=false;s.querySelectorAll('tr').forEach(r=>{const hit=!q||r.textContent.toLowerCase().includes(q);r.style.display=hit?'':'none';any=any||hit});s.style.display=any?'':'none'})});
]]

function M.write(bufnr)
	local rows = collect(bufnr)
	local cats, order = {}, {}
	for _, r in ipairs(rows) do
		if not cats[r.cat] then
			cats[r.cat] = {}
			table.insert(order, r.cat)
		end
		table.insert(cats[r.cat], r)
	end
	table.sort(order, function(a, b)
		local pa, pb = a == "general" and 0 or 1, b == "general" and 0 or 1
		return pa == pb and a < b or pa < pb
	end)
	local h = {
		"<!doctype html><html lang=en><head><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>",
		"<title>Neovim cheat sheet</title><style>" .. CSS .. "</style></head><body><header><h1>Neovim cheat sheet</h1>",
		string.format(
			"<div class=meta>Generated %s from the live config &middot; Neovim %s &middot; LazyVim %s &middot; %d mappings. Regenerate: <kbd>:Cheatsheet</kbd> or <kbd>Space c h</kbd></div>",
			os.date("%Y-%m-%d %H:%M"),
			esc(tostring(vim.version())),
			esc(lazyvim_version()),
			#rows
		),
		"<input id=q placeholder='Filter: type a key or a word (e.g. git, rename, Space f)' autofocus></header>",
		"<p class=intro>Leader is <kbd>Space</kbd>. In Neovim, press <kbd>Space</kbd> (or <kbd>g</kbd>, <kbd>]</kbd>, <kbd>z</kbd>) and wait: the which-key popup shows the same keys live. Mode is normal unless marked.</p><main>",
	}
	for _, cat in ipairs(order) do
		table.sort(cats[cat], function(a, b)
			return a.key < b.key
		end)
		table.insert(h, "<section><h2>" .. esc(cat) .. "</h2><table>")
		for _, r in ipairs(cats[cat]) do
			table.insert(
				h,
				string.format(
					"<tr><td class=k><kbd>%s</kbd>%s</td><td>%s</td></tr>",
					esc(r.key),
					r.mode ~= "normal" and ("<span class=m>" .. r.mode .. "</span>") or "",
					esc(r.desc)
				)
			)
		end
		table.insert(h, "</table></section>")
	end
	local tree = tree_keys()
	if #tree > 0 then
		table.insert(h, "<section><h2>file tree panel (Space e e)</h2><table>")
		for _, r in ipairs(tree) do
			table.insert(
				h,
				string.format("<tr><td class=k><kbd>%s</kbd></td><td>%s</td></tr>", esc(r.key), esc(r.desc))
			)
		end
		table.insert(h, "</table></section>")
	end
	table.insert(h, "</main><script>" .. JS .. "</script></body></html>")
	vim.fn.mkdir(vim.fn.fnamemodify(M.path, ":h"), "p")
	vim.fn.writefile(vim.split(table.concat(h, "\n"), "\n"), M.path)
	return M.path, #rows
end

-- From a running session: include the LSP keys of the current buffer when a server is attached.
function M.open()
	local path, n = M.write(vim.api.nvim_get_current_buf())
	vim.notify(string.format("Cheat sheet: %d mappings -> %s", n, path))
	vim.ui.open(path)
end

-- For chezmoi/scripts: load everything LazyVim loads lazily, attach a language server to a scratch Lua file so its
-- keys are included, write the file, quit.
function M.headless()
	-- `-c` runs before VimEnter, and which-key only registers its groups after startup: wait for it
	if vim.v.vim_did_enter == 0 then
		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				vim.defer_fn(M.headless, 500)
			end,
		})
		return
	end
	vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
	vim.wait(1500) -- which-key and LazyVim's keymaps load on VeryLazy
	local tmp = vim.fn.tempname() .. ".lua"
	vim.fn.writefile({ "local x = 1", "return x" }, tmp)
	vim.cmd("edit " .. vim.fn.fnameescape(tmp))
	local buf = vim.api.nvim_get_current_buf()
	vim.wait(30000, function()
		return #vim.lsp.get_clients({ bufnr = buf }) > 0
	end, 500)
	vim.wait(1000) -- let LspAttach handlers set their keys
	local path, n = M.write(buf)
	io.stdout:write(string.format("cheat sheet: %d mappings -> %s\n", n, path))
	vim.fn.delete(tmp)
	vim.cmd("qa!")
end

return M
