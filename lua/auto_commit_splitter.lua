local M = {}

-- 文件类型定义
local file_types = {
	-- 核心功能代码
	core = {
		patterns = {"^lua/[^/]+%.lua$", "^src/[^/]+%.[^/]+$", "^lib/[^/]+%.[^/]+$"},
		extensions = {".lua", ".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp"},
		priority = 1,
		commit_prefix = "feat"
	},
	-- API/接口相关
	api = {
		patterns = {"api/", "routes/", "controllers/", "handlers/", "endpoints/"},
		priority = 2,
		commit_prefix = "feat"
	},
	-- UI/前端相关
	ui = {
		patterns = {"components/", "views/", "pages/", "ui/", "frontend/"},
		extensions = {".vue", ".jsx", ".tsx", ".svelte"},
		priority = 3,
		commit_prefix = "feat"
	},
	-- 样式相关
	style = {
		extensions = {".css", ".scss", ".sass", ".less", ".styl"},
		patterns = {"styles/", "css/"},
		priority = 4,
		commit_prefix = "style"
	},
	-- 测试相关
	test = {
		patterns = {"test/", "tests/", "spec/", "_test%.", "_spec%.", "%.test%.", "%.spec%."},
		priority = 5,
		commit_prefix = "test"
	},
	-- 配置相关
	config = {
		extensions = {".json", ".yaml", ".yml", ".toml", ".ini", ".conf", ".env"},
		patterns = {"config/", "configs/", "%.config%."},
		priority = 6,
		commit_prefix = "chore"
	},
	-- 构建/部署相关
	build = {
		patterns = {"build/", "dist/", "scripts/", "Makefile", "Dockerfile", "%.github/", "%.gitlab"},
		files = {"package.json", "package-lock.json", "yarn.lock", "requirements.txt", "go.mod", "Cargo.toml"},
		priority = 7,
		commit_prefix = "build"
	},
	-- 文档相关
	docs = {
		extensions = {".md", ".rst", ".txt", ".adoc"},
		patterns = {"docs/", "documentation/", "README", "CHANGELOG", "LICENSE"},
		priority = 8,
		commit_prefix = "docs"
	},
	-- 资源文件
	assets = {
		extensions = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".webp"},
		patterns = {"assets/", "images/", "icons/", "static/"},
		priority = 9,
		commit_prefix = "chore"
	}
}

-- 功能组定义（更高级的分组）
local function_groups = {
	-- 认证相关
	auth = {
		keywords = {"auth", "login", "logout", "session", "token", "user", "permission", "role"},
		priority = 1
	},
	-- 数据库相关
	database = {
		keywords = {"database", "db", "model", "schema", "migration", "query", "orm"},
		priority = 2
	},
	-- API相关
	api = {
		keywords = {"api", "endpoint", "route", "controller", "handler", "rest", "graphql"},
		priority = 3
	},
	-- UI组件
	component = {
		keywords = {"component", "widget", "button", "form", "modal", "dialog", "menu"},
		priority = 4
	},
	-- 工具函数
	utils = {
		keywords = {"util", "helper", "tool", "common", "shared", "lib"},
		priority = 5
	},
	-- 业务逻辑
	business = {
		keywords = {"service", "business", "logic", "process", "workflow", "manager"},
		priority = 6
	}
}

-- 分析文件属于哪个功能组
local function analyze_file_function(file_path, diff_content)
	local filename = file_path:match("[^/]+$") or ""
	local path_lower = file_path:lower()
	local content_lower = (diff_content or ""):lower()
	
	-- 检查功能关键词
	local scores = {}
	for group_name, group_info in pairs(function_groups) do
		scores[group_name] = 0
		for _, keyword in ipairs(group_info.keywords) do
			-- 在文件路径中查找
			if path_lower:match(keyword) then
				scores[group_name] = scores[group_name] + 3
			end
			-- 在文件内容中查找
			if content_lower:match(keyword) then
				scores[group_name] = scores[group_name] + 1
			end
		end
	end
	
	-- 找出得分最高的功能组
	local best_group = "general"
	local best_score = 0
	for group_name, score in pairs(scores) do
		if score > best_score then
			best_score = score
			best_group = group_name
		end
	end
	
	return best_group, best_score
end

-- 获取文件类型
local function get_file_type(file_path)
	local filename = file_path:match("[^/]+$") or ""
	local extension = file_path:match("%.([^%.]+)$")
	
	for type_name, type_info in pairs(file_types) do
		-- 检查特定文件名
		if type_info.files then
			for _, file in ipairs(type_info.files) do
				if filename == file then
					return type_name, type_info
				end
			end
		end
		
		-- 检查路径模式
		if type_info.patterns then
			for _, pattern in ipairs(type_info.patterns) do
				if file_path:match(pattern) then
					return type_name, type_info
				end
			end
		end
		
		-- 检查扩展名
		if type_info.extensions and extension then
			for _, ext in ipairs(type_info.extensions) do
				if ext == "." .. extension then
					return type_name, type_info
				end
			end
		end
	end
	
	return "other", {priority = 10, commit_prefix = "chore"}
end

-- 获取文件的diff内容
local function get_file_diff(file_path)
	local diff = vim.fn.system("git diff --cached -- " .. vim.fn.shellescape(file_path))
	return diff
end

-- 创建智能分组
local function create_smart_groups(files)
	local groups = {}
	
	-- 第一步：按功能分组
	local function_based_groups = {}
	for _, file in ipairs(files) do
		local diff_content = get_file_diff(file.path)
		local func_group, score = analyze_file_function(file.path, diff_content)
		
		-- 只有得分大于0才使用功能分组
		if score > 0 then
			if not function_based_groups[func_group] then
				function_based_groups[func_group] = {
					name = func_group,
					files = {},
					type = "function",
					priority = function_groups[func_group].priority or 10
				}
			end
			table.insert(function_based_groups[func_group].files, file)
		else
			-- 否则按文件类型分组
			local file_type, type_info = get_file_type(file.path)
			local group_key = "type_" .. file_type
			
			if not function_based_groups[group_key] then
				function_based_groups[group_key] = {
					name = file_type,
					files = {},
					type = "file_type",
					priority = type_info.priority,
					commit_prefix = type_info.commit_prefix
				}
			end
			table.insert(function_based_groups[group_key].files, file)
		end
	end
	
	-- 转换为数组并排序
	for _, group in pairs(function_based_groups) do
		if #group.files > 0 then
			table.insert(groups, group)
		end
	end
	
	-- 按优先级排序
	table.sort(groups, function(a, b)
		return a.priority < b.priority
	end)
	
	return groups
end

-- 生成提交信息
local function generate_commit_message(group)
	local prefix = "feat"
	local scope = group.name
	local description = ""
	
	if group.type == "function" then
		-- 功能组的提交信息
		if group.name == "auth" then
			description = "update authentication logic"
			prefix = "feat"
		elseif group.name == "database" then
			description = "update database operations"
			prefix = "feat"
		elseif group.name == "api" then
			description = "update API endpoints"
			prefix = "feat"
		elseif group.name == "component" then
			description = "update UI components"
			prefix = "feat"
		elseif group.name == "utils" then
			description = "update utility functions"
			prefix = "refactor"
		elseif group.name == "business" then
			description = "update business logic"
			prefix = "feat"
		else
			description = "update " .. group.name .. " functionality"
			prefix = "feat"
		end
	else
		-- 文件类型组的提交信息
		prefix = group.commit_prefix or "chore"
		
		if group.name == "core" then
			description = "update core functionality"
		elseif group.name == "test" then
			description = "add/update tests"
		elseif group.name == "docs" then
			description = "update documentation"
		elseif group.name == "config" then
			description = "update configuration"
		elseif group.name == "build" then
			description = "update build configuration"
		elseif group.name == "style" then
			description = "update styles"
		else
			description = "update " .. group.name .. " files"
		end
	end
	
	-- 添加文件统计
	local file_count = #group.files
	if file_count > 1 then
		description = description .. " (" .. file_count .. " files)"
	end
	
	return string.format("%s(%s): %s", prefix, scope, description)
end

-- 执行提交
local function commit_group(group, commit_message)
	local Job = require("plenary.job")
	
	-- 准备文件路径
	local file_paths = {}
	for _, file in ipairs(group.files) do
		table.insert(file_paths, file.path)
	end
	
	-- 重置暂存区
	vim.fn.system("git reset HEAD")
	
	-- 重新添加这个组的文件
	local add_cmd = "git add"
	for _, path in ipairs(file_paths) do
		add_cmd = add_cmd .. " " .. vim.fn.shellescape(path)
	end
	vim.fn.system(add_cmd)
	
	-- 执行提交
	local commit_cmd = string.format("git commit -m %s", vim.fn.shellescape(commit_message))
	local result = vim.fn.system(commit_cmd)
	
	if vim.v.shell_error == 0 then
		vim.notify(string.format("✅ Committed: %s", commit_message), vim.log.levels.INFO)
		return true
	else
		vim.notify(string.format("❌ Failed to commit: %s", result), vim.log.levels.ERROR)
		return false
	end
end

-- 主函数：自动拆分并提交
function M.auto_split_and_commit()
	-- 获取所有暂存的文件
	local staged_output = vim.fn.system("git diff --cached --name-status")
	if staged_output == "" then
		vim.notify("No staged changes found", vim.log.levels.WARN)
		return
	end
	
	-- 解析文件
	local files = {}
	for line in staged_output:gmatch("[^\n]+") do
		local status, file_path = line:match("^([AMDRC]%d*)%s+(.+)$")
		if status and file_path then
			table.insert(files, {
				path = file_path,
				status = status:sub(1, 1)
			})
		end
	end
	
	if #files == 0 then
		vim.notify("No files to process", vim.log.levels.WARN)
		return
	end
	
	vim.notify(string.format("🔍 Analyzing %d files for smart grouping...", #files), vim.log.levels.INFO)
	
	-- 创建智能分组
	local groups = create_smart_groups(files)
	
	vim.notify(string.format("📊 Created %d groups based on functionality", #groups), vim.log.levels.INFO)
	
	-- 自动提交每个组
	local success_count = 0
	local total_count = #groups
	
	for i, group in ipairs(groups) do
		local commit_message = generate_commit_message(group)
		
		vim.notify(string.format("🔄 [%d/%d] Processing %s group with %d files...", 
			i, total_count, group.name, #group.files), vim.log.levels.INFO)
		
		if commit_group(group, commit_message) then
			success_count = success_count + 1
		end
		
		-- 短暂延迟，避免过快
		vim.wait(100)
	end
	
	-- 完成通知
	if success_count == total_count then
		vim.notify(string.format("✅ Successfully created %d commits!", success_count), vim.log.levels.INFO)
	else
		vim.notify(string.format("⚠️  Created %d/%d commits. Some commits failed.", success_count, total_count), vim.log.levels.WARN)
	end
	
	-- 显示提交历史
	local log_output = vim.fn.system("git log --oneline -n " .. success_count)
	vim.notify("Recent commits:\n" .. log_output, vim.log.levels.INFO)
end

-- 预览分组（不实际提交）
function M.preview_auto_split()
	-- 获取所有暂存的文件
	local staged_output = vim.fn.system("git diff --cached --name-status")
	if staged_output == "" then
		vim.notify("No staged changes found", vim.log.levels.WARN)
		return
	end
	
	-- 解析文件
	local files = {}
	for line in staged_output:gmatch("[^\n]+") do
		local status, file_path = line:match("^([AMDRC]%d*)%s+(.+)$")
		if status and file_path then
			table.insert(files, {
				path = file_path,
				status = status:sub(1, 1)
			})
		end
	end
	
	-- 创建智能分组
	local groups = create_smart_groups(files)
	
	-- 显示预览
	local preview_lines = {
		"═══════════════════════════════════════════════",
		"        AUTO COMMIT SPLIT PREVIEW              ",
		"═══════════════════════════════════════════════",
		"",
		string.format("Total files: %d", #files),
		string.format("Groups created: %d", #groups),
		"",
		"Planned commits:",
		""
	}
	
	for i, group in ipairs(groups) do
		local commit_message = generate_commit_message(group)
		table.insert(preview_lines, string.format("%d. %s", i, commit_message))
		for _, file in ipairs(group.files) do
			table.insert(preview_lines, string.format("   - %s", file.path))
		end
		table.insert(preview_lines, "")
	end
	
	table.insert(preview_lines, "═══════════════════════════════════════════════")
	
	-- 创建预览窗口
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, preview_lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
end

return M