--- Resolve tsserver.js for typescript-tools.nvim.
--- After TS 7 / @typescript/typescript6, the hoisted `typescript` package no longer
--- ships tsserver.js; a classic typescript build may still exist under .pnpm.
---@param root string
---@return string|nil
local function find_tsserver(root)
	local standard = root .. "/node_modules/typescript/lib/tsserver.js"
	if vim.uv.fs_stat(standard) then
		return standard
	end

	local matches = vim.fn.glob(
		root .. "/node_modules/.pnpm/typescript@*/node_modules/typescript/lib/tsserver.js",
		false,
		true
	)
	if #matches == 0 then
		return nil
	end

	table.sort(matches)
	return matches[#matches]
end

---@param path string
---@return string
local function monorepo_root(path)
	return vim.fs.root(path, { "pnpm-workspace.yaml", "nx.json", "package.json" })
		or vim.fn.getcwd()
end

return {
	{
		"pmizio/typescript-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
		opts = function()
			local root = monorepo_root(vim.fn.getcwd())
			local tsserver_path = find_tsserver(root)

			return {
				settings = {
					tsserver_logs = "verbose",
					tsserver_path = tsserver_path,
				},
				root_dir = function(bufnr, on_dir)
					local path = vim.api.nvim_buf_get_name(bufnr)
					-- Prefer monorepo root (pnpm/nx) over per-package tsconfig.json.
					-- Important for git worktrees and nested libs/* projects.
					on_dir(monorepo_root(path))
				end,
			}
		end,
	},
}
