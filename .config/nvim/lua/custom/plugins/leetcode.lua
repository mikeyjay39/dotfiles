return {
	{
		"kawre/leetcode.nvim",
		build = ":TSUpdate html", -- if you have `nvim-treesitter` installed
		dependencies = {
			-- include a picker of your choice, see picker section for more details
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
		},
		opts = {
			lang = "typescript",
			-- Rust solutions omit Solution/main; inject stubs so rust-analyzer can analyze the file.
			-- See https://github.com/kawre/leetcode.nvim/issues/86
			injector = {
				["rust"] = {
					before = {
						"#![allow(dead_code)]",
						"fn main() {}",
						"struct Solution;",
					},
				},
			},
			hooks = {
				["question_enter"] = {
					function(question)
						if question.lang ~= "rust" then
							return
						end

						local cargo_path = require("leetcode.config").user.storage.home .. "/Cargo.toml"
						local lib_path = vim.fn.fnamemodify(question:path(), ":t")
						local content = table.concat({
							"[package]",
							'name = "leetcode"',
							'edition = "2024"',
							"",
							"[lib]",
							"path = " .. vim.inspect(lib_path),
							"",
							"[dependencies]",
							'rand = "0.8"',
							'regex = "1"',
							'itertools = "0.14.0"',
							"",
						}, "\n")

						local file = io.open(cargo_path, "w")
						if not file then
							vim.notify("Failed to write " .. cargo_path, vim.log.levels.ERROR)
							return
						end
						file:write(content)
						file:close()

						vim.defer_fn(function()
							pcall(vim.cmd.RustAnalyzer, "restart")
						end, 100)
					end,
				},
			},
		},
	},
}
