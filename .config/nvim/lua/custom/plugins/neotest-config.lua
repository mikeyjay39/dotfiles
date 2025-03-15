local neotest = require("neotest")

local M = {}

M.setup = function()
	neotest.setup({
		adapters = {
			require("neotest-jest")({
				jestCommand = "./node_modules/jest/bin/jest.js",
				jestConfigFile = "/home/mikeyjay/omskit/jest.config.js",
				env = { CI = true },
				cwd = function(path)
					return vim.fn.getcwd()
				end,
			}),
			require("neotest-java")({
				{
					jdtls = require("jdtls"),
				},
			}),
		},
	})
end

return M
