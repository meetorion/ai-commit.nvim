local M = {}
M.config = {
  openrouter_api_key = nil,
  model = "qwen/qwen-2.5-72b-instruct:free",
  auto_push = false,
}

local commit_generator = require("commit_generator")

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

M.generate_commit = function()
  commit_generator.generate_commit(M.config)
end

vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

return M
