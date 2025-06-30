# 🤖 AI提供商完整配置指南

ai-commit.nvim 现在支持多个AI提供商，包括**DeepSeek**、OpenRouter、OpenAI、Anthropic和Google Gemini！

## 🚀 快速开始

### 1. 推荐配置（DeepSeek + 备用方案）

```lua
require("ai-commit").setup({
  -- 主要提供商：DeepSeek（国产AI，编程能力强）
  primary_provider = "deepseek",
  deepseek_api_key = "your-deepseek-api-key", -- 或设置 DEEPSEEK_API_KEY 环境变量
  
  -- 备用提供商
  fallback_providers = {"openrouter", "openai"},
  openrouter_api_key = "your-openrouter-key", -- 免费额度
  
  -- 智能选择策略
  selection_strategy = "balanced", -- 平衡成本、速度、质量
  auto_fallback = true, -- 自动故障转移
  
  -- 其他设置
  language = "zh",
  auto_push = false,
  timeout = 30000
})
```

### 2. 环境变量配置（推荐）

```bash
# 在你的 .bashrc, .zshrc 或 .profile 中添加
export DEEPSEEK_API_KEY="your-deepseek-api-key"
export OPENROUTER_API_KEY="your-openrouter-api-key"
export OPENAI_API_KEY="your-openai-api-key"     # 可选
export ANTHROPIC_API_KEY="your-anthropic-key"   # 可选
export GOOGLE_API_KEY="your-google-api-key"     # 可选
```

## 🔧 支持的AI提供商

### 1. 🇨🇳 DeepSeek（强烈推荐）
- **优势**: 国产AI，编程能力强，价格低廉
- **模型**: `deepseek-chat`, `deepseek-coder`
- **成本**: ￥0.1/请求
- **注册**: https://platform.deepseek.com/

```lua
-- DeepSeek专用配置
{
  primary_provider = "deepseek",
  deepseek_api_key = "your-key",
  model_preferences = {
    coding = {"deepseek-coder"}, -- 编程任务首选
    general = {"deepseek-chat"}  -- 通用任务
  }
}
```

### 2. 🌐 OpenRouter（最佳备选）
- **优势**: 多模型聚合，部分免费
- **模型**: 70+ 种模型可选
- **成本**: 免费额度 + 按需付费
- **注册**: https://openrouter.ai/

```lua
-- OpenRouter配置
{
  primary_provider = "openrouter",
  openrouter_api_key = "your-key",
  model = "qwen/qwen-2.5-72b-instruct:free" -- 免费模型
}
```

### 3. 🤖 OpenAI
- **优势**: GPT-4质量最高
- **模型**: `gpt-4o`, `gpt-4o-mini`, `gpt-3.5-turbo`
- **成本**: $$5-15/请求
- **注册**: https://platform.openai.com/

### 4. 🧠 Anthropic Claude
- **优势**: 长文本处理能力强
- **模型**: `claude-3-opus`, `claude-3-sonnet`, `claude-3-haiku`
- **成本**: $$3-15/请求
- **注册**: https://console.anthropic.com/

### 5. 🏗️ Google Gemini
- **优势**: 多模态能力
- **模型**: `gemini-pro`, `gemini-pro-vision`
- **成本**: $$0.5-2/请求
- **注册**: https://ai.google.dev/

## 📊 选择策略详解

### 1. `"cost_optimized"` - 成本优化
- 自动选择最便宜的可用提供商
- 适合：预算有限的个人开发者

### 2. `"performance_optimized"` - 性能优化
- 优先选择响应最快的提供商
- 适合：需要快速反馈的开发场景

### 3. `"quality_optimized"` - 质量优化
- 优先选择质量最高的模型
- 适合：对提交消息质量要求极高的团队

### 4. `"balanced"` - 平衡模式（推荐）
- 综合考虑成本、速度、质量
- 适合：大多数开发场景

### 5. `"primary_fallback"` - 主备模式
- 优先使用主提供商，失败时切换备用
- 适合：有明确提供商偏好的用户

## 🛠️ 新增命令

### 提供商管理命令

```vim
:AIProviders          " 查看所有提供商状态
:AIProvidersHealth    " 执行健康检查
:AIProvidersConfig    " 显示配置指南
:AIProviderSelect     " 交互式选择提供商
:AIModelSelect        " 交互式选择模型
```

### 使用示例

```vim
" 查看当前提供商状态
:AIProviders

" 输出示例：
" 🤖 AI提供商系统状态报告
" 
" 📊 请求统计:
" 总请求数: 15
" 成功请求: 14 (93.3%)
" 失败请求: 1 (6.7%)
" 平均响应时间: 1247ms
" 
" 🔧 提供商状态:
" ✅ DeepSeek (deepseek)
"    状态: healthy
"    成功率: 95.0%
"    平均响应: 892ms
"    模型数量: 2
```

## 💡 最佳实践

### 1. 推荐配置组合

#### 个人开发者（成本敏感）
```lua
{
  primary_provider = "deepseek",
  fallback_providers = {"openrouter"},
  selection_strategy = "cost_optimized"
}
```

#### 团队开发（质量优先）
```lua
{
  primary_provider = "openai", 
  fallback_providers = {"deepseek", "anthropic"},
  selection_strategy = "quality_optimized"
}
```

#### 企业用户（稳定性优先）
```lua
{
  primary_provider = "deepseek",
  fallback_providers = {"openai", "anthropic", "openrouter"},
  selection_strategy = "primary_fallback",
  auto_fallback = true
}
```

### 2. API密钥安全

```bash
# 使用环境变量（推荐）
export DEEPSEEK_API_KEY="sk-xxx"

# 或使用加密的配置文件
echo "export DEEPSEEK_API_KEY='sk-xxx'" >> ~/.config/nvim/private.sh
source ~/.config/nvim/private.sh
```

### 3. 成本控制

```lua
{
  -- 设置成本阈值
  cost_threshold = 1.0, -- 每次请求不超过1美分
  
  -- 优先使用免费/低成本模型
  model_preferences = {
    coding = {"deepseek-coder", "qwen/qwen-2.5-72b-instruct:free"},
    general = {"deepseek-chat", "gpt-4o-mini"}
  }
}
```

## 🔍 故障排除

### 常见问题

#### 1. "没有找到可用的AI提供商API密钥"
```bash
# 检查环境变量
echo $DEEPSEEK_API_KEY
echo $OPENROUTER_API_KEY

# 或在Neovim中检查
:AIProvidersConfig
```

#### 2. "API请求失败"
```vim
" 检查提供商健康状态
:AIProvidersHealth

" 查看详细状态
:AIProviders
```

#### 3. "响应速度慢"
```lua
-- 调整策略为性能优化
{
  selection_strategy = "performance_optimized",
  timeout = 15000 -- 减少超时时间
}
```

### 调试模式

```lua
-- 开启详细日志
vim.opt.verbosefile = "ai-commit-debug.log"
vim.opt.verbose = 1
```

## 📈 性能监控

### 查看统计信息
```vim
:AIProviders

" 查看详细的使用统计：
" - 各提供商成功率
" - 平均响应时间  
" - 模型使用频率
" - 成本统计
```

### 自动健康检查
```lua
-- 定期健康检查
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      require("ai_request_manager").health_check(require("ai-commit").config)
    end, 5000) -- 启动5秒后检查
  end
})
```

## 🚀 高级功能

### 1. 动态模型选择
```lua
-- 根据时间选择不同模型
local hour = tonumber(os.date("%H"))
local config = {
  primary_provider = hour < 18 and "deepseek" or "openrouter", -- 白天用DeepSeek，晚上用OpenRouter
}
```

### 2. 项目特定配置
```lua
-- 在项目根目录创建 .nvim.lua
return {
  ai_commit = {
    primary_provider = "openai", -- 此项目使用OpenAI
    selection_strategy = "quality_optimized"
  }
}
```

### 3. 自定义提供商优先级
```lua
{
  model_preferences = {
    coding = {"deepseek-coder", "gpt-4o", "claude-3-sonnet"},
    analysis = {"claude-3-opus", "gpt-4o"},
    translation = {"gpt-4o", "claude-3-sonnet"}
  }
}
```

## 🎯 迁移指南

### 从单提供商迁移

#### 原配置
```lua
require("ai-commit").setup({
  openrouter_api_key = "your-key",
  model = "qwen/qwen-2.5-72b-instruct:free"
})
```

#### 新配置（兼容）
```lua
require("ai-commit").setup({
  -- 保持原有配置（仍然有效）
  openrouter_api_key = "your-key", 
  model = "qwen/qwen-2.5-72b-instruct:free",
  
  -- 添加新的多提供商支持
  deepseek_api_key = "your-deepseek-key",
  primary_provider = "deepseek",
  fallback_providers = {"openrouter"},
  auto_fallback = true
})
```

## 📚 总结

多提供商AI架构为ai-commit.nvim带来了：

✅ **更高可靠性** - 自动故障转移  
✅ **更低成本** - 智能选择最优提供商  
✅ **更好性能** - 根据需求选择最快模型  
✅ **更强兼容性** - 支持5大主流AI平台  
✅ **更灵活配置** - 多种选择策略  

立即升级体验吧！🚀