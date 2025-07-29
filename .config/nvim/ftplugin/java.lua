-- If you started neovim within `~/dev/xy/project-1` this would resolve to `project-1`
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local home = os.getenv("HOME")
local workspace_dir = "/home/mikeyjay/jdtls-workspace/" .. project_name
local config = {
	-- cmd = { "/home/mikeyjay/.local/share/nvim/mason/packages/jdtls/bin/jdtls", "-data", workspace_dir },
	cmd = {
		"/usr/lib/jvm/java-21-openjdk/bin/java",
		-- "jdtls",
		-- "-Declipse.application=org.eclipse.jdt.ls.core.id1",
		-- "-Dosgi.bundles.defaultStartLevel=4",
		-- "-Declipse.product=org.eclipse.jdt.ls.core.product",
		-- "-Dlog.protocol=true",
		-- "-Dlog.level=ALL",
		-- "-Xmx4g",
		-- "--add-modules=ALL-SYSTEM",
		-- "--add-opens",
		-- "java.base/java.util=ALL-UNNAMED",
		-- "--add-opens",
		-- "java.base/java.lang=ALL-UNNAMED",
		"-jar",
		vim.fn.glob("/usr/share/java/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
		"-configuration",
		"/usr/share/java/jdtls/config_linux", -- NOTE: need to add write permissions to this directory
		"-data",
		workspace_dir,
	},
	-- root_dir = vim.fs.dirname(vim.fs.find({ "pom.xml", "gradlew", ".git", "mvnw" }, { upward = true })[1]),
	root_dir = vim.fn.getcwd(),
	-- root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = false })[1]),
	-- root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = true })[1]),
	-- on_attach = function(client, bufnr)
	-- 	vim.lsp.set_log_level("debug")
	-- end,
	-- settings = {
	-- 	java = {
	-- 		symbols = {
	-- 			includesourcemethoddeclaratiokns = true,
	-- 		},
	-- 	},
	-- },
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
-- https://github.com/microsoft/java-debug
-- TODO: automate it in this setup
local java_debug_plugin =
	find_jars("/home/mikeyjay/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar")

-- NOTE: need to run npm install && npm run build-plugin
-- https://github.com/microsoft/vscode-java-test
-- TODO: automate the command in the note above
-- local test_bundles = vim.fn.globpath("/home/mikeyjay/vscode-java-test/server", "*.jar", true, true)
--
-- local bundles = {}
-- vim.list_extend(bundles, java_debug_plugin)
-- vim.list_extend(bundles, test_bundles)

-- This bundles definition is the same as in the previous section (java-debug installation)
-- local bundles = {
-- 	vim.fn.glob(
-- 		"/home/mikeyjay/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar",
-- 		1
-- 	),
-- }
--
-- -- This is the new part
-- vim.list_extend(bundles, vim.split(vim.fn.glob("/home/mikeyjay/vscode-java-test/server/*.jar", 1), "\n"))
-- config["init_options"] = {
-- 	bundles = bundles,
-- }

local jar_patterns = {
	"/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar",
	-- '/dev/dgileadi/vscode-java-decompiler/server/*.jar',
	"/vscode-java-test/java-extension/com.microsoft.java.test.plugin/target/*.jar",
	"/vscode-java-test/java-extension/com.microsoft.java.test.runner/target/*.jar",
	"/vscode-java-test/java-extension/com.microsoft.java.test.runner/lib/*.jar",
	-- '/dev/testforstephen/vscode-pde/server/*.jar'
}
-- npm install broke for me: https://github.com/npm/cli/issues/2508
-- So gather the required jars manually; this is based on the gulpfile.js in the vscode-java-test repo
local plugin_path = "/vscode-java-test/java-extension/com.microsoft.java.test.plugin.site/target/repository/plugins/"
local bundle_list = vim.tbl_map(function(x)
	return require("jdtls.path").join(plugin_path, x)
end, {
	"org.eclipse.jdt.junit4.runtime_*.jar",
	"org.eclipse.jdt.junit5.runtime_*.jar",
	"org.junit.jupiter.api*.jar",
	"org.junit.jupiter.engine*.jar",
	"org.junit.jupiter.migrationsupport*.jar",
	"org.junit.jupiter.params*.jar",
	"org.junit.vintage.engine*.jar",
	-- "org.opentest4j*.jar",
	"org.junit.platform.commons*.jar",
	"org.junit.platform.engine*.jar",
	"org.junit.platform.launcher*.jar",
	"org.junit.platform.runner*.jar",
	"org.junit.platform.suite.api*.jar",
	-- "org.apiguardian*.jar",
})
vim.list_extend(jar_patterns, bundle_list)
local bundles = {}
for _, jar_pattern in ipairs(jar_patterns) do
	for _, bundle in ipairs(vim.split(vim.fn.glob(home .. jar_pattern), "\n")) do
		if
			not vim.endswith(bundle, "com.microsoft.java.test.runner-jar-with-dependencies.jar")
			and not vim.endswith(bundle, "com.microsoft.java.test.runner.jar")
		then
			table.insert(bundles, bundle)
		end
	end
end
local jdtls = require("jdtls")
local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
-- jdtls.setup_dap({
-- 	config_overrides = {
-- 		noDebug = false,
-- 		vmArgs = "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005",
-- 	},
-- })
config.init_options = {
	bundles = bundles,
}

-- Add jars from .m2 repository
-- local m2_jars = vim.fn.globpath("~/TKT-14675-java-logs-tracing/.m2/repository", "**/*.jar", true, true)
-- vim.notify("Found " .. #m2_jars .. " jars in .m2 repository", vim.log.levels.INFO, { title = "Java LSP" })
-- -- Extend bundles with .m2 jars
-- vim.list_extend(bundles, m2_jars)

-- config.init_options = {
-- 	logLevel = "INFO", -- Set the desired log level
-- 	bundles = bundles,
-- }
-- print("Final Root Dir:", config.root_dir)
-- NOTE: uncomment this to turn on
jdtls.start_or_attach(config)
