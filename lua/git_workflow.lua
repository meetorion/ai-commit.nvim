local M = {}

-- Advanced Git workflow automation
local Job = require("plenary.job")

-- Smart branch naming suggestions
local function suggest_branch_name(commit_message, branch_type)
	branch_type = branch_type or "feature"
	
	-- Extract key terms from commit message
	local message = commit_message:lower()
	local terms = {}
	
	-- Remove common words and extract meaningful terms
	local common_words = {"the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "add", "fix", "update", "remove"}
	
	for word in message:gmatch("%w+") do
		if #word > 2 and not vim.tbl_contains(common_words, word) then
			table.insert(terms, word)
		end
	end
	
	-- Create branch name
	local branch_suffix = table.concat(vim.list_slice(terms, 1, 3), "-")
	return string.format("%s/%s", branch_type, branch_suffix)
end

-- Analyze merge conflicts potential
local function analyze_merge_conflicts()
	local conflicts = {
		high_risk_files = {},
		recent_conflict_files = {},
		recommendations = {}
	}
	
	-- Get files that frequently have conflicts
	local conflict_history = vim.fn.system("git log --grep='Merge conflict' --pretty=format:'%s' -n 10")
	if conflict_history ~= "" then
		for line in conflict_history:gmatch("[^\n]+") do
			table.insert(conflicts.recent_conflict_files, line)
		end
	end
	
	-- Check current staged files against recently modified files
	local staged_files = vim.fn.system("git diff --cached --name-only")
	local recent_files = vim.fn.system("git log --name-only --pretty=format: -n 10 | sort | uniq")
	
	if staged_files ~= "" and recent_files ~= "" then
		local staged_list = vim.split(staged_files, "\n")
		local recent_list = vim.split(recent_files, "\n")
		
		for _, staged in ipairs(staged_list) do
			if staged ~= "" and vim.tbl_contains(recent_list, staged) then
				table.insert(conflicts.high_risk_files, staged)
			end
		end
	end
	
	-- Generate recommendations
	if #conflicts.high_risk_files > 0 then
		table.insert(conflicts.recommendations, "警告: 以下文件最近被多次修改，可能存在合并冲突风险: " .. table.concat(conflicts.high_risk_files, ", "))
		table.insert(conflicts.recommendations, "建议: 在提交前与团队沟通，或考虑拆分为更小的提交")
	end
	
	if #conflicts.recent_conflict_files > 0 then
		table.insert(conflicts.recommendations, "注意: 项目最近有合并冲突历史，建议频繁同步主分支")
	end
	
	return conflicts
end

-- Automated code review suggestions
local function generate_code_review_suggestions(git_data)
	local suggestions = {
		code_quality = {},
		security = {},
		performance = {},
		testing = {},
		documentation = {}
	}
	
	local diff = git_data.diff
	
	-- Code quality checks
	if diff:match("console%.log") or diff:match("print%(") then
		table.insert(suggestions.code_quality, "发现调试代码 - 建议移除 console.log 或 print 语句")
	end
	
	if diff:match("TODO") or diff:match("FIXME") then
		table.insert(suggestions.code_quality, "发现 TODO/FIXME 注释 - 考虑创建 issue 跟踪")
	end
	
	if diff:match("magic number") or diff:match("%d+") then
		table.insert(suggestions.code_quality, "考虑将魔法数字提取为常量")
	end
	
	-- Security checks
	if diff:match("password") or diff:match("secret") or diff:match("key") then
		table.insert(suggestions.security, "⚠️ 安全警告: 检测到可能的敏感信息")
	end
	
	if diff:match("eval%(") or diff:match("exec%(") then
		table.insert(suggestions.security, "⚠️ 安全警告: 使用 eval/exec 可能存在代码注入风险")
	end
	
	-- Performance checks
	if diff:match("for.*in.*range") or diff:match("while.*true") then
		table.insert(suggestions.performance, "性能建议: 检查循环效率，考虑使用更高效的算法")
	end
	
	if diff:match("SELECT %*") then
		table.insert(suggestions.performance, "性能建议: 避免 SELECT * 查询，明确指定需要的字段")
	end
	
	-- Testing suggestions
	if not diff:match("test") and (diff:match("function") or diff:match("def ") or diff:match("class")) then
		table.insert(suggestions.testing, "测试建议: 新增功能建议添加对应的单元测试")
	end
	
	-- Documentation suggestions
	if diff:match("export") or diff:match("public") then
		table.insert(suggestions.documentation, "文档建议: 公共API变更建议更新相关文档")
	end
	
	return suggestions
end

-- Smart deployment decision helper
local function analyze_deployment_readiness(git_data, context)
	local readiness = {
		score = 0,
		max_score = 100,
		blockers = {},
		warnings = {},
		recommendations = {}
	}
	
	-- Check if tests are passing (simulate)
	local test_status = vim.fn.system("git log -1 --pretty=format:'%s' | grep -i test")
	if test_status ~= "" then
		readiness.score = readiness.score + 20
	else
		table.insert(readiness.warnings, "未检测到测试相关提交")
	end
	
	-- Check for breaking changes
	if context and context.quality and context.quality.breaking_changes then
		table.insert(readiness.blockers, "包含破坏性变更 - 需要版本管理和通知")
		readiness.score = readiness.score - 30
	else
		readiness.score = readiness.score + 15
	end
	
	-- Check for security changes
	if context and context.quality and context.quality.security_concerns then
		table.insert(readiness.warnings, "包含安全相关变更 - 建议安全审查")
		readiness.score = readiness.score - 10
	end
	
	-- Check for database changes
	if context and context.quality and context.quality.migration_required then
		table.insert(readiness.blockers, "需要数据库迁移 - 协调运维团队")
		readiness.score = readiness.score - 20
	end
	
	-- Documentation check
	if context and context.quality and context.quality.documentation_changes then
		readiness.score = readiness.score + 10
	end
	
	-- Determine deployment recommendation
	if readiness.score >= 80 then
		table.insert(readiness.recommendations, "✅ 建议部署 - 变更风险较低")
	elseif readiness.score >= 60 then
		table.insert(readiness.recommendations, "⚠️ 谨慎部署 - 需要额外测试")
	else
		table.insert(readiness.recommendations, "❌ 不建议立即部署 - 存在较高风险")
	end
	
	return readiness
end

-- Generate comprehensive workflow report
function M.generate_workflow_report(git_data)
	local advanced_analysis = require('advanced_analysis')
	local context = advanced_analysis.analyze_commit_context(git_data)
	
	local conflicts = analyze_merge_conflicts()
	local review_suggestions = generate_code_review_suggestions(git_data)
	local deployment = analyze_deployment_readiness(git_data, context)
	
	local report = string.format([[
🔄 Git工作流分析报告

📊 项目上下文:
%s

🔍 代码审查建议:
代码质量: %s
安全检查: %s  
性能建议: %s
测试建议: %s
文档建议: %s

⚠️ 合并冲突分析:
高风险文件: %s
建议: %s

🚀 部署就绪度: %d/100
阻塞问题: %s
警告: %s
部署建议: %s
]], 
		context.enhanced_context,
		#review_suggestions.code_quality > 0 and table.concat(review_suggestions.code_quality, "; ") or "无问题",
		#review_suggestions.security > 0 and table.concat(review_suggestions.security, "; ") or "无问题",
		#review_suggestions.performance > 0 and table.concat(review_suggestions.performance, "; ") or "无建议",
		#review_suggestions.testing > 0 and table.concat(review_suggestions.testing, "; ") or "无建议",
		#review_suggestions.documentation > 0 and table.concat(review_suggestions.documentation, "; ") or "无建议",
		#conflicts.high_risk_files > 0 and table.concat(conflicts.high_risk_files, ", ") or "无",
		#conflicts.recommendations > 0 and table.concat(conflicts.recommendations, "; ") or "无特殊建议",
		deployment.score,
		#deployment.blockers > 0 and table.concat(deployment.blockers, "; ") or "无",
		#deployment.warnings > 0 and table.concat(deployment.warnings, "; ") or "无",
		#deployment.recommendations > 0 and table.concat(deployment.recommendations, "; ") or "无建议"
	)
	
	return {
		report = report,
		context = context,
		conflicts = conflicts,
		review_suggestions = review_suggestions,
		deployment = deployment
	}
end

-- Smart branch management
function M.smart_branch_create(commit_message, branch_type)
	local suggested_name = suggest_branch_name(commit_message, branch_type)
	
	vim.ui.input({
		prompt = "分支名称: ",
		default = suggested_name
	}, function(branch_name)
		if branch_name then
			Job:new({
				command = "git",
				args = {"checkout", "-b", branch_name},
				on_exit = function(_, return_val)
					if return_val == 0 then
						vim.notify("已创建并切换到分支: " .. branch_name, vim.log.levels.INFO)
					else
						vim.notify("创建分支失败", vim.log.levels.ERROR)
					end
				end
			}):start()
		end
	end)
end

-- Interactive pre-commit workflow
function M.interactive_pre_commit_workflow(git_data)
	local workflow_data = M.generate_workflow_report(git_data)
	
	-- Show workflow report
	vim.notify(workflow_data.report, vim.log.levels.INFO)
	
	-- Interactive options
	vim.ui.select({
		"继续提交",
		"查看详细分析", 
		"创建新分支",
		"生成部署清单",
		"取消操作"
	}, {
		prompt = "选择下一步操作:",
	}, function(choice)
		if choice == "继续提交" then
			-- Proceed with normal commit flow
			return true
		elseif choice == "查看详细分析" then
			local detailed = vim.inspect(workflow_data)
			vim.notify(detailed, vim.log.levels.INFO)
		elseif choice == "创建新分支" then
			M.smart_branch_create("feature-branch", "feature")
		elseif choice == "生成部署清单" then
			local checklist = M.generate_deployment_checklist(workflow_data)
			vim.notify(checklist, vim.log.levels.INFO)
		elseif choice == "取消操作" then
			vim.notify("操作已取消", vim.log.levels.INFO)
			return false
		end
	end)
end

-- Generate deployment checklist
function M.generate_deployment_checklist(workflow_data)
	local checklist = {
		"📋 部署前检查清单:",
		"",
		"✅ 代码变更:",
	}
	
	if workflow_data.context.quality.breaking_changes then
		table.insert(checklist, "  ⚠️ 确认破坏性变更已通知相关团队")
		table.insert(checklist, "  ⚠️ 更新版本号和变更日志")
	end
	
	if workflow_data.context.quality.migration_required then
		table.insert(checklist, "  ⚠️ 准备数据库迁移脚本")
		table.insert(checklist, "  ⚠️ 协调运维团队执行迁移")
	end
	
	table.insert(checklist, "")
	table.insert(checklist, "✅ 测试验证:")
	table.insert(checklist, "  □ 单元测试通过")
	table.insert(checklist, "  □ 集成测试通过") 
	table.insert(checklist, "  □ 端到端测试通过")
	
	if workflow_data.context.quality.security_concerns then
		table.insert(checklist, "  □ 安全测试通过")
	end
	
	table.insert(checklist, "")
	table.insert(checklist, "✅ 部署准备:")
	table.insert(checklist, "  □ 环境配置检查")
	table.insert(checklist, "  □ 依赖项更新")
	table.insert(checklist, "  □ 回滚方案准备")
	table.insert(checklist, "  □ 监控告警配置")
	
	return table.concat(checklist, "\n")
end

return M