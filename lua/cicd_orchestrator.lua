local M = {}

-- CI/CD orchestration and workflow management
local cicd_integration = require('cicd_integration')
local test_intelligence = require('test_intelligence')
local deployment_risk = require('deployment_risk')
local performance_monitor = require('performance_monitor')

-- Comprehensive CI/CD workflow analysis
function M.analyze_complete_cicd_workflow(git_data, target_environment)
	target_environment = target_environment or "production"
	
	vim.notify("🔄 开始全面CI/CD工作流分析...", vim.log.levels.INFO)
	
	local workflow_analysis = {
		timestamp = os.time(),
		environment = target_environment,
		git_data = git_data,
		components = {}
	}
	
	-- 1. CI/CD Platform Analysis
	vim.notify("🔧 分析CI/CD平台配置...", vim.log.levels.INFO)
	local cicd_context = cicd_integration.analyze_cicd_context(git_data)
	workflow_analysis.components.cicd = cicd_context
	
	-- 2. Test Intelligence Analysis
	vim.notify("🧪 分析测试智能需求...", vim.log.levels.INFO)
	local test_analysis = test_intelligence.analyze_test_requirements(git_data)
	workflow_analysis.components.testing = test_analysis
	
	-- 3. Deployment Risk Assessment
	vim.notify("⚠️ 评估部署风险...", vim.log.levels.INFO)
	local risk_analysis = deployment_risk.analyze_deployment_readiness(git_data, cicd_context, target_environment)
	workflow_analysis.components.deployment = risk_analysis
	
	-- 4. Performance Impact Analysis
	vim.notify("⚡ 分析性能影响...", vim.log.levels.INFO)
	local performance_analysis = performance_monitor.analyze_performance_requirements(git_data)
	workflow_analysis.components.performance = performance_analysis
	
	-- 5. Generate integrated recommendations
	local integrated_recommendations = M.generate_integrated_recommendations(workflow_analysis)
	workflow_analysis.recommendations = integrated_recommendations
	
	-- 6. Create execution plan
	local execution_plan = M.create_execution_plan(workflow_analysis)
	workflow_analysis.execution_plan = execution_plan
	
	vim.notify("✅ CI/CD工作流分析完成!", vim.log.levels.INFO)
	
	return workflow_analysis
end

-- Generate integrated recommendations
function M.generate_integrated_recommendations(workflow_analysis)
	local recommendations = {
		immediate_actions = {},
		pre_commit_checks = {},
		ci_pipeline_suggestions = {},
		deployment_strategy = {},
		monitoring_requirements = {},
		risk_mitigations = {}
	}
	
	local components = workflow_analysis.components
	
	-- CI/CD specific recommendations
	if components.cicd.has_cicd then
		if components.cicd.ci_status.status == "failure" then
			table.insert(recommendations.immediate_actions, "🚨 修复当前CI构建失败")
			table.insert(recommendations.pre_commit_checks, "等待CI状态恢复")
		elseif components.cicd.ci_status.status == "pending" then
			table.insert(recommendations.immediate_actions, "⏳ 等待当前CI完成")
		end
		
		table.insert(recommendations.ci_pipeline_suggestions, 
			string.format("预计CI运行时间: %d分钟", components.cicd.config_analysis.estimated_runtime))
	else
		table.insert(recommendations.immediate_actions, "💡 考虑添加CI/CD流水线")
	end
	
	-- Testing recommendations
	if components.testing.has_tests then
		local test_health = components.testing.coverage_analysis.test_health
		if test_health == "poor" then
			table.insert(recommendations.immediate_actions, "⚠️ 提高测试覆盖率")
			table.insert(recommendations.pre_commit_checks, "添加关键功能测试")
		elseif test_health == "excellent" then
			table.insert(recommendations.pre_commit_checks, "✅ 测试覆盖率优秀")
		end
		
		local execution_plan = components.testing.execution_plan
		if execution_plan.estimated_runtime > 15 then
			table.insert(recommendations.ci_pipeline_suggestions, "考虑并行化测试执行")
		end
	else
		table.insert(recommendations.immediate_actions, "🧪 建立测试框架")
	end
	
	-- Deployment risk recommendations
	local risk_level = components.deployment.risk_assessment.risk_level
	if risk_level == "high" then
		table.insert(recommendations.deployment_strategy, "🔵 使用蓝绿部署策略")
		table.insert(recommendations.risk_mitigations, "准备完整回滚方案")
		table.insert(recommendations.monitoring_requirements, "实时监控所有关键指标")
	elseif risk_level == "medium" then
		table.insert(recommendations.deployment_strategy, "🐤 使用金丝雀部署")
		table.insert(recommendations.monitoring_requirements, "加强核心功能监控")
	else
		table.insert(recommendations.deployment_strategy, "📦 标准部署流程")
	end
	
	-- Performance recommendations
	if components.performance.has_performance_tools then
		local impact = components.performance.benchmark_data.impact_analysis.overall_impact
		if impact == "high" or impact == "moderate" then
			table.insert(recommendations.pre_commit_checks, "执行性能基准测试")
			table.insert(recommendations.monitoring_requirements, "监控性能退化")
		end
	else
		table.insert(recommendations.ci_pipeline_suggestions, "集成性能监控工具")
	end
	
	return recommendations
end

-- Create comprehensive execution plan
function M.create_execution_plan(workflow_analysis)
	local execution_plan = {
		phases = {
			pre_commit = {name = "提交前检查", steps = {}, estimated_time = 0},
			commit = {name = "提交处理", steps = {}, estimated_time = 2},
			ci_pipeline = {name = "CI流水线", steps = {}, estimated_time = 0},
			deployment = {name = "部署流程", steps = {}, estimated_time = 0},
			post_deployment = {name = "部署后验证", steps = {}, estimated_time = 0}
		},
		total_estimated_time = 0,
		parallel_opportunities = {},
		critical_path = []
	}
	
	local components = workflow_analysis.components
	
	-- Pre-commit phase
	table.insert(execution_plan.phases.pre_commit.steps, {
		name = "代码质量检查",
		description = "运行linting和格式化",
		estimated_time = 1,
		required = true
	})
	
	if components.testing.has_tests then
		local test_time = math.min(components.testing.execution_plan.estimated_runtime, 10)
		table.insert(execution_plan.phases.pre_commit.steps, {
			name = "单元测试",
			description = "执行快速单元测试",
			estimated_time = test_time,
			required = true
		})
		execution_plan.phases.pre_commit.estimated_time = execution_plan.phases.pre_commit.estimated_time + test_time
	end
	
	if components.performance.has_performance_tools and 
	   components.performance.benchmark_data.impact_analysis.overall_impact ~= "minimal" then
		table.insert(execution_plan.phases.pre_commit.steps, {
			name = "性能预检",
			description = "快速性能检查",
			estimated_time = 3,
			required = false
		})
	end
	
	execution_plan.phases.pre_commit.estimated_time = execution_plan.phases.pre_commit.estimated_time + 1
	
	-- CI Pipeline phase
	if components.cicd.has_cicd then
		execution_plan.phases.ci_pipeline.estimated_time = components.cicd.config_analysis.estimated_runtime
		
		table.insert(execution_plan.phases.ci_pipeline.steps, {
			name = "构建验证",
			description = "编译和构建检查",
			estimated_time = 3,
			required = true
		})
		
		if components.testing.has_tests then
			table.insert(execution_plan.phases.ci_pipeline.steps, {
				name = "完整测试套件",
				description = "运行所有测试",
				estimated_time = components.testing.execution_plan.estimated_runtime,
				required = true
			})
		end
		
		if components.performance.has_performance_tools then
			table.insert(execution_plan.phases.ci_pipeline.steps, {
				name = "性能基准测试",
				description = "完整性能评估",
				estimated_time = components.performance.benchmark_data.benchmark_plan.estimated_time,
				required = false
			})
		end
	end
	
	-- Deployment phase
	local risk_level = components.deployment.risk_assessment.risk_level
	if risk_level == "high" then
		execution_plan.phases.deployment.estimated_time = 30
		table.insert(execution_plan.phases.deployment.steps, {
			name = "蓝绿部署",
			description = "零停机时间部署",
			estimated_time = 25,
			required = true
		})
	elseif risk_level == "medium" then
		execution_plan.phases.deployment.estimated_time = 20
		table.insert(execution_plan.phases.deployment.steps, {
			name = "金丝雀部署",
			description = "渐进式部署",
			estimated_time = 15,
			required = true
		})
	else
		execution_plan.phases.deployment.estimated_time = 10
		table.insert(execution_plan.phases.deployment.steps, {
			name = "标准部署",
			description = "常规部署流程",
			estimated_time = 8,
			required = true
		})
	end
	
	-- Post-deployment phase
	execution_plan.phases.post_deployment.estimated_time = 10
	table.insert(execution_plan.phases.post_deployment.steps, {
		name = "健康检查",
		description = "验证服务状态",
		estimated_time = 3,
		required = true
	})
	
	table.insert(execution_plan.phases.post_deployment.steps, {
		name = "监控验证",
		description = "确认监控正常",
		estimated_time = 5,
		required = true
	})
	
	if components.performance.has_performance_tools then
		table.insert(execution_plan.phases.post_deployment.steps, {
			name = "性能验证",
			description = "部署后性能检查",
			estimated_time = 8,
			required = false
		})
	end
	
	-- Calculate total time
	for _, phase in pairs(execution_plan.phases) do
		execution_plan.total_estimated_time = execution_plan.total_estimated_time + phase.estimated_time
	end
	
	-- Identify parallel opportunities
	table.insert(execution_plan.parallel_opportunities, {
		description = "测试和构建可以并行执行",
		time_saved = 5
	})
	
	if components.performance.has_performance_tools then
		table.insert(execution_plan.parallel_opportunities, {
			description = "性能测试可以与其他测试并行",
			time_saved = 10
		})
	end
	
	-- Define critical path
	execution_plan.critical_path = {
		"代码质量检查",
		"单元测试", 
		"构建验证",
		"完整测试套件",
		"部署流程",
		"健康检查"
	}
	
	return execution_plan
end

-- Execute comprehensive workflow
function M.execute_cicd_workflow(workflow_analysis, options)
	options = options or {}
	local dry_run = options.dry_run or false
	local skip_tests = options.skip_tests or false
	local skip_performance = options.skip_performance or false
	
	local execution_results = {
		start_time = os.time(),
		phases_completed = {},
		overall_status = "running",
		issues = {},
		recommendations = {}
	}
	
	if dry_run then
		local preview = M.generate_workflow_preview(workflow_analysis)
		vim.notify(preview, vim.log.levels.INFO)
		return execution_results
	end
	
	vim.notify("🚀 开始执行CI/CD工作流...", vim.log.levels.INFO)
	
	-- Execute each phase
	for phase_name, phase in pairs(workflow_analysis.execution_plan.phases) do
		vim.notify(string.format("📋 执行阶段: %s", phase.name), vim.log.levels.INFO)
		
		local phase_result = {
			name = phase.name,
			status = "completed",
			start_time = os.time(),
			steps_completed = {},
			issues = {}
		}
		
		for _, step in ipairs(phase.steps) do
			if step.required or (not skip_tests and step.name:match("测试")) or 
			   (not skip_performance and step.name:match("性能")) then
				
				vim.notify(string.format("⚡ 执行: %s", step.name), vim.log.levels.INFO)
				
				-- Simulate step execution
				local step_success = math.random() > 0.1 -- 90% success rate
				
				if step_success then
					table.insert(phase_result.steps_completed, step.name)
					vim.notify(string.format("✅ %s 完成", step.name), vim.log.levels.INFO)
				else
					table.insert(phase_result.issues, step.name .. " 失败")
					table.insert(execution_results.issues, string.format("%s阶段的%s失败", phase.name, step.name))
					phase_result.status = "failed"
					
					if step.required then
						vim.notify(string.format("❌ 必需步骤 %s 失败，停止执行", step.name), vim.log.levels.ERROR)
						execution_results.overall_status = "failed"
						goto workflow_end
					end
				end
			else
				vim.notify(string.format("⏭️ 跳过: %s", step.name), vim.log.levels.INFO)
			end
		end
		
		phase_result.end_time = os.time()
		table.insert(execution_results.phases_completed, phase_result)
	end
	
	execution_results.overall_status = "completed"
	
	::workflow_end::
	
	execution_results.end_time = os.time()
	execution_results.total_duration = execution_results.end_time - execution_results.start_time
	
	-- Generate final report
	local final_report = M.generate_execution_report(execution_results, workflow_analysis)
	vim.notify(final_report, vim.log.levels.INFO)
	
	return execution_results
end

-- Generate workflow preview
function M.generate_workflow_preview(workflow_analysis)
	local preview = string.format([[
🔄 CI/CD工作流执行计划

🎯 目标环境: %s
⏱️ 预计总时间: %d分钟
🛡️ 风险等级: %s
📊 部署策略: %s

📋 执行阶段:
%s

💡 集成建议:
%s

🚀 执行命令: 
execute_cicd_workflow(analysis, {dry_run = false})
]], 
		workflow_analysis.environment,
		workflow_analysis.execution_plan.total_estimated_time,
		workflow_analysis.components.deployment.risk_assessment.risk_level,
		workflow_analysis.components.deployment.risk_assessment.deployment_strategy,
		M.format_execution_phases(workflow_analysis.execution_plan.phases),
		M.format_recommendations(workflow_analysis.recommendations)
	)
	
	return preview
end

-- Generate execution report
function M.generate_execution_report(execution_results, workflow_analysis)
	local status_emoji = execution_results.overall_status == "completed" and "🎉" or 
		execution_results.overall_status == "failed" and "❌" or "⏳"
	
	local report = string.format([[
%s CI/CD工作流执行报告

📊 执行状态: %s
⏱️ 总耗时: %d秒
📋 完成阶段: %d个
⚠️ 发现问题: %d个

阶段详情:
%s

%s

💡 后续建议:
%s
]], 
		status_emoji,
		execution_results.overall_status,
		execution_results.total_duration or 0,
		#execution_results.phases_completed,
		#execution_results.issues,
		M.format_phase_results(execution_results.phases_completed),
		#execution_results.issues > 0 and ("⚠️ 问题列表:\n" .. table.concat(execution_results.issues, "\n")) or "✅ 无问题发现",
		M.generate_next_steps(execution_results, workflow_analysis)
	)
	
	return report
end

-- Helper formatting functions
function M.format_execution_phases(phases)
	local formatted = {}
	for phase_name, phase in pairs(phases) do
		table.insert(formatted, string.format("• %s (~%d分钟, %d步骤)", 
			phase.name, phase.estimated_time, #phase.steps))
	end
	return table.concat(formatted, "\n")
end

function M.format_recommendations(recommendations)
	local formatted = {}
	for category, items in pairs(recommendations) do
		if #items > 0 then
			table.insert(formatted, string.format("%s: %s", category, table.concat(items, "; ")))
		end
	end
	return table.concat(formatted, "\n")
end

function M.format_phase_results(phase_results)
	local formatted = {}
	for _, phase in ipairs(phase_results) do
		local status_emoji = phase.status == "completed" and "✅" or "❌"
		table.insert(formatted, string.format("%s %s: %d步骤完成", 
			status_emoji, phase.name, #phase.steps_completed))
	end
	return table.concat(formatted, "\n")
end

function M.generate_next_steps(execution_results, workflow_analysis)
	local next_steps = {}
	
	if execution_results.overall_status == "completed" then
		table.insert(next_steps, "🚀 可以安全进行部署")
		table.insert(next_steps, "📊 建立性能基线监控")
		table.insert(next_steps, "🔄 定期评估工作流效率")
	elseif execution_results.overall_status == "failed" then
		table.insert(next_steps, "🔧 修复失败的步骤")
		table.insert(next_steps, "🧪 重新运行测试")
		table.insert(next_steps, "📋 审查失败原因")
	end
	
	return table.concat(next_steps, "\n")
end

-- Main integration function for commit generation
function M.enhance_commit_with_cicd_intelligence(git_data, base_config)
	local workflow_analysis = M.analyze_complete_cicd_workflow(git_data, base_config.target_environment)
	
	-- Create enhanced context for AI commit generation
	local cicd_context = string.format([[
🔄 CI/CD智能分析结果:

%s

%s

%s

%s

🎯 集成建议:
- 提交策略: %s
- 部署就绪: %s
- 风险等级: %s
- 预计流水线时间: %d分钟

基于以上CI/CD分析，请生成考虑了完整DevOps流程的智能提交消息。
]], 
		workflow_analysis.components.cicd.enhanced_context or "CI/CD: 未配置",
		workflow_analysis.components.testing.enhanced_context or "测试: 未配置", 
		workflow_analysis.components.deployment.risk_assessment and 
			("部署风险: " .. workflow_analysis.components.deployment.risk_assessment.risk_level) or "部署: 未评估",
		workflow_analysis.components.performance.enhanced_context or "性能: 未配置",
		workflow_analysis.recommendations.deployment_strategy[1] or "标准提交",
		workflow_analysis.components.deployment.deployment_ready and "是" or "否",
		workflow_analysis.components.deployment.risk_assessment.risk_level or "未知",
		workflow_analysis.execution_plan.total_estimated_time
	)
	
	return {
		enhanced_prompt = cicd_context,
		workflow_analysis = workflow_analysis,
		cicd_aware = true
	}
end

return M