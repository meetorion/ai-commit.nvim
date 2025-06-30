local M = {}

-- Analyze commits for changelog generation
local function analyze_commits_for_changelog(since_tag, format_type)
	format_type = format_type or "conventional"
	
	local git_command = since_tag and 
		string.format("git log %s..HEAD --pretty=format:'%%h|%%s|%%an|%%ad' --date=short", since_tag) or
		"git log --pretty=format:'%h|%s|%an|%ad' --date=short -n 50"
	
	local commits_output = vim.fn.system(git_command)
	if commits_output == "" then
		return {}
	end
	
	local commits = {}
	local categories = {
		features = {},
		fixes = {},
		improvements = {},
		performance = {},
		docs = {},
		tests = {},
		chores = {},
		breaking = {},
		security = {},
		deprecated = {}
	}
	
	for line in commits_output:gmatch("[^\n]+") do
		local hash, message, author, date = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
		if hash and message then
			local commit = {
				hash = hash,
				message = message,
				author = author,
				date = date,
				category = "chores" -- default
			}
			
			-- Categorize commit
			local msg_lower = message:lower()
			if msg_lower:match("^feat") or msg_lower:match("新增") or msg_lower:match("添加") then
				commit.category = "features"
				table.insert(categories.features, commit)
			elseif msg_lower:match("^fix") or msg_lower:match("修复") or msg_lower:match("修正") then
				commit.category = "fixes"
				table.insert(categories.fixes, commit)
			elseif msg_lower:match("^perf") or msg_lower:match("性能") or msg_lower:match("优化") then
				commit.category = "performance"
				table.insert(categories.performance, commit)
			elseif msg_lower:match("^docs") or msg_lower:match("文档") then
				commit.category = "docs"
				table.insert(categories.docs, commit)
			elseif msg_lower:match("^test") or msg_lower:match("测试") then
				commit.category = "tests"
				table.insert(categories.tests, commit)
			elseif msg_lower:match("breaking") or msg_lower:match("破坏") then
				commit.category = "breaking"
				table.insert(categories.breaking, commit)
			elseif msg_lower:match("security") or msg_lower:match("安全") then
				commit.category = "security"
				table.insert(categories.security, commit)
			elseif msg_lower:match("deprecated") or msg_lower:match("废弃") then
				commit.category = "deprecated"
				table.insert(categories.deprecated, commit)
			elseif msg_lower:match("^refactor") or msg_lower:match("重构") or msg_lower:match("改进") then
				commit.category = "improvements"
				table.insert(categories.improvements, commit)
			else
				table.insert(categories.chores, commit)
			end
			
			table.insert(commits, commit)
		end
	end
	
	return {
		commits = commits,
		categories = categories,
		total_commits = #commits,
		date_range = {
			from = since_tag or "项目开始",
			to = "HEAD"
		}
	}
end

-- Generate AI-enhanced changelog
local function generate_ai_changelog(commit_data, changelog_type, target_audience)
	changelog_type = changelog_type or "release_notes"
	target_audience = target_audience or "developers"
	
	local template = string.format([[
作为专业的技术文档专家，请基于以下提交数据生成高质量的变更日志：

提交统计:
- 总提交数: %d
- 版本范围: %s 到 %s
- 新功能: %d 个
- Bug修复: %d 个  
- 性能优化: %d 个
- 文档更新: %d 个
- 破坏性变更: %d 个

目标类型: %s
目标受众: %s

分类详情:
🚀 新功能:
%s

🐛 Bug修复:
%s

⚡ 性能优化:
%s

📚 文档更新:
%s

⚠️ 破坏性变更:
%s

🔒 安全更新:
%s

请生成以下格式的变更日志：
1. 版本标题和发布日期
2. 重要变更概述
3. 分类详细列表
4. 升级指导（如有破坏性变更）
5. 感谢贡献者

要求：
- 使用清晰、专业的语言
- 突出重要变更的业务价值
- 为破坏性变更提供迁移指导
- 包含适当的emoji增强可读性
- 遵循语义化版本规范
]], 
		commit_data.total_commits,
		commit_data.date_range.from,
		commit_data.date_range.to,
		#commit_data.categories.features,
		#commit_data.categories.fixes,
		#commit_data.categories.performance,
		#commit_data.categories.docs,
		#commit_data.categories.breaking,
		changelog_type,
		target_audience,
		M.format_commits_for_ai(commit_data.categories.features),
		M.format_commits_for_ai(commit_data.categories.fixes),
		M.format_commits_for_ai(commit_data.categories.performance),
		M.format_commits_for_ai(commit_data.categories.docs),
		M.format_commits_for_ai(commit_data.categories.breaking),
		M.format_commits_for_ai(commit_data.categories.security)
	)
	
	return template
end

-- Format commits for AI processing
function M.format_commits_for_ai(commits)
	if #commits == 0 then
		return "无相关变更"
	end
	
	local formatted = {}
	for _, commit in ipairs(commits) do
		table.insert(formatted, string.format("- %s (%s by %s)", commit.message, commit.hash, commit.author))
	end
	
	return table.concat(formatted, "\n")
end

-- Interactive changelog generation
function M.generate_interactive_changelog()
	-- Get available tags
	local tags_output = vim.fn.system("git tag --sort=-version:refname")
	local tags = {}
	
	if tags_output ~= "" then
		for tag in tags_output:gmatch("[^\n]+") do
			table.insert(tags, tag)
		end
	end
	
	-- Add option for no baseline
	table.insert(tags, 1, "从头开始")
	
	vim.ui.select(tags, {
		prompt = "选择变更日志的起始版本:",
	}, function(selected_tag)
		if not selected_tag then return end
		
		local since_tag = selected_tag == "从头开始" and nil or selected_tag
		
		-- Select changelog type
		vim.ui.select({
			"🎉 发布说明 (Release Notes)",
			"📋 详细变更日志 (Detailed Changelog)", 
			"📊 开发者更新 (Developer Update)",
			"👥 用户通知 (User Notification)",
			"🔄 迁移指南 (Migration Guide)"
		}, {
			prompt = "选择变更日志类型:",
		}, function(changelog_type_choice)
			if not changelog_type_choice then return end
			
			local changelog_type = changelog_type_choice:match("%((.+)%)")
			
			-- Select target audience
			vim.ui.select({
				"👨‍💻 开发者 (Developers)",
				"👥 最终用户 (End Users)",
				"🏢 项目管理者 (Project Managers)",
				"🔧 运维团队 (DevOps Team)"
			}, {
				prompt = "选择目标受众:",
			}, function(audience_choice)
				if not audience_choice then return end
				
				local target_audience = audience_choice:match("%((.+)%)")
				
				vim.notify("正在分析提交历史并生成变更日志...", vim.log.levels.INFO)
				
				-- Analyze commits
				local commit_data = analyze_commits_for_changelog(since_tag)
				
				if commit_data.total_commits == 0 then
					vim.notify("没有找到提交记录", vim.log.levels.WARN)
					return
				end
				
				-- Generate AI changelog
				local prompt = generate_ai_changelog(commit_data, changelog_type, target_audience)
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
								local changelog_content = data.choices[1].message.content
								
								-- Show generated changelog
								vim.ui.select({
									"📋 查看变更日志",
									"💾 保存到文件",
									"📤 复制到剪贴板", 
									"✏️ 编辑后保存",
									"🔄 重新生成"
								}, {
									prompt = "变更日志生成完成，选择操作:",
								}, function(action)
									if action and action:match("📋") then
										vim.notify("📋 生成的变更日志:\n\n" .. changelog_content, vim.log.levels.INFO)
									elseif action and action:match("💾") then
										M.save_changelog_to_file(changelog_content, since_tag)
									elseif action and action:match("📤") then
										vim.fn.setreg("+", changelog_content)
										vim.notify("变更日志已复制到剪贴板", vim.log.levels.INFO)
									elseif action and action:match("✏️") then
										M.edit_and_save_changelog(changelog_content, since_tag)
									elseif action and action:match("🔄") then
										M.generate_interactive_changelog() -- Recursive call
									end
								end)
							else
								vim.notify("未能生成变更日志", vim.log.levels.ERROR)
							end
						else
							vim.notify("变更日志生成失败", vim.log.levels.ERROR)
						end
					end),
				})
			end)
		end)
	end)
end

-- Save changelog to file
function M.save_changelog_to_file(content, since_tag)
	local filename = "CHANGELOG-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
	local header = string.format("# 变更日志\n\n生成时间: %s\n基于版本: %s\n\n---\n\n", 
		os.date("%Y-%m-%d %H:%M:%S"), 
		since_tag or "项目开始"
	)
	
	local full_content = header .. content
	vim.fn.writefile(vim.split(full_content, "\n"), filename)
	vim.notify("变更日志已保存到: " .. filename, vim.log.levels.INFO)
end

-- Edit and save changelog
function M.edit_and_save_changelog(content, since_tag)
	-- Create a temporary buffer for editing
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
	vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
	
	-- Open in split window
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, buf)
	
	-- Add autocmd to save when buffer is written
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local edited_content = table.concat(lines, "\n")
			M.save_changelog_to_file(edited_content, since_tag)
			vim.api.nvim_buf_delete(buf, { force = true })
		end,
	})
	
	vim.notify("在此缓冲区编辑变更日志，保存时将自动写入文件", vim.log.levels.INFO)
end

-- Generate release notes specifically
function M.generate_release_notes(version, is_prerelease)
	is_prerelease = is_prerelease or false
	
	-- Get latest tag for comparison
	local latest_tag = vim.fn.system("git describe --tags --abbrev=0"):gsub("\n", "")
	if latest_tag == "" then
		latest_tag = nil
	end
	
	local commit_data = analyze_commits_for_changelog(latest_tag)
	
	if commit_data.total_commits == 0 then
		vim.notify("没有新的提交用于生成发布说明", vim.log.levels.WARN)
		return
	end
	
	local release_template = string.format([[
作为发布经理，请为版本 %s 生成专业的发布说明：

版本信息:
- 版本号: %s
- 类型: %s
- 基于标签: %s
- 提交数量: %d

变更统计:
- 新功能: %d 个
- Bug修复: %d 个
- 性能优化: %d 个
- 破坏性变更: %d 个

详细变更:
%s

请生成包含以下部分的发布说明：
1. 版本概述和亮点
2. 新功能详述
3. Bug修复列表
4. 性能改进
5. 破坏性变更说明
6. 升级指导
7. 下载链接模板
8. 感谢贡献者

格式要求：
- 使用Markdown格式
- 突出重要功能
- 为破坏性变更提供清晰的迁移路径
- 包含适当的emoji和徽章
]], 
		version,
		version,
		is_prerelease and "预发布版本" or "正式版本",
		latest_tag or "首次发布",
		commit_data.total_commits,
		#commit_data.categories.features,
		#commit_data.categories.fixes,
		#commit_data.categories.performance,
		#commit_data.categories.breaking,
		vim.inspect(commit_data.categories)
	)
	
	local data = require('commit_generator').prepare_request_data(release_template, "qwen/qwen-2.5-72b-instruct:free")
	
	vim.notify("正在生成 " .. version .. " 版本的发布说明...", vim.log.levels.INFO)
	
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
					local release_notes = data.choices[1].message.content
					
					-- Save release notes
					local filename = "RELEASE-NOTES-" .. version:gsub("%.", "-") .. ".md"
					vim.fn.writefile(vim.split(release_notes, "\n"), filename)
					
					vim.notify("🎉 " .. version .. " 发布说明已生成: " .. filename, vim.log.levels.INFO)
					vim.notify("发布说明预览:\n" .. release_notes:sub(1, 500) .. "...", vim.log.levels.INFO)
				else
					vim.notify("发布说明生成失败", vim.log.levels.ERROR)
				end
			else
				vim.notify("API调用失败", vim.log.levels.ERROR)
			end
		end),
	})
end

-- Automatically suggest next version based on changes
function M.suggest_next_version()
	local current_version = vim.fn.system("git describe --tags --abbrev=0"):gsub("\n", "")
	if current_version == "" then
		current_version = "0.0.0"
	end
	
	local commit_data = analyze_commits_for_changelog()
	
	local has_breaking = #commit_data.categories.breaking > 0
	local has_features = #commit_data.categories.features > 0
	local has_fixes = #commit_data.categories.fixes > 0
	
	local suggestion
	if has_breaking then
		suggestion = "major"
	elseif has_features then
		suggestion = "minor" 
	elseif has_fixes then
		suggestion = "patch"
	else
		suggestion = "patch"
	end
	
	local version_parts = {}
	for part in current_version:gmatch("[^%.]+") do
		table.insert(version_parts, tonumber(part) or 0)
	end
	
	while #version_parts < 3 do
		table.insert(version_parts, 0)
	end
	
	if suggestion == "major" then
		version_parts[1] = version_parts[1] + 1
		version_parts[2] = 0
		version_parts[3] = 0
	elseif suggestion == "minor" then
		version_parts[2] = version_parts[2] + 1
		version_parts[3] = 0
	else
		version_parts[3] = version_parts[3] + 1
	end
	
	local suggested_version = table.concat(version_parts, ".")
	
	local report = string.format([[
🏷️ 版本建议分析

当前版本: %s
建议版本: %s
建议类型: %s

变更分析:
- 破坏性变更: %d 个 %s
- 新功能: %d 个 %s
- Bug修复: %d 个 %s

%s
]], 
		current_version,
		suggested_version,
		suggestion,
		#commit_data.categories.breaking, has_breaking and "🔴" or "✅",
		#commit_data.categories.features, has_features and "🟡" or "⚪",
		#commit_data.categories.fixes, has_fixes and "🟢" or "⚪",
		has_breaking and "⚠️ 建议主版本升级" or has_features and "💡 建议次版本升级" or "🔧 建议补丁版本升级"
	)
	
	vim.notify(report, vim.log.levels.INFO)
	
	vim.ui.select({
		"✅ 使用建议版本: " .. suggested_version,
		"✏️ 手动输入版本号",
		"📋 生成发布说明",
		"❌ 取消操作"
	}, {
		prompt = "版本号建议:",
	}, function(choice)
		if choice and choice:match("✅") then
			M.generate_release_notes(suggested_version, false)
		elseif choice and choice:match("✏️") then
			vim.ui.input({
				prompt = "输入版本号: ",
				default = suggested_version
			}, function(version)
				if version then
					M.generate_release_notes(version, false)
				end
			end)
		elseif choice and choice:match("📋") then
			M.generate_interactive_changelog()
		end
	end)
end

return M