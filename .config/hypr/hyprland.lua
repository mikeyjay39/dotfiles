-- Hyprland 0.55+ Lua config migrated from hyprland.conf.
-- Legacy hyprland.conf is intentionally kept as rollback fallback.

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

----------------
---- MONITORS ---
----------------
-- Auto-select monitor layout by connected panel descriptions.
-- Capture unknown sets with: ~/.scripts/hypr-monitor-info.sh

local LAPTOP_OUTPUT = "eDP-1"

local function getExternalMonitors()
	local externals = {}
	for _, monitor in ipairs(hl.get_monitors()) do
		if monitor.name ~= LAPTOP_OUTPUT then
			externals[#externals + 1] = monitor
		end
	end
	return externals
end

local function countDescriptionMatches(externals, patterns)
	local score = 0
	for _, monitor in ipairs(externals) do
		for _, pattern in ipairs(patterns) do
			if monitor.description:find(pattern, 1, true) then
				score = score + 1
				break
			end
		end
	end
	return score
end

local function applyWorkspaceRules(monitors)
	for workspace = 1, 3 do
		hl.workspace_rule({ workspace = tostring(workspace), monitor = monitors[workspace], layout = "tabbed" })
	end
	for workspace = 4, 12 do
		local monitor = monitors[((workspace - 1) % #monitors) + 1]
		hl.workspace_rule({ workspace = tostring(workspace), monitor = monitor })
	end
end

local function positionX(position)
	return tonumber(position:match("^(-?%d+)x")) or 0
end

local function applyLayout(specs)
	for _, spec in ipairs(specs) do
		hl.monitor(spec)
	end
	local ordered = {}
	for _, spec in ipairs(specs) do
		ordered[#ordered + 1] = spec
	end
	table.sort(ordered, function(a, b)
		return positionX(a.position) < positionX(b.position)
	end)
	local names = {}
	for _, spec in ipairs(ordered) do
		names[#names + 1] = spec.output
	end
	applyWorkspaceRules(names)
end

local function applySamsungLayout()
	applyLayout({
		{ output = "DP-1", mode = "1920x1200@59", position = "-1920x0", scale = 1 },
		{ output = "DP-2", mode = "1920x1200@59", position = "0x0", scale = 1 },
		{ output = LAPTOP_OUTPUT, mode = "1920x1080@60", position = "1920x0", scale = 1 },
	})
end

local function applyAsusLayout()
	applyLayout({
		{ output = LAPTOP_OUTPUT, mode = "1920x1080@60", position = "-1920x0", scale = 1 },
		{ output = "DP-1", mode = "1920x1080@59", position = "0x0", scale = 1 },
		{ output = "DP-2", mode = "1920x1080@59", position = "1920x0", scale = 1 },
	})
end

local function applyHpLayout()
	applyLayout({
		{ output = "DP-7", mode = "1920x1080@59", position = "-1920x0", scale = 1 },
		{ output = "DP-1", mode = "1920x1080@59", position = "0x0", scale = 1 },
		{ output = LAPTOP_OUTPUT, mode = "1920x1080@60", position = "1920x0", scale = 1 },
	})
end

local function applyLaptopOnlyLayout()
	applyLayout({
		{ output = LAPTOP_OUTPUT, mode = "1920x1080@60", position = "0x0", scale = 1 },
	})
end

-- Capture descriptions per dock with: ~/.scripts/hypr-monitor-info.sh
-- Paste the suggested lua entries below (skip eDP-1 / laptop panel).
--
-- HP set: auto-detected via DP-7 port. Add hpDescriptionPatterns only if
-- you need a backup match when port names change.
--
-- ASUS set: add unique description substrings after docking once.
local asusDescriptionPatterns = {
	-- "ASUSTeK COMPUTER INC ...",
}

local hpDescriptionPatterns = {
	-- "HP Inc ...",
}

local profiles = {
	{
		id = "samsung",
		match = function(externals)
			return countDescriptionMatches(externals, { "Samsung Electric Company SyncMaster" })
		end,
		apply = applySamsungLayout,
	},
	{
		id = "asus",
		match = function(externals)
			if #asusDescriptionPatterns == 0 then
				return 0
			end
			return countDescriptionMatches(externals, asusDescriptionPatterns)
		end,
		apply = applyAsusLayout,
	},
	{
		id = "hp",
		match = function(externals)
			for _, monitor in ipairs(externals) do
				if monitor.name == "DP-7" then
					return 100
				end
			end
			if #hpDescriptionPatterns == 0 then
				return 0
			end
			return countDescriptionMatches(externals, hpDescriptionPatterns)
		end,
		apply = applyHpLayout,
	},
	{
		id = "laptop",
		match = function(externals)
			return #externals == 0 and 1 or 0
		end,
		apply = applyLaptopOnlyLayout,
	},
}

local lastAppliedProfileKey = nil

local function profileKey(profileId, externals)
	local parts = { profileId }
	for _, monitor in ipairs(externals) do
		parts[#parts + 1] = monitor.name .. ":" .. monitor.description
	end
	return table.concat(parts, "|")
end

local function applyBestMonitorProfile()
	local externals = getExternalMonitors()
	local bestProfile = nil
	local bestScore = 0

	for _, profile in ipairs(profiles) do
		local score = profile.match(externals)
		if score > bestScore then
			bestScore = score
			bestProfile = profile
		end
	end

	if not bestProfile then
		return
	end

	local key = profileKey(bestProfile.id, externals)
	if key == lastAppliedProfileKey then
		return
	end
	lastAppliedProfileKey = key
	bestProfile.apply()
end

hl.on("monitor.added", applyBestMonitorProfile)
hl.on("monitor.removed", applyBestMonitorProfile)
applyBestMonitorProfile()

---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "ghostty"
local fileManager = "dolphin"
local menu = "wofi --show drun"
local browser = "brave"
local mainMod = "SUPER"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd('sh -c "sleep 1 && awww-daemon"')
	hl.exec_cmd("awww img ~/.config/hypr/modules/wallpaper/bible.gif")
	hl.exec_cmd('sh -c "sleep 2 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 30%"')
	hl.exec_cmd("blueman-applet")
end)

-----------------------
---- PERMISSIONS ------
-----------------------
hl.config({
	ecosystem = {
		no_update_news = true,
	},
})

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
	general = {
		gaps_in = 2,
		gaps_out = 2,
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(00ffffee)", "rgba(00ccffee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},
		resize_on_border = false,
		allow_tearing = false,
		layout = "tabbed",
	},
	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 0.90,
		inactive_opacity = 0.80,
		dim_inactive = true,
		dim_strength = 0.10,
		shadow = {
			enabled = true,
			range = 3,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},
	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
	input = {
		kb_layout = "us,hu",
		kb_variant = "",
		kb_model = "",
		kb_options = "grp:alt_space_toggle",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("mycurve", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 9, bezier = "mycurve", style = "slide top" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 9, bezier = "mycurve", style = "slide bottom" })
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "easeOutQuint", style = "slidefade" })

---------------------
---- KEYBINDINGS ----
---------------------
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + escape", hl.dsp.exit())
hl.bind("CTRL + M", hl.dsp.exec_cmd("wl-kbptr -o modes=tile,click"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("wl-kbptr -o modes=tile,bisect,click"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("~/.config/wofi/powermenu.sh"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + D", hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.scripts/toggle-theme.sh"))

hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.window.swap({ direction = "d" }))

-- toggle between vertical and horizontal split
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("ALT + SHIFT + tab", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("ALT + tab", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.group.move_window({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.group.move_window({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.group.move_window({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.group.move_window({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + tab", hl.dsp.group.prev())
hl.bind(mainMod .. " + tab", hl.dsp.group.next())

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
