local home = os.getenv("HOME")

-- nvim-jdtls runs `java.project.getSettings` on `language/status` ServiceReady to fill |'path'|.
-- eclipse.jdt.ls often is not ready yet (multi-module / worktrees) and returns errors like
-- "<service> does not exist" — harmless for LSP but noisy.
-- true: skip that sync (recommended; LSP features unchanged; `gf` on classpath less smart)
-- false + ms > 0: defer sync; false + 0: stock behavior (may error)
local jdtls_skip_service_ready_sourcepath = true
local jdtls_defer_sourcepath_ms = 0

-- Prefer Maven/Gradle roots over `.git`. If `.git` wins first, jdtls uses the repo root while the
-- Java project lives in a subdir — then java.project.getSettings can fail with "parent does not exist".
local markers_java = {
	"pom.xml",
	"mvnw",
	"gradlew",
	"settings.gradle",
	"build.gradle",
	"build.gradle.kts",
}
local markers_flat = vim.deepcopy(markers_java)
table.insert(markers_flat, ".git")

local root_dir = vim.fs.root(0, { markers_java, ".git" })
if not root_dir then
	root_dir = require("jdtls.setup").find_root(markers_flat)
end
if not root_dir then
	local buf = vim.api.nvim_buf_get_name(0)
	if buf and buf ~= "" then
		root_dir = vim.fs.dirname(buf)
	end
end
if not root_dir then
	root_dir = vim.fn.getcwd()
end

-- `-data` must match this exact project location. Using only the folder basename (e.g. fix-translator)
-- makes different worktrees or old layouts share one Eclipse dir; metadata then references project names
-- that are missing → java.project.getSettings fails with "<name> does not exist".
local root_abs = vim.fn.fnamemodify(root_dir, ":p")
local workspace_key = vim.fn.sha256(root_abs)
local workspace_dir = home .. "/jdtls-workspace/" .. workspace_key
vim.fn.mkdir(workspace_dir, "p")

local config = {
	name = "jdtls",
	cmd = {
		"/usr/lib/jvm/java-21-openjdk/bin/java",
		"-jar",
		vim.fn.glob("/usr/share/java/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
		"-configuration",
		"/usr/share/java/jdtls/config_linux", -- NOTE: need to add write permissions to this directory
		"-data",
		workspace_dir,
	},
	root_dir = root_dir,
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

local orig_lsp_start = vim.lsp.start
vim.lsp.start = function(lsp_config, start_opts)
	if lsp_config.name == "jdtls" and lsp_config.handlers and lsp_config.handlers["language/status"] then
		local status_h = lsp_config.handlers["language/status"]
		lsp_config.handlers["language/status"] = function(err, result, ctx)
			if result and result.type == "ServiceReady" then
				if jdtls_skip_service_ready_sourcepath then
					return
				end
				if jdtls_defer_sourcepath_ms > 0 then
					vim.defer_fn(function()
						status_h(err, result, ctx)
					end, jdtls_defer_sourcepath_ms)
					return
				end
			end
			return status_h(err, result, ctx)
		end
	end
	return orig_lsp_start(lsp_config, start_opts)
end

jdtls.start_or_attach(config)

vim.lsp.start = orig_lsp_start
