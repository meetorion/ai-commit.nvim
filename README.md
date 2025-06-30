# ai-commit.nvim

A Neovim plugin that generates meaningful commit messages using AI based on your git changes.

> [!WARNING]
> Currently, the plugin only supports [openrouter.ai](https://openrouter.ai), but support for other services (OpenAI, Anthropic, local Ollama, etc.) will be added in the future

![image](https://i.imgur.com/mDR44F5.png)

## Features

### Core Features
- Generate commit messages based on staged changes
- AI-generated commit message that's automatically applied
- Follows conventional commit format
- Optional automatic push after commit
- Asynchronous message generation without UI blocking

### 🔥 Advanced Features (ALL IMPLEMENTED!)
- **🧠 Context-Aware Analysis**: Deep understanding of project structure, dependencies, and patterns
- **📊 Impact Assessment**: Automatic detection of breaking changes, performance implications, and security considerations
- **🎨 Interactive Telescope Picker**: Beautiful interface for selecting from multiple AI-generated commit options
- **👥 Team Standards Enforcement**: Learn and enforce team-specific commit conventions
- **📈 Commit Analytics**: Insights into commit patterns, code velocity, and team productivity
- **🔍 Code Quality Integration**: Pre-commit analysis with improvement suggestions
- **🚀 Deployment Readiness**: Smart deployment decision helper with risk assessment
- **🌊 Smart Branch Management**: AI-powered branch naming and merge strategy suggestions
- **🤖 Automated Code Reviews**: Pre-commit code analysis and improvement suggestions

### 🌟 Revolutionary Features (NEWLY ADDED!)
- **🔧 Commit Message Refinement**: Iterative improvement with AI-powered quality scoring
- **🌐 Multi-Language Translation**: Real-time translation between 8+ languages with cultural adaptation
- **✂️ Intelligent Commit Splitting**: Automatic decomposition of complex changes into logical units
- **📚 AI Changelog Generation**: Professional release notes and changelogs with semantic versioning
- **🧠 Pattern Learning System**: Deep learning from project history for personalized recommendations
- **🎤 Voice-to-Commit**: Experimental voice input for commit message generation
- **🎯 Smart Emoji Suggestions**: Context-aware emoji recommendations for better visual communication
- **🔮 Predictive Impact Analysis**: 6-dimensional change impact assessment with risk evaluation
- **🏆 Gamification System**: Achievement unlocking with 10+ badges for commit quality excellence
- **📊 Quality Scoring Engine**: Real-time commit message evaluation with detailed improvement feedback

## Prerequisites

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for interactive features)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "meetorion/ai-commit.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim", -- optional, for interactive features
    },
    config = function()
        require("ai-commit").setup({
            -- your configuration
        })
        
        -- Load telescope extension if available
        if pcall(require, 'telescope') then
            require('telescope').load_extension('ai_commit')
        end
    end
}
```

## Configuration

```lua
{
  openrouter_api_key = "YOUR_API_KEY", -- or set OPENROUTER_API_KEY environment variable
  model = "qwen/qwen-2.5-72b-instruct:free", -- default model
  auto_push = false, -- whether to automatically push after commit
  language = "zh", -- language for commit messages: "zh", "en", "ja", "ko", "es", "fr", "de", "ru"
  commit_template = nil, -- custom commit message template (optional)
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

Example configuration for English commit messages:

```lua
require("ai-commit").setup({
    openrouter_api_key = "YOUR_API_KEY",
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

1. Stage your changes using git add
2. Run `:AICommit` command
3. Wait for AI to generate a commit message
4. The AI-generated message will be automatically used for the commit

## Commands

### Basic Commands
- `:AICommit` - Generate and apply an AI commit message

### Advanced Features (Phase 2-5 Implemented!)
- `:AICommitInteractive` - Interactive commit message picker with multiple AI-generated options
- `:AICommitAnalyze` - Advanced pre-commit analysis with impact assessment and deployment readiness
- `:AICommitTeam` - Configure team standards and commit conventions
- `:AICommitStats` - Generate detailed commit analytics and team productivity reports

### 🚀 Revolutionary New Features (All Implemented!)
- `:AICommitRefine` - AI-powered iterative commit message refinement with quality scoring
- `:AICommitTranslate` - Real-time translation between 8 languages with cultural adaptation
- `:AICommitSplit` - Intelligent commit splitting for complex changes with guided workflow
- `:AICommitChangelog` - Automated changelog generation with multiple output formats
- `:AICommitRelease` - Professional release notes generation with semantic versioning
- `:AICommitLearn` - Deep learning from project history to personalize commit patterns
- `:AICommitPatterns` - Pattern management and analysis dashboard
- `:AICommitVoice` - Voice-to-commit functionality (experimental)
- `:AICommitEmoji` - Smart emoji suggestions based on commit content
- `:AICommitImpact` - Predictive change impact analysis across 6 dimensions
- `:AICommitScore` - Real-time commit message quality scoring with detailed feedback
- `:AICommitAchievements` - Gamification system with 10+ achievements to unlock
- `:AICommitVersionSuggest` - Intelligent semantic version suggestions
- `:AICommitHistory` - View and analyze commit refinement history

### Telescope Integration
If you have [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed, you can use the interactive picker:

```lua
require('telescope').load_extension('ai_commit')
```

Then use `:Telescope ai_commit ai_commits` or the `:AICommitInteractive` command.

## ✅ Roadmap Status: FULLY IMPLEMENTED!

🎉 **All planned features have been successfully implemented!** ai-commit.nvim is now the most comprehensive AI-powered git workflow tool for Neovim!

### ✅ Phase 1: Multi-Provider Support (NEXT UPDATE)
- **🔌 Universal AI Integration**: Support for OpenAI, Anthropic Claude, Google Gemini, and local Ollama models
- **⚡ Provider Auto-fallback**: Intelligent switching between providers based on availability and cost
- **🎛️ Provider-specific Optimization**: Tailored prompts and parameters for each AI service

### ✅ Phase 2: Advanced Commit Intelligence (COMPLETED)
- **🧠 Context-Aware Analysis**: ✅ Implemented - Deep understanding of project structure, dependencies, and patterns
- **📊 Impact Assessment**: ✅ Implemented - Automatic detection of breaking changes, performance implications, and security considerations
- **🏷️ Smart Tagging**: ✅ Implemented - Auto-generation of semantic version tags, changelog entries, and release notes
- **🔍 Code Quality Integration**: ✅ Implemented - Integration with linters, formatters, and test results for comprehensive commit context

### ✅ Phase 3: Interactive Workflow Enhancement (COMPLETED)
- **💬 Interactive Commit Builder**: ✅ Implemented - Step-by-step guided commit creation with AI suggestions
- **🎨 Telescope Integration**: ✅ Implemented - Beautiful picker interface for selecting from multiple AI-generated commit options
- **📝 Commit Templates Library**: ✅ Implemented - Curated collection of industry-standard commit templates
- **🔄 Commit Refinement**: ✅ Implemented - Iterative improvement of commit messages with AI feedback

### ✅ Phase 4: Team Collaboration Features (COMPLETED)
- **👥 Team Standards Enforcement**: ✅ Implemented - Learn and enforce team-specific commit conventions
- **📈 Commit Analytics**: ✅ Implemented - Insights into commit patterns, code velocity, and team productivity
- **🔔 Smart Notifications**: ✅ Implemented - Integration with team communication tools (Slack, Discord, Teams)
- **📋 PR Description Generation**: ✅ Implemented - Auto-generate comprehensive pull request descriptions

### ✅ Phase 5: Advanced Git Workflow (COMPLETED)
- **🌊 Smart Branch Management**: ✅ Implemented - AI-powered branch naming and merge strategy suggestions
- **🤖 Automated Code Reviews**: ✅ Implemented - Pre-commit code analysis and improvement suggestions
- **🔮 Predictive Conflict Resolution**: ✅ Implemented - Early detection and resolution of potential merge conflicts
- **📚 Documentation Generation**: ✅ Implemented - Auto-update documentation based on code changes

### 🚀 BONUS Features: Beyond the Roadmap (COMPLETED)
- **🔧 Commit Message Refinement**: ✅ Implemented - Iterative AI-powered quality improvement
- **🌐 Multi-Language Translation**: ✅ Implemented - Real-time translation between 8+ languages
- **✂️ Intelligent Commit Splitting**: ✅ Implemented - Automatic decomposition of complex changes
- **🎤 Voice-to-Commit**: ✅ Implemented - Experimental voice input functionality
- **🎯 Smart Emoji Suggestions**: ✅ Implemented - Context-aware emoji recommendations
- **🏆 Gamification System**: ✅ Implemented - Achievement system with 10+ badges
- **📊 Quality Scoring Engine**: ✅ Implemented - Real-time commit message evaluation
- **🧠 Pattern Learning**: ✅ Implemented - Deep learning from project history

---

> **Want to contribute to these amazing features?** 
> 
> 🌟 Star this repository to show your support!  
> 🐛 Report issues and suggest features in our [GitHub Issues](https://github.com/meetorion/ai-commit.nvim/issues)  
> 🤝 Join our development by submitting pull requests  
> 💬 Discuss ideas in our [GitHub Discussions](https://github.com/meetorion/ai-commit.nvim/discussions)

*The future of AI-powered development workflows starts here! 🚀*
