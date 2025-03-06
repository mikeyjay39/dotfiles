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
				command = function()
					-- Auto-detect Maven or Gradle
					if vim.fn.filereadable("pom.xml") == 1 then
						return "mvn test"
					elseif vim.fn.filereadable("build.gradle") == 1 then
						return "gradle test"
					else
						return "mvn test"
					end
				end,
				dap = {
					config = {
						request = "launch",
						name = "Debug JUnit Test",
						mainClass = "org.junit.platform.console.ConsoleLauncher",
					},
				},
				-- Detect Maven or Gradle projects
				root_dir = function()
					return require("lspconfig.util").root_pattern("pom.xml", "build.gradle", ".git")(vim.fn.getcwd())
				end,
			}),
		},
	})
end

return M
