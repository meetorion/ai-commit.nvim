local M = {}

M.config = {
  openrouter_api_key = nil,
  model = "qwen/qwen-2.5-72b-instruct:free",
  auto_push = false,
}

local function generate_commit_message(diff_context, recent_commits, callback)
  local api_key = M.config.openrouter_api_key or vim.env.OPENROUTER_API_KEY

  if not api_key then
    vim.notify(
      "OpenRouter API key not found. Please set it in the configuration or OPENROUTER_API_KEY environment variable.",
      vim.log.levels.ERROR
    )
    return
  end

  local curl = require("plenary.curl")

  -- Уведомление сразу, перед началом запроса
  vim.schedule(function()
    vim.notify("Generating commit message...", vim.log.levels.INFO)
  end)

  local prompt = string.format(
    [[
Generate a git commit message following these instructions:

Use the conventional commit format (type: concise description) (remember to use semantic types like feat, fix, docs, style, refactor, perf, test, chore, etc.)
Return ONLY the commit message - no introduction, no explanation, no quotes around it. Don't forget to specify scope like this: feat(auth)

Git diff:
%s

Recent commits:
%s

Provide at least five different commit messages to choose from.]],
    diff_context,
    recent_commits
  )

  local data = {
    model = M.config.model,
    messages = {
      {
        role = "system",
        content = "You are a helpful assistant that generates git commit messages following the conventional commits specification.",
      },
      {
        role = "user",
        content = prompt,
      },
    },
  }

  -- Асинхронный HTTP-запрос
  curl.post("https://openrouter.ai/api/v1/chat/completions", {
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. api_key,
    },
    body = vim.json.encode(data), -- <-- Используем vim.json.encode вместо vim.fn.json_encode

    -- Обрабатываем ответ асинхронно
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local data = vim.json.decode(response.body)
        local messages = {}

        for _, choice in ipairs(data.choices) do
          local message_content = choice.message.content
          for msg in message_content:gmatch("[^\n]+") do
            table.insert(messages, msg)
          end
        end

        callback(messages) -- Отправляем результат в Telescope
      else
        vim.notify("Failed to generate commit message: " .. response.body, vim.log.levels.ERROR)
      end
    end),
  })
end

local function show_commit_suggestions(messages)
  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
  end

  require("telescope").extensions["ai-commit"].commit({ messages = messages })
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

M.generate_commit = function()
  -- Get git diff
  local Job = require("plenary.job")
  Job:new({
    command = "git",
    args = { "diff", "--cached" },
    on_exit = function(j, return_val)
      if return_val == 0 then
        local diff_context = table.concat(j:result(), "\n")
        if diff_context == "" then
          vim.notify("No staged changes found. Please stage your changes first.", vim.log.levels.ERROR)
          return
        end

        -- Get recent commits for context
        Job:new({
          command = "git",
          args = { "log", "--oneline", "-n", "5" },
          on_exit = function(j2)
            local recent_commits = table.concat(j2:result(), "\n")
            generate_commit_message(diff_context, recent_commits, show_commit_suggestions)
          end,
        }):start()
      else
        vim.notify("Failed to get git diff", vim.log.levels.ERROR)
      end
    end,
  }):start()
end

-- Create the AICommit command
vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

return M
