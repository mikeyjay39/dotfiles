local neotest = require("neotest")

local M = {}

-- Escape a test title into a vitest --testNamePattern regex fragment.
-- Mirrors neotest-vitest's own escaping: metacharacters are backslash-escaped
-- and spaces become \s.
local function escape_test_pattern(s)
	return (s:gsub("[%(%)%[%]%.%*%+%-%?%$%^%/]", "\\%0"):gsub(" ", "\\s"))
end

-- Rewrite the --testNamePattern entry of a command list in place. Returns true if found.
local function replace_test_name_pattern(list, pattern)
	if type(list) ~= "table" then
		return false
	end
	for i, arg in ipairs(list) do
		if type(arg) == "string" and arg:match("^%-%-testNamePattern=") then
			list[i] = "--testNamePattern=" .. pattern
			return true
		end
	end
	return false
end

-- vitest v5 joins describe/it names with " > " when matching --testNamePattern.
-- neotest-vitest (c3c6971) still joins them with a single space, so every test nested
-- inside a describe fails to match and is reported "skipped".
-- Wrap build_spec to rebuild the pattern with the " > " separator.
--
-- The rewrite must hit two places. A normal run reads the pattern from spec.command.
-- A debugger (DAP) run reads it from spec.strategy.args, which get_strategy_config builds
-- as a copy of command *at build time* — so rewriting spec.command alone leaves the debug
-- config with the old single-space pattern, and the debugger skips every nested test.
--
-- TEMPORARY: remove this wrapper (and call require("neotest-vitest")({...}) directly)
-- once https://github.com/marilari88/neotest-vitest/pull/99 is merged and pulled in.
local function patch_vitest_separator(adapter)
	local orig_build_spec = adapter.build_spec
	adapter.build_spec = function(args)
		local spec = orig_build_spec(args)
		if not (spec and args.tree) then
			return spec
		end

		local names = {}
		local tree = args.tree
		while tree and tree:data().type ~= "file" and tree:data().type ~= "dir" do
			table.insert(names, 1, tree:data().name)
			tree = tree:parent()
		end
		if #names == 0 then
			return spec -- whole-file/dir run uses ".*"; leave it untouched
		end

		local pattern = "^\\s?" .. escape_test_pattern(table.concat(names, " > "))
		if args.tree:data().type == "test" then
			pattern = pattern .. "$"
		end

		replace_test_name_pattern(spec.command, pattern)
		if spec.strategy then
			replace_test_name_pattern(spec.strategy.args, pattern)
		end
		return spec
	end
	return adapter
end

M.setup = function()
	neotest.setup({
		-- WARN (not DEBUG): DEBUG grows neotest.log without bound (it had reached 112MB).
		log_level = vim.log.levels.WARN,
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
			patch_vitest_separator(require("neotest-vitest")({
				filter_dir = function(name, rel_path, root)
					return name ~= "node_modules"
				end,
			})),
		},
	})

	-- After neotest-rust is fully loaded (avoid circular require with debug.lua)
	require("custom.neotest-rust-dap-patch").apply()
end

return M
