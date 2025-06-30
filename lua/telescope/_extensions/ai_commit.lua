local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)')
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local M = {}

-- Generate multiple commit message options
local function generate_multiple_commits(git_data, config, count)
	count = count or 5
	local commit_generator = require('commit_generator')
	local advanced_analysis = require('advanced_analysis')
	
	-- Get enhanced context
	local context = advanced_analysis.analyze_commit_context(git_data)
	
	-- Enhanced template for multiple options
	local multi_template = string.format([[
%s

请基于以上分析生成 %d 个不同风格的commit消息选项：

1. 简洁风格 - 突出核心变更
2. 详细风格 - 包含技术细节和影响
3. 业务风格 - 强调业务价值和用户影响  
4. 技术风格 - 关注架构和实现细节
5. 团队风格 - 便于团队理解和协作

Git diff:
%s

Recent commits:
%s

每个选项使用以下格式：
选项X: commit消息内容

只返回commit消息选项，不要其他格式。
]], context.enhanced_context, count, git_data.diff, git_data.commits)
	
	return multi_template
end

-- Parse multiple commit options from AI response
local function parse_commit_options(response_content)
	local options = {}
	local styles = {
		"简洁风格",
		"详细风格", 
		"业务风格",
		"技术风格",
		"团队风格"
	}
	
	-- Split response into lines and extract commit messages
	for line in response_content:gmatch("[^\n]+") do
		local clean_line = line:gsub("^%s+", ""):gsub("%s+$", "")
		if clean_line:match("^选项%d+:") then
			local commit_msg = clean_line:gsub("^选项%d+:%s*", "")
			if commit_msg ~= "" then
				table.insert(options, commit_msg)
			end
		end
	end
	
	-- If parsing failed, create default options
	if #options == 0 then
		local first_line = response_content:match("[^\n]+")
		if first_line then
			table.insert(options, first_line:gsub("^%s+", ""):gsub("%s+$", ""))
		end
	end
	
	-- Add style labels to options
	for i, option in ipairs(options) do
		if styles[i] then
			options[i] = string.format("[%s] %s", styles[i], option)
		end
	end
	
	return options
end

-- Interactive commit message picker
local function commit_picker(git_data, config)
	-- Generate prompt for multiple commits
	local prompt = generate_multiple_commits(git_data, config)
	local data = require('commit_generator').prepare_request_data(prompt, config.model)
	
	vim.notify("Generating commit options...", vim.log.levels.INFO)
	
	-- Make API request
	require("plenary.curl").post("https://openrouter.ai/api/v1/chat/completions", {
		headers = {
			content_type = "application/json",
			authorization = "Bearer " .. (config.openrouter_api_key or vim.env.OPENROUTER_API_KEY),
		},
		body = vim.json.encode(data),
		callback = vim.schedule_wrap(function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if data.choices and #data.choices > 0 then
					local response_content = data.choices[1].message.content
					local options = parse_commit_options(response_content)
					
					-- Show telescope picker
					pickers.new({}, {
						prompt_title = "🤖 AI Commit Messages",
						finder = finders.new_table {
							results = options,
							entry_maker = function(entry)
								return {
									value = entry,
									display = entry,
									ordinal = entry,
								}
							end
						},
						sorter = conf.generic_sorter({}),
						attach_mappings = function(prompt_bufnr, map)
							actions.select_default:replace(function()
								actions.close(prompt_bufnr)
								local selection = action_state.get_selected_entry()
								if selection then
									-- Extract actual commit message (remove style prefix)
									local commit_msg = selection.value:gsub("^%[.-%]%s*", "")
									vim.notify("Selected: " .. commit_msg, vim.log.levels.INFO)
									
									-- Commit the changes
									local Job = require("plenary.job")
									Job:new({
										command = "git",
										args = { "commit", "-m", commit_msg },
										on_exit = function(_, return_val)
											if return_val == 0 then
												vim.notify("Commit created successfully!", vim.log.levels.INFO)
												if config.auto_push then
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
							end)
							
							-- Add preview mapping
							map('i', '<C-p>', function()
								local selection = action_state.get_selected_entry()
								if selection then
									local commit_msg = selection.value:gsub("^%[.-%]%s*", "")
									vim.notify("Preview: " .. commit_msg, vim.log.levels.INFO)
								end
							end)
							
							return true
						end,
					}):find()
				else
					vim.notify("No commit options generated", vim.log.levels.ERROR)
				end
			else
				vim.notify("Failed to generate commit options: " .. response.status, vim.log.levels.ERROR)
			end
		end),
	})
end

-- Telescope extension setup
function M.ai_commits(opts)
	opts = opts or {}
	
	-- Validate git status
	local git_data = require('commit_generator').collect_git_data and 
		require('commit_generator').collect_git_data() or nil
	
	if not git_data then
		return
	end
	
	-- Get config
	local config = require('ai-commit').config
	
	-- Validate API key
	local api_key = config.openrouter_api_key or vim.env.OPENROUTER_API_KEY
	if not api_key then
		vim.notify("OpenRouter API key not found", vim.log.levels.ERROR)
		return
	end
	
	-- Optimize git data
	local optimize_git_data = require('commit_generator').optimize_git_data
	if optimize_git_data then
		git_data = optimize_git_data(git_data)
	end
	
	-- Launch interactive picker
	commit_picker(git_data, config)
end

-- Register the extension
return telescope.register_extension({
	setup = function(ext_config, config)
		-- Extension setup if needed
	end,
	exports = {
		ai_commits = M.ai_commits,
	},
})