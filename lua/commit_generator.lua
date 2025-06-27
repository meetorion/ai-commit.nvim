local M = {}

local openrouter_api_endpoint = "https://openrouter.ai/api/v1/chat/completions"

-- Configuration for improved diff processing
local MAX_CONTEXT_LINES = 15  -- Context lines for git diff to balance detail and size

-- Function to optimize diff content by removing excessive context while preserving semantic meaning
local function optimize_diff_content(diff_text)
	-- Split diff into lines
	local lines = {}
	for line in diff_text:gmatch("[^\n]*\n?") do
		if line ~= "" then
			table.insert(lines, line)
		end
	end
	
	-- Process diff to keep meaningful changes while reducing excessive context
	local optimized_lines = {}
	local in_hunk = false
	local consecutive_context = 0
	local max_consecutive_context = 3
	
	for i, line in ipairs(lines) do
		-- Keep diff headers
		if line:match("^diff ") or line:match("^index ") or line:match("^%+%+%+ ") or line:match("^%-%-%- ") then
			table.insert(optimized_lines, line)
			in_hunk = false
			consecutive_context = 0
		-- Keep hunk headers
		elseif line:match("^@@ ") then
			table.insert(optimized_lines, line)
			in_hunk = true
			consecutive_context = 0
		-- Process content lines
		elseif in_hunk then
			local first_char = line:sub(1, 1)
			-- Always keep added/removed lines
			if first_char == "+" or first_char == "-" then
				table.insert(optimized_lines, line)
				consecutive_context = 0
			-- Handle context lines more intelligently
			elseif first_char == " " then
				consecutive_context = consecutive_context + 1
				-- Keep limited context around changes
				if consecutive_context <= max_consecutive_context then
					table.insert(optimized_lines, line)
				elseif consecutive_context == max_consecutive_context + 1 then
					-- Add ellipsis to indicate skipped content
					table.insert(optimized_lines, " ... (context omitted for brevity)\n")
				end
				-- Skip excessive context lines
			end
		else
			table.insert(optimized_lines, line)
		end
	end
	
	return table.concat(optimized_lines)
end

-- Function to optimize git data for better semantic understanding
local function optimize_git_data(git_data)
	-- Optimize diff content while preserving semantic meaning
	git_data.diff = optimize_diff_content(git_data.diff)
	
	-- Keep recent commits for context (no truncation for better understanding)
	return git_data
end

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

-- Enhanced commit message template for comprehensive analysis
local default_commit_template = [[
你是一个专业的软件工程师，负责分析代码变更并生成高质量的commit消息。

请分析以下git差异和相关上下文：

Git diff:
%s

Recent commits (for context):
%s

请生成一个详细而准确的commit消息，要求：
1. 使用常规commit格式 (type(scope): description)
2. 准确描述变更的内容和原因
3. 标题控制在50字符以内
4. 如果需要，可以包含更详细的描述
5. 关注变更的业务价值和技术影响
6. 使用清晰、专业的语言
7. 深入理解代码变更的语义和目的
8. 考虑变更对整个项目的影响

只返回commit消息，不要包含其他格式或额外文本。
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
	local diff_context = vim.fn.system("git -P diff --cached -U" .. MAX_CONTEXT_LINES)

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

local function commit_changes(message)
	local Job = require("plenary.job")

	Job:new({
		command = "git",
		args = { "commit", "-m", message },
		on_exit = function(_, return_val)
			if return_val == 0 then
				vim.notify("Commit created successfully!", vim.log.levels.INFO)
				local config = require("ai-commit").config
				if config.auto_push then
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
			else
				vim.notify("Failed to create commit", vim.log.levels.ERROR)
			end
		end,
	}):start()
end

-- TODO: Refactor this
local function handle_api_response(response)
	if response.status == 200 then
		local data = vim.json.decode(response.body)

		if data.choices and #data.choices > 0 and data.choices[1].message and data.choices[1].message.content then
			local message_content = data.choices[1].message.content
			-- Clean up the message content by removing extra formatting
			local cleaned_message = message_content
				:gsub("^```[^%s]*%s*", "") -- Remove opening code block
				:gsub("%s*```$", "") -- Remove closing code block
				:gsub("^%d+%.%s*", "") -- Remove "1. "
				:gsub("^%*%*(.-)%*%*", "%1") -- Remove **text**
				:gsub("^%*%s*", "") -- Remove "* "
				:gsub("^%-+%s*", "") -- Remove "- "
				:gsub("^%s+", "") -- Remove leading whitespace
				:gsub("%s+$", "") -- Remove trailing whitespace

			-- Get the first meaningful line as the commit message
			local commit_message = ""
			for line in cleaned_message:gmatch("[^\n]+") do
				local clean_line = line:gsub("^%s+", ""):gsub("%s+$", "")
				if clean_line ~= "" and not clean_line:match("^[%u%s]+:$") and clean_line:match("%S") then
					commit_message = clean_line
					break
				end
			end

			if commit_message ~= "" then
				vim.notify("Generated commit message: " .. commit_message, vim.log.levels.INFO)
				commit_changes(commit_message)
			else
				vim.notify("No valid commit message was generated. Try again or modify your changes.", vim.log.levels.WARN)
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

	-- Optimize git data for better semantic understanding
	git_data = optimize_git_data(git_data)

	local prompt = create_prompt(git_data, config.language or "zh", config.commit_template)
	
	-- Log prompt size for monitoring without truncation
	if #prompt > 50000 then
		vim.notify("Large diff detected. Processing comprehensive semantic analysis...", vim.log.levels.INFO)
	elseif #prompt > 20000 then
		vim.notify("Medium-sized diff detected. Analyzing detailed changes...", vim.log.levels.INFO)
	end
	
	local data = prepare_request_data(prompt, config.model)

	send_api_request(api_key, data)
end

return M
