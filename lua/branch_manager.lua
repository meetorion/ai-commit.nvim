local M = {}

-- 分支类型和前缀配置
local branch_types = {
	feature = {
		prefix = "feature/",
		keywords = {"feat", "add", "new", "implement", "create", "build", "增加", "新增", "实现", "创建", "构建"},
		patterns = {
			"^%+.*function", -- 新增函数
			"^%+.*class", -- 新增类
			"^%+.*module", -- 新增模块
			"^%+.*API", -- API相关
			"^%+.*endpoint", -- 新端点
		},
		weight = 1
	},
	fix = {
		prefix = "fix/",
		keywords = {"fix", "bug", "issue", "error", "problem", "resolve", "patch", "修复", "错误", "问题", "解决"},
		patterns = {
			"try.*catch", -- 错误处理
			"if.*error", -- 错误检查
			"fix.*bug", -- 修复bug
			"resolve.*issue", -- 解决问题
		},
		weight = 2
	},
	hotfix = {
		prefix = "hotfix/",
		keywords = {"hotfix", "urgent", "critical", "security", "emergency", "紧急", "严重", "安全", "关键"},
		patterns = {
			"security", -- 安全相关
			"critical", -- 关键修复
			"urgent", -- 紧急修复
		},
		weight = 3
	},
	docs = {
		prefix = "docs/",
		keywords = {"docs", "doc", "readme", "comment", "documentation", "文档", "说明", "注释"},
		patterns = {
			"%.md$", -- Markdown文件
			"README", -- README文件
			"^%+.*%-%-%s", -- 注释行
			"^%+.*%/%*", -- 块注释
		},
		weight = 1
	},
	refactor = {
		prefix = "refactor/",
		keywords = {"refactor", "restructure", "optimize", "improve", "clean", "重构", "优化", "改进", "清理"},
		patterns = {
			"rename", -- 重命名
			"move", -- 移动
			"extract", -- 提取
			"optimize", -- 优化
		},
		weight = 1
	},
	style = {
		prefix = "style/",
		keywords = {"style", "format", "lint", "prettier", "格式", "样式", "规范"},
		patterns = {
			"^%+%s*$", -- 空行
			"^%-%-%-", -- 分隔线
			"indent", -- 缩进
		},
		weight = 0.5
	},
	test = {
		prefix = "test/",
		keywords = {"test", "spec", "testing", "测试", "用例"},
		patterns = {
			"_test%.lua$", -- 测试文件
			"_spec%.lua$", -- 规范文件
			"describe%(", -- 测试描述
			"it%(", -- 测试用例
		},
		weight = 1
	},
	chore = {
		prefix = "chore/",
		keywords = {"chore", "build", "deps", "config", "setup", "构建", "依赖", "配置", "设置"},
		patterns = {
			"package%.json", -- 依赖文件
			"%.toml$", -- 配置文件
			"%.yml$", -- YAML配置
			"%.config", -- 配置文件
		},
		weight = 0.5
	}
}

-- 停用词列表
local stop_words = {
	"the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
	"这个", "那个", "一个", "的", "了", "和", "或者", "但是", "在", "对", "为了", "通过"
}

-- 分析git变更获取文件信息
local function analyze_git_changes()
	-- 获取staged文件
	local staged_files = vim.fn.system("git diff --cached --name-status")
	if staged_files == "" then
		-- 如果没有staged文件，分析最近的commit
		staged_files = vim.fn.system("git diff HEAD~1 --name-status")
	end
	
	local diff_content = vim.fn.system("git diff --cached")
	if diff_content == "" then
		diff_content = vim.fn.system("git diff HEAD~1")
	end
	
	local files = {}
	local changes = {
		added_lines = {},
		removed_lines = {},
		modified_files = {},
		added_files = {},
		deleted_files = {}
	}
	
	-- 解析文件状态
	for line in staged_files:gmatch("[^\n]+") do
		local status, file = line:match("^([AMD])%s+(.+)$")
		if status and file then
			table.insert(files, {status = status, file = file})
			
			if status == "A" then
				table.insert(changes.added_files, file)
			elseif status == "D" then
				table.insert(changes.deleted_files, file)
			elseif status == "M" then
				table.insert(changes.modified_files, file)
			end
		end
	end
	
	-- 解析diff内容
	for line in diff_content:gmatch("[^\n]+") do
		if line:match("^%+") and not line:match("^%+%+%+") then
			table.insert(changes.added_lines, line:sub(2))
		elseif line:match("^%-") and not line:match("^%-%-%-") then
			table.insert(changes.removed_lines, line:sub(2))
		end
	end
	
	return changes, files
end

-- 检测变更类型
local function detect_change_type(changes, files)
	local type_scores = {}
	
	-- 初始化分数
	for type_name, _ in pairs(branch_types) do
		type_scores[type_name] = 0
	end
	
	-- 基于文件路径和状态评分
	for _, file_info in ipairs(files) do
		local file = file_info.file
		local status = file_info.status
		
		for type_name, type_config in pairs(branch_types) do
			-- 检查文件路径模式
			for _, pattern in ipairs(type_config.patterns) do
				if file:match(pattern) then
					type_scores[type_name] = type_scores[type_name] + type_config.weight
				end
			end
		end
		
		-- 新增文件偏向于feature
		if status == "A" then
			type_scores.feature = type_scores.feature + 0.5
		end
	end
	
	-- 基于代码内容评分
	local all_content = table.concat(changes.added_lines, " ") .. " " .. table.concat(changes.removed_lines, " ")
	all_content = all_content:lower()
	
	for type_name, type_config in pairs(branch_types) do
		-- 检查关键词
		for _, keyword in ipairs(type_config.keywords) do
			local count = 0
			for match in all_content:gmatch(keyword:lower()) do
				count = count + 1
			end
			type_scores[type_name] = type_scores[type_name] + count * type_config.weight
		end
		
		-- 检查内容模式
		for _, pattern in ipairs(type_config.patterns) do
			if all_content:match(pattern:lower()) then
				type_scores[type_name] = type_scores[type_name] + type_config.weight
			end
		end
	end
	
	-- 找到最高分的类型
	local best_type = "feature"
	local best_score = 0
	
	for type_name, score in pairs(type_scores) do
		if score > best_score then
			best_type = type_name
			best_score = score
		end
	end
	
	return best_type, type_scores
end

-- 从内容中提取关键词
local function extract_keywords(changes, files)
	local keywords = {}
	local content = ""
	
	-- 从文件名提取关键词
	for _, file_info in ipairs(files) do
		local file = file_info.file
		local basename = file:match("[^/]+$") or file
		-- 移除扩展名
		basename = basename:gsub("%.%w+$", "")
		-- 分割驼峰命名和下划线命名
		for word in basename:gmatch("[%w]+") do
			if #word > 2 and not vim.tbl_contains(stop_words, word:lower()) then
				table.insert(keywords, word:lower())
			end
		end
		content = content .. " " .. basename
	end
	
	-- 从添加的代码行提取关键词
	for _, line in ipairs(changes.added_lines) do
		-- 提取函数名、变量名等
		for word in line:gmatch("%w+") do
			if #word > 2 and not vim.tbl_contains(stop_words, word:lower()) then
				table.insert(keywords, word:lower())
			end
		end
		content = content .. " " .. line
	end
	
	-- 去重和排序
	local unique_keywords = {}
	local keyword_counts = {}
	
	for _, keyword in ipairs(keywords) do
		if not keyword_counts[keyword] then
			keyword_counts[keyword] = 0
			table.insert(unique_keywords, keyword)
		end
		keyword_counts[keyword] = keyword_counts[keyword] + 1
	end
	
	-- 按频率排序
	table.sort(unique_keywords, function(a, b)
		return keyword_counts[a] > keyword_counts[b]
	end)
	
	return unique_keywords, content
end

-- 生成分支名称
local function generate_branch_name(change_type, keywords, config)
	local max_keywords = config.max_keywords or 3
	local max_length = config.max_length or 40
	
	-- 获取类型配置
	local type_config = branch_types[change_type]
	local prefix = config.custom_prefixes and config.custom_prefixes[change_type] or type_config.prefix
	
	-- 选择最相关的关键词
	local selected_keywords = {}
	for i = 1, math.min(max_keywords, #keywords) do
		table.insert(selected_keywords, keywords[i])
	end
	
	-- 构建分支名称
	local name_part = table.concat(selected_keywords, "-")
	
	-- 清理和格式化
	name_part = name_part:gsub("[^%w%-_]", "") -- 移除特殊字符
	name_part = name_part:gsub("%-+", "-") -- 合并多个连字符
	name_part = name_part:gsub("^%-", "") -- 移除开头的连字符
	name_part = name_part:gsub("%-$", "") -- 移除结尾的连字符
	
	local full_name = prefix .. name_part
	
	-- 限制长度
	if #full_name > max_length then
		local available_length = max_length - #prefix
		name_part = name_part:sub(1, available_length)
		full_name = prefix .. name_part
	end
	
	return full_name
end

-- 检查分支是否已存在
local function branch_exists(branch_name)
	local result = vim.fn.system("git branch --list " .. vim.fn.shellescape(branch_name))
	return result ~= ""
end

-- 生成唯一分支名称
local function generate_unique_branch_name(base_name)
	if not branch_exists(base_name) then
		return base_name
	end
	
	local counter = 1
	local unique_name = base_name .. "-" .. counter
	
	while branch_exists(unique_name) do
		counter = counter + 1
		unique_name = base_name .. "-" .. counter
	end
	
	return unique_name
end

-- 主要的智能分支创建函数
function M.create_smart_branch(config)
	config = config or {}
	
	-- 分析变更
	local changes, files = analyze_git_changes()
	
	if #files == 0 then
		vim.notify("No changes detected. Make sure you have staged changes or recent commits.", vim.log.levels.WARN)
		return nil
	end
	
	-- 检测变更类型
	local change_type, type_scores = detect_change_type(changes, files)
	
	-- 提取关键词
	local keywords, content = extract_keywords(changes, files)
	
	-- 生成分支名称
	local branch_name = generate_branch_name(change_type, keywords, config)
	local unique_branch_name = generate_unique_branch_name(branch_name)
	
	-- 显示分析结果
	local analysis_info = string.format(
		"Change Analysis:\n" ..
		"- Detected type: %s\n" ..
		"- Files changed: %d\n" ..
		"- Keywords: %s\n" ..
		"- Suggested branch: %s",
		change_type,
		#files,
		table.concat(keywords, ", "),
		unique_branch_name
	)
	
	vim.notify(analysis_info, vim.log.levels.INFO)
	
	-- 询问用户是否创建分支
	if config.auto_create then
		M.create_and_switch_branch(unique_branch_name)
	else
		vim.ui.input({
			prompt = "Create branch? (Y/n/edit): ",
			default = unique_branch_name
		}, function(input)
			if input == nil then
				return -- 用户取消
			elseif input:lower() == "n" or input:lower() == "no" then
				vim.notify("Branch creation cancelled", vim.log.levels.INFO)
				return
			elseif input:lower() == "y" or input:lower() == "yes" or input == "" then
				M.create_and_switch_branch(unique_branch_name)
			else
				-- 用户编辑了分支名称
				local final_name = generate_unique_branch_name(input)
				M.create_and_switch_branch(final_name)
			end
		end)
	end
	
	return {
		branch_name = unique_branch_name,
		change_type = change_type,
		keywords = keywords,
		type_scores = type_scores
	}
end

-- 创建并切换到分支
function M.create_and_switch_branch(branch_name)
	local Job = require("plenary.job")
	
	-- 创建分支
	Job:new({
		command = "git",
		args = {"checkout", "-b", branch_name},
		on_exit = function(_, return_val)
			if return_val == 0 then
				vim.notify(string.format("Successfully created and switched to branch: %s", branch_name), vim.log.levels.INFO)
			else
				vim.notify(string.format("Failed to create branch: %s", branch_name), vim.log.levels.ERROR)
			end
		end,
	}):start()
end

-- AI增强的分支命名
function M.create_smart_branch_with_ai(ai_config, branch_config)
	branch_config = branch_config or {}
	
	-- 首先进行基础分析
	local basic_result = M.create_smart_branch(vim.tbl_extend("force", branch_config, {auto_create = false}))
	
	if not basic_result then
		return
	end
	
	-- 验证AI配置
	local api_key = nil
	local api_provider = ai_config.api_provider or "openrouter"
	
	if api_provider == "openrouter" then
		api_key = ai_config.openrouter_api_key or vim.env.OPENROUTER_API_KEY
	elseif api_provider == "deepseek" then
		api_key = ai_config.deepseek_api_key or vim.env.DEEPSEEK_API_KEY
	end
	
	if not api_key then
		vim.notify("AI API key not found. Using basic branch naming.", vim.log.levels.WARN)
		return basic_result
	end
	
	-- 准备AI分析的上下文
	local changes, files = analyze_git_changes()
	local diff_content = vim.fn.system("git diff --cached")
	if diff_content == "" then
		diff_content = vim.fn.system("git diff HEAD~1")
	end
	
	-- 构建AI提示
	local ai_prompt = string.format([[
你是一个专业的软件工程师，负责分析代码变更并生成语义化的分支名称。

变更分析：
- 检测到的类型：%s
- 文件变更：%s
- 基础建议：%s
- 提取的关键词：%s

代码差异：
%s

请生成一个更准确、更语义化的分支名称，要求：
1. 保持简洁（最多30字符，不包含前缀）
2. 使用kebab-case格式（单词间用连字符连接）
3. 只返回分支名称主体部分，不要包含前缀（如feature/、fix/）
4. 体现变更的核心目的和价值
5. 优先使用英文单词，简洁明了
6. 避免使用通用词汇如"update"、"change"、"modify"

直接返回分支名称，不要包含任何解释或格式标记。]], 
		basic_result.change_type,
		table.concat(vim.tbl_map(function(f) return f.file end, files), ", "),
		basic_result.branch_name:gsub("^[^/]+/", ""), -- 移除前缀显示
		table.concat(basic_result.keywords, ", "),
		diff_content:sub(1, 1500) -- 限制长度
	)
	
	-- 准备API请求数据
	local request_data = {
		model = ai_config.model,
		messages = {
			{
				role = "system",
				content = "You are a helpful assistant that generates semantic git branch names."
			},
			{
				role = "user",
				content = ai_prompt
			}
		}
	}
	
	-- API端点配置
	local api_endpoints = {
		openrouter = "https://openrouter.ai/api/v1/chat/completions",
		deepseek = "https://api.deepseek.com/chat/completions",
	}
	
	local endpoint = api_endpoints[api_provider]
	
	vim.notify("Analyzing changes with AI for better branch naming...", vim.log.levels.INFO)
	
	-- 发送AI请求
	require("plenary.curl").post(endpoint, {
		headers = {
			content_type = "application/json",
			authorization = "Bearer " .. api_key,
		},
		body = vim.json.encode(request_data),
		callback = vim.schedule_wrap(function(response)
			if response.status == 200 then
				local ok, data = pcall(vim.json.decode, response.body)
				if ok and data.choices and #data.choices > 0 and data.choices[1].message then
					local ai_suggestion = data.choices[1].message.content
					
					-- 清理AI返回的内容
					ai_suggestion = ai_suggestion:gsub("^%s+", ""):gsub("%s+$", "")
					ai_suggestion = ai_suggestion:gsub("\n.*", "") -- 只取第一行
					ai_suggestion = ai_suggestion:gsub("[^%w%-_]", "") -- 只保留字母数字连字符下划线
					ai_suggestion = ai_suggestion:gsub("%-+", "-") -- 合并多个连字符
					ai_suggestion = ai_suggestion:gsub("^%-", ""):gsub("%-$", "") -- 移除首尾连字符
					
					if ai_suggestion ~= "" and #ai_suggestion > 2 then
						-- 使用AI建议构建分支名称
						local branch_types = {
							feature = {prefix = "feature/"},
							fix = {prefix = "fix/"},
							hotfix = {prefix = "hotfix/"},
							docs = {prefix = "docs/"},
							refactor = {prefix = "refactor/"},
							style = {prefix = "style/"},
							test = {prefix = "test/"},
							chore = {prefix = "chore/"}
						}
						
						local type_config = branch_types[basic_result.change_type]
						local prefix = branch_config.custom_prefixes and branch_config.custom_prefixes[basic_result.change_type] 
							or type_config.prefix
						
						local ai_branch_name = prefix .. ai_suggestion
						local unique_ai_name = generate_unique_branch_name(ai_branch_name)
						
						-- 显示AI增强的结果
						local comparison = string.format(
							"AI Enhanced Branch Naming:\n\n" ..
							"Basic suggestion: %s\n" ..
							"AI enhanced: %s\n" ..
							"Change type: %s\n" ..
							"Files: %d changed",
							basic_result.branch_name,
							unique_ai_name,
							basic_result.change_type,
							#files
						)
						
						vim.notify(comparison, vim.log.levels.INFO)
						
						-- 询问用户选择
						vim.ui.select(
							{unique_ai_name, basic_result.branch_name, "Edit custom name"},
							{
								prompt = "Choose branch name:",
								format_item = function(item)
									if item == unique_ai_name then
										return "🤖 AI Enhanced: " .. item
									elseif item == basic_result.branch_name then
										return "📊 Basic: " .. item
									else
										return "✏️  " .. item
									end
								end
							},
							function(choice)
								if choice == unique_ai_name or choice == basic_result.branch_name then
									M.create_and_switch_branch(choice)
								elseif choice == "Edit custom name" then
									vim.ui.input({
										prompt = "Enter custom branch name: ",
										default = unique_ai_name
									}, function(custom_name)
										if custom_name and custom_name ~= "" then
											local final_name = generate_unique_branch_name(custom_name)
											M.create_and_switch_branch(final_name)
										end
									end)
								end
							end
						)
					else
						vim.notify("AI suggestion was invalid. Using basic naming.", vim.log.levels.WARN)
						vim.ui.input({
							prompt = "Create branch? (Y/n/edit): ",
							default = basic_result.branch_name
						}, function(input)
							if input == nil then
								return
							elseif input:lower() == "n" or input:lower() == "no" then
								vim.notify("Branch creation cancelled", vim.log.levels.INFO)
								return
							elseif input:lower() == "y" or input:lower() == "yes" or input == "" then
								M.create_and_switch_branch(basic_result.branch_name)
							else
								local final_name = generate_unique_branch_name(input)
								M.create_and_switch_branch(final_name)
							end
						end)
					end
				else
					vim.notify("Invalid AI response. Using basic naming.", vim.log.levels.WARN)
					return M.create_smart_branch(branch_config)
				end
			else
				vim.notify("AI API request failed: " .. response.status .. ". Using basic naming.", vim.log.levels.WARN)
				return M.create_smart_branch(branch_config)
			end
		end)
	})
	
	return basic_result
end

return M