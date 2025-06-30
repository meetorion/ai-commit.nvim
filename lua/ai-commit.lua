local M = {}

M.config = {
  openrouter_api_key = nil,
  model = "qwen/qwen-2.5-72b-instruct:free",
  auto_push = false,
  language = "zh", -- Default language for commit messages: "zh" (Chinese), "en" (English), "ja" (Japanese), "ko" (Korean), etc.
  commit_template = nil, -- Custom commit message template (optional)
}

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
end

M.generate_commit = function()
  require("commit_generator").generate_commit(M.config)
end

-- Enhanced user commands
vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

vim.api.nvim_create_user_command("AICommitInteractive", function()
  if not pcall(require, 'telescope') then
    vim.notify("Telescope is required for interactive mode", vim.log.levels.ERROR)
    return
  end
  require('telescope').extensions.ai_commit.ai_commits()
end, {})

vim.api.nvim_create_user_command("AICommitAnalyze", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    local workflow = require("git_workflow")
    workflow.interactive_pre_commit_workflow(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitTeam", function()
  require("team_standards").setup_team_standards()
end, {})

vim.api.nvim_create_user_command("AICommitStats", function()
  require("team_standards").generate_analytics_report()
end, {})

-- Advanced feature commands
vim.api.nvim_create_user_command("AICommitRefine", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("commit_refinement").refine_commit_message(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitTranslate", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    vim.ui.input({prompt = "输入要翻译的提交消息: "}, function(message)
      if message then
        require("commit_translation").translate_commit_message(message, git_data)
      end
    end)
  end
end, {})

vim.api.nvim_create_user_command("AICommitSplit", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("commit_splitting").interactive_commit_splitting(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitChangelog", function()
  require("changelog_generator").generate_interactive_changelog()
end, {})

vim.api.nvim_create_user_command("AICommitRelease", function()
  vim.ui.input({prompt = "输入版本号: "}, function(version)
    if version then
      require("changelog_generator").generate_release_notes(version, false)
    end
  end)
end, {})

vim.api.nvim_create_user_command("AICommitLearn", function()
  require("pattern_learning").learn_from_project_history()
end, {})

vim.api.nvim_create_user_command("AICommitPatterns", function()
  require("pattern_learning").manage_learned_patterns()
end, {})

vim.api.nvim_create_user_command("AICommitVoice", function()
  require("advanced_features").voice_to_commit()
end, {})

vim.api.nvim_create_user_command("AICommitEmoji", function()
  require("advanced_features").add_emoji_to_commit()
end, {})

vim.api.nvim_create_user_command("AICommitImpact", function()
  local git_data = require("commit_generator").collect_git_data()
  if git_data then
    require("advanced_features").analyze_change_impact(git_data)
  end
end, {})

vim.api.nvim_create_user_command("AICommitAchievements", function()
  require("advanced_features").show_achievement_dashboard()
end, {})

vim.api.nvim_create_user_command("AICommitScore", function()
  vim.ui.input({prompt = "输入提交消息进行评分: "}, function(message)
    if message then
      local result = require("advanced_features").validate_and_score_commit(message)
      local report = string.format([[
📊 提交消息质量评分

消息: %s

评分: %d/%d (%d%%) - %s

反馈:
%s
]], message, result.score, result.max_score, result.percentage, result.grade, table.concat(result.feedback, "\n"))
      vim.notify(report, vim.log.levels.INFO)
    end
  end)
end, {})

vim.api.nvim_create_user_command("AICommitVersionSuggest", function()
  require("changelog_generator").suggest_next_version()
end, {})

vim.api.nvim_create_user_command("AICommitHistory", function()
  require("commit_refinement").show_refinement_history()
end, {})

return M
