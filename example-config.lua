-- Example configuration for ai-commit.nvim
-- Copy this to your Neovim config and adjust as needed

-- For lazy.nvim users:
return {
  dir = vim.fn.expand("~/work/ai-commit.nvim"), -- Adjust path to your local repo
  name = "ai-commit",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("ai-commit").setup({
      -- API Provider Configuration
      api_provider = "openrouter", -- Options: "openrouter", "deepseek"
      
      -- OpenRouter API Configuration
      openrouter_api_key = vim.env.OPENROUTER_API_KEY,
      
      -- DeepSeek API Configuration (alternative to OpenRouter)
      -- api_provider = "deepseek",
      -- deepseek_api_key = vim.env.DEEPSEEK_API_KEY,
      
      -- Model selection
      model = "qwen/qwen-2.5-72b-instruct:free", -- For OpenRouter
      -- model = "deepseek-chat", -- For DeepSeek
      
      -- Language for commit messages
      language = "zh", -- Options: "zh", "en", "ja", "ko", "es", "fr", "de", "ru"
      
      -- Auto push after commit
      auto_push = false,
      
      -- Smart branch configuration
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
        }
      },
      
      -- Custom commit template (optional)
      -- commit_template = [[
      -- Custom template here...
      -- Git diff: %s
      -- Recent commits: %s
      -- ]],
    })
  end,
  
  -- Optional: Key mappings
  keys = {
    { "<leader>gc", "<cmd>AICommit<cr>", desc = "Generate AI commit message" },
    { "<leader>gi", "<cmd>AICommitImpact<cr>", desc = "Analyze commit impact" },
    { "<leader>gI", "<cmd>AICommitImpactAI<cr>", desc = "AI-enhanced impact analysis" },
    { "<leader>gb", "<cmd>AIBranch<cr>", desc = "Create smart branch" },
    { "<leader>gB", "<cmd>AIBranchAI<cr>", desc = "Create AI-enhanced branch" },
  },
  
  -- Optional: Commands
  cmd = { "AICommit", "AICommitImpact", "AICommitImpactAI", "AIBranch", "AIBranchAI" },
}

-- For packer.nvim users:
-- use {
--   '~/work/ai-commit.nvim',
--   requires = { 'nvim-lua/plenary.nvim' },
--   config = function()
--     require('ai-commit').setup({
--       openrouter_api_key = vim.env.OPENROUTER_API_KEY,
--       language = "zh",
--     })
--   end
-- }

-- For manual loading (testing):
-- vim.opt.runtimepath:append(vim.fn.expand("~/work/ai-commit.nvim"))
-- require('ai-commit').setup({ openrouter_api_key = vim.env.OPENROUTER_API_KEY })