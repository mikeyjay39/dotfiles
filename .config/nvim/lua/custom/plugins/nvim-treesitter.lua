-- Neovim 0.12+ uses nvim-treesitter `main` (see `:help nvim-treesitter` and upstream README).
local parsers = {
	"bash",
	"zsh",
	"c",
	"diff",
	"html",
	"lua",
	"luadoc",
	"markdown",
	"markdown_inline",
	"query",
	"vim",
	"vimdoc",
	"java",
	"typescript",
	"rust",
}

-- Filetypes that should use treesitter highlight + nvim-treesitter indent (parser names differ).
local ts_filetypes = {
	"bash",
	"sh",
	"zsh",
	"c",
	"diff",
	"html",
	"lua",
	"markdown",
	"query",
	"vim",
	"help",
	"java",
	"typescript",
	"typescriptreact",
	"rust",
}

local prepended_bins = {}

local function prepend_path_bins()
	local sep = vim.fn.has("win32") == 1 and ";" or ":"
	for _, dir in ipairs({ vim.fn.expand("~/.local/bin"), vim.fn.expand("~/.cargo/bin") }) do
		if not prepended_bins[dir] and vim.fn.isdirectory(dir) == 1 then
			vim.env.PATH = dir .. sep .. vim.env.PATH
			prepended_bins[dir] = true
		end
	end
end

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		-- Before load/build so `:TSUpdate` can find `tree-sitter` (e.g. under ~/.cargo/bin).
		init = prepend_path_bins,
		config = function()
			require("nvim-treesitter").install(parsers):wait(300000)

			vim.api.nvim_create_autocmd("FileType", {
				pattern = ts_filetypes,
				callback = function()
					vim.treesitter.start()
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
}
