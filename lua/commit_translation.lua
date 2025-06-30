local M = {}

-- Supported languages with cultural adaptations
local languages = {
	zh = { name = "中文", culture = "简洁务实，强调技术细节" },
	en = { name = "English", culture = "清晰直接，符合国际惯例" },
	ja = { name = "日本語", culture = "礼貌精确，注重细节" },
	ko = { name = "한국어", culture = "简洁明了，技术导向" },
	es = { name = "Español", culture = "表达丰富，重视团队协作" },
	fr = { name = "Français", culture = "优雅精确，强调逻辑" },
	de = { name = "Deutsch", culture = "严谨详细，工程化思维" },
	ru = { name = "Русский", culture = "技术深入，系统性强" }
}

-- Detect commit message language
local function detect_language(message)
	-- Chinese
	if message:match("[\228-\233]") then
		return "zh"
	end
	
	-- Japanese (Hiragana/Katakana)
	if message:match("[\227-\227]") then
		return "ja"
	end
	
	-- Korean
	if message:match("[\234-\237]") then
		return "ko"
	end
	
	-- Russian (Cyrillic)
	if message:match("[\208-\209]") then
		return "ru"
	end
	
	-- Spanish indicators
	if message:lower():match("ñ") or message:lower():match("ción") then
		return "es"
	end
	
	-- German indicators
	if message:lower():match("ß") or message:lower():match("ü") or message:lower():match("ö") or message:lower():match("ä") then
		return "de"
	end
	
	-- French indicators
	if message:lower():match("ç") or message:lower():match("à") or message:lower():match("é") then
		return "fr"
	end
	
	-- Default to English
	return "en"
end

-- Generate culturally adapted translation
local function generate_translation(message, source_lang, target_lang, git_data)
	local source_culture = languages[source_lang] and languages[source_lang].culture or "通用风格"
	local target_culture = languages[target_lang] and languages[target_lang].culture or "通用风格"
	
	local template = string.format([[
作为专业的代码提交消息翻译专家，请将以下提交消息翻译并适应目标文化：

原始消息: %s
源语言: %s (%s)
目标语言: %s (%s)

Git变更上下文:
%s

翻译要求：
1. 保持技术准确性和常规提交格式
2. 适应目标语言的文化表达习惯
3. 保留原始消息的核心含义和技术细节
4. 使用目标语言社区的常用术语
5. 符合该语言社区的提交消息惯例

请提供3个翻译版本：
版本1: 直译版本 - 忠实原文，保持结构
版本2: 意译版本 - 自然表达，符合目标语言习惯  
版本3: 本地化版本 - 完全适应目标文化，使用地道表达

格式：
直译版本: [翻译结果]
意译版本: [翻译结果]
本地化版本: [翻译结果]
]], 
		message, 
		languages[source_lang].name, 
		source_culture,
		languages[target_lang].name, 
		target_culture,
		git_data.diff:sub(1, 1000)
	)
	
	return template
end

-- Interactive translation process
function M.translate_commit_message(message, git_data)
	local source_lang = detect_language(message)
	
	-- Show language selection
	local lang_options = {}
	for code, info in pairs(languages) do
		if code ~= source_lang then
			table.insert(lang_options, code .. " - " .. info.name)
		end
	end
	
	vim.ui.select(lang_options, {
		prompt = string.format("检测到源语言: %s，选择目标语言:", languages[source_lang].name),
	}, function(choice)
		if not choice then return end
		
		local target_lang = choice:match("^([^%-]+)")
		if target_lang then
			target_lang = target_lang:gsub("%s+", "")
			
			local prompt = generate_translation(message, source_lang, target_lang, git_data)
			local data = require('commit_generator').prepare_request_data(prompt, "qwen/qwen-2.5-72b-instruct:free")
			
			vim.notify("正在翻译提交消息...", vim.log.levels.INFO)
			
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
							
							-- Parse translation options
							local options = {}
							for version_type, translation in content:gmatch("([^:]+):%s*([^\n]+)") do
								if translation and translation ~= "" then
									table.insert(options, version_type .. ": " .. translation)
								end
							end
							
							if #options > 0 then
								table.insert(options, 1, "原始消息: " .. message)
								
								vim.ui.select(options, {
									prompt = "选择翻译版本:",
								}, function(selected)
									if selected then
										local translated = selected:gsub("^[^:]*:%s*", "")
										
										-- Show comparison
										local comparison = string.format([[
🌐 翻译结果对比

原始消息 (%s): %s
翻译消息 (%s): %s

是否使用翻译后的消息进行提交？
]], languages[source_lang].name, message, languages[target_lang].name, translated)
										
										vim.notify(comparison, vim.log.levels.INFO)
										
										vim.ui.select({
											"✅ 使用翻译消息提交",
											"📝 继续编辑", 
											"❌ 取消操作"
										}, {
											prompt = "选择操作:",
										}, function(action)
											if action and action:match("✅") then
												-- Commit with translated message
												local Job = require("plenary.job")
												Job:new({
													command = "git",
													args = { "commit", "-m", translated },
													on_exit = function(_, return_val)
														if return_val == 0 then
															vim.notify("✅ 提交成功: " .. translated, vim.log.levels.INFO)
														else
															vim.notify("❌ 提交失败", vim.log.levels.ERROR)
														end
													end,
												}):start()
											elseif action and action:match("📝") then
												vim.ui.input({
													prompt = "编辑提交消息: ",
													default = translated
												}, function(edited)
													if edited then
														local Job = require("plenary.job")
														Job:new({
															command = "git",
															args = { "commit", "-m", edited },
															on_exit = function(_, return_val)
																if return_val == 0 then
																	vim.notify("✅ 提交成功: " .. edited, vim.log.levels.INFO)
																else
																	vim.notify("❌ 提交失败", vim.log.levels.ERROR)
																end
															end,
														}):start()
													end
												end)
											end
										end)
									end
								end)
							else
								vim.notify("无法生成翻译选项", vim.log.levels.WARN)
							end
						else
							vim.notify("未收到翻译结果", vim.log.levels.WARN)
						end
					else
						vim.notify("翻译失败", vim.log.levels.ERROR)
					end
				end),
			})
		end
	end)
end

-- Batch translate commit history
function M.translate_commit_history(target_lang, count)
	count = count or 10
	
	local commits = vim.fn.system(string.format("git log --pretty=format:'%%h|%%s' -n %d", count))
	if commits == "" then
		vim.notify("没有找到提交历史", vim.log.levels.WARN)
		return
	end
	
	local commit_list = vim.split(commits, "\n")
	local translated_commits = {}
	
	vim.notify(string.format("开始翻译最近%d个提交到%s...", count, languages[target_lang].name), vim.log.levels.INFO)
	
	local function translate_next(index)
		if index > #commit_list then
			-- Show results
			local result = "📚 提交历史翻译结果:\n\n"
			for i, item in ipairs(translated_commits) do
				result = result .. string.format("%s\n原始: %s\n翻译: %s\n\n", item.hash, item.original, item.translated)
			end
			vim.notify(result, vim.log.levels.INFO)
			return
		end
		
		local commit_line = commit_list[index]
		local hash, message = commit_line:match("([^|]+)|(.+)")
		if hash and message then
			local source_lang = detect_language(message)
			if source_lang ~= target_lang then
				local git_data = { diff = "", commits = "" } -- Simplified for batch processing
				local prompt = generate_translation(message, source_lang, target_lang, git_data)
				local data = require('commit_generator').prepare_request_data(prompt, "qwen/qwen-2.5-72b-instruct:free")
				
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
								local translated = content:match("意译版本:%s*([^\n]+)") or content:match("([^\n]+)")
								
								table.insert(translated_commits, {
									hash = hash,
									original = message,
									translated = translated or message
								})
							end
						end
						
						-- Continue with next commit
						translate_next(index + 1)
					end),
				})
			else
				-- Same language, skip
				table.insert(translated_commits, {
					hash = hash,
					original = message,
					translated = message .. " (未翻译-相同语言)"
				})
				translate_next(index + 1)
			end
		else
			translate_next(index + 1)
		end
	end
	
	translate_next(1)
end

-- Language learning from project
function M.learn_project_language_patterns()
	local commits = vim.fn.system("git log --pretty=format:'%s' -n 50")
	if commits == "" then
		vim.notify("没有找到提交历史", vim.log.levels.WARN)
		return
	end
	
	local commit_list = vim.split(commits, "\n")
	local language_stats = {}
	local patterns = {}
	
	for _, commit in ipairs(commit_list) do
		if commit ~= "" then
			local lang = detect_language(commit)
			language_stats[lang] = (language_stats[lang] or 0) + 1
			
			if not patterns[lang] then
				patterns[lang] = {}
			end
			table.insert(patterns[lang], commit)
		end
	end
	
	-- Show language distribution
	local report = "📊 项目语言使用模式分析:\n\n"
	for lang, count in pairs(language_stats) do
		local percentage = math.floor((count / #commit_list) * 100)
		report = report .. string.format("%s: %d次 (%d%%)\n", languages[lang].name, count, percentage)
	end
	
	-- Find dominant language
	local dominant_lang = nil
	local max_count = 0
	for lang, count in pairs(language_stats) do
		if count > max_count then
			max_count = count
			dominant_lang = lang
		end
	end
	
	if dominant_lang then
		report = report .. string.format("\n🎯 主要语言: %s\n", languages[dominant_lang].name)
		report = report .. string.format("建议: 使用%s作为默认提交语言以保持一致性", languages[dominant_lang].name)
	end
	
	vim.notify(report, vim.log.levels.INFO)
	
	return {
		stats = language_stats,
		patterns = patterns,
		dominant = dominant_lang
	}
end

return M