# Neovim configuration

[LazyVim](https://www.lazyvim.org/) plus personal overrides, on Neovim 0.12 (mise).

- `lua/cwchen/lazy.lua`: LazyVim + extras (telescope, nvim-cmp, alpha, languages, prettier, eslint).
- `lua/cwchen/core/`: options and keymaps, loaded after LazyVim's defaults via `lua/config/`.
- `lua/cwchen/plugins/`: only additions/overrides (catppuccin, nvim-tree instead of the snacks explorer/neo-tree,
  auto-session instead of persistence, tmux navigator, flog, maximizer, colorizer, surround, telescope/cmp keys).
- `lazy-lock.json`: pinned plugin commits. Update with `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`.

Cheat sheet: `~/.local/share/nvim/cheatsheet.html` (fish: `nvim-keys`) is generated from the live keymaps by
`lua/cwchen/cheatsheet.lua`: every mapping with a description, grouped like the which-key popup, plus the LSP and
nvim-tree panel keys. chezmoi regenerates it whenever this config changes (`run_onchange_after_45-nvim-cheatsheet`);
`:Cheatsheet` / `<Space>ch` regenerates it from the running session and opens it.

Dependencies (ripgrep, fd, fzf, tree-sitter, node, go, …) come from the dotfiles (apt/mise). LSP servers, formatters
and linters are installed by Mason on first start (`:Mason`).
