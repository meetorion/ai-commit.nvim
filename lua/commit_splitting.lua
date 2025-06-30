local M = {}

-- Analyze diff complexity and suggest splitting
local function analyze_diff_complexity(diff_content)
	local complexity = {
		total_lines = 0,
		files_changed = 0,
		additions = 0,
		deletions = 0,
		file_types = {},
		logical_units = {},
		should_split = false,
		split_suggestions = {}
	}
	
	-- Count basic metrics
	local files = {}
	local current_file = nil
	
	for line in diff_content:gmatch("[^\n]+") do
		complexity.total_lines = complexity.total_lines + 1
		
		if line:match("^diff --git") then
			current_file = line:match("b/(.+)$")
			if current_file and not files[current_file] then
				files[current_file] = {
					additions = 0,
					deletions = 0,
					file_type = current_file:match("%.([^%.]+)$") or "unknown"
				}
				complexity.files_changed = complexity.files_changed + 1
			end
		elseif line:match("^%+") and not line:match("^%+%+%+") then
			complexity.additions = complexity.additions + 1
			if current_file then
				files[current_file].additions = files[current_file].additions + 1
			end
		elseif line:match("^%-") and not line:match("^%-%-%- ") then
			complexity.deletions = complexity.deletions + 1
			if current_file then
				files[current_file].deletions = files[current_file].deletions + 1
			end
		end
	end
	
	-- Analyze file types
	for file, data in pairs(files) do
		local file_type = data.file_type
		complexity.file_types[file_type] = (complexity.file_types[file_type] or 0) + 1
	end
	
	-- Determine if splitting is needed
	if complexity.files_changed > 5 then
		complexity.should_split = true
		table.insert(complexity.split_suggestions, "文件数量过多 (" .. complexity.files_changed .. " 个文件)")
	end
	
	if complexity.additions + complexity.deletions > 200 then
		complexity.should_split = true
		table.insert(complexity.split_suggestions, "变更行数过多 (" .. (complexity.additions + complexity.deletions) .. " 行)")
	end
	
	-- Check for mixed concerns
	local has_code = complexity.file_types.lua or complexity.file_types.js or complexity.file_types.py or complexity.file_types.go
	local has_docs = complexity.file_types.md or complexity.file_types.txt
	local has_config = complexity.file_types.json or complexity.file_types.yml or complexity.file_types.yaml
	local has_tests = false
	
	for file in pairs(files) do
		if file:match("test") or file:match("spec") then
			has_tests = true
			break
		end
	end
	
	if (has_code and has_docs) or (has_code and has_config) or (has_code and has_tests) then
		complexity.should_split = true
		table.insert(complexity.split_suggestions, "混合了不同类型的变更（代码/文档/配置/测试）")
	end
	
	-- Detect logical units
	complexity.logical_units = {
		{ type = "代码变更", files = {} },
		{ type = "文档更新", files = {} },
		{ type = "配置修改", files = {} },
		{ type = "测试添加", files = {} },
		{ type = "其他变更", files = {} }
	}
	
	for file, data in pairs(files) do
		if file:match("%.md$") or file:match("%.txt$") or file:match("README") then
			table.insert(complexity.logical_units[2].files, file)
		elseif file:match("%.json$") or file:match("%.yml$") or file:match("%.yaml$") or file:match("config") then
			table.insert(complexity.logical_units[3].files, file)
		elseif file:match("test") or file:match("spec") then
			table.insert(complexity.logical_units[4].files, file)
		elseif data.file_type and (data.file_type == "lua" or data.file_type == "js" or data.file_type == "py" or data.file_type == "go") then
			table.insert(complexity.logical_units[1].files, file)
		else
			table.insert(complexity.logical_units[5].files, file)
		end
	end
	
	return complexity, files
end

-- Generate splitting strategy
local function generate_splitting_strategy(complexity, files, git_data)
	local template = string.format([[
作为专业的代码提交管理专家，请分析以下大型变更并提供智能拆分建议：

变更统计:
- 文件数量: %d
- 新增行数: %d
- 删除行数: %d
- 文件类型: %s

Git差异:
%s

拆分建议原则:
1. 按功能逻辑分组（功能开发、bug修复、重构等）
2. 按文件类型分组（代码、测试、文档、配置）
3. 按依赖关系分组（相互依赖的变更放在一起）
4. 确保每个提交都是原子性的、可独立运行的

请提供详细的拆分方案，格式如下：
提交1: [类型] [描述] - 包含文件: [文件列表]
提交2: [类型] [描述] - 包含文件: [文件列表]
...

每个提交都要有清晰的提交消息建议。
]], 
		complexity.files_changed,
		complexity.additions,
		complexity.deletions,
		vim.inspect(complexity.file_types),
		git_data.diff:sub(1, 3000)
	)
	
	return template
end

-- Interactive splitting process
function M.interactive_commit_splitting(git_data)
	local complexity, files = analyze_diff_complexity(git_data.diff)
	
	-- Show complexity analysis
	local analysis_report = string.format([[
📊 变更复杂度分析

📈 统计信息:
- 变更文件: %d 个
- 新增行数: %d 行
- 删除行数: %d 行
- 总变更: %d 行

📁 文件类型分布:
%s

🤔 是否需要拆分: %s

💡 拆分建议:
%s
]], 
		complexity.files_changed,
		complexity.additions,
		complexity.deletions,
		complexity.additions + complexity.deletions,
		vim.inspect(complexity.file_types),
		complexity.should_split and "建议拆分" or "可以单次提交",
		#complexity.split_suggestions > 0 and table.concat(complexity.split_suggestions, "\n") or "变更规模适中，可以单次提交"
	)
	
	vim.notify(analysis_report, vim.log.levels.INFO)
	
	if not complexity.should_split then
		vim.ui.select({
			"✅ 继续单次提交",
			"🔧 强制拆分分析",
			"❌ 取消操作"
		}, {
			prompt = "变更复杂度较低:",
		}, function(choice)
			if choice and choice:match("✅") then
				require('ai-commit').generate_commit()
			elseif choice and choice:match("🔧") then
				M.force_splitting_analysis(git_data, complexity, files)
			end
		end)
		return
	end
	
	-- Generate splitting suggestions
	local prompt = generate_splitting_strategy(complexity, files, git_data)
	local data = require('commit_generator').prepare_request_data(prompt, "qwen/qwen-2.5-72b-instruct:free")
	
	vim.notify("正在生成智能拆分方案...", vim.log.levels.INFO)
	
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
					
					-- Parse splitting suggestions
					local commits = {}
					for commit_line in content:gmatch("提交%d+:[^\n]+") do
						table.insert(commits, commit_line)
					end
					
					if #commits > 0 then
						-- Show splitting plan
						local plan = "🎯 智能拆分方案:\n\n" .. table.concat(commits, "\n")
						vim.notify(plan, vim.log.levels.INFO)
						
						vim.ui.select({
							"🚀 执行拆分方案",
							"✏️ 手动调整方案",
							"❌ 取消拆分",
							"💾 保存方案到文件"
						}, {
							prompt = "选择操作:",
						}, function(action)
							if action and action:match("🚀") then
								M.execute_splitting_plan(commits, git_data)
							elseif action and action:match("✏️") then
								M.manual_splitting_adjustment(commits, git_data, complexity, files)
							elseif action and action:match("💾") then
								M.save_splitting_plan(commits, complexity)
							end
						end)
					else
						vim.notify("无法生成拆分方案", vim.log.levels.WARN)
					end
				else
					vim.notify("未收到拆分建议", vim.log.levels.WARN)
				end
			else
				vim.notify("生成拆分方案失败", vim.log.levels.ERROR)
			end
		end),
	})
end

-- Execute splitting plan
function M.execute_splitting_plan(commits, git_data)
	vim.notify("⚠️ 拆分功能需要谨慎操作，建议先备份当前更改", vim.log.levels.WARN)
	
	vim.ui.input({
		prompt = "确认执行拆分？输入 'YES' 确认: "
	}, function(input)
		if input == "YES" then
			-- This is a complex operation that would require:
			-- 1. Unstaging all changes
			-- 2. Selectively staging files for each commit
			-- 3. Creating individual commits
			-- For safety, we'll show the manual process instead
			
			local manual_instructions = [[
🔧 手动拆分指导:

由于自动拆分涉及复杂的git操作，建议手动执行：

1. 取消暂存所有更改:
   git reset HEAD

2. 按计划逐个暂存和提交:
]] .. table.concat(commits, "\n   执行: git add [对应文件] && git commit -m \"[对应消息]\"\n")
			
			vim.notify(manual_instructions, vim.log.levels.INFO)
		else
			vim.notify("已取消拆分操作", vim.log.levels.INFO)
		end
	end)
end

-- Manual splitting adjustment
function M.manual_splitting_adjustment(commits, git_data, complexity, files)
	-- Show current staged files for manual selection
	local staged_files = {}
	for line in git_data.diff:gmatch("[^\n]+") do
		local file = line:match("^diff --git a/.+ b/(.+)$")
		if file then
			table.insert(staged_files, file)
		end
	end
	
	vim.ui.select(staged_files, {
		prompt = "选择要单独提交的文件 (可多选):",
	}, function(selected_file)
		if selected_file then
			-- Create commit with selected file
			vim.ui.input({
				prompt = "为文件 " .. selected_file .. " 输入提交消息: "
			}, function(commit_msg)
				if commit_msg then
					local Job = require("plenary.job")
					
					-- Reset and add only selected file
					Job:new({
						command = "git",
						args = {"reset", "HEAD"},
						on_exit = function()
							Job:new({
								command = "git",
								args = {"add", selected_file},
								on_exit = function()
									Job:new({
										command = "git",
										args = {"commit", "-m", commit_msg},
										on_exit = function(_, return_val)
											if return_val == 0 then
												vim.notify("✅ 已提交文件: " .. selected_file, vim.log.levels.INFO)
												-- Continue with remaining files
												local remaining_files = vim.tbl_filter(function(f) return f ~= selected_file end, staged_files)
												if #remaining_files > 0 then
													vim.notify("继续处理剩余文件...", vim.log.levels.INFO)
													-- Recursive call for remaining files
												end
											else
												vim.notify("❌ 提交失败", vim.log.levels.ERROR)
											end
										end
									}):start()
								end
							}):start()
						end
					}):start()
				end
			end)
		end
	end)
end

-- Save splitting plan to file
function M.save_splitting_plan(commits, complexity)
	local plan_content = string.format([[
# 提交拆分方案
生成时间: %s

## 复杂度分析
- 文件数量: %d
- 新增行数: %d  
- 删除行数: %d
- 文件类型: %s

## 拆分方案
%s

## 执行指导
1. git reset HEAD  # 取消所有暂存
2. 按照上述方案逐个提交
3. 每次提交前检查文件状态
]], 
		os.date("%Y-%m-%d %H:%M:%S"),
		complexity.files_changed,
		complexity.additions,
		complexity.deletions,
		vim.inspect(complexity.file_types),
		table.concat(commits, "\n")
	)
	
	local filename = ".ai-commit-split-plan-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
	vim.fn.writefile(vim.split(plan_content, "\n"), filename)
	vim.notify("拆分方案已保存到: " .. filename, vim.log.levels.INFO)
end

-- Force splitting analysis for smaller changes
function M.force_splitting_analysis(git_data, complexity, files)
	vim.notify("🔬 强制分析模式 - 即使是小规模变更也进行拆分分析", vim.log.levels.INFO)
	
	-- Show logical units
	local units_report = "📋 逻辑单元分析:\n\n"
	for _, unit in ipairs(complexity.logical_units) do
		if #unit.files > 0 then
			units_report = units_report .. string.format("%s (%d个文件):\n", unit.type, #unit.files)
			for _, file in ipairs(unit.files) do
				units_report = units_report .. "  - " .. file .. "\n"
			end
			units_report = units_report .. "\n"
		end
	end
	
	vim.notify(units_report, vim.log.levels.INFO)
	
	-- Suggest micro-commits
	vim.ui.select({
		"📦 按逻辑单元拆分",
		"📁 按文件类型拆分", 
		"🎯 按功能模块拆分",
		"❌ 取消分析"
	}, {
		prompt = "选择拆分策略:",
	}, function(strategy)
		if strategy and strategy:match("📦") then
			M.split_by_logical_units(complexity, git_data)
		elseif strategy and strategy:match("📁") then
			M.split_by_file_types(complexity, git_data)
		elseif strategy and strategy:match("🎯") then
			M.split_by_functional_modules(complexity, git_data)
		end
	end)
end

-- Implementation stubs for different splitting strategies
function M.split_by_logical_units(complexity, git_data)
	vim.notify("🔄 按逻辑单元拆分功能开发中...", vim.log.levels.INFO)
end

function M.split_by_file_types(complexity, git_data)
	vim.notify("🔄 按文件类型拆分功能开发中...", vim.log.levels.INFO)
end

function M.split_by_functional_modules(complexity, git_data)
	vim.notify("🔄 按功能模块拆分功能开发中...", vim.log.levels.INFO)
end

return M