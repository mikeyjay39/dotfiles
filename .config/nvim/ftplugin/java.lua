local config = {
	cmd = { "~/.local/share/nvim/mason/packages/jdtls/bin/jdtls" },
	root_dir = vim.fs.dirname(vim.fs.find({ "pom.xml", "gradlew", ".git", "mvnw" }, { upward = true })[1]),
	-- root_dir = vim.fn.getcwd(),
}
local function find_jars(pattern)
	local files = vim.fn.glob(vim.fn.expand(pattern), true, true)
	if type(files) == "string" and files ~= "" then
		return { files }
	elseif type(files) == "table" then
		return files
	end
	return {}
end

-- NOTE: need to run ./mwnw clean install for this
-- TODO: automate it in this setup
local java_debug_plugin =
	find_jars("/home/mikeyjay/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar")

-- NOTE: need to run npm install && npm run build-plugin
-- TODO: automate the command in the note above
local test_bundles = vim.fn.globpath("/home/mikeyjay/vscode-java-test/server", "*.jar", true, true)

local bundles = {}
vim.list_extend(bundles, java_debug_plugin)
vim.list_extend(bundles, test_bundles)

config.init_options = {
	bundles = bundles,
}
-- print("Final Root Dir:", config.root_dir)
-- NOTE: uncomment this to turn on
require("jdtls").start_or_attach(config)
