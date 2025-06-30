local M = {}

-- Team standards and collaboration features
local STANDARDS_FILE = ".ai-commit-standards.json"

-- Default team standards
local default_standards = {
	commit_format = "conventional",
	max_title_length = 50,
	max_body_length = 72,
	required_sections = {},
	forbidden_words = {},
	preferred_types = {
		"feat", "fix", "docs", "style", "refactor", 
		"perf", "test", "chore", "ci", "build"
	},
	team_conventions = {
		use_chinese = true,
		include_impact = true,
		require_scope = false,
		auto_tag_version = false
	}
}

-- Load team standards from project file
local function load_team_standards()
	if vim.fn.filereadable(STANDARDS_FILE) == 1 then
		local content = vim.fn.readfile(STANDARDS_FILE)
		local success, standards = pcall(vim.json.decode, table.concat(content, "\n"))
		if success then
			return vim.tbl_deep_extend("force", default_standards, standards)
		end
	end
	return default_standards
end

-- Save team standards to project file
local function save_team_standards(standards)
	local content = vim.json.encode(standards)
	vim.fn.writefile(vim.split(content, "\n"), STANDARDS_FILE)
end

-- Analyze recent commits to learn team patterns
local function learn_team_patterns()
	local recent_commits = vim.fn.system("git log --oneline -n 20 --pretty=format:'%s'")
	if recent_commits == "" then
		return {}
	end
	
	local patterns = {
		common_types = {},
		common_scopes = {},
		avg_title_length = 0,
		uses_chinese = false,
		uses_emoji = false
	}
	
	local commits = vim.split(recent_commits, "\n")
	local total_length = 0
	local type_count = {}
	local scope_count = {}
	
	for _, commit in ipairs(commits) do
		if commit ~= "" then
			total_length = total_length + #commit
			
			-- Check for Chinese characters
			if commit:match("[\228-\233]") then
				patterns.uses_chinese = true
			end
			
			-- Check for emoji
			if commit:match("[\240-\244]") then
				patterns.uses_emoji = true
			end
			
			-- Extract type and scope from conventional commits
			local type_scope = commit:match("^([^:]+):")
			if type_scope then
				local type_part, scope_part = type_scope:match("^([^%(]+)%(([^%)]+)%)")
				if not type_part then
					type_part = type_scope
				end
				
				if type_part then
					type_count[type_part] = (type_count[type_part] or 0) + 1
				end
				
				if scope_part then
					scope_count[scope_part] = (scope_count[scope_part] or 0) + 1
				end
			end
		end
	end
	
	patterns.avg_title_length = math.floor(total_length / #commits)
	
	-- Get most common types and scopes
	for type, count in pairs(type_count) do
		table.insert(patterns.common_types, {type = type, count = count})
	end
	for scope, count in pairs(scope_count) do
		table.insert(patterns.common_scopes, {scope = scope, count = count})
	end
	
	-- Sort by frequency
	table.sort(patterns.common_types, function(a, b) return a.count > b.count end)
	table.sort(patterns.common_scopes, function(a, b) return a.count > b.count end)
	
	return patterns
end

-- Validate commit message against team standards
local function validate_commit_message(message, standards)
	local violations = {}
	
	-- Check title length
	local title = message:match("^([^\n]*)")
	if title and #title > standards.max_title_length then
		table.insert(violations, string.format("标题超过%d字符限制 (当前: %d)", standards.max_title_length, #title))
	end
	
	-- Check for forbidden words
	for _, word in ipairs(standards.forbidden_words) do
		if message:lower():match(word:lower()) then
			table.insert(violations, string.format("包含禁用词汇: %s", word))
		end
	end
	
	-- Check conventional commit format
	if standards.commit_format == "conventional" then
		if not title:match("^[a-zA-Z]+") then
			table.insert(violations, "不符合常规提交格式 (type: description)")
		end
	end
	
	-- Check required scope
	if standards.team_conventions.require_scope then
		if not title:match("%(.*%)") then
			table.insert(violations, "缺少必需的scope")
		end
	end
	
	return violations
end

-- Generate team-aware commit suggestions
function M.generate_team_commit(git_data, base_config)
	local standards = load_team_standards()
	local patterns = learn_team_patterns()
	
	-- Build team-aware prompt
	local team_context = string.format([[
团队代码规范:
- 提交格式: %s
- 标题长度限制: %d字符
- 常用类型: %s
- 常用范围: %s
- 使用中文: %s
- 使用表情: %s
- 平均标题长度: %d字符

最近提交模式分析显示该团队倾向于:
%s
]], 
		standards.commit_format,
		standards.max_title_length,
		table.concat(vim.tbl_map(function(t) return t.type end, vim.list_slice(patterns.common_types, 1, 3)), ", "),
		table.concat(vim.tbl_map(function(s) return s.scope end, vim.list_slice(patterns.common_scopes, 1, 3)), ", "),
		patterns.uses_chinese and "是" or "否",
		patterns.uses_emoji and "是" or "否",
		patterns.avg_title_length,
		patterns.uses_chinese and "使用中文提交消息" or "使用英文提交消息"
	)
	
	-- Enhanced template with team context
	local team_template = string.format([[
%s

请严格按照团队规范生成提交消息:

Git diff:
%s

Recent commits:
%s

请生成符合团队规范的提交消息，确保:
1. 遵循团队的提交格式和风格
2. 使用团队常用的类型和范围
3. 符合长度限制和语言偏好
4. 保持与最近提交的一致性

只返回符合规范的提交消息。
]], team_context, git_data.diff, git_data.commits)
	
	return {
		prompt = team_template,
		standards = standards,
		patterns = patterns,
		validator = function(message)
			return validate_commit_message(message, standards)
		end
	}
end

-- Setup team standards interactively
function M.setup_team_standards()
	local standards = load_team_standards()
	local patterns = learn_team_patterns()
	
	vim.ui.select({
		"查看当前团队规范",
		"学习项目提交模式", 
		"配置团队规范",
		"重置为默认规范"
	}, {
		prompt = "团队规范管理:",
	}, function(choice)
		if choice == "查看当前团队规范" then
			local display = vim.json.encode(standards)
			vim.notify("当前团队规范:\n" .. display, vim.log.levels.INFO)
		elseif choice == "学习项目提交模式" then
			local learned = vim.json.encode(patterns)
			vim.notify("学习到的提交模式:\n" .. learned, vim.log.levels.INFO)
		elseif choice == "配置团队规范" then
			-- Interactive configuration (simplified)
			vim.ui.input({prompt = "最大标题长度: ", default = tostring(standards.max_title_length)}, function(input)
				if input then
					standards.max_title_length = tonumber(input) or standards.max_title_length
					save_team_standards(standards)
					vim.notify("团队规范已更新", vim.log.levels.INFO)
				end
			end)
		elseif choice == "重置为默认规范" then
			save_team_standards(default_standards)
			vim.notify("已重置为默认团队规范", vim.log.levels.INFO)
		end
	end)
end

-- Generate commit analytics report
function M.generate_analytics_report()
	local report = {
		total_commits = 0,
		commit_frequency = {},
		author_stats = {},
		type_distribution = {},
		avg_commit_size = 0
	}
	
	-- Get commit history with stats
	local commits_data = vim.fn.system("git log --since='30 days ago' --pretty=format:'%an|%s|%ad' --date=short")
	if commits_data ~= "" then
		local commits = vim.split(commits_data, "\n")
		report.total_commits = #commits
		
		for _, commit_line in ipairs(commits) do
			local author, subject, date = commit_line:match("([^|]*)|([^|]*)|([^|]*)")
			if author and subject and date then
				-- Author stats
				report.author_stats[author] = (report.author_stats[author] or 0) + 1
				
				-- Date frequency
				report.commit_frequency[date] = (report.commit_frequency[date] or 0) + 1
				
				-- Type distribution
				local commit_type = subject:match("^([^%(:]*)") or "other"
				report.type_distribution[commit_type] = (report.type_distribution[commit_type] or 0) + 1
			end
		end
	end
	
	-- Display report
	local report_text = string.format([[
📊 提交分析报告 (最近30天)

总提交数: %d
最活跃作者: %s
最常用类型: %s
平均每日提交: %.1f

类型分布:
%s
]], 
		report.total_commits,
		next(report.author_stats) or "无",
		next(report.type_distribution) or "无",
		report.total_commits / 30,
		vim.inspect(report.type_distribution)
	)
	
	vim.notify(report_text, vim.log.levels.INFO)
	return report
end

return M