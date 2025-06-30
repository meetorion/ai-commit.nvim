local M = {}

-- Import analysis modules
local code_review_engine = require("code_review_engine")
local security_scanner = require("security_scanner")
local performance_analyzer = require("performance_analyzer")

-- Review modes
local REVIEW_MODES = {
	quick = {
		name = "快速审查",
		description = "基本代码质量检查",
		modules = {"code_review_engine"},
		ai_analysis = false
	},
	comprehensive = {
		name = "全面审查", 
		description = "代码质量 + 安全 + 性能分析",
		modules = {"code_review_engine", "security_scanner", "performance_analyzer"},
		ai_analysis = true
	},
	security_focused = {
		name = "安全审查",
		description = "专注安全漏洞和风险检测", 
		modules = {"security_scanner"},
		ai_analysis = true
	},
	performance_focused = {
		name = "性能审查",
		description = "专注性能问题和优化建议",
		modules = {"performance_analyzer"},
		ai_analysis = true
	},
	ai_powered = {
		name = "AI审查",
		description = "使用AI进行深度代码分析",
		modules = {"code_review_engine"},
		ai_analysis = true
	}
}

-- Review configuration
local default_config = {
	auto_review_on_commit = false,
	review_mode = "comprehensive",
	ai_provider_preference = "deepseek", -- Best for code analysis
	max_files_per_review = 10,
	exclude_patterns = {
		"%.min%.js$",
		"%.bundle%.js$", 
		"node_modules/",
		"%.git/",
		"dist/",
		"build/"
	},
	severity_thresholds = {
		block_commit = {"critical"},
		warn_commit = {"high"},
		show_info = {"medium", "low", "info"}
	}
}

-- Comprehensive code review
function M.perform_comprehensive_review(file_paths, options)
	options = options or {}
	local mode = options.mode or default_config.review_mode
	local mode_config = REVIEW_MODES[mode]
	
	if not mode_config then
		return {error = "未知的审查模式: " .. mode}
	end
	
	vim.notify(string.format("🧠 开始%s...", mode_config.name), vim.log.levels.INFO)
	
	local review_results = {
		mode = mode,
		timestamp = os.time(),
		files_reviewed = {},
		summary = {
			total_issues = 0,
			critical_issues = 0,
			high_issues = 0,
			security_issues = 0,
			performance_issues = 0,
			files_count = 0
		},
		recommendations = {},
		ai_insights = {}
	}
	
	-- Filter files based on exclude patterns
	local filtered_files = {}
	for _, file_path in ipairs(file_paths) do
		local should_exclude = false
		for _, pattern in ipairs(default_config.exclude_patterns) do
			if file_path:match(pattern) then
				should_exclude = true
				break
			end
		end
		
		if not should_exclude and vim.fn.filereadable(file_path) == 1 then
			table.insert(filtered_files, file_path)
		end
	end
	
	-- Limit files to prevent overwhelming analysis
	if #filtered_files > default_config.max_files_per_review then
		filtered_files = vim.list_slice(filtered_files, 1, default_config.max_files_per_review)
		vim.notify(string.format("⚠️ 文件数量过多，限制为前%d个文件", default_config.max_files_per_review), 
			vim.log.levels.WARN)
	end
	
	review_results.summary.files_count = #filtered_files
	
	-- Analyze each file
	for _, file_path in ipairs(filtered_files) do
		vim.notify(string.format("🔍 分析 %s...", file_path), vim.log.levels.INFO)
		
		local file_content = table.concat(vim.fn.readfile(file_path), "\n")
		local language = code_review_engine.detect_language(file_path)
		
		local file_analysis = {
			file_path = file_path,
			language = language,
			issues = {},
			metrics = {},
			ai_analysis = nil
		}
		
		-- Run selected analysis modules
		if vim.tbl_contains(mode_config.modules, "code_review_engine") then
			local code_analysis = code_review_engine.generate_ai_review(file_path, file_content, {})
			file_analysis.issues = vim.list_extend(file_analysis.issues, code_analysis.static_issues or {})
			file_analysis.metrics.complexity = code_analysis.complexity
		end
		
		if vim.tbl_contains(mode_config.modules, "security_scanner") then
			local security_issues = security_scanner.scan_content(file_content, language, file_path)
			file_analysis.issues = vim.list_extend(file_analysis.issues, security_issues)
		end
		
		if vim.tbl_contains(mode_config.modules, "performance_analyzer") then
			local perf_analysis = performance_analyzer.analyze_performance(file_content, language, file_path)
			file_analysis.issues = vim.list_extend(file_analysis.issues, perf_analysis.issues)
			file_analysis.metrics.performance = perf_analysis.metrics
		end
		
		-- Count issues by severity
		for _, issue in ipairs(file_analysis.issues) do
			review_results.summary.total_issues = review_results.summary.total_issues + 1
			
			if issue.severity == "critical" then
				review_results.summary.critical_issues = review_results.summary.critical_issues + 1
			elseif issue.severity == "high" then
				review_results.summary.high_issues = review_results.summary.high_issues + 1
			end
			
			if issue.category == "security" or vim.tbl_contains({"injection", "authentication", "cryptography"}, issue.category) then
				review_results.summary.security_issues = review_results.summary.security_issues + 1
			end
			
			if issue.type == "performance" or issue.category == "performance" then
				review_results.summary.performance_issues = review_results.summary.performance_issues + 1
			end
		end
		
		table.insert(review_results.files_reviewed, file_analysis)
		
		-- Request AI analysis if enabled
		if mode_config.ai_analysis then
			M.request_ai_insights(file_path, file_content, file_analysis.issues)
		end
	end
	
	-- Generate recommendations
	review_results.recommendations = M.generate_review_recommendations(review_results)
	
	vim.notify(string.format("✅ 审查完成：%d个文件，%d个问题", 
		review_results.summary.files_count, review_results.summary.total_issues), vim.log.levels.INFO)
	
	return review_results
end

-- Review git changes
function M.review_git_changes(git_data, options)
	options = options or {}
	
	if not git_data or not git_data.diff then
		return {error = "没有找到Git变更数据"}
	end
	
	vim.notify("🔍 开始审查Git变更...", vim.log.levels.INFO)
	
	-- Extract changed files from git diff
	local changed_files = {}
	local current_file = nil
	local file_changes = {}
	
	for line in git_data.diff:gmatch("[^\n]+") do
		if line:match("^diff --git") then
			local file_match = line:match("b/(.+)$")
			if file_match then
				current_file = file_match
				file_changes[current_file] = {
					additions = {},
					deletions = {},
					context = {}
				}
			end
		elseif line:match("^%+") and current_file and not line:match("^%+%+%+") then
			table.insert(file_changes[current_file].additions, line:sub(2))
		elseif line:match("^%-") and current_file and not line:match("^%-%-%- ") then
			table.insert(file_changes[current_file].deletions, line:sub(2))
		elseif line:match("^ ") and current_file then
			table.insert(file_changes[current_file].context, line:sub(2))
		end
	end
	
	-- Analyze changes
	local change_analysis = {
		mode = "git_changes",
		files_analyzed = {},
		summary = {
			files_changed = 0,
			lines_added = 0,
			lines_deleted = 0,
			issues_found = 0,
			security_risks = 0,
			performance_concerns = 0
		},
		blocking_issues = {},
		warnings = [],
		suggestions = []
	}
	
	for file_path, changes in pairs(file_changes) do
		if #changes.additions > 0 then
			change_analysis.summary.files_changed = change_analysis.summary.files_changed + 1
			change_analysis.summary.lines_added = change_analysis.summary.lines_added + #changes.additions
			change_analysis.summary.lines_deleted = change_analysis.summary.lines_deleted + #changes.deletions
			
			-- Analyze only added lines for issues
			local added_content = table.concat(changes.additions, "\n")
			local language = code_review_engine.detect_language(file_path)
			
			local file_analysis = {
				file_path = file_path,
				language = language,
				changes = changes,
				issues = []
			}
			
			-- Quick security scan on changes
			local security_issues = security_scanner.scan_content(added_content, language, file_path)
			file_analysis.issues = vim.list_extend(file_analysis.issues, security_issues)
			
			-- Quick performance scan on changes
			local perf_analysis = performance_analyzer.analyze_performance(added_content, language, file_path)
			file_analysis.issues = vim.list_extend(file_analysis.issues, perf_analysis.issues)
			
			-- Categorize issues
			for _, issue in ipairs(file_analysis.issues) do
				change_analysis.summary.issues_found = change_analysis.summary.issues_found + 1
				
				if vim.tbl_contains(default_config.severity_thresholds.block_commit, issue.severity) then
					table.insert(change_analysis.blocking_issues, issue)
				elseif vim.tbl_contains(default_config.severity_thresholds.warn_commit, issue.severity) then
					table.insert(change_analysis.warnings, issue)
				else
					table.insert(change_analysis.suggestions, issue)
				end
				
				if issue.category == "security" or vim.tbl_contains({"injection", "authentication"}, issue.category) then
					change_analysis.summary.security_risks = change_analysis.summary.security_risks + 1
				end
				
				if issue.type == "performance" then
					change_analysis.summary.performance_concerns = change_analysis.summary.performance_concerns + 1
				end
			end
			
			table.insert(change_analysis.files_analyzed, file_analysis)
		end
	end
	
	return change_analysis
end

-- Request AI insights for complex issues
function M.request_ai_insights(file_path, content, issues)
	if #issues == 0 then return end
	
	-- Prepare AI analysis prompt
	local issues_summary = {}
	for _, issue in ipairs(issues) do
		if issue.severity == "critical" or issue.severity == "high" then
			table.insert(issues_summary, string.format("L%d: %s", issue.line or 0, issue.message))
		end
	end
	
	if #issues_summary == 0 then return end
	
	local prompt = string.format([[
作为资深代码审查专家，请分析以下代码文件中发现的问题：

文件: %s
发现的问题:
%s

原始代码:
```
%s
```

请提供:
1. 问题根本原因分析
2. 具体修复建议（包含代码示例）
3. 预防类似问题的最佳实践
4. 对代码整体质量的评估

请用中文回复，提供actionable的建议。
]], file_path, table.concat(issues_summary, "\n"), content:sub(1, 2000)) -- Limit content for AI
	
	local ai_request_manager = require("ai_request_manager")
	local config = require("ai-commit").config
	
	local messages = {
		{
			role = "system",
			content = "你是一位资深的代码审查专家，专门帮助开发者提高代码质量和安全性。"
		},
		{
			role = "user",
			content = prompt
		}
	}
	
	-- Send async AI request
	vim.schedule(function()
		ai_request_manager.send_ai_request(messages, config, {
			task_type = "analysis",
			max_retries = 2,
			timeout = 45000
		})
	end)
end

-- Generate review recommendations
function M.generate_review_recommendations(review_results)
	local recommendations = {
		immediate_actions = {},
		code_improvements = {},
		team_process = {},
		tools_and_automation = {}
	}
	
	local summary = review_results.summary
	
	-- Immediate actions based on critical issues
	if summary.critical_issues > 0 then
		table.insert(recommendations.immediate_actions, 
			string.format("🚨 修复%d个严重问题后再进行部署", summary.critical_issues))
	end
	
	if summary.security_issues > 0 then
		table.insert(recommendations.immediate_actions,
			string.format("🔒 审查并修复%d个安全风险", summary.security_issues))
	end
	
	-- Code improvement suggestions
	if summary.total_issues > 20 then
		table.insert(recommendations.code_improvements, "📈 代码质量需要系统性改进")
		table.insert(recommendations.team_process, "📋 建立代码质量检查清单")
	end
	
	if summary.performance_issues > 5 then
		table.insert(recommendations.code_improvements, "⚡ 关注性能优化，建立性能基准")
	end
	
	-- Team process improvements
	local issue_density = summary.files_count > 0 and (summary.total_issues / summary.files_count) or 0
	if issue_density > 3 then
		table.insert(recommendations.team_process, "👥 加强代码审查流程")
		table.insert(recommendations.team_process, "📚 团队代码质量培训")
	end
	
	-- Tools and automation
	if summary.security_issues > 0 then
		table.insert(recommendations.tools_and_automation, "🛡️ 集成安全扫描工具到CI/CD")
	end
	
	if summary.total_issues > 10 then
		table.insert(recommendations.tools_and_automation, "🤖 启用pre-commit hooks自动检查")
	end
	
	return recommendations
end

-- Interactive review interface
function M.interactive_code_review()
	-- Get git data for current changes
	local git_data = require("commit_generator").collect_git_data()
	if not git_data then
		vim.notify("没有找到staged变更", vim.log.levels.ERROR)
		return
	end
	
	-- Show review mode selection
	vim.ui.select({
		"🚀 快速审查 - 基本代码质量检查",
		"🔍 全面审查 - 代码质量+安全+性能", 
		"🔒 安全审查 - 专注安全漏洞检测",
		"⚡ 性能审查 - 专注性能问题分析",
		"🧠 AI审查 - 深度AI代码分析"
	}, {
		prompt = "选择审查模式:",
	}, function(choice)
		if not choice then return end
		
		local mode_map = {
			["🚀"] = "quick",
			["🔍"] = "comprehensive", 
			["🔒"] = "security_focused",
			["⚡"] = "performance_focused",
			["🧠"] = "ai_powered"
		}
		
		local selected_mode = nil
		for icon, mode in pairs(mode_map) do
			if choice:match(icon) then
				selected_mode = mode
				break
			end
		end
		
		if not selected_mode then return end
		
		-- Perform review
		local review_results = M.review_git_changes(git_data, {mode = selected_mode})
		
		-- Show results
		M.display_review_results(review_results)
	end)
end

-- Display review results
function M.display_review_results(review_results)
	if review_results.error then
		vim.notify("审查失败: " .. review_results.error, vim.log.levels.ERROR)
		return
	end
	
	local summary = review_results.summary
	
	-- Generate summary report
	local report = string.format([[
🧠 智能代码审查结果

📊 审查统计:
📁 文件数: %d
📝 新增行: %d
🗑️ 删除行: %d
🔍 发现问题: %d个

⚠️ 问题分布:
🚨 阻塞问题: %d个
⚠️ 警告: %d个  
💡 建议: %d个
🔒 安全风险: %d个
⚡ 性能问题: %d个

]], 
		summary.files_changed or 0,
		summary.lines_added or 0,
		summary.lines_deleted or 0,
		summary.issues_found or 0,
		#(review_results.blocking_issues or {}),
		#(review_results.warnings or {}),
		#(review_results.suggestions or {}),
		summary.security_risks or 0,
		summary.performance_concerns or 0
	)
	
	-- Add detailed issues if any
	if review_results.blocking_issues and #review_results.blocking_issues > 0 then
		report = report .. "🚨 阻塞问题:\n"
		for i, issue in ipairs(review_results.blocking_issues) do
			if i <= 3 then
				report = report .. string.format("• %s (L%d): %s\n", 
					issue.file_path, issue.line or 0, issue.message)
			end
		end
		report = report .. "\n"
	end
	
	-- Show recommendations for proceeding
	if #(review_results.blocking_issues or {}) > 0 then
		report = report .. "❌ 建议: 修复阻塞问题后再提交\n"
	elseif #(review_results.warnings or {}) > 0 then
		report = report .. "⚠️ 建议: 考虑修复警告后提交\n"
	else
		report = report .. "✅ 可以安全提交\n"
	end
	
	vim.notify(report, vim.log.levels.INFO)
	
	-- Ask for next action
	if #(review_results.blocking_issues or {}) == 0 then
		vim.ui.select({
			"✅ 继续提交",
			"🔧 查看详细问题",
			"📊 生成完整报告",
			"❌ 取消"
		}, {
			prompt = "下一步操作:",
		}, function(action)
			if action and action:match("✅") then
				-- Proceed with commit
				require("ai-commit").generate_commit()
			elseif action and action:match("🔧") then
				M.show_detailed_issues(review_results)
			elseif action and action:match("📊") then
				M.generate_full_report(review_results)
			end
		end)
	end
end

-- Show detailed issues
function M.show_detailed_issues(review_results)
	local all_issues = {}
	vim.list_extend(all_issues, review_results.blocking_issues or {})
	vim.list_extend(all_issues, review_results.warnings or {})
	vim.list_extend(all_issues, review_results.suggestions or {})
	
	if #all_issues == 0 then
		vim.notify("没有发现问题", vim.log.levels.INFO)
		return
	end
	
	local detailed_report = "🔍 详细问题列表:\n\n"
	
	for i, issue in ipairs(all_issues) do
		detailed_report = detailed_report .. string.format([[
%d. %s
   📁 文件: %s
   📍 行号: %d
   ⚠️ 级别: %s
   📝 问题: %s
   💡 建议: %s
   📋 代码: %s

]], 
			i,
			issue.icon or "🔍",
			issue.file_path or "未知",
			issue.line or 0,
			issue.severity,
			issue.message,
			issue.suggestion or "无",
			issue.code_snippet or "无"
		)
	end
	
	vim.notify(detailed_report, vim.log.levels.INFO)
end

-- Generate full report file
function M.generate_full_report(review_results)
	local filename = string.format("code-review-report-%s.md", os.date("%Y%m%d-%H%M%S"))
	
	local report_content = string.format([[
# 🧠 智能代码审查报告

**生成时间**: %s  
**审查模式**: %s

## 📊 审查摘要

| 指标 | 数值 |
|------|------|
| 文件数 | %d |
| 新增行数 | %d |
| 删除行数 | %d |
| 发现问题 | %d |
| 阻塞问题 | %d |
| 安全风险 | %d |
| 性能问题 | %d |

## 🚨 关键问题

]], 
		os.date("%Y-%m-%d %H:%M:%S"),
		review_results.mode or "unknown",
		review_results.summary.files_changed or 0,
		review_results.summary.lines_added or 0,
		review_results.summary.lines_deleted or 0,
		review_results.summary.issues_found or 0,
		#(review_results.blocking_issues or {}),
		review_results.summary.security_risks or 0,
		review_results.summary.performance_concerns or 0
	)
	
	-- Add detailed issues
	local all_issues = {}
	vim.list_extend(all_issues, review_results.blocking_issues or {})
	vim.list_extend(all_issues, review_results.warnings or {})
	
	for _, issue in ipairs(all_issues) do
		report_content = report_content .. string.format([[
### %s %s

- **文件**: %s
- **行号**: %d  
- **级别**: %s
- **问题**: %s
- **建议**: %s

```
%s
```

]], 
			issue.icon or "🔍",
			issue.message,
			issue.file_path or "未知",
			issue.line or 0,
			issue.severity,
			issue.message,
			issue.suggestion or "无",
			issue.code_snippet or "无"
		)
	end
	
	-- Write report to file
	vim.fn.writefile(vim.split(report_content, "\n"), filename)
	vim.notify(string.format("📊 完整报告已保存到: %s", filename), vim.log.levels.INFO)
end

-- Pre-commit hook integration
function M.pre_commit_review()
	local git_data = require("commit_generator").collect_git_data()
	if not git_data then
		return true -- Allow commit if no data
	end
	
	local review_results = M.review_git_changes(git_data, {mode = "quick"})
	
	-- Check for blocking issues
	if review_results.blocking_issues and #review_results.blocking_issues > 0 then
		vim.notify("🚨 发现阻塞问题，提交被拒绝", vim.log.levels.ERROR)
		M.display_review_results(review_results)
		return false
	end
	
	return true -- Allow commit
end

-- Configuration management
function M.setup_code_review(config)
	default_config = vim.tbl_deep_extend("force", default_config, config or {})
	
	if default_config.auto_review_on_commit then
		-- Setup pre-commit hook
		vim.api.nvim_create_autocmd("User", {
			pattern = "AICommitPreHook",
			callback = function()
				return M.pre_commit_review()
			end
		})
	end
end

-- Export configuration
M.REVIEW_MODES = REVIEW_MODES
M.default_config = default_config

return M