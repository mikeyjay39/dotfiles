return {
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false, -- Never set this value to "*"! Never!
		init = function()
			-- Avante maps <Tab> buffer-locally in the sidebar (pane switching), which
			-- shadows copilot.vim's global <Tab> accept map inside the input window.
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "AvanteInput", "AvantePromptInput" },
				callback = function(ev)
					if vim.fn.exists("*copilot#Accept") == 0 then
						return
					end
					vim.keymap.set("i", "<C-a>", 'copilot#Accept("")', {
						buffer = ev.buf,
						expr = true,
						replace_keycodes = false,
						silent = true,
						desc = "Accept Copilot suggestion",
					})
				end,
			})
		end,
		opts = {
			behaviour = {
				-- enable_cursor_planning_mode = true,
				auto_apply_diff_after_generation = false, -- don't auto-apply code changes
				auto_approve_tool_permissions = false, -- always ask before using file tools
			},
			instructions_file = "AGENTS.md",

			-- Define your reusable prompt templates (shortcuts) here
			shortcuts = {
				{
					name = "time",
					description = "Get the current date and time",
					details = "Returns the current date and time in ISO 8601 format.",
					prompt = [[
What is the current date and time in ISO 8601 format?
          ]],
				},
			},
			mappings = {
				-- sidebar = {
				-- 	-- pick non-Tab keys for pane switching
				-- 	switch_windows = { normal = "<C-l>", insert = "<C-l>" },
				-- 	reverse_switch_windows = { normal = "<C-h>", insert = "<C-h>" },
				-- },
				-- NOTE: mappings.suggestion only takes effect when
				-- behaviour.auto_suggestions is true; the ghost text in the input
				-- window comes from copilot.vim, mapped in `init` below.
				-- suggestion = { accept = "<C-a>" },
			},

			-- add any opts here
			-- for example
			provider = "cursor", -- ACP provider defined below; :AvanteSwitchProvider copilot to switch
			acp_providers = {
				cursor = {
					command = "cursor-agent",
					args = { "acp" },
					auth_method = "cursor_login", -- reuses `cursor-agent login`, no API key
					env = {
						-- Avante spawns ACP agents with PATH only; the cursor-agent
						-- wrapper runs under `set -u` and dereferences $HOME, so it
						-- exits immediately without this.
						HOME = os.getenv("HOME"),
					},
				},
			},
			-- openai = {
			-- 	endpoint = "https://api.openai.com/v1",
			-- 	model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
			-- 	timeout = 30000, -- Timeout in milliseconds, increase this for reasoning models
			-- 	temperature = 0,
			-- 	max_completion_tokens = 8192, -- Increase this to include reasoning tokens (for reasoning models)
			-- 	--reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
			-- },
			system_prompt = function()
				local hub = require("mcphub").get_hub_instance()
				return hub and hub:get_active_servers_prompt() or ""
			end,
			custom_tools = function()
				return {
					require("mcphub.extensions.avante").mcp_tool(),
				}
			end,
		},
		-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
		build = "make",
		-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
		dependencies = {
			"ravitemer/mcphub.nvim",
			"nvim-treesitter/nvim-treesitter",
			"stevearc/dressing.nvim",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			--- The below dependencies are optional,
			-- "echasnovski/mini.pick", -- for file_selector provider mini.pick
			"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
			"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
			"ibhagwan/fzf-lua", -- for file_selector provider fzf
			"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
			"zbirenbaum/copilot.lua", -- for providers='copilot'
			{
				-- support for image pasting
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					-- recommended settings
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- required for Windows users
						use_absolute_path = true,
						verbose = false,
					},
				},
			},
			{
				-- Make sure to set this up properly if you have lazy=true
				"MeanderingProgrammer/render-markdown.nvim",
				opts = {
					file_types = { "markdown", "Avante" },
				},
				ft = { "markdown", "Avante" },
			},
		},
	},
}
