local M = {}

-- Pattern learning data storage
local PATTERN_FILE = ".ai-commit-patterns.json"

-- Default pattern structure
local default_patterns = {
	commit_styles = {},
	author_patterns = {},
	temporal_patterns = {},
	project_conventions = {},
	learned_templates = {},
	learning_metadata = {
		last_updated = 0,
		total_commits_analyzed = 0,
		confidence_score = 0
	}
}

-- Load learned patterns
local function load_patterns()
	if vim.fn.filereadable(PATTERN_FILE) == 1 then
		local content = vim.fn.readfile(PATTERN_FILE)
		local success, patterns = pcall(vim.json.decode, table.concat(content, "\n"))
		if success then
			return vim.tbl_deep_extend("force", default_patterns, patterns)
		end
	end
	return default_patterns
end

-- Save learned patterns
local function save_patterns(patterns)
	patterns.learning_metadata.last_updated = os.time()
	local content = vim.json.encode(patterns)
	vim.fn.writefile(vim.split(content, "\n"), PATTERN_FILE)
end

-- Analyze commit message structure
local function analyze_commit_structure(message)
	local structure = {
		has_type = false,
		has_scope = false,
		has_emoji = false,
		has_issue_ref = false,
		has_coauthor = false,
		length = #message,
		language = "unknown",
		format_style = "unknown"
	}
	
	-- Detect conventional commit format
	if message:match("^[a-zA-Z]+%(.*%):%s*.+") then
		structure.has_type = true
		structure.has_scope = true
		structure.format_style = "conventional_with_scope"
	elseif message:match("^[a-zA-Z]+:%s*.+") then
		structure.has_type = true
		structure.format_style = "conventional_basic"
	end
	
	-- Detect emoji usage
	if message:match("[\240-\244]") then
		structure.has_emoji = true
	end
	
	-- Detect issue references
	if message:match("#%d+") or message:match("fixes") or message:match("closes") then
		structure.has_issue_ref = true
	end
	
	-- Detect co-author
	if message:match("[Cc]o%-[Aa]uthored%-[Bb]y:") then
		structure.has_coauthor = true
	end
	
	-- Detect language
	if message:match("[\228-\233]") then
		structure.language = "chinese"
	elseif message:match("[\227]") then
		structure.language = "japanese"
	elseif message:match("[\234-\237]") then
		structure.language = "korean"
	else
		structure.language = "english"
	end
	
	return structure
end

-- Extract patterns from commit history
local function extract_commit_patterns(commit_count)
	commit_count = commit_count or 100
	
	local commits_data = vim.fn.system(string.format("git log --pretty=format:'%%h|%%s|%%an|%%ad|%%ae' --date=iso -n %d", commit_count))
	if commits_data == "" then
		return {}
	end
	
	local patterns = {
		commit_types = {},
		scopes = {},
		authors = {},
		time_patterns = {},
		length_distribution = {},
		format_preferences = {},
		language_usage = {},
		emoji_usage = {},
		templates = {}
	}
	
	local commits = vim.split(commits_data, "\n")
	
	for _, commit_line in ipairs(commits) do
		local hash, message, author, date, email = commit_line:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
		if hash and message and author then
			local structure = analyze_commit_structure(message)
			
			-- Extract commit type
			local commit_type = message:match("^([^%(:%s]+)")
			if commit_type then
				patterns.commit_types[commit_type] = (patterns.commit_types[commit_type] or 0) + 1
			end
			
			-- Extract scope
			local scope = message:match("^[^%(]+%(([^%)]+)%)")
			if scope then
				patterns.scopes[scope] = (patterns.scopes[scope] or 0) + 1
			end
			
			-- Author patterns
			if not patterns.authors[author] then
				patterns.authors[author] = {
					commit_count = 0,
					avg_length = 0,
					preferred_types = {},
					preferred_language = structure.language,
					uses_emoji = structure.has_emoji,
					uses_scope = structure.has_scope
				}
			end
			patterns.authors[author].commit_count = patterns.authors[author].commit_count + 1
			patterns.authors[author].avg_length = (patterns.authors[author].avg_length + structure.length) / 2
			
			if commit_type then
				patterns.authors[author].preferred_types[commit_type] = (patterns.authors[author].preferred_types[commit_type] or 0) + 1
			end
			
			-- Time patterns (extract hour from ISO date)
			local hour = date:match("T(%d%d):")
			if hour then
				patterns.time_patterns[hour] = (patterns.time_patterns[hour] or 0) + 1
			end
			
			-- Length distribution
			local length_bucket = math.floor(structure.length / 10) * 10
			patterns.length_distribution[tostring(length_bucket)] = (patterns.length_distribution[tostring(length_bucket)] or 0) + 1
			
			-- Format preferences
			patterns.format_preferences[structure.format_style] = (patterns.format_preferences[structure.format_style] or 0) + 1
			
			-- Language usage
			patterns.language_usage[structure.language] = (patterns.language_usage[structure.language] or 0) + 1
			
			-- Emoji usage
			if structure.has_emoji then
				patterns.emoji_usage.total = (patterns.emoji_usage.total or 0) + 1
			end
		end
	end
	
	return patterns
end

-- Generate personalized templates
local function generate_personalized_templates(patterns, current_author)
	local templates = {}
	
	-- Find current author's preferences
	local author_prefs = patterns.authors[current_author]
	if not author_prefs then
		return templates
	end
	
	-- Most used commit type
	local most_used_type = ""
	local max_count = 0
	for type, count in pairs(author_prefs.preferred_types) do
		if count > max_count then
			max_count = count
			most_used_type = type
		end
	end
	
	-- Generate templates based on patterns
	if author_prefs.uses_scope then
		table.insert(templates, {
			name = "个人常用格式(带scope)",
			template = string.format("%s(scope): 描述变更内容", most_used_type),
			confidence = 0.8
		})
	end
	
	table.insert(templates, {
		name = "个人常用格式(基础)",
		template = string.format("%s: 描述变更内容", most_used_type),
		confidence = 0.7
	})
	
	if author_prefs.uses_emoji then
		table.insert(templates, {
			name = "个人常用格式(带emoji)",
			template = string.format("✨ %s: 描述变更内容", most_used_type),
			confidence = 0.6
		})
	end
	
	return templates
end

-- Learn from project history
function M.learn_from_project_history(force_relearn)
	force_relearn = force_relearn or false
	
	local patterns = load_patterns()
	
	-- Check if recent learning exists
	if not force_relearn and patterns.learning_metadata.last_updated > 0 then
		local last_learned = os.time() - patterns.learning_metadata.last_updated
		if last_learned < 86400 then -- Less than 24 hours
			vim.notify("项目模式已在24小时内学习过，使用缓存结果", vim.log.levels.INFO)
			M.show_learned_patterns(patterns)
			return patterns
		end
	end
	
	vim.notify("🧠 正在深度学习项目提交模式...", vim.log.levels.INFO)
	
	-- Extract new patterns
	local extracted_patterns = extract_commit_patterns(200) -- Analyze more commits
	
	-- Merge with existing patterns
	patterns.commit_styles = extracted_patterns
	patterns.learning_metadata.total_commits_analyzed = 200
	patterns.learning_metadata.confidence_score = M.calculate_confidence_score(extracted_patterns)
	
	-- Generate personalized templates
	local current_author = vim.fn.system("git config user.name"):gsub("\n", "")
	patterns.learned_templates = generate_personalized_templates(extracted_patterns, current_author)
	
	-- Save learned patterns
	save_patterns(patterns)
	
	vim.notify("✅ 项目模式学习完成！", vim.log.levels.INFO)
	M.show_learned_patterns(patterns)
	
	return patterns
end

-- Calculate confidence score for learned patterns
function M.calculate_confidence_score(patterns)
	local score = 0
	
	-- More commit types = higher confidence
	local type_count = 0
	for _ in pairs(patterns.commit_types or {}) do
		type_count = type_count + 1
	end
	score = score + math.min(type_count * 10, 50)
	
	-- Consistent format style = higher confidence  
	local total_commits = 0
	local max_format_count = 0
	for format, count in pairs(patterns.format_preferences or {}) do
		total_commits = total_commits + count
		max_format_count = math.max(max_format_count, count)
	end
	
	if total_commits > 0 then
		local consistency = (max_format_count / total_commits) * 100
		score = score + consistency / 2
	end
	
	-- Author diversity
	local author_count = 0
	for _ in pairs(patterns.authors or {}) do
		author_count = author_count + 1
	end
	score = score + math.min(author_count * 5, 25)
	
	return math.min(score, 100)
end

-- Show learned patterns
function M.show_learned_patterns(patterns)
	patterns = patterns or load_patterns()
	
	local report = string.format([[
🧠 项目提交模式学习报告

📊 学习统计:
- 最后更新: %s
- 分析提交数: %d
- 置信度评分: %.1f/100

🏷️ 常用提交类型:
%s

🎯 作用域使用:
%s

👥 作者模式:
%s

⏰ 提交时间偏好:
%s

📝 格式偏好:
%s

🌐 语言使用:
%s

💡 个性化模板 (%d个):
%s
]], 
		patterns.learning_metadata.last_updated > 0 and os.date("%Y-%m-%d %H:%M", patterns.learning_metadata.last_updated) or "从未学习",
		patterns.learning_metadata.total_commits_analyzed,
		patterns.learning_metadata.confidence_score,
		M.format_frequency_data(patterns.commit_styles.commit_types or {}),
		M.format_frequency_data(patterns.commit_styles.scopes or {}),
		M.format_author_data(patterns.commit_styles.authors or {}),
		M.format_time_data(patterns.commit_styles.time_patterns or {}),
		M.format_frequency_data(patterns.commit_styles.format_preferences or {}),
		M.format_frequency_data(patterns.commit_styles.language_usage or {}),
		#patterns.learned_templates,
		M.format_template_data(patterns.learned_templates)
	)
	
	vim.notify(report, vim.log.levels.INFO)
end

-- Helper function to format frequency data
function M.format_frequency_data(data)
	if not data or next(data) == nil then
		return "无数据"
	end
	
	local sorted = {}
	for key, count in pairs(data) do
		table.insert(sorted, {key = key, count = count})
	end
	
	table.sort(sorted, function(a, b) return a.count > b.count end)
	
	local result = {}
	for i = 1, math.min(5, #sorted) do
		table.insert(result, string.format("  %s: %d次", sorted[i].key, sorted[i].count))
	end
	
	return table.concat(result, "\n")
end

-- Helper function to format author data
function M.format_author_data(authors)
	if not authors or next(authors) == nil then
		return "无数据"
	end
	
	local result = {}
	local count = 0
	for author, data in pairs(authors) do
		if count < 3 then
			table.insert(result, string.format("  %s: %d次提交, 平均长度%.0f", author, data.commit_count, data.avg_length))
			count = count + 1
		end
	end
	
	return table.concat(result, "\n")
end

-- Helper function to format time data
function M.format_time_data(time_data)
	if not time_data or next(time_data) == nil then
		return "无数据"
	end
	
	local sorted = {}
	for hour, count in pairs(time_data) do
		table.insert(sorted, {hour = hour, count = count})
	end
	
	table.sort(sorted, function(a, b) return a.count > b.count end)
	
	local result = {}
	for i = 1, math.min(3, #sorted) do
		table.insert(result, string.format("  %s:00时段: %d次", sorted[i].hour, sorted[i].count))
	end
	
	return table.concat(result, "\n")
end

-- Helper function to format template data
function M.format_template_data(templates)
	if not templates or #templates == 0 then
		return "无个性化模板"
	end
	
	local result = {}
	for _, template in ipairs(templates) do
		table.insert(result, string.format("  %s (置信度: %.1f)", template.name, template.confidence))
	end
	
	return table.concat(result, "\n")
end

-- Apply learned patterns to commit generation
function M.apply_learned_patterns(git_data, base_config)
	local patterns = load_patterns()
	
	if patterns.learning_metadata.confidence_score < 30 then
		vim.notify("学习置信度较低，建议先运行学习功能", vim.log.levels.WARN)
		return nil
	end
	
	local current_author = vim.fn.system("git config user.name"):gsub("\n", "")
	local author_prefs = patterns.commit_styles.authors and patterns.commit_styles.authors[current_author]
	
	if not author_prefs then
		return nil
	end
	
	-- Build enhanced prompt with learned patterns
	local pattern_context = string.format([[
基于项目历史学习的个性化模式 (置信度: %.1f/100):

你的提交习惯:
- 平均消息长度: %.0f字符
- 偏好语言: %s
- 使用emoji: %s
- 使用scope: %s
- 常用类型: %s

项目整体模式:
- 主要格式风格: %s
- 常用提交类型: %s

请严格按照学习到的个人习惯和项目惯例生成提交消息。
]], 
		patterns.learning_metadata.confidence_score,
		author_prefs.avg_length,
		author_prefs.preferred_language,
		author_prefs.uses_emoji and "是" or "否",
		author_prefs.uses_scope and "是" or "否",
		M.get_top_item(author_prefs.preferred_types),
		M.get_top_item(patterns.commit_styles.format_preferences or {}),
		M.get_top_item(patterns.commit_styles.commit_types or {})
	)
	
	-- Enhanced template with pattern context
	local enhanced_template = string.format([[
%s

Git diff:
%s

Recent commits:
%s

请基于学习到的模式生成最符合项目惯例和个人风格的提交消息。
]], pattern_context, git_data.diff, git_data.commits)
	
	return {
		prompt = enhanced_template,
		confidence = patterns.learning_metadata.confidence_score,
		author_prefs = author_prefs
	}
end

-- Helper to get most frequent item
function M.get_top_item(data)
	if not data or next(data) == nil then
		return "未知"
	end
	
	local max_key = ""
	local max_count = 0
	for key, count in pairs(data) do
		if count > max_count then
			max_count = count
			max_key = key
		end
	end
	
	return max_key
end

-- Interactive pattern management
function M.manage_learned_patterns()
	vim.ui.select({
		"🧠 重新学习项目模式",
		"📊 查看当前学习结果",
		"🗑️ 清除学习数据",
		"💾 导出学习数据",
		"📥 导入学习数据",
		"⚙️ 调整学习参数"
	}, {
		prompt = "提交模式学习管理:",
	}, function(choice)
		if choice and choice:match("🧠") then
			M.learn_from_project_history(true)
		elseif choice and choice:match("📊") then
			M.show_learned_patterns()
		elseif choice and choice:match("🗑️") then
			vim.ui.input({
				prompt = "确认清除学习数据？输入 'YES' 确认: "
			}, function(input)
				if input == "YES" then
					save_patterns(default_patterns)
					vim.notify("学习数据已清除", vim.log.levels.INFO)
				end
			end)
		elseif choice and choice:match("💾") then
			M.export_learning_data()
		elseif choice and choice:match("📥") then
			M.import_learning_data()
		elseif choice and choice:match("⚙️") then
			M.adjust_learning_parameters()
		end
	end)
end

-- Export learning data
function M.export_learning_data()
	local patterns = load_patterns()
	local export_file = "ai-commit-patterns-export-" .. os.date("%Y%m%d-%H%M%S") .. ".json"
	local content = vim.json.encode(patterns)
	vim.fn.writefile(vim.split(content, "\n"), export_file)
	vim.notify("学习数据已导出到: " .. export_file, vim.log.levels.INFO)
end

-- Import learning data
function M.import_learning_data()
	vim.ui.input({
		prompt = "输入导入文件路径: "
	}, function(file_path)
		if file_path and vim.fn.filereadable(file_path) == 1 then
			local content = vim.fn.readfile(file_path)
			local success, imported_patterns = pcall(vim.json.decode, table.concat(content, "\n"))
			if success then
				save_patterns(imported_patterns)
				vim.notify("学习数据导入成功", vim.log.levels.INFO)
			else
				vim.notify("导入失败：文件格式错误", vim.log.levels.ERROR)
			end
		else
			vim.notify("文件不存在或无法读取", vim.log.levels.ERROR)
		end
	end)
end

-- Adjust learning parameters
function M.adjust_learning_parameters()
	vim.notify("学习参数调整功能开发中...", vim.log.levels.INFO)
end

return M