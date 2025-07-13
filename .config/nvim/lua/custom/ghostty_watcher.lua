-- Monitor ~/.config/ghostty/config for theme updates and adjust Neovim's colorscheme
local uv = vim.loop
local theme_file_path = vim.fn.expand("~/.config/ghostty/config")

-- Function to read theme from the configuration file
local function read_theme()
	local file = io.open(theme_file_path, "r")
	if not file then
		vim.notify("Failed to open theme configuration file.", vim.log.levels.ERROR)
		return nil
	end

	for line in file:lines() do
		local theme = line:match("^theme%s*=%s*(%w+)")
		if theme then
			file:close()
			return theme
		end
	end

	file:close()
	vim.notify("No theme found in configuration file.", vim.log.levels.WARN)
	return nil
end

-- Function to set the Neovim colorscheme based on the theme
local function set_colorscheme(theme)
	-- Map specific theme names to their corresponding colorscheme values
	if theme == "AtomOneLight" then
		theme = "onedark"
	elseif theme == "tokyonight-night" then
		theme = "tokyonight"
	end

	if type(theme) == "string" and theme ~= "" then
		local success, _ = pcall(function()
			vim.cmd("colorscheme " .. theme)
		end)
		if not success then
			vim.notify("Failed to set colorscheme: " .. theme, vim.log.levels.ERROR)
		end
	else
		vim.notify("Invalid theme provided: " .. tostring(theme), vim.log.levels.ERROR)
	end
end

-- Watcher function to monitor file changes
local watcher

local function start_watcher()
	if not watcher then
		watcher = uv.new_fs_poll()
	end

	watcher:start(theme_file_path, 1000, function(err, prev, curr)
		if err then
			vim.notify("Error watching theme file: " .. err, vim.log.levels.ERROR)
			return
		end

		if prev.mtime ~= curr.mtime then
			vim.schedule(function()
				vim.notify("Theme configuration file changed, reloading theme...", vim.log.levels.INFO)
				local theme = read_theme()
				if theme then
					set_colorscheme(theme)
				end
			end)
		end
	end)

	-- Ensure the watcher persists for subsequent changes
	-- vim.notify("Watcher remains active for additional changes...", vim.log.levels.INFO)

	-- Stop the watcher on Neovim exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			watcher:stop()
			watcher:close()
			watcher = nil
		end,
	})
end

-- Initialize the theme and start watching
local initial_theme = read_theme()
if initial_theme then
	set_colorscheme(initial_theme)
end
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		start_watcher()
	end,
})
