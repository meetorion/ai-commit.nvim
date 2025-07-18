local M = {}

-- 分组策略定义
local grouping_strategies = {
	by_type = {
		name = "按变更类型分组",
		description = "根据变更类型（新增、修改、删除、重命名）分组",
		weight = 1
	},
	by_module = {
		name = "按模块分组",
		description = "根据文件所属模块或目录分组",
		weight = 2
	},
	by_functionality = {
		name = "按功能分组",
		description = "根据功能相关性分组",
		weight = 3
	},
	by_file_type = {
		name = "按文件类型分组",
		description = "根据文件扩展名和类型分组",
		weight = 1
	},
	by_dependency = {
		name = "按依赖关系分组",
		description = "根据文件间的依赖关系分组",
		weight = 2
	}
}

-- 文件类型分类
local file_categories = {
	source = {
		extensions = {".lua", ".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp", ".h"},
		name = "源代码",
		priority = 1
	},
	config = {
		extensions = {".json", ".yaml", ".yml", ".toml", ".ini", ".conf"},
		name = "配置文件",
		priority = 2
	},
	docs = {
		extensions = {".md", ".rst", ".txt", ".doc"},
		name = "文档",
		priority = 3
	},
	tests = {
		patterns = {"test", "spec", "_test", "_spec"},
		name = "测试文件",
		priority = 1
	},
	assets = {
		extensions = {".css", ".scss", ".less", ".png", ".jpg", ".svg", ".ico"},
		name = "资源文件",
		priority = 4
	},
	build = {
		patterns = {"Makefile", "Dockerfile", ".github", "package.json", "requirements.txt"},
		name = "构建文件",
		priority = 2
	}
}

-- 文件分类
local function categorize_file(file_path)
	local filename = file_path:match("[^/]*$")
	local extension = file_path:match("%.([^%.]+)$")
	
	-- 检查特殊模式
	for category, info in pairs(file_categories) do
		if info.patterns then
			for _, pattern in ipairs(info.patterns) do
				if filename:lower():match(pattern:lower()) or file_path:lower():match(pattern:lower()) then
					return category
				end
			end
		end
		
		if info.extensions and extension then
			for _, ext in ipairs(info.extensions) do
				if ext == "." .. extension then
					return category
				end
			end
		end
	end
	
	return "other"
end

-- 提取模块名
local function extract_module(file_path)
	local parts = {}
	for part in file_path:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	
	if #parts > 1 then
		return parts[1] -- 返回第一级目录作为模块
	end
	
	return "root"
end

-- 获取文件变更大小
local function get_file_change_size(file_path)
	local diff = vim.fn.system("git diff --cached --numstat " .. vim.fn.shellescape(file_path))
	local added, deleted = diff:match("(%d+)%s+(%d+)")
	
	if added and deleted then
		return {
			added = tonumber(added),
			deleted = tonumber(deleted),
			total = tonumber(added) + tonumber(deleted)
		}
	end
	
	return {added = 0, deleted = 0, total = 0}
end

-- 分析当前的大改动
local function analyze_large_changes()
	-- 获取所有已暂存的文件
	local staged_files = vim.fn.system("git diff --cached --name-status")
	if staged_files == "" then
		return nil, "没有发现已暂存的文件"
	end
	
	local files = {}
	local changes_summary = {
		total_files = 0,
		added = 0,
		modified = 0,
		deleted = 0,
		renamed = 0,
		by_category = {}
	}
	
	-- 解析文件状态
	for line in staged_files:gmatch("[^\n]+") do
		local status, file_path = line:match("^([AMDRC]%d*)%s+(.+)$")
		if status and file_path then
			local file_info = {
				path = file_path,
				status = status:sub(1, 1),
				full_status = status,
				category = categorize_file(file_path),
				module = extract_module(file_path),
				size = get_file_change_size(file_path)
			}
			
			table.insert(files, file_info)
			changes_summary.total_files = changes_summary.total_files + 1
			
			-- 统计变更类型
			if status:sub(1, 1) == "A" then
				changes_summary.added = changes_summary.added + 1
			elseif status:sub(1, 1) == "M" then
				changes_summary.modified = changes_summary.modified + 1
			elseif status:sub(1, 1) == "D" then
				changes_summary.deleted = changes_summary.deleted + 1
			elseif status:sub(1, 1) == "R" then
				changes_summary.renamed = changes_summary.renamed + 1
			end
			
			-- 按分类统计
			local category = file_info.category
			if not changes_summary.by_category[category] then
				changes_summary.by_category[category] = 0
			end
			changes_summary.by_category[category] = changes_summary.by_category[category] + 1
		end
	end
	
	return files, changes_summary
end

-- 智能分组建议
local function suggest_groups(files, changes_summary)
	local suggested_groups = {}
	
	-- 策略1：按文件类型分组
	if changes_summary.total_files > 5 then
		local type_groups = {}
		for _, file in ipairs(files) do
			local category = file.category
			if not type_groups[category] then
				type_groups[category] = {
					name = file_categories[category] and file_categories[category].name or category,
					files = {},
					priority = file_categories[category] and file_categories[category].priority or 5
				}
			end
			table.insert(type_groups[category].files, file)
		end
		
		for category, group in pairs(type_groups) do
			if #group.files > 1 then
				table.insert(suggested_groups, {
					strategy = "by_type",
					name = group.name,
					files = group.files,
					priority = group.priority,
					description = string.format("包含%d个%s", #group.files, group.name)
				})
			end
		end
	end
	
	-- 策略2：按模块分组
	if changes_summary.total_files > 3 then
		local module_groups = {}
		for _, file in ipairs(files) do
			local module = file.module
			if not module_groups[module] then
				module_groups[module] = {
					name = module,
					files = {},
					priority = 2
				}
			end
			table.insert(module_groups[module].files, file)
		end
		
		for module, group in pairs(module_groups) do
			if #group.files > 1 then
				table.insert(suggested_groups, {
					strategy = "by_module",
					name = module .. "模块",
					files = group.files,
					priority = group.priority,
					description = string.format("包含%d个%s模块的文件", #group.files, module)
				})
			end
		end
	end
	
	-- 策略3：按变更大小分组
	if changes_summary.total_files > 4 then
		local small_changes = {}
		local large_changes = {}
		
		for _, file in ipairs(files) do
			if file.size.total < 50 then
				table.insert(small_changes, file)
			else
				table.insert(large_changes, file)
			end
		end
		
		if #small_changes > 1 then
			table.insert(suggested_groups, {
				strategy = "by_size",
				name = "小型变更",
				files = small_changes,
				priority = 4,
				description = string.format("包含%d个小型变更文件", #small_changes)
			})
		end
		
		if #large_changes > 1 then
			table.insert(suggested_groups, {
				strategy = "by_size",
				name = "大型变更",
				files = large_changes,
				priority = 1,
				description = string.format("包含%d个大型变更文件", #large_changes)
			})
		end
	end
	
	-- 按优先级排序
	table.sort(suggested_groups, function(a, b)
		return a.priority < b.priority
	end)
	
	return suggested_groups
end

-- 显示分析结果
local function display_analysis(files, changes_summary, suggested_groups)
	local lines = {}
	
	-- 标题
	table.insert(lines, "═══════════════════════════════════════════════")
	table.insert(lines, "           COMMIT 拆分分析结果                   ")
	table.insert(lines, "═══════════════════════════════════════════════")
	table.insert(lines, "")
	
	-- 总体统计
	table.insert(lines, "📊 变更总览:")
	table.insert(lines, string.format("  总文件数: %d", changes_summary.total_files))
	table.insert(lines, string.format("  新增: %d | 修改: %d | 删除: %d | 重命名: %d", 
		changes_summary.added, changes_summary.modified, changes_summary.deleted, changes_summary.renamed))
	table.insert(lines, "")
	
	-- 按分类统计
	table.insert(lines, "📁 文件分类:")
	for category, count in pairs(changes_summary.by_category) do
		local category_name = file_categories[category] and file_categories[category].name or category
		table.insert(lines, string.format("  %s: %d个文件", category_name, count))
	end
	table.insert(lines, "")
	
	-- 分组建议
	table.insert(lines, "💡 智能分组建议:")
	if #suggested_groups > 0 then
		for i, group in ipairs(suggested_groups) do
			table.insert(lines, string.format("  %d. %s (%s)", i, group.name, group.description))
		end
	else
		table.insert(lines, "  当前变更较少，建议作为单个commit提交")
	end
	table.insert(lines, "")
	
	-- 详细文件列表
	table.insert(lines, "📄 详细文件列表:")
	for _, file in ipairs(files) do
		local status_icon = file.status == "A" and "➕" or 
							file.status == "M" and "📝" or 
							file.status == "D" and "➖" or 
							file.status == "R" and "🔄" or "❓"
		local category_name = file_categories[file.category] and file_categories[file.category].name or file.category
		table.insert(lines, string.format("  %s %s [%s] (+%d/-%d)", 
			status_icon, file.path, category_name, file.size.added, file.size.deleted))
	end
	table.insert(lines, "")
	table.insert(lines, "═══════════════════════════════════════════════")
	
	return table.concat(lines, "\n")
end

-- 交互式分组选择
local function interactive_group_selection(files, suggested_groups)
	if #suggested_groups == 0 then
		vim.notify("当前变更较少，建议作为单个commit提交", vim.log.levels.INFO)
		return
	end
	
	-- 准备选择列表
	local options = {}
	for i, group in ipairs(suggested_groups) do
		table.insert(options, string.format("%d. %s - %s", i, group.name, group.description))
	end
	table.insert(options, "自定义分组")
	table.insert(options, "取消操作")
	
	vim.ui.select(options, {
		prompt = "选择分组策略:",
		format_item = function(item)
			return item
		end
	}, function(choice)
		if not choice or choice == "取消操作" then
			return
		end
		
		if choice == "自定义分组" then
			custom_grouping(files)
		else
			-- 解析选择的分组
			local group_index = tonumber(choice:match("^(%d+)%."))
			if group_index and suggested_groups[group_index] then
				execute_group_commit(suggested_groups[group_index])
			end
		end
	end)
end

-- 自定义分组
local function custom_grouping(files)
	-- 显示文件列表供用户选择
	local file_options = {}
	for i, file in ipairs(files) do
		local status_icon = file.status == "A" and "➕" or 
							file.status == "M" and "📝" or 
							file.status == "D" and "➖" or 
							file.status == "R" and "🔄" or "❓"
		table.insert(file_options, string.format("%d. %s %s", i, status_icon, file.path))
	end
	
	vim.ui.input({
		prompt = "输入要一起提交的文件编号 (用逗号分隔, 如: 1,3,5): ",
		default = ""
	}, function(input)
		if not input or input == "" then
			return
		end
		
		local selected_files = {}
		for num_str in input:gmatch("[^,]+") do
			local num = tonumber(num_str:match("^%s*(%d+)%s*$"))
			if num and files[num] then
				table.insert(selected_files, files[num])
			end
		end
		
		if #selected_files > 0 then
			vim.ui.input({
				prompt = "为这个分组输入commit描述: ",
				default = ""
			}, function(description)
				if description and description ~= "" then
					local custom_group = {
						name = "自定义分组",
						files = selected_files,
						description = description
					}
					execute_group_commit(custom_group)
				end
			end)
		else
			vim.notify("没有选择有效的文件", vim.log.levels.WARN)
		end
	end)
end

-- 执行分组提交
local function execute_group_commit(group)
	local file_paths = {}
	for _, file in ipairs(group.files) do
		table.insert(file_paths, file.path)
	end
	
	-- 显示即将提交的文件
	local confirmation = string.format(
		"即将提交以下文件:\n\n%s\n\n描述: %s\n\n确认提交吗？",
		table.concat(vim.tbl_map(function(f) return "  " .. f.path end, group.files), "\n"),
		group.description
	)
	
	vim.ui.select({"是", "否", "编辑commit信息"}, {
		prompt = confirmation,
	}, function(choice)
		if choice == "是" then
			commit_files(file_paths, group.description)
		elseif choice == "编辑commit信息" then
			vim.ui.input({
				prompt = "编辑commit信息: ",
				default = group.description
			}, function(new_description)
				if new_description and new_description ~= "" then
					commit_files(file_paths, new_description)
				end
			end)
		end
	end)
end

-- 提交指定文件
local function commit_files(file_paths, description)
	local Job = require("plenary.job")
	
	-- 重置暂存区
	Job:new({
		command = "git",
		args = {"reset", "HEAD"},
		on_exit = function(_, return_val)
			if return_val == 0 then
				-- 重新暂存选中的文件
				local add_args = {"add"}
				for _, path in ipairs(file_paths) do
					table.insert(add_args, path)
				end
				
				Job:new({
					command = "git",
					args = add_args,
					on_exit = function(_, add_return_val)
						if add_return_val == 0 then
							-- 提交
							Job:new({
								command = "git",
								args = {"commit", "-m", description},
								on_exit = function(_, commit_return_val)
									if commit_return_val == 0 then
										vim.notify(string.format("成功提交: %s", description), vim.log.levels.INFO)
										-- 继续处理剩余文件
										continue_splitting()
									else
										vim.notify("提交失败", vim.log.levels.ERROR)
									end
								end
							}):start()
						else
							vim.notify("重新暂存文件失败", vim.log.levels.ERROR)
						end
					end
				}):start()
			else
				vim.notify("重置暂存区失败", vim.log.levels.ERROR)
			end
		end
	}):start()
end

-- 继续拆分剩余文件
local function continue_splitting()
	vim.defer_fn(function()
		vim.ui.select({"继续拆分剩余文件", "完成拆分"}, {
			prompt = "选择下一步操作:"
		}, function(choice)
			if choice == "继续拆分剩余文件" then
				M.split_large_commit()
			else
				vim.notify("Commit拆分完成！", vim.log.levels.INFO)
			end
		end)
	end, 1000)
end

-- 主函数：分析并拆分大型commit
function M.split_large_commit()
	local files, changes_summary = analyze_large_changes()
	
	if not files then
		vim.notify(changes_summary or "没有检测到大型变更", vim.log.levels.WARN)
		return
	end
	
	if changes_summary.total_files < 3 then
		vim.notify("当前变更较少，不需要拆分", vim.log.levels.INFO)
		return
	end
	
	-- 生成分组建议
	local suggested_groups = suggest_groups(files, changes_summary)
	
	-- 显示分析结果
	local analysis_report = display_analysis(files, changes_summary, suggested_groups)
	
	-- 创建分析报告窗口
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(analysis_report, "\n"))
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	
	-- 打开分析窗口
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_option(0, "wrap", true)
	vim.api.nvim_win_set_option(0, "number", false)
	vim.api.nvim_win_set_option(0, "relativenumber", false)
	
	-- 添加快捷键
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
	
	-- 启动交互式分组选择
	vim.defer_fn(function()
		interactive_group_selection(files, suggested_groups)
	end, 1000)
end

-- 快速分组提交（非交互式）
function M.quick_split_commit()
	local files, changes_summary = analyze_large_changes()
	
	if not files then
		vim.notify("没有检测到变更", vim.log.levels.WARN)
		return
	end
	
	-- 自动按文件类型分组
	local type_groups = {}
	for _, file in ipairs(files) do
		local category = file.category
		if not type_groups[category] then
			type_groups[category] = {
				name = file_categories[category] and file_categories[category].name or category,
				files = {}
			}
		end
		table.insert(type_groups[category].files, file)
	end
	
	-- 自动提交每个分组
	for category, group in pairs(type_groups) do
		if #group.files > 0 then
			local file_paths = {}
			for _, file in ipairs(group.files) do
				table.insert(file_paths, file.path)
			end
			
			local description = string.format("chore(%s): 更新%s", category, group.name)
			commit_files(file_paths, description)
		end
	end
end

return M