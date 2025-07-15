# ai-commit.nvim

A Neovim plugin that generates meaningful commit messages using AI based on your git changes.

## Supported AI Providers

- ✅ **OpenRouter** - Access to multiple AI models including free options
- ✅ **DeepSeek** - High-performance AI models with competitive pricing
- 🔄 **Coming Soon**: OpenAI, Anthropic, local Ollama, etc.

![image](https://i.imgur.com/mDR44F5.png)

## Features

### 🤖 AI-Powered Commit Messages
- Generate commit messages based on staged changes
- AI-generated commit message that's automatically applied
- Follows conventional commit format
- Multi-language support (8 languages)
- Custom commit templates

### 📊 Smart Impact Analysis
- Analyze potential impact of your changes
- Detect breaking changes, API modifications, security impacts
- Categorized impact assessment with recommendations
- Visual impact reports

### 🌿 Intelligent Branch Management
- **NEW!** Smart branch creation based on change analysis
- Automatic change type detection (feature/fix/docs/etc.)
- Semantic branch name generation from code changes
- AI-enhanced branch naming for better semantics
- Configurable branch prefixes and naming rules
- Interactive branch name selection and editing

### ⚡ Additional Features
- Optional automatic push after commit
- Asynchronous operations without UI blocking
- Debug mode for troubleshooting
- Support for OpenRouter and DeepSeek APIs

## Prerequisites

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "meetorion/ai-commit.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("ai-commit").setup({
            -- your configuration
        })
    end
}
```

## Configuration

### OpenRouter Configuration

```lua
{
  api_provider = "openrouter", -- default provider
  openrouter_api_key = "YOUR_API_KEY", -- or set OPENROUTER_API_KEY environment variable
  model = "qwen/qwen-2.5-72b-instruct:free", -- free model option
  auto_push = false, -- whether to automatically push after commit
  language = "zh", -- language for commit messages: "zh", "en", "ja", "ko", "es", "fr", "de", "ru"
  commit_template = nil, -- custom commit message template (optional)
}
```

### DeepSeek Configuration

```lua
{
  api_provider = "deepseek",
  deepseek_api_key = "YOUR_API_KEY", -- or set DEEPSEEK_API_KEY environment variable
  model = "deepseek-chat", -- DeepSeek's chat model
  auto_push = false,
  language = "zh",
  commit_template = nil,
}
```

### Smart Branch Configuration

```lua
{
  -- Enable smart branch features
  smart_branch = {
    auto_create = false, -- Auto-create without confirmation
    max_keywords = 3, -- Max keywords in branch name
    max_length = 40, -- Max branch name length
    ai_enhanced = true, -- Use AI for better naming
    custom_prefixes = {
      feature = "feat/",
      fix = "bugfix/",
      hotfix = "urgent/",
      docs = "doc/",
      refactor = "refactor/",
      style = "style/",
      test = "test/",
      chore = "chore/",
    }
  }
}
```

### Language Support

The plugin supports multiple languages for generating commit messages:

- **zh** (中文) - Chinese (default)
- **en** (English) - English
- **ja** (日本語) - Japanese
- **ko** (한국어) - Korean
- **es** (Español) - Spanish
- **fr** (Français) - French
- **de** (Deutsch) - German
- **ru** (Русский) - Russian

Example configuration for English commit messages with DeepSeek:

```lua
require("ai-commit").setup({
    api_provider = "deepseek",
    deepseek_api_key = "YOUR_API_KEY",
    model = "deepseek-chat",
    language = "en",
})
```

### Custom Commit Template

You can customize the AI prompt template used for generating commit messages by setting the `commit_template` option. This allows you to define your own format, style, and guidelines for commit messages.

Example custom template:

```lua
require("ai-commit").setup({
    openrouter_api_key = "YOUR_API_KEY",
    language = "en",
    commit_template = [[
You are a senior software engineer creating commit messages.

Analyze this git diff and create 5 concise commit messages following these rules:
1. Use imperative mood (e.g., "Add feature" not "Added feature")
2. Keep the first line under 50 characters
3. Focus on the "why" not the "what"
4. Use conventional commit format: type(scope): description

Git diff:
%s

Recent commits for context:
%s

Generate exactly 5 commit messages following the above guidelines:
    ]]
})
```

The template must include two `%s` placeholders:

- First `%s` will be replaced with the git diff
- Second `%s` will be replaced with recent commit history

If no custom template is provided, the plugin uses its default comprehensive template that follows conventional commit standards.

## Usage

### Commit Generation
1. Stage your changes using `git add`
2. Run `:AICommit` command
3. Wait for AI to generate a commit message
4. The AI-generated message will be automatically used for the commit

### Smart Branch Creation
1. Make some changes to your code (stage them or keep them unstaged)
2. Run `:AIBranch` for basic smart branch creation
3. Or run `:AIBranchAI` for AI-enhanced naming
4. Review the suggested branch name and choose your preferred option
5. The plugin will create and switch to the new branch

### Impact Analysis
1. Stage your changes using `git add`
2. Run `:AICommitImpact` to see potential impact analysis
3. Review the detailed report showing affected areas and recommendations

## Commands

### Commit Generation
- `:AICommit` - Generate and apply an AI commit message
- `:AICommitDebug` - Generate commit with debug logging enabled

### Impact Analysis
- `:AICommitImpact` - Analyze the impact of staged changes
- `:AICommitImpactAI` - Analyze impact with AI enhancement (coming soon)

### Smart Branch Management
- `:AIBranch` - Create intelligent branch based on staged changes
- `:AIBranchAI` - Create branch with AI-enhanced naming

## Development Setup

For local development and testing, you can load the plugin from your local directory:

```lua
-- Using lazy.nvim
{
  dir = "~/work/ai-commit.nvim",  -- Path to your local clone
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("ai-commit").setup({
      openrouter_api_key = vim.env.OPENROUTER_API_KEY,
      language = "zh",
    })
  end,
}
```

See `example-config.lua` for a complete configuration example with all available options.
