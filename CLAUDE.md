# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ai-commit.nvim** is a Neovim plugin that generates meaningful commit messages using AI based on git changes. The plugin now supports multiple AI providers including DeepSeek, OpenRouter, OpenAI, Anthropic Claude, and Google Gemini with intelligent provider selection and automatic failover.

## Architecture

### Core Components

- **lua/ai-commit.lua** - Main plugin entry point with configuration management and user command setup
- **lua/commit_generator.lua** - Core logic for AI-powered commit message generation, API communication, and git operations
- **lua/ai_providers.lua** - Multi-provider AI architecture with support for 5+ AI services
- **lua/ai_request_manager.lua** - Smart request routing, failover, and health monitoring system

### Key Features

- **Multi-Provider AI Support** - DeepSeek, OpenRouter, OpenAI, Anthropic, Google Gemini
- **Intelligent Provider Selection** - Cost/performance/quality optimized routing
- **Automatic Failover** - Seamless switching between providers on failure
- **Health Monitoring** - Real-time provider health tracking and statistics
- Multi-language support (zh, en, ja, ko, es, fr, de, ru) with language-specific prompts
- Custom commit message templates via `commit_template` configuration
- No request truncation - full semantic analysis of large diffs
- Intelligent text optimization with context preservation
- Async operations using plenary.nvim jobs
- Automatic git commit and optional push functionality
- CI/CD deep integration with deployment risk assessment
- Comprehensive workflow orchestration and testing intelligence

### Configuration System

The plugin uses a table-based configuration in `M.config` with these key options:

#### Multi-Provider Configuration:
- `primary_provider` - Main AI provider (default: "deepseek")
- `fallback_providers` - Fallback order (default: {"openrouter", "openai"})
- `selection_strategy` - Provider selection strategy: "cost_optimized", "performance_optimized", "quality_optimized", "balanced", "primary_fallback"
- `auto_fallback` - Enable automatic failover (default: true)

#### API Keys (use environment variables recommended):
- `deepseek_api_key` - DeepSeek API key (DEEPSEEK_API_KEY env var)
- `openrouter_api_key` - OpenRouter API key (OPENROUTER_API_KEY env var)  
- `openai_api_key` - OpenAI API key (OPENAI_API_KEY env var)
- `anthropic_api_key` - Anthropic API key (ANTHROPIC_API_KEY env var)
- `google_api_key` - Google API key (GOOGLE_API_KEY env var)

#### Legacy Support:
- `model` - AI model selection (default: "qwen/qwen-2.5-72b-instruct:free")

#### Other Options:
- `language` - Output language for commit messages
- `commit_template` - Custom prompt template with %s placeholders for diff and commits
- `auto_push` - Whether to automatically push after commit
- `timeout` - Request timeout in milliseconds (default: 30000)
- `retry_attempts` - Number of retry attempts (default: 2)

## Development

### Dependencies

- Neovim >= 0.8.0
- plenary.nvim (for async jobs and curl operations)
- Git (for diff and commit operations)

### API Integration

The plugin integrates with OpenRouter.ai using:
- Endpoint: https://openrouter.ai/api/v1/chat/completions
- Chat completions format with system/user roles
- Comprehensive error handling for various API response codes (402, 403, 408, 429, 502, 503)

### Core Workflow

1. Validate API key (config or environment variable)
2. Collect git data (staged diff with -U10 context, recent 5 commits)
3. Validate and truncate data to prevent oversized requests
4. Generate language-specific prompt using template
5. Send async API request via plenary.curl
6. Parse response and extract clean commit message
7. Execute git commit using plenary.job
8. Optionally push changes if auto_push is enabled

### Testing

No specific test framework is configured. Manual testing involves staging changes and running `:AICommit` command.

### Key Functions

#### Core Functions:
- `validate_api_key()` - Checks for API key in config or environment
- `collect_git_data()` - Gathers staged diff and recent commits
- `optimize_git_data()` - Intelligently optimizes diff content without truncation
- `create_prompt()` - Builds language-specific prompt from template
- `handle_api_response()` - Parses API response and extracts commit message
- `commit_changes()` - Executes git commit and optional push operations

#### Multi-Provider Functions:
- `generate_commit_multi_provider()` - Enhanced commit generation with provider intelligence
- `select_smart_provider()` - Intelligent provider selection with health consideration
- `send_ai_request()` - Multi-provider request handling with retry and failover
- `parse_error_response()` - Provider-specific error handling
- `update_provider_health()` - Real-time health monitoring and statistics

## Usage Commands

### Core Commands:
- `:AICommit` - Generate and apply AI commit message for staged changes (now with multi-provider support)

### Multi-Provider Management Commands:
- `:AIProviders` - Show comprehensive AI providers status and statistics
- `:AIProvidersHealth` - Perform health check on all configured providers
- `:AIProvidersConfig` - Display configuration guide and recommendations
- `:AIProviderSelect` - Interactive provider selection interface
- `:AIModelSelect` - Interactive model selection for current provider

### Advanced Feature Commands (24+ total):
- `:AICommitInteractive` - Telescope-based interactive commit picker
- `:AICommitAnalyze` - Advanced pre-commit analysis with impact assessment
- `:AICommitTeam` - Configure team standards and commit conventions
- `:AICommitStats` - Generate detailed commit analytics and team productivity reports
- `:AICommitRefine` - AI-powered iterative commit message refinement
- `:AICommitTranslate` - Real-time translation between 8 languages
- `:AICommitSplit` - Intelligent commit splitting for complex changes
- `:AICommitChangelog` - Automated changelog generation
- `:AICommitRelease` - Professional release notes generation
- `:AICommitLearn` - Deep learning from project history
- `:AICommitPatterns` - Pattern management and analysis dashboard
- `:AICommitVoice` - Voice-to-commit functionality (experimental)
- `:AICommitEmoji` - Smart emoji suggestions
- `:AICommitImpact` - Predictive change impact analysis
- `:AICommitScore` - Real-time commit message quality scoring
- `:AICommitAchievements` - Gamification system with achievements
- `:AICommitVersionSuggest` - Intelligent semantic version suggestions
- `:AICommitHistory` - View and analyze commit refinement history

### CI/CD Deep Integration Commands:
- `:AICommitCICD` - Comprehensive CI/CD workflow management
- `:AICommitPipeline` - CI/CD pipeline status monitoring and analysis
- `:AICommitRisk` - Advanced deployment risk assessment
- `:AICommitTest` - Intelligent test planning and execution
- `:AICommitPerf` - Performance impact analysis and benchmark execution