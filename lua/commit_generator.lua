local M = {}

local openrouter_api_endpoint = "https://openrouter.ai/api/v1/chat/completions"
-- TODO: Make commit message template configurable
local commit_prompt_template = [[
Generate a git commit messages following these instructions:
Use the conventional commit format: type(scope): concise description. Remember to use semantic types like feat, fix, docs, style, refactor, perf, test, chore
Return ONLY the commit message - no introduction, no quotes around it, and no explanations of purpose or benefits (avoid phrases like "for better performance", "to improve readability", etc.).
The commit message should be concise, stating only WHAT was done, not WHY. Only the commit messages line by line.

Examples of good commits:
feat(api): add user authentication endpoint
fix(ui): resolve button alignment issue

Examples to avoid:
feat(api): add user authentication endpoint for improved security
fix(ui): resolve button alignment issue to enhance user experience

Git diff:
%s
Recent commits:
%s
Provide at least 5 different commit messages to choose from.]]

local function validate_api_key(config)
  local api_key = config.openrouter_api_key or vim.env.OPENROUTER_API_KEY
  if not api_key then
    vim.notify(
      "OpenRouter API key not found. Please set OPENROUTER_API_KEY environment variable or configure openrouter_api_key in your config",
      vim.log.levels.ERROR
    )
    return nil
  end
  return api_key
end

local function collect_git_data()
  local diff_context = vim.fn.system("git -P diff --cached")

  if diff_context == "" then
    vim.notify("No staged changes found. Add files with 'git add' first.", vim.log.levels.ERROR)
    return nil
  end

  local recent_commits = vim.fn.system("git log --oneline -n 5")

  return {
    diff = diff_context,
    commits = recent_commits,
  }
end

local function create_prompt(git_data)
  return string.format(commit_prompt_template, git_data.diff, git_data.commits)
end

local function prepare_request_data(prompt, model)
  return {
    model = model,
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
end

local function handle_api_response(response)
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
end

local function send_api_request(api_key, data)
  vim.schedule(function()
    vim.notify("Generating commit message...", vim.log.levels.INFO)
  end)

  require("plenary.curl").post(openrouter_api_endpoint, {
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. api_key,
    },
    body = vim.json.encode(data),
    callback = vim.schedule_wrap(handle_api_response),
  })
end

function M.generate_commit(config)
  local api_key = validate_api_key(config)
  if not api_key then
    return
  end

  local git_data = collect_git_data()
  if not git_data then
    return
  end

  local prompt = create_prompt(git_data)
  local data = prepare_request_data(prompt, config.model)

  send_api_request(api_key, data)
end

return M
