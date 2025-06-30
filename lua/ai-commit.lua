local M = {}

M.config = {
  -- Legacy single provider support (still supported)
  openrouter_api_key = nil,
  model = "qwen/qwen-2.5-72b-instruct:free",
  
  -- Multi-provider AI configuration
  primary_provider = "deepseek", -- Default to DeepSeek for best coding experience
  fallback_providers = {"openrouter", "openai"}, -- Fallback order
  selection_strategy = "balanced", -- cost_optimized, performance_optimized, quality_optimized, balanced, primary_fallback
  auto_fallback = true, -- Enable automatic fallback on provider failure
  
  -- API keys for different providers
  deepseek_api_key = nil, -- Set DEEPSEEK_API_KEY environment variable
  openai_api_key = nil, -- Set OPENAI_API_KEY environment variable  
  anthropic_api_key = nil, -- Set ANTHROPIC_API_KEY environment variable
  google_api_key = nil, -- Set GOOGLE_API_KEY environment variable
  
  -- Other settings
  auto_push = false,
  language = "zh", -- Default language for commit messages: "zh" (Chinese), "en" (English), "ja" (Japanese), "ko" (Korean), etc.
  commit_template = nil, -- Custom commit message template (optional)
  timeout = 30000, -- Request timeout in milliseconds
  retry_attempts = 2, -- Number of retry attempts
}

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
end

M.generate_commit = function()
  require("commit_generator").generate_commit(M.config)
end

-- Enhanced user commands
vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

vim.api.nvim_create_user_command("AICommitInteractive", function()
  if not pcall(require, 'telescope') then
    vim.notify("Telescope is required for interactive mode", vim.log.levels.ERROR)
    return
  end
  require('telescope').extensions.ai_commit.ai_commits()
end, {})

vim.api.nvim_create_user_command("AICommitAnalyze", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local workflow = require("git_workflow")
    workflow.interactive_pre_commit_workflow(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitTeam", function()
  require("team_standards").setup_team_standards()
end, {})

vim.api.nvim_create_user_command("AICommitStats", function()
  require("team_standards").generate_analytics_report()
end, {})

-- Advanced feature commands
vim.api.nvim_create_user_command("AICommitRefine", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("commit_refinement").refine_commit_message(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitTranslate", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    vim.ui.input({prompt = "输入要翻译的提交消息: "}, function(message)
      if message then
        require("commit_translation").translate_commit_message(message, git_data)
      end
    end)
  end
end, {})

vim.api.nvim_create_user_command("AICommitSplit", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("commit_splitting").interactive_commit_splitting(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitChangelog", function()
  require("changelog_generator").generate_interactive_changelog()
end, {})

vim.api.nvim_create_user_command("AICommitRelease", function()
  vim.ui.input({prompt = "输入版本号: "}, function(version)
    if version then
      require("changelog_generator").generate_release_notes(version, false)
    end
  end)
end, {})

vim.api.nvim_create_user_command("AICommitLearn", function()
  require("pattern_learning").learn_from_project_history()
end, {})

vim.api.nvim_create_user_command("AICommitPatterns", function()
  require("pattern_learning").manage_learned_patterns()
end, {})

vim.api.nvim_create_user_command("AICommitVoice", function()
  require("advanced_features").voice_to_commit()
end, {})

vim.api.nvim_create_user_command("AICommitEmoji", function()
  require("advanced_features").add_emoji_to_commit()
end, {})

vim.api.nvim_create_user_command("AICommitImpact", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("advanced_features").analyze_change_impact(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitAchievements", function()
  require("advanced_features").show_achievement_dashboard()
end, {})

vim.api.nvim_create_user_command("AICommitScore", function()
  vim.ui.input({prompt = "输入提交消息进行评分: "}, function(message)
    if message then
      local result = require("advanced_features").validate_and_score_commit(message)
      local report = string.format([[
📊 提交消息质量评分

消息: %s

评分: %d/%d (%d%%) - %s

反馈:
%s
]], message, result.score, result.max_score, result.percentage, result.grade, table.concat(result.feedback, "\n"))
      vim.notify(report, vim.log.levels.INFO)
    end
  end)
end, {})

vim.api.nvim_create_user_command("AICommitVersionSuggest", function()
  require("changelog_generator").suggest_next_version()
end, {})

vim.api.nvim_create_user_command("AICommitHistory", function()
  require("commit_refinement").show_refinement_history()
end, {})

-- CI/CD Deep Integration Commands
vim.api.nvim_create_user_command("AICommitCICD", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    vim.ui.select({
      "📊 完整CI/CD工作流分析",
      "🔧 CI/CD平台状态检查", 
      "🧪 智能测试计划生成",
      "⚠️ 部署风险评估",
      "⚡ 性能影响分析",
      "🚀 执行CI/CD工作流"
    }, {
      prompt = "选择CI/CD操作:",
    }, function(choice)
      if choice and choice:match("📊") then
        local orchestrator = require("cicd_orchestrator")
        local analysis = orchestrator.analyze_complete_cicd_workflow(git_data)
        local preview = orchestrator.generate_workflow_preview(analysis)
        vim.notify(preview, vim.log.levels.INFO)
      elseif choice and choice:match("🔧") then
        local cicd_integration = require("cicd_integration")
        local context = cicd_integration.analyze_cicd_context(git_data)
        vim.notify(context.enhanced_context, vim.log.levels.INFO)
      elseif choice and choice:match("🧪") then
        local test_intelligence = require("test_intelligence")
        local analysis = test_intelligence.analyze_test_requirements(git_data)
        vim.notify(analysis.enhanced_context, vim.log.levels.INFO)
        if analysis.has_tests then
          vim.ui.select({"预览测试计划", "执行测试计划"}, {
            prompt = "测试操作:",
          }, function(test_choice)
            if test_choice and test_choice:match("预览") then
              test_intelligence.execute_test_plan(analysis.execution_plan, {dry_run = true})
            elseif test_choice and test_choice:match("执行") then
              test_intelligence.execute_test_plan(analysis.execution_plan, {dry_run = false})
            end
          end)
        end
      elseif choice and choice:match("⚠️") then
        local deployment_risk = require("deployment_risk")
        vim.ui.input({prompt = "目标环境 (development/staging/production): ", default = "production"}, function(env)
          if env then
            local analysis = deployment_risk.analyze_deployment_readiness(git_data, {}, env)
            local report = deployment_risk.generate_risk_report(analysis.risk_assessment, env)
            vim.notify(report, vim.log.levels.INFO)
          end
        end)
      elseif choice and choice:match("⚡") then
        local performance_monitor = require("performance_monitor")
        local analysis = performance_monitor.analyze_performance_requirements(git_data)
        vim.notify(analysis.enhanced_context, vim.log.levels.INFO)
        if analysis.has_performance_tools then
          vim.ui.select({"预览基准测试", "执行基准测试"}, {
            prompt = "性能操作:",
          }, function(perf_choice)
            if perf_choice and perf_choice:match("预览") then
              performance_monitor.execute_benchmark_plan(analysis.benchmark_data, {dry_run = true})
            elseif perf_choice and perf_choice:match("执行") then
              performance_monitor.execute_benchmark_plan(analysis.benchmark_data, {dry_run = false})
            end
          end)
        end
      elseif choice and choice:match("🚀") then
        local orchestrator = require("cicd_orchestrator")
        local analysis = orchestrator.analyze_complete_cicd_workflow(git_data)
        vim.ui.select({"预览工作流", "执行工作流", "执行工作流(跳过测试)", "执行工作流(跳过性能测试)"}, {
          prompt = "工作流执行选项:",
        }, function(exec_choice)
          if exec_choice and exec_choice:match("预览") then
            orchestrator.execute_cicd_workflow(analysis, {dry_run = true})
          elseif exec_choice and exec_choice:match("跳过测试") then
            orchestrator.execute_cicd_workflow(analysis, {skip_tests = true})
          elseif exec_choice and exec_choice:match("跳过性能") then
            orchestrator.execute_cicd_workflow(analysis, {skip_performance = true})
          elseif exec_choice and exec_choice:match("执行工作流") and not exec_choice:match("跳过") then
            orchestrator.execute_cicd_workflow(analysis, {})
          end
        end)
      end
    end)
  end
end, {})

vim.api.nvim_create_user_command("AICommitPipeline", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local cicd_integration = require("cicd_integration")
    local context = cicd_integration.analyze_cicd_context(git_data)
    if context.has_cicd then
      local report = string.format([[
🔧 CI/CD流水线状态报告

平台: %s
状态: %s
消息: %s
最后运行: %s

配置分析:
- 总作业数: %d
- 预计运行时间: %d分钟

建议:
%s
]], 
        table.concat(vim.tbl_map(function(p) return p.name end, context.platforms), ", "),
        context.ci_status.status,
        context.ci_status.message,
        context.ci_status.last_run or "未知",
        context.config_analysis.total_jobs,
        context.config_analysis.estimated_runtime,
        context.recommendations.commit_strategy
      )
      vim.notify(report, vim.log.levels.INFO)
    else
      vim.notify("未检测到CI/CD配置", vim.log.levels.WARN)
    end
  end
end, {})

vim.api.nvim_create_user_command("AICommitRisk", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    vim.ui.input({prompt = "评估环境 (dev/staging/prod): ", default = "prod"}, function(env_input)
      local environment = env_input == "dev" and "development" or 
        env_input == "staging" and "staging" or "production"
      
      local deployment_risk = require("deployment_risk")
      local analysis = deployment_risk.analyze_deployment_readiness(git_data, {}, environment)
      
      -- Show risk assessment
      vim.notify(analysis.risk_report, vim.log.levels.INFO)
      
      -- Show deployment checklist
      vim.ui.select({"查看部署检查清单", "生成部署计划", "取消"}, {
        prompt = "下一步操作:",
      }, function(action)
        if action and action:match("检查清单") then
          local checklist_text = string.format([[
📋 %s环境部署检查清单

预部署:
%s

部署过程:
%s

部署后:
%s

回滚计划:
%s
]], 
            environment,
            table.concat(analysis.deployment_checklist.pre_deployment, "\n"),
            table.concat(analysis.deployment_checklist.deployment, "\n"),
            table.concat(analysis.deployment_checklist.post_deployment, "\n"),
            table.concat(analysis.deployment_checklist.rollback_plan, "\n")
          )
          vim.notify(checklist_text, vim.log.levels.INFO)
        elseif action and action:match("部署计划") then
          local filename = string.format("deployment-plan-%s-%s.md", environment, os.date("%Y%m%d-%H%M%S"))
          local plan_content = analysis.risk_report .. "\n\n" .. "检查清单:\n" .. vim.inspect(analysis.deployment_checklist)
          vim.fn.writefile(vim.split(plan_content, "\n"), filename)
          vim.notify("部署计划已保存到: " .. filename, vim.log.levels.INFO)
        end
      end)
    end)
  end
end, {})

vim.api.nvim_create_user_command("AICommitTest", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local test_intelligence = require("test_intelligence")
    local analysis = test_intelligence.analyze_test_requirements(git_data)
    
    if analysis.has_tests then
      vim.ui.select({
        "📊 查看测试分析报告",
        "📋 查看测试执行计划", 
        "🧪 执行智能测试",
        "📈 查看测试覆盖率",
        "💡 获取测试建议"
      }, {
        prompt = "智能测试操作:",
      }, function(choice)
        if choice and choice:match("📊") then
          vim.notify(analysis.enhanced_context, vim.log.levels.INFO)
        elseif choice and choice:match("📋") then
          local plan_summary = string.format([[
🧪 智能测试执行计划

立即测试: %d个
回归测试: %d个
集成测试: %d个
端到端测试: %d个
性能测试: %d个

预计总时间: %d分钟

测试框架: %s
]], 
            #analysis.execution_plan.immediate_tests,
            #analysis.execution_plan.regression_tests,
            #analysis.execution_plan.integration_tests,
            #analysis.execution_plan.e2e_tests,
            #analysis.execution_plan.performance_tests,
            analysis.execution_plan.estimated_runtime,
            table.concat(test_intelligence.get_framework_names(analysis.frameworks), ", ")
          )
          vim.notify(plan_summary, vim.log.levels.INFO)
        elseif choice and choice:match("🧪") then
          test_intelligence.execute_test_plan(analysis.execution_plan, {dry_run = false})
        elseif choice and choice:match("📈") then
          local coverage_report = string.format([[
📈 测试覆盖率分析

测试健康度: %s
已覆盖文件: %d个
未覆盖文件: %d个

缺失测试:
%s
]], 
            analysis.coverage_analysis.test_health,
            #analysis.coverage_analysis.covered_files,
            #analysis.coverage_analysis.uncovered_files,
            table.concat(vim.tbl_map(function(missing) 
              return string.format("- %s (优先级: %s)", missing.file, missing.priority)
            end, analysis.coverage_analysis.missing_tests), "\n")
          )
          vim.notify(coverage_report, vim.log.levels.INFO)
        elseif choice and choice:match("💡") then
          vim.notify(test_intelligence.generate_test_suggestions(analysis.coverage_analysis), vim.log.levels.INFO)
        end
      end)
    else
      vim.notify("未检测到测试框架，建议添加测试支持", vim.log.levels.WARN)
    end
  end
end, {})

vim.api.nvim_create_user_command("AICommitPerf", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local performance_monitor = require("performance_monitor")
    local analysis = performance_monitor.analyze_performance_requirements(git_data)
    
    if analysis.has_performance_tools then
      vim.ui.select({
        "📊 查看性能影响分析",
        "🚀 执行性能基准测试",
        "📈 生成性能报告",
        "💡 获取优化建议"
      }, {
        prompt = "性能监控操作:",
      }, function(choice)
        if choice and choice:match("📊") then
          vim.notify(analysis.enhanced_context, vim.log.levels.INFO)
        elseif choice and choice:match("🚀") then
          vim.ui.select({"预览测试计划", "执行完整测试", "执行快速测试"}, {
            prompt = "基准测试选项:",
          }, function(test_option)
            if test_option and test_option:match("预览") then
              performance_monitor.execute_benchmark_plan(analysis.benchmark_data, {dry_run = true})
            elseif test_option and test_option:match("完整") then
              performance_monitor.execute_benchmark_plan(analysis.benchmark_data, {dry_run = false})
            elseif test_option and test_option:match("快速") then
              -- Run only high priority tests
              local quick_plan = vim.deepcopy(analysis.benchmark_data)
              quick_plan.benchmark_plan.test_categories = vim.tbl_filter(function(cat)
                return cat.priority == "high" or cat.priority == "critical"
              end, quick_plan.benchmark_plan.test_categories)
              performance_monitor.execute_benchmark_plan(quick_plan, {dry_run = false})
            end
          end)
        elseif choice and choice:match("📈") then
          local filename = "performance-analysis-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
          local content = "# 性能影响分析报告\n\n" .. analysis.enhanced_context
          vim.fn.writefile(vim.split(content, "\n"), filename)
          vim.notify("性能报告已保存到: " .. filename, vim.log.levels.INFO)
        elseif choice and choice:match("💡") then
          local suggestions = table.concat(analysis.benchmark_data.impact_analysis.optimization_opportunities, "\n")
          vim.notify("性能优化建议:\n" .. suggestions, vim.log.levels.INFO)
        end
      end)
    else
      vim.notify("未检测到性能监控工具，建议添加性能测试支持", vim.log.levels.WARN)
    end
  end
end, {})

-- 🤖 Multi-Provider AI Management Commands
vim.api.nvim_create_user_command("AIProviders", function()
  local ai_request_manager = require("ai_request_manager")
  local status_report = ai_request_manager.generate_status_report(M.config)
  vim.notify(status_report, vim.log.levels.INFO)
end, {desc = "Show AI providers status and configuration"})

vim.api.nvim_create_user_command("AIProvidersHealth", function()
  local ai_request_manager = require("ai_request_manager")
  vim.notify("🔍 开始AI提供商健康检查...", vim.log.levels.INFO)
  ai_request_manager.health_check(M.config)
end, {desc = "Perform health check on all AI providers"})

vim.api.nvim_create_user_command("AIProvidersConfig", function()
  local ai_providers = require("ai_providers")
  local report = ai_providers.generate_provider_report(M.config)
  
  local config_report = string.format([[
🤖 AI提供商配置报告

⏰ 生成时间: %s

📋 可用提供商 (%d个):
%s

💡 推荐配置:
%s

🔧 快速配置命令:
-- 在你的Neovim配置中添加:
require("ai-commit").setup({
  primary_provider = "deepseek",
  deepseek_api_key = "your-deepseek-key", -- 或设置 DEEPSEEK_API_KEY 环境变量
  fallback_providers = {"openrouter", "openai"},
  selection_strategy = "balanced"
})
]], 
    os.date("%Y-%m-%d %H:%M:%S"),
    #report.available_providers,
    table.concat(vim.tbl_map(function(p) 
      return string.format("- %s: %s (%d个模型)", p.display_name, p.status, p.models_count)
    end, report.available_providers), "\n"),
    table.concat(report.recommended_setup, "\n")
  )
  
  vim.notify(config_report, vim.log.levels.INFO)
end, {desc = "Show AI providers configuration guide"})

vim.api.nvim_create_user_command("AIProviderSelect", function()
  local ai_providers = require("ai_providers")
  local available_providers = {}
  
  for provider_name, provider_config in pairs(ai_providers.PROVIDERS) do
    local api_key, error = ai_providers.validate_api_key(provider_name, M.config)
    if api_key then
      table.insert(available_providers, {
        name = provider_name,
        display = string.format("%s (%s)", provider_config.name, provider_name)
      })
    end
  end
  
  if #available_providers == 0 then
    vim.notify("没有配置可用的AI提供商API密钥", vim.log.levels.ERROR)
    return
  end
  
  vim.ui.select(vim.tbl_map(function(p) return p.display end, available_providers), {
    prompt = "选择主要AI提供商:",
  }, function(choice)
    if choice then
      for _, provider in ipairs(available_providers) do
        if provider.display == choice then
          M.config.primary_provider = provider.name
          vim.notify(string.format("✅ 主要AI提供商已设置为: %s", choice), vim.log.levels.INFO)
          break
        end
      end
    end
  end)
end, {desc = "Interactive provider selection"})

vim.api.nvim_create_user_command("AIModelSelect", function()
  local ai_providers = require("ai_providers")
  local provider_name = M.config.primary_provider
  local models = ai_providers.get_provider_models(provider_name)
  
  if #models == 0 then
    vim.notify("当前提供商没有可用模型", vim.log.levels.ERROR)
    return
  end
  
  local model_options = vim.tbl_map(function(model)
    return string.format("%s (成本: $%.2f, 速度: %s, 质量: %s)", 
      model.name, model.cost, model.speed, model.quality)
  end, models)
  
  vim.ui.select(model_options, {
    prompt = string.format("选择 %s 的模型:", provider_name),
  }, function(choice)
    if choice then
      local selected_model = models[vim.tbl_contains(model_options, choice) and 
        vim.fn.index(model_options, choice) + 1 or 1]
      M.config.model = selected_model.name
      vim.notify(string.format("✅ 模型已设置为: %s", selected_model.name), vim.log.levels.INFO)
    end
  end)
end, {desc = "Interactive model selection"})

-- Enhanced commit generation with multi-provider support
M.generate_commit = function()
  -- Initialize AI providers system
  local ai_request_manager = require("ai_request_manager")
  ai_request_manager.initialize()
  
  -- Use the new multi-provider commit generator
  require("commit_generator").generate_commit_multi_provider(M.config)
end

-- 🧠 Intelligent Code Review Commands
vim.api.nvim_create_user_command("AICodeReview", function()
  require("intelligent_code_review").interactive_code_review()
end, {desc = "Interactive intelligent code review"})

vim.api.nvim_create_user_command("AISecurityScan", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local security_scanner = require("security_scanner")
    local scan_results = security_scanner.quick_security_scan(git_data)
    
    if scan_results.error then
      vim.notify("安全扫描失败: " .. scan_results.error, vim.log.levels.ERROR)
    else
      vim.notify(scan_results.scan_summary, vim.log.levels.INFO)
    end
  else
    vim.notify("没有找到staged变更", vim.log.levels.ERROR)
  end
end, {desc = "Security vulnerability scan"})

vim.api.nvim_create_user_command("AIPerformanceAudit", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local performance_analyzer = require("performance_analyzer")
    local perf_results = performance_analyzer.quick_performance_scan(git_data)
    
    if perf_results.error then
      vim.notify("性能分析失败: " .. perf_results.error, vim.log.levels.ERROR)
    else
      vim.notify(perf_results.performance_report, vim.log.levels.INFO)
    end
  else
    vim.notify("没有找到staged变更", vim.log.levels.ERROR)
  end
end, {desc = "Performance analysis and optimization suggestions"})

vim.api.nvim_create_user_command("AICodeSmells", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local code_review_engine = require("code_review_engine")
    local analysis_results = code_review_engine.analyze_changed_files(git_data)
    
    if analysis_results.error then
      vim.notify("代码分析失败: " .. analysis_results.error, vim.log.levels.ERROR)
    else
      local report = code_review_engine.generate_review_report(analysis_results)
      vim.notify(report, vim.log.levels.INFO)
    end
  else
    vim.notify("没有找到staged变更", vim.log.levels.ERROR)
  end
end, {desc = "Code quality analysis and refactoring suggestions"})

vim.api.nvim_create_user_command("AIReviewMode", function()
  vim.ui.select({
    "🚀 快速模式 - 基本质量检查",
    "🔍 全面模式 - 质量+安全+性能",
    "🔒 安全模式 - 专注安全扫描",
    "⚡ 性能模式 - 专注性能优化",
    "🧠 AI模式 - 深度AI分析"
  }, {
    prompt = "选择代码审查模式:",
  }, function(choice)
    if choice then
      local intelligent_code_review = require("intelligent_code_review")
      local mode_map = {
        ["🚀"] = "quick",
        ["🔍"] = "comprehensive",
        ["🔒"] = "security_focused", 
        ["⚡"] = "performance_focused",
        ["🧠"] = "ai_powered"
      }
      
      for icon, mode in pairs(mode_map) do
        if choice:match(icon) then
          M.config.code_review_mode = mode
          vim.notify(string.format("✅ 代码审查模式设置为: %s", choice), vim.log.levels.INFO)
          break
        end
      end
    end
  end)
end, {desc = "Configure code review mode"})

vim.api.nvim_create_user_command("AIReviewSettings", function()
  local intelligent_code_review = require("intelligent_code_review")
  
  vim.ui.select({
    "⚙️ 查看当前配置",
    "🔧 启用/禁用自动审查",
    "🎯 设置严重程度阈值",
    "📁 配置排除文件",
    "🤖 配置AI提供商偏好"
  }, {
    prompt = "代码审查设置:",
  }, function(choice)
    if choice and choice:match("⚙️") then
      local config_report = string.format([[
🧠 智能代码审查配置

📋 当前设置:
- 审查模式: %s
- 自动审查: %s
- AI提供商: %s
- 最大文件数: %d

🚨 阻塞提交: %s
⚠️ 警告级别: %s
ℹ️ 信息级别: %s

📁 排除模式: %s
]], 
        M.config.code_review_mode or "comprehensive",
        M.config.auto_review_on_commit and "启用" or "禁用",
        M.config.primary_provider or "deepseek",
        intelligent_code_review.default_config.max_files_per_review,
        table.concat(intelligent_code_review.default_config.severity_thresholds.block_commit, ", "),
        table.concat(intelligent_code_review.default_config.severity_thresholds.warn_commit, ", "),
        table.concat(intelligent_code_review.default_config.severity_thresholds.show_info, ", "),
        table.concat(intelligent_code_review.default_config.exclude_patterns, ", ")
      )
      vim.notify(config_report, vim.log.levels.INFO)
      
    elseif choice and choice:match("🔧") then
      vim.ui.select({"启用自动审查", "禁用自动审查"}, {
        prompt = "自动审查设置:",
      }, function(auto_choice)
        if auto_choice then
          M.config.auto_review_on_commit = auto_choice:match("启用")
          vim.notify(string.format("✅ 自动审查已%s", auto_choice:match("启用") and "启用" or "禁用"), 
            vim.log.levels.INFO)
        end
      end)
    end
  end)
end, {desc = "Configure code review settings"})

vim.api.nvim_create_user_command("AIReviewReport", function()
  vim.ui.input({prompt = "输入报告文件名 (可选): "}, function(filename)
    local git_data = require("commit_generator").collect_git_data()
    if git_data then
      local intelligent_code_review = require("intelligent_code_review")
      local review_results = intelligent_code_review.review_git_changes(git_data)
      
      if filename and filename ~= "" then
        intelligent_code_review.generate_full_report(review_results)
      else
        intelligent_code_review.display_review_results(review_results)
      end
    else
      vim.notify("没有找到staged变更", vim.log.levels.ERROR)
    end
  end)
end, {desc = "Generate comprehensive code review report"})

return M
