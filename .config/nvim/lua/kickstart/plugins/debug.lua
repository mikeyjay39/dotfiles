-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
	{
		"microsoft/vscode-js-debug",
		build = "npm install --legacy-peer-deps && npx gulp dapDebugServer && mv dist out",
	},
	{
		-- NOTE: Yes, you can install new plugins here!
		"mfussenegger/nvim-dap",
		-- NOTE: And you can specify dependencies as well
		dependencies = {
			-- Creates a beautiful debugger UI
			"rcarriga/nvim-dap-ui",

			-- Required dependency for nvim-dap-ui
			"nvim-neotest/nvim-nio",

			-- Installs the debug adapters for you
			"williamboman/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",

			-- Add your own debuggers here
			"leoluz/nvim-dap-go",
		},
		keys = function(_, keys)
			local dap = require("dap")
			local dapui = require("dapui")
			return {
				{
					"<leader>td",
					function()
						require("neotest").run.run({ strategy = "dap" })
					end,
					desc = "Debug Nearest",
				},
				-- Basic debugging keymaps, feel free to change to your liking!
				{ "<F5>", dap.continue, desc = "Debug: Start/Continue" },
				{ "<F1>", dap.step_into, desc = "Debug: Step Into" },
				{ "<F2>", dap.step_over, desc = "Debug: Step Over" },
				{ "<F3>", dap.step_out, desc = "Debug: Step Out" },
				{ "<leader>b", dap.toggle_breakpoint, desc = "Debug: Toggle Breakpoint" },
				{
					"<leader>B",
					function()
						dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
					end,
					desc = "Debug: Set Breakpoint",
				},
				-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
				{ "<F7>", dapui.toggle, desc = "Debug: See last session result." },
				unpack(keys),
			}
		end,
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			require("mason-nvim-dap").setup({
				-- Makes a best effort to setup the various debuggers with
				-- reasonable debug configurations
				automatic_installation = true,

				-- You can provide additional configuration to the handlers,
				-- see mason-nvim-dap README for more information
				handlers = {},

				-- You'll need to check that you have the required things installed
				-- online, please don't ask me how to install them :)
				ensure_installed = {
					-- Update this to ensure that you have the debuggers for the langs you want
					-- "delve",
					-- "node2",
					"pwa-node",
					"java",
					"neotest,",
					"codelldb",
				},
			})

			-- Dap UI setup
			-- For more information, see |:help nvim-dap-ui|
			dapui.setup({
				-- Set icons to characters that are more likely to work in every terminal.
				--    Feel free to remove or use ones that you like more! :)
				--    Don't feel like these are good choices.
				icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
				controls = {
					icons = {
						pause = "⏸",
						play = "▶",
						step_into = "⏎",
						step_over = "⏭",
						step_out = "⏮",
						step_back = "b",
						run_last = "▶▶",
						terminate = "⏹",
						disconnect = "⏏",
					},
				},
			})

			-- Change breakpoint icons
			-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
			-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
			-- local breakpoint_icons = vim.g.have_nerd_font
			--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
			--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
			-- for type, icon in pairs(breakpoint_icons) do
			--   local tp = 'Dap' .. type
			--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
			--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
			-- end

			dap.listeners.after.event_initialized["dapui_config"] = dapui.open
			--dap.listeners.before.event_terminated["dapui_config"] = dapui.close
			--dap.listeners.before.event_exited["dapui_config"] = dapui.close
			--
			-- dap.adapters.java = function(callback)
			-- 	-- FIXME:
			-- 	-- Here a function needs to trigger the `vscode.java.startDebugSession` LSP command
			-- 	-- The response to the command must be the `port` used below
			-- 	callback({
			-- 		type = "server",
			-- 		host = "127.0.0.1",
			-- 		port = 5005,
			-- 	})
			-- end
			-- dap.adapters.java = {
			-- 	type = "server",
			-- 	host = "127.0.0.1",
			-- 	port = 5005,
			-- }
			--
			-- dap.configurations.java = {
			-- 	{
			-- 		type = "java",
			-- 		name = "Debug (Attach) - Remote",
			-- 		request = "attach",
			-- 		hostName = "127.0.0.1",
			-- 		port = 5005,
			-- 	},
			-- 	{
			-- 		type = "java",
			-- 		name = "Debug (Launch) - Project",
			-- 		request = "launch",
			-- 		mainClass = "${file}",
			-- 		cwd = vim.fn.getcwd(),
			-- 		stopOnEntry = false,
			-- 	},
			-- }
			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				host = "localhost",
				executable = {
					command = "codelldb",
					args = { "--port", "${port}" },
				},
			}
			dap.configurations.rust = {
				{
					name = "Launch file",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
				},
			}

			require("dap").adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					-- 💀 Make sure to update this path to point to your installation
					-- clone this repo: https://github.com/microsoft/vscode-js-debug/releases
					args = {
						"/home/mikeyjay/.local/share/nvim/lazy/vscode-js-debug/out/src/dapDebugServer.js",
						"${port}",
					},
				},
			}

			for _, language in ipairs({ "typescript", "javascript" }) do
				require("dap").configurations[language] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Debug Jest Tests",
						-- trace = true, -- include debugger info
						runtimeExecutable = "node",
						runtimeArgs = {
							"./node_modules/jest/bin/jest.js",
							"--runInBand",
						},
						rootPath = "${workspaceFolder}",
						cwd = "${workspaceFolder}",
						console = "integratedTerminal",
						internalConsoleOptions = "neverOpen",
					},
				}
			end
		end,
	},
}
