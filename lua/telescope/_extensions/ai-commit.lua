local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires nvim-telescope/telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local themes = require("telescope.themes")

local create_commit_job = function(selection)
  local Job = require("plenary.job")
  return Job:new({
    command = "git",
    args = { "commit", "-m", selection[1] },
    on_exit = function(j, return_val)
      if return_val == 0 then
        vim.notify("Commit created successfully!", vim.log.levels.INFO)
        if require("ai-commit").config.auto_push then
          push_changes()
        end
      else
        vim.notify("Failed to create commit", vim.log.levels.ERROR)
      end
    end,
  })
end

local push_changes = function()
  local Job = require("plenary.job")
  vim.notify("Pushing changes...", vim.log.levels.INFO)
  Job:new({
    command = "git",
    args = { "push" },
    on_exit = function(_, push_return_val)
      if push_return_val == 0 then
        vim.notify("Changes pushed successfully!", vim.log.levels.INFO)
      else
        vim.notify("Failed to push changes", vim.log.levels.ERROR)
      end
    end,
  }):start()
end

local handle_selection = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  vim.notify("Creating commit...", vim.log.levels.INFO)
  create_commit_job(selection):start()
end

local commit_picker = function(opts)
  opts = opts or {}
  if opts.theme == nil then
    opts = themes.get_dropdown(opts)
  end

  pickers.new(opts, {
    prompt_title = "AI Commit Messages",
    finder = finders.new_table({
      results = opts.messages or {},
    }),
    previewer = false,
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        handle_selection(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    commit = commit_picker,
  },
})
