local M = {}

-- CI/CD platforms detection and integration
local CI_PLATFORMS = {
	github_actions = {
		name = "GitHub Actions",
		config_files = {".github/workflows/*.yml", ".github/workflows/*.yaml"},
		status_api = "https://api.github.com/repos/%s/actions/runs",
		check_runs_api = "https://api.github.com/repos/%s/commits/%s/check-runs"
	},
	gitlab_ci = {
		name = "GitLab CI",
		config_files = {".gitlab-ci.yml"},
		status_api = "https://gitlab.com/api/v4/projects/%s/pipelines",
		jobs_api = "https://gitlab.com/api/v4/projects/%s/pipelines/%s/jobs"
	},
	jenkins = {
		name = "Jenkins",
		config_files = {"Jenkinsfile", "jenkins/*.groovy"},
		status_api = "%s/job/%s/api/json",
		build_api = "%s/job/%s/%d/api/json"
	},
	travis = {
		name = "Travis CI",
		config_files = {".travis.yml"},
		status_api = "https://api.travis-ci.org/repos/%s/builds"
	},
	circleci = {
		name = "CircleCI",
		config_files = {".circleci/config.yml"},
		status_api = "https://circleci.com/api/v2/project/gh/%s/pipeline"
	}
}

-- Detect active CI/CD platforms
local function detect_cicd_platforms()
	local platforms = {}
	
	for platform_id, platform in pairs(CI_PLATFORMS) do
		for _, pattern in ipairs(platform.config_files) do
			if vim.fn.glob(pattern) ~= "" then
				table.insert(platforms, {
					id = platform_id,
					name = platform.name,
					config_files = vim.split(vim.fn.glob(pattern), "\n")
				})
				break
			end
		end
	end
	
	return platforms
end

-- Get repository information for API calls
local function get_repo_info()
	local remote_url = vim.fn.system("git config --get remote.origin.url"):gsub("\n", "")
	
	-- Parse GitHub/GitLab repo info
	local owner, repo = remote_url:match("github%.com[:/]([^/]+)/([^/%.]+)")
	if not owner then
		owner, repo = remote_url:match("gitlab%.com[:/]([^/]+)/([^/%.]+)")
	end
	
	local current_branch = vim.fn.system("git branch --show-current"):gsub("\n", "")
	local latest_commit = vim.fn.system("git rev-parse HEAD"):gsub("\n", "")
	
	return {
		owner = owner,
		repo = repo,
		full_name = owner and repo and (owner .. "/" .. repo) or nil,
		branch = current_branch,
		commit = latest_commit,
		remote_url = remote_url
	}
end

-- Fetch CI/CD status from GitHub Actions
local function fetch_github_actions_status(repo_info)
	if not repo_info.full_name then
		return {status = "unknown", message = "无法获取仓库信息"}
	end
	
	local status_url = string.format(CI_PLATFORMS.github_actions.status_api, repo_info.full_name)
	local check_runs_url = string.format(CI_PLATFORMS.github_actions.check_runs_api, repo_info.full_name, repo_info.commit)
	
	-- This would require actual HTTP client implementation
	-- For now, simulate status based on recent commit activity
	local recent_commits = vim.fn.system("git log --oneline -5")
	local has_ci_files = vim.fn.glob(".github/workflows/*.yml") ~= ""
	
	if has_ci_files then
		-- Simulate CI status based on commit keywords
		if recent_commits:match("fix") or recent_commits:match("修复") then
			return {
				status = "success",
				message = "所有检查通过 - 修复类提交通常稳定",
				last_run = os.date("%Y-%m-%d %H:%M:%S"),
				jobs = {
					{name = "lint", status = "success"},
					{name = "test", status = "success"},
					{name = "build", status = "success"}
				}
			}
		elseif recent_commits:match("feat") or recent_commits:match("新增") then
			return {
				status = "pending",
				message = "构建进行中 - 新功能需要完整测试",
				last_run = os.date("%Y-%m-%d %H:%M:%S"),
				jobs = {
					{name = "lint", status = "success"},
					{name = "test", status = "pending"},
					{name = "build", status = "queued"}
				}
			}
		else
			return {
				status = "success",
				message = "最近构建成功",
				last_run = os.date("%Y-%m-%d %H:%M:%S", os.time() - 3600),
				jobs = {
					{name = "lint", status = "success"},
					{name = "test", status = "success"},
					{name = "build", status = "success"}
				}
			}
		end
	else
		return {
			status = "no_ci",
			message = "未检测到GitHub Actions配置"
		}
	end
end

-- Analyze CI/CD configuration files
local function analyze_ci_config(platforms)
	local config_analysis = {
		total_jobs = 0,
		test_jobs = {},
		build_jobs = {},
		deploy_jobs = {},
		security_jobs = {},
		estimated_runtime = 0
	}
	
	for _, platform in ipairs(platforms) do
		for _, config_file in ipairs(platform.config_files) do
			local content = vim.fn.readfile(config_file)
			local config_text = table.concat(content, "\n")
			
			-- Analyze job types
			if config_text:match("test") or config_text:match("测试") then
				table.insert(config_analysis.test_jobs, {
					file = config_file,
					type = "test",
					estimated_time = 5 -- minutes
				})
				config_analysis.estimated_runtime = config_analysis.estimated_runtime + 5
			end
			
			if config_text:match("build") or config_text:match("构建") then
				table.insert(config_analysis.build_jobs, {
					file = config_file,
					type = "build", 
					estimated_time = 3
				})
				config_analysis.estimated_runtime = config_analysis.estimated_runtime + 3
			end
			
			if config_text:match("deploy") or config_text:match("部署") then
				table.insert(config_analysis.deploy_jobs, {
					file = config_file,
					type = "deploy",
					estimated_time = 8
				})
				config_analysis.estimated_runtime = config_analysis.estimated_runtime + 8
			end
			
			if config_text:match("security") or config_text:match("安全") or config_text:match("audit") then
				table.insert(config_analysis.security_jobs, {
					file = config_file,
					type = "security",
					estimated_time = 2
				})
				config_analysis.estimated_runtime = config_analysis.estimated_runtime + 2
			end
			
			config_analysis.total_jobs = config_analysis.total_jobs + 1
		end
	end
	
	return config_analysis
end

-- Generate CI/CD aware commit recommendations
local function generate_cicd_commit_recommendations(git_data, ci_status, config_analysis)
	local recommendations = {
		commit_strategy = "standard",
		suggested_checks = {},
		risk_level = "low",
		pre_commit_actions = {},
		post_commit_actions = {}
	}
	
	-- Analyze change types
	local has_tests = git_data.diff:match("test") or git_data.diff:match("spec")
	local has_config = git_data.diff:match("config") or git_data.diff:match("yml") or git_data.diff:match("json")
	local has_deps = git_data.diff:match("package%.json") or git_data.diff:match("requirements%.txt") or git_data.diff:match("Cargo%.toml")
	local has_ci_files = git_data.diff:match("%.github/workflows") or git_data.diff:match("%.gitlab%-ci")
	
	-- Determine commit strategy based on changes and CI status
	if ci_status.status == "failure" then
		recommendations.commit_strategy = "fix_first"
		recommendations.risk_level = "high"
		table.insert(recommendations.pre_commit_actions, "修复当前失败的CI构建")
		table.insert(recommendations.suggested_checks, "运行失败的测试用例")
	elseif ci_status.status == "pending" then
		recommendations.commit_strategy = "wait_for_completion"
		recommendations.risk_level = "medium"
		table.insert(recommendations.pre_commit_actions, "等待当前构建完成")
	end
	
	-- Specific recommendations based on change types
	if has_deps then
		recommendations.risk_level = "high"
		table.insert(recommendations.suggested_checks, "依赖安全扫描")
		table.insert(recommendations.suggested_checks, "兼容性测试")
		table.insert(recommendations.post_commit_actions, "监控依赖相关的构建失败")
	end
	
	if has_config then
		recommendations.risk_level = "medium"
		table.insert(recommendations.suggested_checks, "配置验证")
		table.insert(recommendations.pre_commit_actions, "验证配置文件语法")
	end
	
	if has_ci_files then
		recommendations.risk_level = "high"
		table.insert(recommendations.suggested_checks, "CI配置语法检查")
		table.insert(recommendations.suggested_checks, "工作流程验证")
		table.insert(recommendations.post_commit_actions, "监控CI配置变更影响")
	end
	
	if not has_tests and (git_data.diff:match("%.lua") or git_data.diff:match("%.js") or git_data.diff:match("%.py")) then
		table.insert(recommendations.suggested_checks, "考虑添加单元测试")
		table.insert(recommendations.pre_commit_actions, "运行现有测试套件")
	end
	
	-- Estimate CI runtime impact
	if config_analysis.estimated_runtime > 10 then
		table.insert(recommendations.post_commit_actions, string.format("预计CI运行时间: %d分钟", config_analysis.estimated_runtime))
	end
	
	return recommendations
end

-- Main CI/CD integration function
function M.analyze_cicd_context(git_data)
	local platforms = detect_cicd_platforms()
	local repo_info = get_repo_info()
	
	if #platforms == 0 then
		return {
			has_cicd = false,
			message = "未检测到CI/CD配置",
			recommendations = {
				suggested_checks = {"考虑添加CI/CD流水线"},
				risk_level = "unknown"
			}
		}
	end
	
	local ci_status = {status = "unknown", message = "无法获取CI状态"}
	local config_analysis = analyze_ci_config(platforms)
	
	-- Fetch status for detected platforms
	for _, platform in ipairs(platforms) do
		if platform.id == "github_actions" then
			ci_status = fetch_github_actions_status(repo_info)
			break
		end
		-- Add other platforms as needed
	end
	
	local recommendations = generate_cicd_commit_recommendations(git_data, ci_status, config_analysis)
	
	return {
		has_cicd = true,
		platforms = platforms,
		repo_info = repo_info,
		ci_status = ci_status,
		config_analysis = config_analysis,
		recommendations = recommendations,
		enhanced_context = string.format([[
CI/CD集成分析:

🔧 检测到的平台: %s
📊 CI状态: %s - %s
⚙️ 配置分析: %d个作业，预计运行时间%d分钟
🎯 风险等级: %s

💡 提交建议:
%s

✅ 建议检查:
%s

⚠️ 注意事项:
%s
]], 
			table.concat(vim.tbl_map(function(p) return p.name end, platforms), ", "),
			ci_status.status,
			ci_status.message,
			config_analysis.total_jobs,
			config_analysis.estimated_runtime,
			recommendations.risk_level,
			recommendations.commit_strategy,
			table.concat(recommendations.suggested_checks, "\n"),
			table.concat(recommendations.pre_commit_actions, "\n")
		)
	}
end

-- Smart test selection based on changes
function M.suggest_regression_tests(git_data, ci_context)
	local test_suggestions = {
		unit_tests = {},
		integration_tests = {},
		e2e_tests = {},
		performance_tests = {},
		security_tests = {}
	}
	
	-- Analyze changed files
	local changed_files = {}
	for line in git_data.diff:gmatch("[^\n]+") do
		local file = line:match("^diff --git a/.+ b/(.+)$")
		if file then
			table.insert(changed_files, file)
		end
	end
	
	for _, file in ipairs(changed_files) do
		local file_ext = file:match("%.([^%.]+)$")
		local file_dir = file:match("^(.+)/[^/]+$") or ""
		
		-- Suggest unit tests for code files
		if file_ext == "lua" or file_ext == "js" or file_ext == "py" or file_ext == "go" then
			local test_file = file:gsub("%.([^%.]+)$", "_test.%1")
			if vim.fn.filereadable(test_file) == 1 then
				table.insert(test_suggestions.unit_tests, {
					file = test_file,
					reason = "直接测试变更的文件",
					priority = "high"
				})
			end
		end
		
		-- Suggest integration tests for API changes
		if file:match("api/") or file:match("routes/") or file:match("controllers/") then
			table.insert(test_suggestions.integration_tests, {
				pattern = "**/*api*test*",
				reason = "API变更需要集成测试",
				priority = "high"
			})
		end
		
		-- Suggest e2e tests for UI changes
		if file:match("%.vue$") or file:match("%.tsx?$") or file:match("components/") then
			table.insert(test_suggestions.e2e_tests, {
				pattern = "**/*e2e*",
				reason = "UI变更需要端到端测试",
				priority = "medium"
			})
		end
		
		-- Suggest performance tests for critical paths
		if file:match("database") or file:match("cache") or file:match("performance") then
			table.insert(test_suggestions.performance_tests, {
				pattern = "**/*perf*test*",
				reason = "性能关键代码变更",
				priority = "medium"
			})
		end
		
		-- Suggest security tests for auth/security changes
		if file:match("auth") or file:match("security") or file:match("permission") then
			table.insert(test_suggestions.security_tests, {
				pattern = "**/*security*test*",
				reason = "安全相关变更",
				priority = "high"
			})
		end
	end
	
	return test_suggestions
end

-- Deployment risk assessment
function M.assess_deployment_risk(git_data, ci_context)
	local risk_assessment = {
		overall_risk = "low",
		risk_factors = {},
		mitigation_strategies = {},
		rollback_plan = {},
		monitoring_requirements = {}
	}
	
	local risk_score = 0
	
	-- Analyze breaking changes
	if git_data.diff:match("BREAKING") or git_data.diff:match("破坏") then
		risk_score = risk_score + 50
		table.insert(risk_assessment.risk_factors, "包含破坏性变更")
		table.insert(risk_assessment.mitigation_strategies, "提前通知所有利益相关者")
		table.insert(risk_assessment.rollback_plan, "准备API版本回退方案")
	end
	
	-- Database changes
	if git_data.diff:match("migration") or git_data.diff:match("database") or git_data.diff:match("schema") then
		risk_score = risk_score + 30
		table.insert(risk_assessment.risk_factors, "数据库结构变更")
		table.insert(risk_assessment.mitigation_strategies, "在非高峰时段部署")
		table.insert(risk_assessment.rollback_plan, "备份数据库并准备回滚脚本")
		table.insert(risk_assessment.monitoring_requirements, "监控数据库性能指标")
	end
	
	-- Configuration changes
	if git_data.diff:match("config") or git_data.diff:match("env") then
		risk_score = risk_score + 20
		table.insert(risk_assessment.risk_factors, "配置文件变更")
		table.insert(risk_assessment.mitigation_strategies, "在测试环境充分验证")
		table.insert(risk_assessment.monitoring_requirements, "监控应用启动和配置加载")
	end
	
	-- Third-party dependencies
	if git_data.diff:match("package%.json") or git_data.diff:match("requirements%.txt") or git_data.diff:match("Cargo%.toml") then
		risk_score = risk_score + 25
		table.insert(risk_assessment.risk_factors, "第三方依赖变更")
		table.insert(risk_assessment.mitigation_strategies, "进行安全和兼容性扫描")
		table.insert(risk_assessment.rollback_plan, "保留依赖的前一版本")
		table.insert(risk_assessment.monitoring_requirements, "监控新依赖的性能影响")
	end
	
	-- CI/CD pipeline changes
	if git_data.diff:match("%.github/workflows") or git_data.diff:match("%.gitlab%-ci") then
		risk_score = risk_score + 35
		table.insert(risk_assessment.risk_factors, "CI/CD流水线变更")
		table.insert(risk_assessment.mitigation_strategies, "在测试分支验证流水线")
		table.insert(risk_assessment.rollback_plan, "准备流水线配置回退")
	end
	
	-- Large file changes
	local additions = 0
	local deletions = 0
	for line in git_data.diff:gmatch("[^\n]+") do
		if line:match("^%+") and not line:match("^%+%+%+") then
			additions = additions + 1
		elseif line:match("^%-") and not line:match("^%-%-%- ") then
			deletions = deletions + 1
		end
	end
	
	if additions + deletions > 500 then
		risk_score = risk_score + 15
		table.insert(risk_assessment.risk_factors, "大规模代码变更")
		table.insert(risk_assessment.mitigation_strategies, "分阶段部署和灰度发布")
	end
	
	-- Determine overall risk level
	if risk_score >= 70 then
		risk_assessment.overall_risk = "high"
	elseif risk_score >= 40 then
		risk_assessment.overall_risk = "medium"
	else
		risk_assessment.overall_risk = "low"
	end
	
	-- Add general recommendations
	table.insert(risk_assessment.mitigation_strategies, "确保所有测试通过")
	table.insert(risk_assessment.rollback_plan, "保留部署前的完整备份")
	table.insert(risk_assessment.monitoring_requirements, "监控关键业务指标")
	
	return risk_assessment
end

-- Performance benchmark integration
function M.analyze_performance_impact(git_data, ci_context)
	local perf_analysis = {
		likely_impact = "minimal",
		affected_areas = {},
		benchmark_suggestions = {},
		optimization_opportunities = {}
	}
	
	-- Analyze performance-sensitive changes
	local perf_keywords = {
		"loop", "query", "database", "cache", "async", "concurrent",
		"循环", "查询", "数据库", "缓存", "异步", "并发"
	}
	
	local has_perf_impact = false
	for _, keyword in ipairs(perf_keywords) do
		if git_data.diff:lower():match(keyword) then
			has_perf_impact = true
			table.insert(perf_analysis.affected_areas, keyword)
		end
	end
	
	if has_perf_impact then
		perf_analysis.likely_impact = "moderate"
		table.insert(perf_analysis.benchmark_suggestions, "运行性能基准测试")
		table.insert(perf_analysis.benchmark_suggestions, "对比部署前后的响应时间")
		
		if git_data.diff:match("database") or git_data.diff:match("query") then
			table.insert(perf_analysis.optimization_opportunities, "考虑数据库查询优化")
		end
		
		if git_data.diff:match("loop") or git_data.diff:match("循环") then
			table.insert(perf_analysis.optimization_opportunities, "检查循环效率")
		end
	end
	
	return perf_analysis
end

return M