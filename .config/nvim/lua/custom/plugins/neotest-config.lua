local neotest = require("neotest")

local M = {}

M.setup = function()
	-- NOTE: This is a workaround until neotest-vitest fixes how they resolve the vitest setup file.	local function find_nearest_node_modules_dir()
	-- https://github.com/marilari88/neotest-vitest/issues/75
	--
	-- local function find_nearest_node_modules_dir()
	-- 	local current_dir = vim.fn.expand("%:p:h") -- current buffer dir
	-- 	while current_dir ~= "/" do
	-- 		if vim.fn.isdirectory(current_dir .. "/node_modules") == 1 then
	-- 			return current_dir
	-- 		end
	-- 		current_dir = vim.fn.fnamemodify(current_dir, ":h")
	-- 	end
	-- 	return nil
	-- end
	--
	-- local function get_root_dir()
	-- 	local original_cwd = vim.fn.getcwd()
	-- 	local node_modules_dir = find_nearest_node_modules_dir()
	-- 	return node_modules_dir or original_cwd
	-- end
	-- -- end workaround

	neotest.setup({
		adapters = {
			require("neotest-jest")({
				-- 	-- jestCommand = "./node_modules/jest/bin/jest.js",
				-- 	-- jestConfigFile = "/home/mikeyjay/omskit/jest.config.js",
				-- 	-- env = { CI = true },
				-- 	-- cwd = function(path)
				-- 	-- 	return vim.fn.getcwd()
				-- 	-- end,
			}),
			require("neotest-java")({
				{
					jdtls = require("jdtls"),
					debug = true,
				},
			}),
			require("neotest-rust")({}),
			-- NOTE: this project has open issues regarding setting the path of the vitest setup file. This may not
			-- be too usable until they fix it.
			--
			-- require("neotest-vitest")({
			-- 	cwd = get_root_dir(),
			-- 	filter_dir = function(name, rel_path, root)
			-- 		return name ~= "node_modules"
			-- 	end,
			-- }),
		},
	})
end

return M
