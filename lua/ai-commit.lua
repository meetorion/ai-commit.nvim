local M = {}

M.config = {
  -- API provider configuration
  api_provider = "openrouter", -- "openrouter" or "deepseek"

  -- OpenRouter API configuration
  openrouter_api_key = nil,

  -- DeepSeek API configuration
  deepseek_api_key = nil,

  -- Model configuration
  model = "qwen/qwen-2.5-72b-instruct:free", -- For OpenRouter
  -- model = "deepseek-chat", -- For DeepSeek

  auto_push = false,
  language = "zh",      -- Default language for commit messages: "zh" (Chinese), "en" (English), "ja" (Japanese), "ko" (Korean), etc.
  commit_template = nil, -- Custom commit message template (optional)

  -- Smart branch configuration
  smart_branch = {
    auto_create = false, -- Whether to create branch automatically without confirmation
    max_keywords = 3,  -- Maximum keywords in branch name
    max_length = 40,   -- Maximum branch name length
    ai_enhanced = false, -- Use AI to enhance branch naming
    custom_prefixes = { -- Custom prefixes for each branch type
      feature = "feat/",
      fix = "bugfix/",
      hotfix = "urgent/",
      docs = "doc/",
      refactor = "refactor/",
      style = "style/",
      test = "test/",
      chore = "chore/",
    },
  },
}

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
end

M.generate_commit = function()
  require("commit_generator").generate_commit(M.config)
end

M.analyze_impact = function()
  require("commit_impact_analyzer").analyze_commit_impact()
end

M.analyze_impact_with_ai = function()
  require("commit_impact_analyzer").analyze_commit_impact_with_ai(M.config)
end

M.debug_commit = function()
  -- Enable debug logging temporarily
  vim.notify("Debug mode enabled - check messages for detailed logs", vim.log.levels.INFO)
  require("commit_generator").generate_commit(M.config)
end

M.create_smart_branch = function()
  require("branch_manager").create_smart_branch(M.config.smart_branch)
end

M.create_smart_branch_with_ai = function()
  if M.config.smart_branch.ai_enhanced then
    require("branch_manager").create_smart_branch_with_ai(M.config, M.config.smart_branch)
  else
    vim.notify("AI enhancement is disabled. Enable with smart_branch.ai_enhanced = true", vim.log.levels.WARN)
    M.create_smart_branch()
  end
end

M.split_large_commit = function()
  require("commit_splitter").split_large_commit()
end

M.quick_split_commit = function()
  require("commit_splitter").quick_split_commit()
end

M.auto_split_and_commit = function()
  require("auto_commit_splitter").auto_split_and_commit()
end

M.preview_auto_split = function()
  require("auto_commit_splitter").preview_auto_split()
end

vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

vim.api.nvim_create_user_command("AICommitDebug", function()
  M.debug_commit()
end, {})

vim.api.nvim_create_user_command("AICommitImpact", function()
  M.analyze_impact()
end, {})

vim.api.nvim_create_user_command("AICommitImpactAI", function()
  M.analyze_impact_with_ai()
end, {})

vim.api.nvim_create_user_command("AIBranch", function()
  M.create_smart_branch()
end, {})

vim.api.nvim_create_user_command("AIBranchAI", function()
  M.create_smart_branch_with_ai()
end, {})

vim.api.nvim_create_user_command("AICommitSplit", function()
  M.split_large_commit()
end, {})

vim.api.nvim_create_user_command("AICommitQuickSplit", function()
  M.quick_split_commit()
end, {})

vim.api.nvim_create_user_command("AICommitAutoSplit", function()
  M.auto_split_and_commit()
end, {})

vim.api.nvim_create_user_command("AICommitPreviewSplit", function()
  M.preview_auto_split()
end, {})

return M
