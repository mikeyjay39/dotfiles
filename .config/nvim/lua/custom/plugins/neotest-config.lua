local neotest = require("neotest")

local M = {}

M.setup = function()
	neotest.setup({
		adapters = {
			-- require("neotest-jest")({
			-- }),
			require("neotest-java")({
				{
					jdtls = require("jdtls"),
					debug = true,
				},
			}),
			require("neotest-rust")({}),
			require("neotest-vitest")({
				filter_dir = function(name, rel_path, root)
					return name ~= "node_modules"
				end,
			}),
		},
	})

	-- After neotest-rust is fully loaded (avoid circular require with debug.lua)
	require("custom.neotest-rust-dap-patch").apply()
end

return M
