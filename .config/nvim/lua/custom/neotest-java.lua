local neotest = require("neotest")
local nio = require("nio")

local M = {}

M.name = "neotest-java"

-- Determine if a file is a test file
M.is_test_file = function(file_path)
	return file_path:match("src/test/java/.*%.java$") ~= nil
end

-- Define the root of the project
M.root = function(dir)
	return require("neotest.lib").files.match_root_pattern("pom.xml", "build.gradle", ".git")(dir)
end

-- Discover test positions (test methods) in a file asynchronously using nvim-nio
local Path = require("plenary.path")
local async = require("plenary.async")

M.discover_positions = async(function(file_path, callback)
	-- Create a Path object from plenary
	local file = Path:new(file_path)

	-- Read the file asynchronously
	local data, err = file:read()

	if err then
		print("Error reading file:", err)
		return
	end

	-- Parse the positions using the treesitter query
	local treesitter = require("neotest.lib.treesitter")
	local tree, parse_err = treesitter.parse_positions(data, {
		queries = {
			java = [[
                (method_declaration
                  (modifiers
                    (marker_annotation
                      (type_identifier) @test.name (#match? @test.name "Test")))
                  name: (identifier) @test.name)
            ]],
		},
	})

	if parse_err then
		print("Error parsing positions:", parse_err)
		return
	end

	-- Call the callback with the parsed tree
	callback(tree)
end)

-- Build the test execution command
M.build_spec = function(args)
	local test_name = args.tree:data().name
	local project_root = M.root(vim.fn.getcwd()) -- Get the project's root directory

	if not project_root then
		return nil
	end

	local cmd = {}
	if vim.fn.filereadable(project_root .. "/pom.xml") == 1 then
		cmd = { "mvn", "test", "-Dtest=" .. test_name }
	elseif vim.fn.filereadable(project_root .. "/build.gradle") == 1 then
		cmd = { "gradle", "test", "--tests", test_name }
	else
		return nil
	end

	-- Debugging: Print the output to check Neotest expectations
	print(vim.inspect({
		command = cmd, -- Ensure it's a table
		cwd = project_root,
		strategy = "integrated",
	}))

	return {
		command = cmd,
		cwd = project_root,
		strategy = { "integrated" },
	}
end

-- Process test results
M.results = function(spec, result, tree)
	local success = result.code == 0
	return {
		[tree:data().id] = {
			status = success and "passed" or "failed",
			output = result.output,
		},
	}
end

return M
