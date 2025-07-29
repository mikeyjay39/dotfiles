-- If you started neovim within `~/dev/xy/project-1` this would resolve to `project-1`
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local home = os.getenv("HOME")
local workspace_dir = home .. "/jdtls-workspace/" .. project_name
local config = {
	cmd = {
		"/usr/lib/jvm/java-21-openjdk/bin/java",
		"-jar",
		vim.fn.glob("/usr/share/java/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
		"-configuration",
		"/usr/share/java/jdtls/config_linux", -- NOTE: need to add write permissions to this directory
		"-data",
		workspace_dir,
	},
	root_dir = vim.fn.getcwd(),
}

-- NOTE: need to run ./mwnw clean install for this
-- https://github.com/microsoft/java-debug
-- TODO: automate it in this setup

-- NOTE: need to run npm install && npm run build-plugin
-- https://github.com/microsoft/vscode-java-test

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
config.init_options = {
	bundles = bundles,
}

-- NOTE: uncomment this to turn on
jdtls.start_or_attach(config)
