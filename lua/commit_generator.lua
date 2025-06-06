local M = {}

local openrouter_api_endpoint = "https://openrouter.ai/api/v1/chat/completions"

-- Language configuration for commit messages
local language_configs = {
	zh = {
		name = "中文",
		instruction = "请使用中文生成提交消息。",
		examples_prefix = "中文示例：",
	},
	en = {
		name = "English",
		instruction = "Please generate commit messages in English.",
		examples_prefix = "English examples:",
	},
	ja = {
		name = "日本語",
		instruction = "日本語でコミットメッセージを生成してください。",
		examples_prefix = "日本語の例：",
	},
	ko = {
		name = "한국어",
		instruction = "한국어로 커밋 메시지를 생성해주세요.",
		examples_prefix = "한국어 예시:",
	},
	es = {
		name = "Español",
		instruction = "Por favor, genera mensajes de commit en español.",
		examples_prefix = "Ejemplos en español:",
	},
	fr = {
		name = "Français",
		instruction = "Veuillez générer des messages de commit en français.",
		examples_prefix = "Exemples en français:",
	},
	de = {
		name = "Deutsch",
		instruction = "Bitte generiere Commit-Nachrichten auf Deutsch.",
		examples_prefix = "Deutsche Beispiele:",
	},
	ru = {
		name = "Русский",
		instruction = "Пожалуйста, создавайте сообщения коммитов на русском языке.",
		examples_prefix = "Примеры на русском:",
	},
}

-- Default commit message template
local default_commit_template = [[
Git diff:
%s

Recent commits (for context):
%s

'Write commit message for the change with commitizen convention. Keep the title under 50 characters and wrap message at 72 characters. Format as a gitcommit code block.',

]]

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
	local diff_context = vim.fn.system("git -P diff --cached -U10")

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

local function create_prompt(git_data, language, custom_template)
	-- Use custom template if provided, otherwise use default
	local template = custom_template or default_commit_template

	-- Get language configuration
	local lang_config = language_configs[language] or language_configs["en"]

	-- Create language-specific template
	local language_instruction = lang_config.instruction

	-- Inject language instruction into the template
	local language_enhanced_template = template:gsub(
		"Generate exactly 5 commit messages following the above guidelines",
		language_instruction .. "\n\nGenerate exactly 5 commit messages following the above guidelines"
	)

	return string.format(language_enhanced_template, git_data.diff, git_data.commits)
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

-- TODO: Refactor this
local function handle_api_response(response)
	if response.status == 200 then
		local data = vim.json.decode(response.body)
		local messages = {}

		if data.choices and #data.choices > 0 and data.choices[1].message and data.choices[1].message.content then
			local message_content = data.choices[1].message.content
			for line in message_content:gmatch("[^\n]+") do
				-- Clean up the line by removing numbers, asterisks, and extra whitespace
				local cleaned = line
					:gsub("^%d+%.%s*", "") -- Remove "1. "
					:gsub("^%*%*(.-)%*%*", "%1") -- Remove **text**
					:gsub("^%*%s*", "") -- Remove "* "
					:gsub("^%-+%s*", "") -- Remove "- "
					:gsub("^%s+", "") -- Remove leading whitespace
					:gsub("%s+$", "") -- Remove trailing whitespace

				-- Only add non-empty lines that look like commit messages
				if cleaned ~= "" and not cleaned:match("^[%u%s]+:$") and cleaned:match("%S") then
					table.insert(messages, cleaned)
				end
			end

			if #messages > 0 then
				require("ai-commit").show_commit_suggestions(messages)
			else
				vim.notify("No commit messages were generated. Try again or modify your changes.", vim.log.levels.WARN)
			end
		else
			vim.notify(
				"Received empty response from model. The model may be warming up, try again in a few moments.",
				vim.log.levels.WARN
			)
		end
	else
		local error_info = "Unknown error"

		local ok, error_data = pcall(vim.json.decode, response.body)

		if ok and error_data and error_data.error then
			local error_code = error_data.error.code or response.status
			local error_message = error_data.error.message or "No error message provided"

			if error_code == 402 then
				error_info = "Insufficient credits: " .. error_message
			elseif error_code == 403 and error_data.error.metadata and error_data.error.metadata.reasons then
				local reasons = table.concat(error_data.error.metadata.reasons, ", ")
				error_info = "Content moderation error: " .. reasons
				if error_data.error.metadata.flagged_input then
					error_info = error_info .. " (flagged input: '" .. error_data.error.metadata.flagged_input .. "')"
				end
			elseif error_code == 408 then
				error_info = "Request timed out. Try again later."
			elseif error_code == 429 then
				error_info = "Rate limited. Please wait before trying again."
			elseif error_code == 502 then
				error_info = "Model provider error: " .. error_message
				if error_data.error.metadata and error_data.error.metadata.provider_name then
					error_info = error_info .. " (provider: " .. error_data.error.metadata.provider_name .. ")"
				end
			elseif error_code == 503 then
				error_info = "No available model provider: " .. error_message
			else
				error_info = string.format("Error %d: %s", error_code, error_message)
			end
		else
			error_info = string.format("Error %d: %s", response.status, response.body)
		end

		vim.notify("Failed to generate commit message: " .. error_info, vim.log.levels.ERROR)
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

	local prompt = create_prompt(git_data, config.language or "zh", config.commit_template)
	local data = prepare_request_data(prompt, config.model)

	send_api_request(api_key, data)
end

return M
