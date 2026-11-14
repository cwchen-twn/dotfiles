--if vim.loader then
--	vim.loader.enable()
--end

--_G.dd = function(...)
--	require("cwchen.util.debug").dump(...)
--end
--vim.print = _G.dd

require("cwchen.core.keymaps")
require("cwchen.core.options")
require("cwchen.lazy")
