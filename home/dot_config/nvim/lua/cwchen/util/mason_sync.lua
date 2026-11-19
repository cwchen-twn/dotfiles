-- Headless Mason sync: install every package the nvim config asks for (mason.nvim `ensure_installed`, plus each
-- enabled nvim-lspconfig server through mason-lspconfig's mapping), repair half-installed ones, uninstall the ones
-- the config no longer declares, report failures.
-- Run: nvim --headless -c 'lua require("cwchen.util.mason_sync").run()'   (exit 1 when anything is missing)
local M = {}

local function out(msg)
	io.stdout:write(msg .. "\n")
end

local function wanted_packages()
	local Config = require("lazy.core.config")
	local Plugin = require("lazy.core.plugin")
	local wanted = {}
	local mopts = Plugin.values(Config.plugins["mason.nvim"], "opts", false)
	for _, name in ipairs(mopts.ensure_installed or {}) do
		wanted[name] = true
	end
	local ok, mappings = pcall(require, "mason-lspconfig.mappings")
	local map = ok and mappings.get_mason_map and mappings.get_mason_map().lspconfig_to_package or {}
	local lopts = Plugin.values(Config.plugins["nvim-lspconfig"], "opts", false)
	for server, sopts in pairs(lopts.servers or {}) do
		local enabled = sopts == true or (type(sopts) == "table" and sopts.enabled ~= false and sopts.mason ~= false)
		if enabled and map[server] then
			wanted[map[server]] = true
		end
	end
	-- lang.python picks its server from this global, outside `servers`
	local py = vim.g.lazyvim_python_lsp
	if py and map[py] then
		wanted[map[py]] = true
	end
	return wanted
end

-- installed = every executable the package declares exists in mason/bin (a failed install leaves only a dir)
local function healthy(pkg)
	if not pkg:is_installed() then
		return false
	end
	local bindir = vim.fn.stdpath("data") .. "/mason/bin/"
	for bin in pairs(pkg.spec.bin or {}) do
		if vim.fn.executable(bindir .. bin) ~= 1 then
			return false
		end
	end
	return true
end

function M.run()
	require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig" } })
	local registry = require("mason-registry")
	local refreshed = false
	registry.refresh(function()
		refreshed = true
	end)
	vim.wait(120000, function()
		return refreshed
	end, 200)

	local wanted = wanted_packages()
	local started = {}
	for name in pairs(wanted) do
		local ok, pkg = pcall(registry.get_package, name)
		if not ok then
			out("mason: unknown package " .. name)
		elseif not healthy(pkg) then
			out("mason: installing " .. name)
			pkg:install({ force = true })
			table.insert(started, pkg)
		end
	end
	vim.wait(1800000, function()
		for _, pkg in ipairs(started) do
			if pkg:is_installing() then
				return false
			end
		end
		return true
	end, 1000)

	-- One owner: a package the config no longer declares (a replaced server, e.g. pyright after pyrefly) is
	-- uninstalled, so its binary leaves PATH, where Claude Code would otherwise offer an LSP plugin for it.
	local removed = {}
	for _, name in ipairs(registry.get_installed_package_names()) do
		if not wanted[name] then
			local ok, pkg = pcall(registry.get_package, name)
			if ok then
				pkg:uninstall()
				table.insert(removed, name)
			end
		end
	end
	table.sort(removed)
	if #removed > 0 then
		out("mason: removed (no longer in the config): " .. table.concat(removed, " "))
	end

	local missing = {}
	for name in pairs(wanted) do
		local ok, pkg = pcall(registry.get_package, name)
		if not ok or not healthy(pkg) then
			table.insert(missing, name)
		end
	end
	table.sort(missing)
	if #missing > 0 then
		out("mason: NOT installed: " .. table.concat(missing, " "))
		vim.cmd("cquit 1")
	end
	out(("mason: all %d configured packages installed"):format(vim.tbl_count(wanted)))
	vim.cmd("qall!")
end

return M
