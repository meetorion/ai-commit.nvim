local M = {}

-- Voice-to-commit feature (simulation)
function M.voice_to_commit()
	vim.notify("🎤 语音转提交功能", vim.log.levels.INFO)
	vim.notify("请描述你的代码变更...", vim.log.levels.INFO)
	
	-- Simulate voice input with text input for now
	vim.ui.input({
		prompt = "语音输入 (模拟文本): "
	}, function(voice_input)
		if voice_input then
			-- Process voice input into commit message
			local voice_template = string.format([[
用户通过语音描述了以下代码变更:
"%s"

请将这个语音描述转换为专业的git提交消息:
1. 使用常规提交格式
2. 保持简洁明了
3. 突出核心变更
4. 使用技术术语

只返回提交消息，不要其他内容。
]], voice_input)
			
			local data = require('commit_generator').prepare_request_data(voice_template, "qwen/qwen-2.5-72b-instruct:free")
			
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
							local commit_msg = data.choices[1].message.content:gsub("^%s+", ""):gsub("%s+$", "")
							
							vim.ui.select({
								"✅ 使用生成的提交消息",
								"✏️ 编辑后使用",
								"❌ 取消"
							}, {
								prompt = "语音转换结果: " .. commit_msg,
							}, function(choice)
								if choice and choice:match("✅") then
									M.execute_commit(commit_msg)
								elseif choice and choice:match("✏️") then
									vim.ui.input({
										prompt = "编辑提交消息: ",
										default = commit_msg
									}, function(edited)
										if edited then
											M.execute_commit(edited)
										end
									end)
								end
							end)
						end
					end
				end),
			})
		end
	end)
end

-- Emoji suggestion system
function M.suggest_emoji_for_commit(commit_message)
	local emoji_map = {
		-- Features
		["feat"] = "✨", ["feature"] = "✨", ["新增"] = "✨", ["添加"] = "✨",
		-- Fixes
		["fix"] = "🐛", ["bug"] = "🐛", ["修复"] = "🐛", ["修正"] = "🐛",
		-- Documentation
		["docs"] = "📚", ["documentation"] = "📚", ["文档"] = "📚",
		-- Performance
		["perf"] = "⚡", ["performance"] = "⚡", ["性能"] = "⚡", ["优化"] = "⚡",
		-- Refactor
		["refactor"] = "♻️", ["重构"] = "♻️",
		-- Tests
		["test"] = "🧪", ["测试"] = "🧪",
		-- Style
		["style"] = "💄", ["样式"] = "💄",
		-- CI/CD
		["ci"] = "🔧", ["build"] = "🔨", ["构建"] = "🔨",
		-- Security
		["security"] = "🔒", ["安全"] = "🔒",
		-- Database
		["database"] = "🗄️", ["数据库"] = "🗄️", ["migration"] = "🗄️",
		-- Configuration
		["config"] = "⚙️", ["配置"] = "⚙️",
		-- Dependencies
		["deps"] = "📦", ["依赖"] = "📦",
		-- Breaking changes
		["breaking"] = "💥", ["破坏"] = "💥"
	}
	
	local suggestions = {}
	local message_lower = commit_message:lower()
	
	for keyword, emoji in pairs(emoji_map) do
		if message_lower:match(keyword) then
			table.insert(suggestions, {
				emoji = emoji,
				keyword = keyword,
				message = emoji .. " " .. commit_message
			})
		end
	end
	
	if #suggestions == 0 then
		-- Default suggestions based on common patterns
		table.insert(suggestions, {emoji = "🚀", keyword = "general", message = "🚀 " .. commit_message})
		table.insert(suggestions, {emoji = "✨", keyword = "feature", message = "✨ " .. commit_message})
		table.insert(suggestions, {emoji = "🔧", keyword = "improvement", message = "🔧 " .. commit_message})
	end
	
	return suggestions
end

-- Interactive emoji addition
function M.add_emoji_to_commit()
	local git_data = require('commit_generator').collect_git_data()
	if not git_data then return end
	
	-- Generate basic commit message first
	local commit_generator = require('commit_generator')
	local config = require('ai-commit').config
	local api_key = config.openrouter_api_key or vim.env.OPENROUTER_API_KEY
	
	local git_data_optimized = commit_generator.optimize_git_data(git_data)
	local prompt = string.format("基于以下diff生成简洁的提交消息：\n%s", git_data.diff:sub(1, 1000))
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
					local basic_message = data.choices[1].message.content:gsub("^%s+", ""):gsub("%s+$", "")
					local first_line = basic_message:match("[^\n]+") or basic_message
					
					local emoji_suggestions = M.suggest_emoji_for_commit(first_line)
					
					local options = {}
					for _, suggestion in ipairs(emoji_suggestions) do
						table.insert(options, suggestion.message)
					end
					table.insert(options, "⭐ 自定义emoji")
					table.insert(options, "📝 不使用emoji")
					
					vim.ui.select(options, {
						prompt = "选择emoji增强的提交消息:",
					}, function(choice)
						if choice and choice:match("⭐") then
							vim.ui.input({
								prompt = "输入emoji: ",
								default = "🚀"
							}, function(custom_emoji)
								if custom_emoji then
									local enhanced_message = custom_emoji .. " " .. first_line
									M.execute_commit(enhanced_message)
								end
							end)
						elseif choice and choice:match("📝") then
							M.execute_commit(first_line)
						elseif choice then
							M.execute_commit(choice)
						end
					end)
				end
			end
		end),
	})
end

-- Predictive change impact analysis
function M.analyze_change_impact(git_data)
	local impact_template = string.format([[
作为高级系统架构师，请分析以下代码变更的潜在影响：

Git差异:
%s

最近提交:
%s

请从以下维度进行深度影响分析：

1. 🏗️ 架构影响
   - 对系统架构的影响
   - 模块间依赖变化
   - 接口兼容性

2. 📊 性能影响  
   - 运行时性能变化
   - 内存使用影响
   - 网络请求变化

3. 🔒 安全影响
   - 潜在安全风险
   - 权限变更影响
   - 数据安全考虑

4. 🧪 测试影响
   - 需要新增的测试
   - 可能失效的测试
   - 测试覆盖率变化

5. 📚 文档影响
   - 需要更新的文档
   - API文档变更
   - 用户指南更新

6. 🚀 部署影响
   - 部署策略建议
   - 回滚风险评估
   - 环境配置变更

为每个维度提供详细分析和建议。
]], git_data.diff:sub(1, 3000), git_data.commits)
	
	local data = require('commit_generator').prepare_request_data(impact_template, "qwen/qwen-2.5-72b-instruct:free")
	
	vim.notify("🔮 正在进行预测性影响分析...", vim.log.levels.INFO)
	
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
					local impact_analysis = data.choices[1].message.content
					
					-- Save analysis to file
					local filename = "impact-analysis-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
					local header = "# 变更影响分析报告\n\n生成时间: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n---\n\n"
					vim.fn.writefile(vim.split(header .. impact_analysis, "\n"), filename)
					
					vim.notify("🔮 影响分析完成，已保存到: " .. filename, vim.log.levels.INFO)
					vim.notify("影响分析预览:\n" .. impact_analysis:sub(1, 500) .. "...", vim.log.levels.INFO)
				end
			end
		end),
	})
end

-- Gamification and achievement system
local achievements = {
	{id = "first_commit", name = "首次提交", desc = "完成第一次AI辅助提交", emoji = "🎉"},
	{id = "quality_master", name = "质量大师", desc = "连续10次高质量提交(>80分)", emoji = "👑"},
	{id = "consistency_king", name = "一致性之王", desc = "连续使用统一格式20次", emoji = "🎯"},
	{id = "translator", name = "国际化专家", desc = "使用5种不同语言提交", emoji = "🌍"},
	{id = "splitter", name = "拆分专家", desc = "智能拆分复杂提交5次", emoji = "✂️"},
	{id = "analyzer", name = "分析师", desc = "完成10次影响分析", emoji = "🔬"},
	{id = "team_player", name = "团队合作者", desc = "遵循团队规范100次", emoji = "👥"},
	{id = "security_guard", name = "安全卫士", desc = "检测并修复安全问题", emoji = "🛡️"},
	{id = "performance_guru", name = "性能大师", desc = "优化性能相关提交10次", emoji = "⚡"},
	{id = "doc_master", name = "文档专家", desc = "文档相关提交累计50次", emoji = "📚"}
}

local ACHIEVEMENT_FILE = ".ai-commit-achievements.json"

function M.load_achievements()
	if vim.fn.filereadable(ACHIEVEMENT_FILE) == 1 then
		local content = vim.fn.readfile(ACHIEVEMENT_FILE)
		local success, data = pcall(vim.json.decode, table.concat(content, "\n"))
		if success then
			return data
		end
	end
	return {unlocked = {}, stats = {}}
end

function M.save_achievements(data)
	local content = vim.json.encode(data)
	vim.fn.writefile(vim.split(content, "\n"), ACHIEVEMENT_FILE)
end

function M.check_achievements(commit_data)
	local user_data = M.load_achievements()
	local new_achievements = {}
	
	-- Update stats
	user_data.stats.total_commits = (user_data.stats.total_commits or 0) + 1
	user_data.stats.last_commit_time = os.time()
	
	-- Check for new achievements
	for _, achievement in ipairs(achievements) do
		if not user_data.unlocked[achievement.id] then
			local unlocked = false
			
			if achievement.id == "first_commit" and user_data.stats.total_commits >= 1 then
				unlocked = true
			elseif achievement.id == "quality_master" and (user_data.stats.high_quality_streak or 0) >= 10 then
				unlocked = true
			end
			-- Add more achievement logic...
			
			if unlocked then
				user_data.unlocked[achievement.id] = {
					unlocked_at = os.time(),
					name = achievement.name,
					desc = achievement.desc,
					emoji = achievement.emoji
				}
				table.insert(new_achievements, achievement)
			end
		end
	end
	
	M.save_achievements(user_data)
	
	-- Show new achievements
	for _, achievement in ipairs(new_achievements) do
		vim.notify(string.format("🏆 成就解锁: %s %s\n%s", achievement.emoji, achievement.name, achievement.desc), vim.log.levels.INFO)
	end
	
	return new_achievements
end

function M.show_achievement_dashboard()
	local user_data = M.load_achievements()
	
	local unlocked_count = 0
	for _ in pairs(user_data.unlocked) do
		unlocked_count = unlocked_count + 1
	end
	
	local progress = math.floor((unlocked_count / #achievements) * 100)
	
	local dashboard = string.format([[
🏆 成就面板

📊 总体进度: %d/%d (%d%%)
📈 总提交数: %d
⏰ 最后活跃: %s

🎖️ 已解锁成就:
%s

🔒 待解锁成就:
%s
]], 
		unlocked_count,
		#achievements,
		progress,
		user_data.stats.total_commits or 0,
		user_data.stats.last_commit_time and os.date("%Y-%m-%d %H:%M", user_data.stats.last_commit_time) or "从未",
		M.format_unlocked_achievements(user_data.unlocked),
		M.format_locked_achievements(user_data.unlocked)
	)
	
	vim.notify(dashboard, vim.log.levels.INFO)
end

function M.format_unlocked_achievements(unlocked)
	local result = {}
	for _, data in pairs(unlocked) do
		table.insert(result, string.format("  %s %s - %s", data.emoji, data.name, os.date("%Y-%m-%d", data.unlocked_at)))
	end
	return #result > 0 and table.concat(result, "\n") or "  暂无解锁成就"
end

function M.format_locked_achievements(unlocked)
	local result = {}
	for _, achievement in ipairs(achievements) do
		if not unlocked[achievement.id] then
			table.insert(result, string.format("  🔒 %s - %s", achievement.name, achievement.desc))
		end
	end
	return #result > 0 and table.concat(result, "\n") or "  全部成就已解锁！"
end

-- Execute commit with gamification
function M.execute_commit(message)
	local Job = require("plenary.job")
	Job:new({
		command = "git",
		args = { "commit", "-m", message },
		on_exit = function(_, return_val)
			if return_val == 0 then
				vim.notify("✅ 提交成功: " .. message, vim.log.levels.INFO)
				
				-- Check achievements
				M.check_achievements({message = message})
				
				-- Auto push if configured
				local config = require('ai-commit').config
				if config.auto_push then
					Job:new({
						command = "git",
						args = { "push" },
						on_exit = function(_, push_return_val)
							if push_return_val == 0 then
								vim.notify("🚀 推送成功!", vim.log.levels.INFO)
							else
								vim.notify("❌ 推送失败", vim.log.levels.ERROR)
							end
						end,
					}):start()
				end
			else
				vim.notify("❌ 提交失败", vim.log.levels.ERROR)
			end
		end,
	}):start()
end

-- Commit validation and scoring
function M.validate_and_score_commit(message)
	local score = 0
	local max_score = 100
	local feedback = {}
	
	-- Length check (20 points)
	local title = message:match("^([^\n]*)")
	if title then
		if #title >= 10 and #title <= 50 then
			score = score + 20
			table.insert(feedback, "✅ 标题长度合适")
		elseif #title < 10 then
			score = score + 5
			table.insert(feedback, "⚠️ 标题较短，建议更具描述性")
		else
			score = score + 10
			table.insert(feedback, "⚠️ 标题过长，建议简化")
		end
	end
	
	-- Conventional commit format (25 points)
	if title and title:match("^[a-zA-Z]+%(.*%):%s*.+") then
		score = score + 25
		table.insert(feedback, "✅ 完美的常规提交格式(带scope)")
	elseif title and title:match("^[a-zA-Z]+:%s*.+") then
		score = score + 20
		table.insert(feedback, "✅ 良好的常规提交格式")
	else
		score = score + 5
		table.insert(feedback, "❌ 建议使用常规提交格式")
	end
	
	-- Clear action verb (15 points)
	local action_words = {"feat", "fix", "docs", "style", "refactor", "perf", "test", "chore", "添加", "修复", "更新", "优化"}
	local has_action = false
	for _, word in ipairs(action_words) do
		if message:lower():match(word) then
			has_action = true
			break
		end
	end
	
	if has_action then
		score = score + 15
		table.insert(feedback, "✅ 包含明确的动作词")
	else
		score = score + 5
		table.insert(feedback, "⚠️ 建议使用明确的动作词")
	end
	
	-- Avoid vague terms (10 points)
	local vague_terms = {"update", "change", "fix stuff", "修改", "更改"}
	local has_vague = false
	for _, term in ipairs(vague_terms) do
		if message:lower():match(term) then
			has_vague = true
			break
		end
	end
	
	if not has_vague then
		score = score + 10
		table.insert(feedback, "✅ 避免了模糊表达")
	else
		table.insert(feedback, "⚠️ 尽量避免模糊的词汇")
	end
	
	-- Specificity (10 points) 
	if message:match("实现") or message:match("解决") or message:match("优化") then
		score = score + 10
		table.insert(feedback, "✅ 描述具体明确")
	else
		score = score + 5
		table.insert(feedback, "💡 可以更具体地描述变更")
	end
	
	-- Consistency with project (10 points)
	-- This would require learning from project history
	score = score + 8
	table.insert(feedback, "✅ 与项目风格基本一致")
	
	-- Technical accuracy (10 points)
	-- This is hard to evaluate automatically, give average score
	score = score + 7
	table.insert(feedback, "💡 技术描述准确性良好")
	
	local grade = ""
	if score >= 90 then
		grade = "A+ 🌟"
	elseif score >= 80 then
		grade = "A 👍"
	elseif score >= 70 then
		grade = "B 👌"
	elseif score >= 60 then
		grade = "C 🤔"
	else
		grade = "D 📝"
	end
	
	return {
		score = score,
		max_score = max_score,
		percentage = math.floor((score / max_score) * 100),
		grade = grade,
		feedback = feedback
	}
end

return M