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
      -- API key (required)
      -- Option 1: Set directly (not recommended for public configs)
      -- openrouter_api_key = "your-api-key-here",
      
      -- Option 2: Use environment variable (recommended)
      openrouter_api_key = vim.env.OPENROUTER_API_KEY,
      
      -- Model selection
      model = "qwen/qwen-2.5-72b-instruct:free", -- Free model
      -- model = "anthropic/claude-3.5-sonnet", -- Premium model
      
      -- Language for commit messages
      language = "zh", -- Options: "zh", "en", "ja", "ko", "es", "fr", "de", "ru"
      
      -- Auto push after commit
      auto_push = false,
      
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
  },
  
  -- Optional: Commands
  cmd = { "AICommit", "AICommitImpact", "AICommitImpactAI" },
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