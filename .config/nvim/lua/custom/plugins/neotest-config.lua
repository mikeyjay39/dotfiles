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
end

return M
