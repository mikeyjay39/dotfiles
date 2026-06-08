--- Patch neotest-rust DAP binary lookup for Cargo workspace member lib unit tests.
---
--- neotest-rust runs `cargo test --no-run` without `--workspace` or `-p`, so unit
--- tests in workspace member libs (e.g. backend/libs/auth) never appear in cargo
--- JSON and `program` is nil when launching codelldb.
local M = {}

local function get_src_paths(root, extra_args)
	local sep = require("plenary.path").path.sep
	local src_paths = {}
	local src_filter = '"src_path":"(.+' .. sep .. '.+.rs)",'
	local exe_filter = '"executable":"(.+' .. sep .. "deps" .. sep .. '.+)",'

	local cmd = {
		"cargo",
		"test",
		"--manifest-path=" .. root .. sep .. "Cargo.toml",
		"--message-format=JSON",
		"--no-run",
		"--quiet",
	}
	vim.list_extend(cmd, extra_args or {})

	local ok, handle = pcall(io.popen, table.concat(cmd, " "))
	if not ok or not handle then
		return src_paths
	end

	for line in handle:lines() do
		if string.find(line, src_filter) and string.find(line, exe_filter) then
			src_paths[string.match(line, src_filter)] = string.match(line, exe_filter)
		end
	end
	handle:close()

	return src_paths
end

local function package_for_path(workspace_root, path)
	local lib = require("neotest.lib")
	local sep = require("plenary.path").path.sep
	local package_root = lib.files.match_root_pattern("Cargo.toml")(path)
	if not package_root then
		return nil, nil
	end

	local workspace_prefix = workspace_root .. sep
	if package_root:sub(1, #workspace_prefix) ~= workspace_prefix then
		return nil, nil
	end

	for _, line in ipairs(vim.fn.readfile(package_root .. sep .. "Cargo.toml")) do
		local name = line:match('^name = "([^"]+)"')
		if name then
			return name, package_root
		end
	end

	return nil, nil
end

local function unit_test_entrypoint(package_root)
	local sep = require("plenary.path").path.sep
	local lib_rs = package_root .. sep .. "src/lib.rs"
	local main_rs = package_root .. sep .. "src/main.rs"

	if vim.fn.filereadable(lib_rs) == 1 then
		return lib_rs
	end
	if vim.fn.filereadable(main_rs) == 1 then
		return main_rs
	end

	return nil
end

local function find_in_package(root, path, package_name, package_root)
	local sep = require("plenary.path").path.sep
	local src_paths = get_src_paths(root, { "-p", package_name })

	if src_paths[path] then
		return src_paths[path]
	end

	local src_dir = package_root .. sep .. "src" .. sep
	if path:sub(1, #src_dir) == src_dir then
		local entrypoint = unit_test_entrypoint(package_root)
		if entrypoint and src_paths[entrypoint] then
			return src_paths[entrypoint]
		end
	end

	return nil
end

function M.apply()
	local neotest_rust_dap = require("neotest-rust.dap")
	if neotest_rust_dap.__workspace_dap_patch then
		return
	end
	neotest_rust_dap.__workspace_dap_patch = true

	local orig_get_test_binary = neotest_rust_dap.get_test_binary

	neotest_rust_dap.get_test_binary = function(root, path)
		local ok, binary = pcall(orig_get_test_binary, root, path)
		if ok and binary then
			return binary
		end

		local package_name, package_root = package_for_path(root, path)
		if not package_name then
			return nil
		end

		binary = find_in_package(root, path, package_name, package_root)
		if binary then
			return binary
		end

		local src_paths = get_src_paths(root, { "--workspace" })
		if src_paths[path] then
			return src_paths[path]
		end

		local entrypoint = unit_test_entrypoint(package_root)
		return entrypoint and src_paths[entrypoint]
	end
end

return M
