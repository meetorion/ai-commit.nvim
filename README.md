# ai-commit.nvim

A Neovim plugin that generates meaningful commit messages using AI based on your git changes.

> [!WARNING]
> Currently, the plugin only supports [openrouter.ai](https://openrouter.ai), but support for other services (OpenAI, Anthropic, local Ollama, etc.) will be added in the future

![image](https://i.imgur.com/mDR44F5.png)

## Features

- Generate commit messages based on staged changes
- AI-generated commit message that's automatically applied
- Follows conventional commit format
- Optional automatic push after commit
- Asynchronous message generation without UI blocking

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

- `:AICommit` - Generate and apply an AI commit message
- `:AICommitImpact` - Analyze the impact of staged changes
- `:AICommitImpactAI` - Analyze impact with AI enhancement (coming soon)

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
