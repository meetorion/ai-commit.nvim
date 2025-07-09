# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ai-commit.nvim** is a Neovim plugin that generates meaningful commit messages using AI based on git changes. The plugin currently supports OpenRouter.ai API and can generate commit messages in multiple languages.

## Architecture

### Core Components

- **lua/ai-commit.lua** - Main plugin entry point with configuration management and user command setup
- **lua/commit_generator.lua** - Core logic for AI-powered commit message generation, API communication, and git operations

### Key Features

- Multi-language support (zh, en, ja, ko, es, fr, de, ru) with language-specific prompts
- Custom commit message templates via `commit_template` configuration  
- Intelligent diff optimization with context preservation
- Async operations using plenary.nvim jobs
- Automatic git commit and optional push functionality
- Comprehensive error handling for various API response codes

### Configuration System

The plugin uses a table-based configuration in `M.config` with these key options:
- `openrouter_api_key` - API key (can use OPENROUTER_API_KEY env var)
- `model` - AI model selection (default: "qwen/qwen-2.5-72b-instruct:free")
- `language` - Output language for commit messages (default: "zh")
- `commit_template` - Custom prompt template with %s placeholders for diff and commits
- `auto_push` - Whether to automatically push after commit (default: false)

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
2. Collect git data (staged diff with -U15 context, recent 5 commits)
3. Optimize diff content while preserving semantic meaning
4. Generate language-specific prompt using template
5. Send async API request via plenary.curl
6. Parse response and extract clean commit message
7. Execute git commit using plenary.job
8. Optionally push changes if auto_push is enabled

### Diff Optimization

The plugin includes intelligent diff optimization (`optimize_diff_content`) that:
- Preserves diff headers and hunk markers
- Keeps all added/removed lines
- Limits consecutive context lines to 3 with ellipsis for omitted content
- Maintains semantic meaning while reducing request size

### Testing

No specific test framework is configured. Manual testing involves:
1. Stage changes with `git add`
2. Run `:AICommit` command
3. Verify commit message generation and application

### Key Functions

- `validate_api_key()` - Checks for API key in config or environment (lua/commit_generator.lua:140)
- `collect_git_data()` - Gathers staged diff and recent commits (lua/commit_generator.lua:152)
- `optimize_diff_content()` - Optimizes diff while preserving semantic meaning (lua/commit_generator.lua:9)
- `create_prompt()` - Builds language-specific prompt from template (lua/commit_generator.lua:168)
- `handle_api_response()` - Parses API response and extracts commit message (lua/commit_generator.lua:235)
- `commit_changes()` - Executes git commit and optional push operations (lua/commit_generator.lua:203)

## Usage Commands

- `:AICommit` - Generate and apply AI commit message for staged changes