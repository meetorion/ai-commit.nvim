local M = {}
local curl = require("plenary.curl")

function M.generate_commit(config)
  local api_key = config.openrouter_api_key or vim.env.OPENROUTER_API_KEY

  if not api_key then
    vim.notify("OpenRouter API key not found.", vim.log.levels.ERROR)
    return
  end

  local diff_context = vim.fn.system("git diff --cached")
  local recent_commits = vim.fn.system("git log --oneline -n 5")

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
    model = config.model,
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

  vim.schedule(function()
    vim.notify("Generating commit message...", vim.log.levels.INFO)
  end)

  curl.post("https://openrouter.ai/api/v1/chat/completions", {
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. api_key,
    },
    body = vim.json.encode(data),

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

        require("ai-commit").show_commit_suggestions(messages)
      else
        vim.notify("Failed to generate commit message: " .. response.body, vim.log.levels.ERROR)
      end
    end),
  })
end

return M
