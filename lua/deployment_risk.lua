local M = {}

-- Risk categories and scoring
local RISK_CATEGORIES = {
	breaking_changes = {weight = 40, max_score = 100},
	database_changes = {weight = 35, max_score = 100},
	config_changes = {weight = 25, max_score = 100},
	dependency_changes = {weight = 30, max_score = 100},
	security_changes = {weight = 45, max_score = 100},
	performance_changes = {weight = 25, max_score = 100},
	infrastructure_changes = {weight = 35, max_score = 100},
	large_scale_changes = {weight = 20, max_score = 100}
}

-- Environment configurations
local ENVIRONMENTS = {
	development = {risk_tolerance = "high", auto_deploy = true},
	staging = {risk_tolerance = "medium", auto_deploy = true},
	production = {risk_tolerance = "low", auto_deploy = false}
}

-- Analyze breaking changes
local function analyze_breaking_changes(git_data)
	local analysis = {
		score = 0,
		factors = {},
		mitigation = {},
		rollback = {}
	}
	
	local diff = git_data.diff:lower()
	
	-- API changes
	if diff:match("breaking") or diff:match("破坏") then
		analysis.score = analysis.score + 50
		table.insert(analysis.factors, "明确标记的破坏性变更")
		table.insert(analysis.mitigation, "版本兼容性处理")
		table.insert(analysis.rollback, "API版本回退方案")
	end
	
	-- Function signature changes
	if diff:match("function.*%(.*%)") and (diff:match("%-.*function") or diff:match("%+.*function")) then
		analysis.score = analysis.score + 30
		table.insert(analysis.factors, "函数签名可能变更")
		table.insert(analysis.mitigation, "检查所有调用点")
	end
	
	-- Interface/Contract changes
	if diff:match("interface") or diff:match("contract") or diff:match("schema") then
		analysis.score = analysis.score + 25
		table.insert(analysis.factors, "接口或契约变更")
		table.insert(analysis.mitigation, "向后兼容性验证")
	end
	
	-- Removed exports/public methods
	if diff:match("%-.*export") or diff:match("%-.*public") then
		analysis.score = analysis.score + 40
		table.insert(analysis.factors, "可能移除了公共接口")
		table.insert(analysis.rollback, "恢复被移除的接口")
	end
	
	-- Database schema changes
	if diff:match("drop") or diff:match("alter") or diff:match("删除") then
		analysis.score = analysis.score + 35
		table.insert(analysis.factors, "数据库结构变更")
		table.insert(analysis.mitigation, "数据迁移验证")
		table.insert(analysis.rollback, "数据库回滚脚本")
	end
	
	return math.min(analysis.score, 100), analysis
end

-- Analyze database changes
local function analyze_database_changes(git_data)
	local analysis = {
		score = 0,
		factors = {},
		mitigation = {},
		rollback = {}
	}
	
	local diff = git_data.diff:lower()
	
	-- Migration files
	if diff:match("migration") or diff:match("migrate") then
		analysis.score = analysis.score + 40
		table.insert(analysis.factors, "数据库迁移文件变更")
		table.insert(analysis.mitigation, "在测试环境验证迁移")
		table.insert(analysis.rollback, "准备回滚迁移脚本")
	end
	
	-- Schema changes
	if diff:match("create table") or diff:match("alter table") or diff:match("drop table") then
		analysis.score = analysis.score + 50
		table.insert(analysis.factors, "数据库表结构变更")
		table.insert(analysis.mitigation, "数据备份和验证")
		table.insert(analysis.rollback, "表结构回滚方案")
	end
	
	-- Index changes
	if diff:match("create index") or diff:match("drop index") then
		analysis.score = analysis.score + 20
		table.insert(analysis.factors, "数据库索引变更")
		table.insert(analysis.mitigation, "监控查询性能")
	end
	
	-- Database configuration
	if diff:match("database.*config") or diff:match("db.*config") then
		analysis.score = analysis.score + 30
		table.insert(analysis.factors, "数据库配置变更")
		table.insert(analysis.mitigation, "连接池和超时设置验证")
	end
	
	-- ORM model changes
	if diff:match("model") and (diff:match("field") or diff:match("column")) then
		analysis.score = analysis.score + 25
		table.insert(analysis.factors, "数据模型变更")
		table.insert(analysis.mitigation, "数据一致性检查")
	end
	
	return math.min(analysis.score, 100), analysis
end

-- Analyze configuration changes
local function analyze_config_changes(git_data)
	local analysis = {
		score = 0,
		factors = {},
		mitigation = {},
		rollback = {}
	}
	
	local diff = git_data.diff
	
	-- Environment variables
	if diff:match("%.env") or diff:match("environment") then
		analysis.score = analysis.score + 35
		table.insert(analysis.factors, "环境变量配置变更")
		table.insert(analysis.mitigation, "环境特定配置验证")
		table.insert(analysis.rollback, "配置文件备份")
	end
	
	-- Application config files
	local config_patterns = {"config%.json", "config%.yml", "config%.yaml", "settings%.py", "application%.properties"}
	for _, pattern in ipairs(config_patterns) do
		if diff:match(pattern) then
			analysis.score = analysis.score + 25
			table.insert(analysis.factors, "应用配置文件变更")
			table.insert(analysis.mitigation, "配置语法验证")
			break
		end
	end
	
	-- Security config
	if diff:match("security") or diff:match("auth") or diff:match("ssl") or diff:match("tls") then
		analysis.score = analysis.score + 40
		table.insert(analysis.factors, "安全配置变更")
		table.insert(analysis.mitigation, "安全设置验证")
		table.insert(analysis.rollback, "安全配置回退")
	end
	
	-- Logging config
	if diff:match("log") or diff:match("logging") then
		analysis.score = analysis.score + 15
		table.insert(analysis.factors, "日志配置变更")
		table.insert(analysis.mitigation, "日志级别和输出验证")
	end
	
	-- Docker/K8s config
	if diff:match("dockerfile") or diff:match("docker%-compose") or diff:match("kubernetes") or diff:match("k8s") then
		analysis.score = analysis.score + 30
		table.insert(analysis.factors, "容器/编排配置变更")
		table.insert(analysis.mitigation, "容器构建和部署测试")
	end
	
	return math.min(analysis.score, 100), analysis
end

-- Analyze dependency changes
local function analyze_dependency_changes(git_data)
	local analysis = {
		score = 0,
		factors = {},
		mitigation = {},
		rollback = {}
	}
	
	local diff = git_data.diff
	
	-- Package files
	local package_files = {"package%.json", "requirements%.txt", "Cargo%.toml", "go%.mod", "Gemfile", "composer%.json"}
	for _, pattern in ipairs(package_files) do
		if diff:match(pattern) then
			analysis.score = analysis.score + 30
			table.insert(analysis.factors, "依赖包文件变更")
			table.insert(analysis.mitigation, "依赖安全扫描")
			table.insert(analysis.rollback, "依赖版本回退")
			break
		end
	end
	
	-- Major version updates
	if diff:match("%+.*%d+%.0%.0") or diff:match("%+.*\".*\": \".*%^%d+%.") then
		analysis.score = analysis.score + 40
		table.insert(analysis.factors, "主版本依赖更新")
		table.insert(analysis.mitigation, "兼容性回归测试")
	end
	
	-- Security-related dependencies
	if diff:match("security") or diff:match("crypto") or diff:match("auth") then
		analysis.score = analysis.score + 35
		table.insert(analysis.factors, "安全相关依赖变更")
		table.insert(analysis.mitigation, "安全漏洞扫描")
	end
	
	-- Lock file changes
	if diff:match("lock") or diff:match("yarn%.lock") or diff:match("package%-lock%.json") then
		analysis.score = analysis.score + 15
		table.insert(analysis.factors, "依赖锁定文件变更")
		table.insert(analysis.mitigation, "依赖一致性验证")
	end
	
	return math.min(analysis.score, 100), analysis
end

-- Analyze security changes
local function analyze_security_changes(git_data)
	local analysis = {
		score = 0,
		factors = {},
		mitigation = {},
		rollback = {}
	}
	
	local diff = git_data.diff:lower()
	
	-- Authentication changes
	if diff:match("auth") or diff:match("login") or diff:match("password") then
		analysis.score = analysis.score + 40
		table.insert(analysis.factors, "认证相关变更")
		table.insert(analysis.mitigation, "认证流程测试")
		table.insert(analysis.rollback, "认证配置回退")
	end
	
	-- Permission/Authorization
	if diff:match("permission") or diff:match("role") or diff:match("access") then
		analysis.score = analysis.score + 35
		table.insert(analysis.factors, "权限控制变更")
		table.insert(analysis.mitigation, "权限矩阵验证")
	end
	
	-- Cryptography
	if diff:match("encrypt") or diff:match("decrypt") or diff:match("hash") or diff:match("crypto") then
		analysis.score = analysis.score + 45
		table.insert(analysis.factors, "加密相关变更")
		table.insert(analysis.mitigation, "加密算法安全性验证")
	end
	
	-- Security headers/config
	if diff:match("cors") or diff:match("csrf") or diff:match("xss") then
		analysis.score = analysis.score + 30
		table.insert(analysis.factors, "安全策略配置变更")
		table.insert(analysis.mitigation, "安全头部配置验证")
	end
	
	-- API keys/secrets
	if diff:match("api[_%-]?key") or diff:match("secret") or diff:match("token") then
		analysis.score = analysis.score + 50
		table.insert(analysis.factors, "密钥或令牌相关变更")
		table.insert(analysis.mitigation, "密钥轮换和访问审计")
	end
	
	return math.min(analysis.score, 100), analysis
end

-- Comprehensive risk assessment
function M.assess_deployment_risk(git_data, cicd_context)
	local risk_assessment = {
		overall_score = 0,
		risk_level = "low",
		category_scores = {},
		detailed_analysis = {},
		recommendations = {
			pre_deployment = {},
			monitoring = {},
			rollback = {},
			communication = {}
		},
		deployment_strategy = "standard"
	}
	
	-- Analyze each risk category
	local categories = {
		breaking_changes = analyze_breaking_changes,
		database_changes = analyze_database_changes,
		config_changes = analyze_config_changes,
		dependency_changes = analyze_dependency_changes,
		security_changes = analyze_security_changes
	}
	
	local total_weighted_score = 0
	local total_weight = 0
	
	for category, analyzer in pairs(categories) do
		local score, analysis = analyzer(git_data)
		local weight = RISK_CATEGORIES[category].weight
		
		risk_assessment.category_scores[category] = score
		risk_assessment.detailed_analysis[category] = analysis
		
		total_weighted_score = total_weighted_score + (score * weight / 100)
		total_weight = total_weight + weight
	end
	
	-- Calculate overall risk score
	risk_assessment.overall_score = math.floor(total_weighted_score / total_weight * 100)
	
	-- Determine risk level
	if risk_assessment.overall_score >= 70 then
		risk_assessment.risk_level = "high"
		risk_assessment.deployment_strategy = "blue_green"
	elseif risk_assessment.overall_score >= 40 then
		risk_assessment.risk_level = "medium"
		risk_assessment.deployment_strategy = "canary"
	else
		risk_assessment.risk_level = "low"
		risk_assessment.deployment_strategy = "standard"
	end
	
	-- Generate recommendations
	M.generate_risk_recommendations(risk_assessment)
	
	return risk_assessment
end

-- Generate risk-based recommendations
function M.generate_risk_recommendations(risk_assessment)
	local level = risk_assessment.risk_level
	local recs = risk_assessment.recommendations
	
	-- Base recommendations for all levels
	table.insert(recs.pre_deployment, "执行完整的测试套件")
	table.insert(recs.monitoring, "监控关键业务指标")
	table.insert(recs.rollback, "准备快速回滚方案")
	
	if level == "high" then
		-- High risk recommendations
		table.insert(recs.pre_deployment, "进行全面的安全审计")
		table.insert(recs.pre_deployment, "在生产镜像环境测试")
		table.insert(recs.pre_deployment, "准备详细的部署计划")
		table.insert(recs.monitoring, "实时监控所有系统指标")
		table.insert(recs.monitoring, "设置低阈值告警")
		table.insert(recs.rollback, "准备多层次回滚策略")
		table.insert(recs.rollback, "准备数据恢复方案")
		table.insert(recs.communication, "通知所有利益相关者")
		table.insert(recs.communication, "准备应急响应团队")
		
		risk_assessment.deployment_strategy = "blue_green"
		
	elseif level == "medium" then
		-- Medium risk recommendations
		table.insert(recs.pre_deployment, "进行集成测试验证")
		table.insert(recs.pre_deployment, "检查配置一致性")
		table.insert(recs.monitoring, "监控核心功能指标")
		table.insert(recs.rollback, "验证回滚流程")
		table.insert(recs.communication, "通知相关技术团队")
		
		risk_assessment.deployment_strategy = "canary"
		
	else
		-- Low risk recommendations
		table.insert(recs.pre_deployment, "基础冒烟测试")
		table.insert(recs.monitoring, "标准监控检查")
		table.insert(recs.communication, "发送部署通知")
	end
	
	-- Category-specific recommendations
	for category, analysis in pairs(risk_assessment.detailed_analysis) do
		for _, mitigation in ipairs(analysis.mitigation) do
			table.insert(recs.pre_deployment, mitigation)
		end
		for _, rollback in ipairs(analysis.rollback) do
			table.insert(recs.rollback, rollback)
		end
	end
end

-- Generate deployment checklist
function M.generate_deployment_checklist(risk_assessment, target_environment)
	local env_config = ENVIRONMENTS[target_environment] or ENVIRONMENTS.production
	local checklist = {
		pre_deployment = {},
		deployment = {},
		post_deployment = {},
		rollback_plan = {}
	}
	
	-- Pre-deployment checklist
	table.insert(checklist.pre_deployment, "✅ 所有测试通过")
	table.insert(checklist.pre_deployment, "✅ 代码审查完成")
	table.insert(checklist.pre_deployment, "✅ 安全扫描通过")
	
	for _, rec in ipairs(risk_assessment.recommendations.pre_deployment) do
		table.insert(checklist.pre_deployment, "☐ " .. rec)
	end
	
	-- Deployment checklist
	table.insert(checklist.deployment, "☐ 数据库备份完成")
	table.insert(checklist.deployment, "☐ 部署窗口确认")
	table.insert(checklist.deployment, "☐ 监控告警已配置")
	
	if risk_assessment.deployment_strategy == "blue_green" then
		table.insert(checklist.deployment, "☐ 蓝绿环境准备就绪")
		table.insert(checklist.deployment, "☐ 流量切换方案确认")
	elseif risk_assessment.deployment_strategy == "canary" then
		table.insert(checklist.deployment, "☐ 金丝雀版本部署")
		table.insert(checklist.deployment, "☐ 流量分配配置")
	end
	
	-- Post-deployment checklist
	table.insert(checklist.post_deployment, "☐ 健康检查通过")
	table.insert(checklist.post_deployment, "☐ 关键功能验证")
	table.insert(checklist.post_deployment, "☐ 性能指标正常")
	
	for _, monitor in ipairs(risk_assessment.recommendations.monitoring) do
		table.insert(checklist.post_deployment, "☐ " .. monitor)
	end
	
	-- Rollback plan
	table.insert(checklist.rollback_plan, "🔄 代码版本回退")
	table.insert(checklist.rollback_plan, "🔄 数据库回滚（如需要）")
	table.insert(checklist.rollback_plan, "🔄 配置恢复")
	
	for _, rollback in ipairs(risk_assessment.recommendations.rollback) do
		table.insert(checklist.rollback_plan, "🔄 " .. rollback)
	end
	
	return checklist
end

-- Environment-specific risk adjustment
function M.adjust_risk_for_environment(risk_assessment, environment)
	local env_config = ENVIRONMENTS[environment] or ENVIRONMENTS.production
	local adjusted_assessment = vim.deepcopy(risk_assessment)
	
	-- Adjust risk based on environment tolerance
	if environment == "development" then
		adjusted_assessment.overall_score = math.floor(adjusted_assessment.overall_score * 0.5)
	elseif environment == "staging" then
		adjusted_assessment.overall_score = math.floor(adjusted_assessment.overall_score * 0.7)
	end
	-- Production keeps original score
	
	-- Re-determine risk level after adjustment
	if adjusted_assessment.overall_score >= 70 then
		adjusted_assessment.risk_level = "high"
	elseif adjusted_assessment.overall_score >= 40 then
		adjusted_assessment.risk_level = "medium"
	else
		adjusted_assessment.risk_level = "low"
	end
	
	return adjusted_assessment
end

-- Risk visualization and reporting
function M.generate_risk_report(risk_assessment, environment)
	local env_assessment = M.adjust_risk_for_environment(risk_assessment, environment or "production")
	
	local report = string.format([[
🎯 部署风险评估报告

🌍 目标环境: %s
📊 综合风险评分: %d/100
⚠️ 风险等级: %s
🚀 推荐部署策略: %s

📋 分类风险评分:
- 💥 破坏性变更: %d/100
- 🗄️ 数据库变更: %d/100  
- ⚙️ 配置变更: %d/100
- 📦 依赖变更: %d/100
- 🔒 安全变更: %d/100

🎯 风险因素:
%s

💡 部署建议:
%s

📋 监控要求:
%s

🔄 回滚准备:
%s

📞 沟通计划:
%s
]], 
		environment or "production",
		env_assessment.overall_score,
		env_assessment.risk_level,
		env_assessment.deployment_strategy,
		env_assessment.category_scores.breaking_changes or 0,
		env_assessment.category_scores.database_changes or 0,
		env_assessment.category_scores.config_changes or 0,
		env_assessment.category_scores.dependency_changes or 0,
		env_assessment.category_scores.security_changes or 0,
		M.format_risk_factors(env_assessment.detailed_analysis),
		table.concat(env_assessment.recommendations.pre_deployment, "\n"),
		table.concat(env_assessment.recommendations.monitoring, "\n"),
		table.concat(env_assessment.recommendations.rollback, "\n"),
		table.concat(env_assessment.recommendations.communication, "\n")
	)
	
	return report
end

-- Helper function to format risk factors
function M.format_risk_factors(detailed_analysis)
	local factors = {}
	
	for category, analysis in pairs(detailed_analysis) do
		if #analysis.factors > 0 then
			table.insert(factors, string.format("%s: %s", category, table.concat(analysis.factors, ", ")))
		end
	end
	
	return #factors > 0 and table.concat(factors, "\n") or "无特殊风险因素"
end

-- Main integration function
function M.analyze_deployment_readiness(git_data, cicd_context, target_environment)
	local risk_assessment = M.assess_deployment_risk(git_data, cicd_context)
	local env_assessment = M.adjust_risk_for_environment(risk_assessment, target_environment or "production")
	local checklist = M.generate_deployment_checklist(env_assessment, target_environment or "production")
	local report = M.generate_risk_report(risk_assessment, target_environment)
	
	return {
		risk_assessment = env_assessment,
		deployment_checklist = checklist,
		risk_report = report,
		deployment_ready = env_assessment.risk_level ~= "high",
		recommended_strategy = env_assessment.deployment_strategy
	}
end

return M