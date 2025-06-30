local M = {}

-- AI-powered commit message refinement system
local refinement_history = {}

-- Quality metrics for commit messages
local function analyze_commit_quality(message)
	local score = 0
	local max_score = 100
	local issues = {}
	local suggestions = {}
	
	-- Length checks
	local title = message:match("^([^\n]*)")
	if title then
		if #title > 50 then
			table.insert(issues, "标题超过50字符 (当前: " .. #title .. ")")
			score = score - 15
		elseif #title < 10 then
			table.insert(issues, "标题过短，缺乏描述性")
			score = score - 10
		else
			score = score + 20
		end
	end
	
	-- Conventional commit format
	if title and title:match("^[a-zA-Z]+%(.*%):%s*.+") then
		score = score + 25
		table.insert(suggestions, "✅ 符合常规提交格式")
	elseif title and title:match("^[a-zA-Z]+:%s*.+") then
		score = score + 15
		table.insert(suggestions, "建议添加scope以提高精确性")
	else
		table.insert(issues, "不符合常规提交格式")
		score = score - 20
	end
	
	-- Language and clarity
	if message:match("[\228-\233]") then -- Chinese characters
		score = score + 10
		table.insert(suggestions, "✅ 使用中文描述清晰")
	end
	
	-- Action verbs
	local action_verbs = {"feat", "fix", "docs", "style", "refactor", "perf", "test", "chore", "ci", "build", "添加", "修复", "更新", "移除", "优化"}
	local has_action = false
	for _, verb in ipairs(action_verbs) do
		if message:lower():match(verb) then
			has_action = true
			break
		end
	end
	
	if has_action then
		score = score + 15
	else
		table.insert(issues, "缺乏明确的动作词")
		score = score - 10
	end
	
	-- Specificity
	if message:match("具体") or message:match("详细") or message:match("实现") then
		score = score + 10
	end
	
	-- Avoid vague terms
	local vague_terms = {"修改", "变更", "更新代码", "fix stuff", "update", "change"}
	for _, term in ipairs(vague_terms) do
		if message:lower():match(term) then
			table.insert(issues, "避免使用模糊词汇: " .. term)
			score = score - 5
		end
	end
	
	return {
		score = math.max(0, score),
		max_score = max_score,
		percentage = math.floor((math.max(0, score) / max_score) * 100),
		issues = issues,
		suggestions = suggestions
	}
end

-- Generate refinement suggestions
local function generate_refinement_suggestions(message, git_data)
	local template = string.format([[
作为专业的代码提交消息优化专家，请分析并改进以下提交消息：

当前提交消息:
%s

Git差异信息:
%s

请提供3个改进版本：
1. 简洁版本 - 保持核心信息，更加简洁
2. 详细版本 - 增加技术细节和影响说明
3. 业务版本 - 强调业务价值和用户影响

每个版本要求：
- 遵循常规提交格式 (type(scope): description)
- 标题不超过50字符
- 使用清晰的动作词
- 避免模糊表达
- 突出变更的核心价值

格式：
简洁版本: [提交消息]
详细版本: [提交消息]
业务版本: [提交消息]
]], message, git_data.diff:sub(1, 2000))
	
	return template
end

-- Interactive refinement process
local function interactive_refinement(message, git_data, callback)
	local prompt = generate_refinement_suggestions(message, git_data)
	local data = require('commit_generator').prepare_request_data(prompt, "qwen/qwen-2.5-72b-instruct:free")
	
	vim.notify("正在生成提交消息改进建议...", vim.log.levels.INFO)
	
	require("plenary.curl").post("https://openrouter.ai/api/v1/chat/completions", {
		headers = {
			content_type = "application/json",
			authorization = "Bearer " .. (vim.env.OPENROUTER_API_KEY or require('ai-commit').config.openrouter_api_key),
		},
		body = vim.json.encode(data),
		callback = vim.schedule_wrap(function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if data.choices and #data.choices > 0 then
					local content = data.choices[1].message.content
					
					-- Parse refinement options
					local options = {}
					for version_type in content:gmatch("([^:]+):%s*([^\n]+)") do
						if version_type and version_type ~= "" then
							table.insert(options, version_type)
						end
					end
					
					-- Show options in picker
					if #options > 0 then
						table.insert(options, 1, "原始版本: " .. message)
						table.insert(options, "✨ 手动编辑")
						
						vim.ui.select(options, {
							prompt = "选择改进后的提交消息:",
							format_item = function(item)
								return item
							end,
						}, function(choice)
							if choice then
								if choice:match("^✨") then
									-- Manual editing
									vim.ui.input({
										prompt = "编辑提交消息: ",
										default = message
									}, function(edited)
										if edited then
											callback(edited)
										end
									end)
								else
									local refined_message = choice:gsub("^[^:]*:%s*", "")
									callback(refined_message)
								end
							end
						end)
					else
						vim.notify("无法生成改进建议", vim.log.levels.WARN)
						callback(message)
					end
				else
					vim.notify("未收到改进建议", vim.log.levels.WARN)
					callback(message)
				end
			else
				vim.notify("生成改进建议失败", vim.log.levels.ERROR)
				callback(message)
			end
		end),
	})
end

-- Store refinement in history
local function store_refinement(original, refined, quality_score)
	table.insert(refinement_history, {
		original = original,
		refined = refined,
		quality_score = quality_score,
		timestamp = os.time()
	})
	
	-- Keep only last 50 refinements
	if #refinement_history > 50 then
		table.remove(refinement_history, 1)
	end
end

-- Main refinement interface
function M.refine_commit_message(git_data)
	-- First generate initial commit message
	local commit_generator = require('commit_generator')
	
	local function on_initial_message(initial_message)
		-- Analyze quality
		local quality = analyze_commit_quality(initial_message)
		
		-- Show quality report
		local report = string.format([[
📊 提交消息质量分析

消息: %s

质量评分: %d/%d (%d%%)

❌ 问题:
%s

✅ 建议:
%s

是否需要改进？
]], 
			initial_message,
			quality.score,
			quality.max_score,
			quality.percentage,
			#quality.issues > 0 and table.concat(quality.issues, "\n") or "无问题",
			#quality.suggestions > 0 and table.concat(quality.suggestions, "\n") or "无建议"
		)
		
		vim.notify(report, vim.log.levels.INFO)
		
		if quality.percentage < 80 then
			vim.ui.select({
				"🔧 改进提交消息",
				"✅ 直接使用当前消息",
				"❌ 取消操作"
			}, {
				prompt = "提交消息质量可以改进:",
			}, function(choice)
				if choice and choice:match("🔧") then
					interactive_refinement(initial_message, git_data, function(refined_message)
						store_refinement(initial_message, refined_message, quality.percentage)
						
						-- Commit with refined message
						local Job = require("plenary.job")
						Job:new({
							command = "git",
							args = { "commit", "-m", refined_message },
							on_exit = function(_, return_val)
								if return_val == 0 then
									vim.notify("✅ 提交成功 (已改进): " .. refined_message, vim.log.levels.INFO)
								else
									vim.notify("❌ 提交失败", vim.log.levels.ERROR)
								end
							end,
						}):start()
					end)
				elseif choice and choice:match("✅") then
					-- Use current message
					local Job = require("plenary.job")
					Job:new({
						command = "git",
						args = { "commit", "-m", initial_message },
						on_exit = function(_, return_val)
							if return_val == 0 then
								vim.notify("✅ 提交成功: " .. initial_message, vim.log.levels.INFO)
							else
								vim.notify("❌ 提交失败", vim.log.levels.ERROR)
							end
						end,
					}):start()
				end
			end)
		else
			vim.notify("🎉 提交消息质量优秀！", vim.log.levels.INFO)
			-- Auto commit high quality message
			local Job = require("plenary.job")
			Job:new({
				command = "git",
				args = { "commit", "-m", initial_message },
				on_exit = function(_, return_val)
					if return_val == 0 then
						vim.notify("✅ 提交成功: " .. initial_message, vim.log.levels.INFO)
					else
						vim.notify("❌ 提交失败", vim.log.levels.ERROR)
					end
				end,
			}):start()
		end
	end
	
	-- Generate initial message using existing system
	local config = require('ai-commit').config
	local api_key = config.openrouter_api_key or vim.env.OPENROUTER_API_KEY
	
	if not api_key then
		vim.notify("需要API密钥", vim.log.levels.ERROR)
		return
	end
	
	local git_data_optimized = commit_generator.optimize_git_data(git_data)
	local prompt = require('commit_generator').create_prompt(git_data_optimized, config.language or "zh", config.commit_template)
	local data = commit_generator.prepare_request_data(prompt, config.model)
	
	require("plenary.curl").post("https://openrouter.ai/api/v1/chat/completions", {
		headers = {
			content_type = "application/json",
			authorization = "Bearer " .. api_key,
		},
		body = vim.json.encode(data),
		callback = vim.schedule_wrap(function(response)
			if response.status == 200 then
				local data = vim.json.decode(response.body)
				if data.choices and #data.choices > 0 then
					local message_content = data.choices[1].message.content
					local cleaned_message = message_content:gsub("^%s+", ""):gsub("%s+$", "")
					local first_line = cleaned_message:match("[^\n]+") or cleaned_message
					
					on_initial_message(first_line)
				else
					vim.notify("无法生成初始提交消息", vim.log.levels.ERROR)
				end
			else
				vim.notify("生成初始提交消息失败", vim.log.levels.ERROR)
			end
		end),
	})
end

-- Show refinement history
function M.show_refinement_history()
	if #refinement_history == 0 then
		vim.notify("暂无提交消息改进历史", vim.log.levels.INFO)
		return
	end
	
	local history_items = {}
	for i, item in ipairs(refinement_history) do
		local date = os.date("%Y-%m-%d %H:%M", item.timestamp)
		table.insert(history_items, string.format("[%s] %s → %s (质量: %d%%)", 
			date, item.original:sub(1, 30), item.refined:sub(1, 30), item.quality_score))
	end
	
	vim.ui.select(history_items, {
		prompt = "提交消息改进历史:",
	}, function(choice)
		if choice then
			local index = vim.tbl_filter(function(item) return choice:find(item, 1, true) end, history_items)[1]
			if index then
				for i, item in ipairs(refinement_history) do
					if history_items[i] == choice then
						local detail = string.format([[
改进详情:

原始消息: %s
改进消息: %s
质量评分: %d%%
改进时间: %s
]], item.original, item.refined, item.quality_score, os.date("%Y-%m-%d %H:%M:%S", item.timestamp))
						vim.notify(detail, vim.log.levels.INFO)
						break
					end
				end
			end
		end
	end)
end

return M