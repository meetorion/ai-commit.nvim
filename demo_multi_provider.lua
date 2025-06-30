#!/usr/bin/env lua

-- 多提供商AI演示脚本
-- 用于测试和演示ai-commit.nvim的多提供商功能

print("🤖 ai-commit.nvim 多提供商演示")
print("=" .. string.rep("=", 50))

-- 模拟配置
local demo_config = {
  -- DeepSeek (推荐)
  primary_provider = "deepseek",
  deepseek_api_key = "sk-xxx...xxx", -- 请替换为真实API密钥
  
  -- 备用提供商
  fallback_providers = {"openrouter", "openai"},
  openrouter_api_key = "sk-or-xxx...xxx",
  openai_api_key = "sk-xxx...xxx",
  
  -- 选择策略
  selection_strategy = "balanced",
  auto_fallback = true,
  
  -- 模型偏好
  model_preferences = {
    coding = {"deepseek-coder", "qwen/qwen-2.5-72b-instruct:free"},
    general = {"deepseek-chat", "gpt-4o-mini"},
    analysis = {"claude-3-opus-20240229", "gpt-4o"}
  },
  
  -- 其他设置
  language = "zh",
  timeout = 30000,
  retry_attempts = 2
}

-- 演示不同场景下的提供商选择
local scenarios = {
  {
    name = "💻 编程任务（DeepSeek优势）",
    task_type = "coding", 
    description = "优先使用DeepSeek Coder，专门针对编程任务优化"
  },
  {
    name = "📝 通用任务（平衡选择）", 
    task_type = "general",
    description = "根据平衡策略选择最佳提供商"
  },
  {
    name = "🔍 深度分析（质量优先）",
    task_type = "analysis", 
    description = "选择质量最高的模型进行复杂分析"
  }
}

-- 模拟提供商状态
local provider_status = {
  deepseek = {health = "healthy", success_rate = 0.95, avg_response = 892},
  openrouter = {health = "healthy", success_rate = 0.88, avg_response = 1247}, 
  openai = {health = "degraded", success_rate = 0.75, avg_response = 2156},
  anthropic = {health = "unavailable", success_rate = 0.0, avg_response = 0},
  google = {health = "healthy", success_rate = 0.82, avg_response = 1834}
}

-- 演示函数
local function demonstrate_provider_selection(scenario)
  print(string.format("\n🎯 场景: %s", scenario.name))
  print(string.format("📋 描述: %s", scenario.description))
  print(string.format("🔧 任务类型: %s", scenario.task_type))
  
  -- 根据任务类型选择首选模型
  local preferred_models = demo_config.model_preferences[scenario.task_type] or demo_config.model_preferences.general
  
  print(string.format("🎨 首选模型: %s", table.concat(preferred_models, ", ")))
  
  -- 模拟选择过程
  local selected_provider = nil
  local selected_model = nil
  
  -- 查找可用的首选模型
  for _, model_name in ipairs(preferred_models) do
    if model_name:match("deepseek") and provider_status.deepseek.health == "healthy" then
      selected_provider = "deepseek"
      selected_model = model_name
      break
    elseif model_name:match("qwen") and provider_status.openrouter.health == "healthy" then
      selected_provider = "openrouter" 
      selected_model = model_name
      break
    elseif model_name:match("gpt") and provider_status.openai.health ~= "unavailable" then
      selected_provider = "openai"
      selected_model = model_name
      break
    elseif model_name:match("claude") and provider_status.anthropic.health == "healthy" then
      selected_provider = "anthropic"
      selected_model = model_name
      break
    end
  end
  
  -- 如果没找到首选，使用健康的DeepSeek作为默认
  if not selected_provider and provider_status.deepseek.health == "healthy" then
    selected_provider = "deepseek"
    selected_model = "deepseek-chat"
  end
  
  if selected_provider then
    local status = provider_status[selected_provider]
    print(string.format("✅ 选中提供商: %s", selected_provider))
    print(string.format("🤖 选中模型: %s", selected_model))
    print(string.format("📊 健康状态: %s (成功率: %.1f%%, 平均响应: %dms)", 
      status.health, status.success_rate * 100, status.avg_response))
  else
    print("❌ 没有可用的提供商")
  end
  
  return selected_provider, selected_model
end

-- 演示提供商状态报告
local function demonstrate_status_report()
  print("\n🤖 AI提供商系统状态报告")
  print(string.rep("-", 50))
  
  local total_requests = 156
  local successful_requests = 142
  local failed_requests = 14
  
  print(string.format("📊 请求统计:"))
  print(string.format("总请求数: %d", total_requests))
  print(string.format("成功请求: %d (%.1f%%)", successful_requests, successful_requests * 100 / total_requests))
  print(string.format("失败请求: %d (%.1f%%)", failed_requests, failed_requests * 100 / total_requests))
  print(string.format("平均响应时间: %.0fms", 1247))
  
  print("\n🔧 提供商状态:")
  
  local providers = {
    {name = "deepseek", display = "DeepSeek", models = 2},
    {name = "openrouter", display = "OpenRouter", models = 70}, 
    {name = "openai", display = "OpenAI", models = 3},
    {name = "anthropic", display = "Anthropic", models = 3},
    {name = "google", display = "Google Gemini", models = 2}
  }
  
  for _, provider in ipairs(providers) do
    local status = provider_status[provider.name]
    local health_icon = "❌"
    if status.health == "healthy" then
      health_icon = "✅"
    elseif status.health == "degraded" then  
      health_icon = "⚠️"
    elseif status.health == "recovering" then
      health_icon = "🔄"
    end
    
    print(string.format("%s %s (%s)", health_icon, provider.display, provider.name))
    print(string.format("   状态: %s", status.health))
    print(string.format("   成功率: %.1f%%", status.success_rate * 100))
    print(string.format("   平均响应: %dms", status.avg_response))
    print(string.format("   模型数量: %d", provider.models))
  end
end

-- 演示配置建议
local function demonstrate_config_recommendations()
  print("\n💡 配置建议")
  print(string.rep("-", 50))
  
  local recommendations = {
    "✅ DeepSeek: 推荐用于编程任务（高质量，低成本）",
    "✅ OpenRouter: 提供多种免费模型选择", 
    "⚠️ OpenAI: 当前状态降级，建议检查API配额",
    "❌ Anthropic: 暂时不可用，请检查API密钥配置"
  }
  
  for _, rec in ipairs(recommendations) do
    print(rec)
  end
  
  print("\n🔧 推荐配置:")
  print([[
require("ai-commit").setup({
  primary_provider = "deepseek",
  deepseek_api_key = "your-deepseek-key",
  fallback_providers = {"openrouter", "openai"},
  selection_strategy = "balanced",
  auto_fallback = true
})
]])
end

-- 演示故障转移
local function demonstrate_failover()
  print("\n🔄 故障转移演示")
  print(string.rep("-", 50))
  
  print("模拟场景: 主要提供商DeepSeek暂时不可用")
  
  -- 模拟DeepSeek故障
  local original_status = provider_status.deepseek.health
  provider_status.deepseek.health = "unavailable"
  
  print("🚨 DeepSeek状态: unavailable")
  print("🔄 启动自动故障转移...")
  
  -- 检查备用提供商
  local fallback_providers = demo_config.fallback_providers
  local selected_fallback = nil
  
  for _, provider_name in ipairs(fallback_providers) do
    if provider_status[provider_name].health ~= "unavailable" then
      selected_fallback = provider_name
      break
    end
  end
  
  if selected_fallback then
    print(string.format("✅ 切换到备用提供商: %s", selected_fallback))
    print(string.format("📊 备用提供商状态: %s", provider_status[selected_fallback].health))
  else
    print("❌ 所有备用提供商均不可用")
  end
  
  -- 恢复状态
  provider_status.deepseek.health = original_status
  print(string.format("🔄 DeepSeek恢复正常: %s", provider_status.deepseek.health))
end

-- 主演示流程
local function main_demo()
  print("开始多提供商功能演示...\n")
  
  -- 1. 演示不同场景下的提供商选择
  for _, scenario in ipairs(scenarios) do
    demonstrate_provider_selection(scenario)
  end
  
  -- 2. 演示系统状态报告
  demonstrate_status_report()
  
  -- 3. 演示配置建议
  demonstrate_config_recommendations()
  
  -- 4. 演示故障转移
  demonstrate_failover()
  
  print("\n🎉 演示完成！")
  print("ai-commit.nvim 多提供商功能让你的开发体验更加稳定、高效、经济！")
end

-- 运行演示
main_demo()

--[[
使用方法：
1. 在终端中运行: lua demo_multi_provider.lua
2. 或在Neovim中运行: :luafile demo_multi_provider.lua

注意事项：
- 这是一个演示脚本，不会实际调用API
- 请将API密钥替换为真实值以进行实际测试
- 建议先在开发环境中测试新配置
--]]