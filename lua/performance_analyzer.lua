local M = {}

-- Performance anti-patterns by language
local PERFORMANCE_PATTERNS = {
	javascript = {
		name = "JavaScript",
		patterns = {
			{
				pattern = "for.*in.*array",
				severity = "medium",
				message = "性能问题: 对数组使用for...in循环",
				suggestion = "使用for...of或传统for循环遍历数组",
				category = "iteration"
			},
			{
				pattern = "document%.getElementById.*loop",
				severity = "high", 
				message = "DOM查询在循环中：频繁DOM操作",
				suggestion = "将DOM查询移出循环或缓存结果",
				category = "dom"
			},
			{
				pattern = "%+.*['\"].*%+.*['\"].*%+",
				severity = "medium",
				message = "字符串拼接性能问题：多次字符串连接",
				suggestion = "使用数组join()或模板字符串",
				category = "string"
			},
			{
				pattern = "forEach.*forEach",
				severity = "medium",
				message = "嵌套forEach：可能影响性能",
				suggestion = "考虑使用单层循环或优化算法",
				category = "iteration"
			},
			{
				pattern = "JSON%.parse.*JSON%.stringify",
				severity = "low",
				message = "深拷贝性能：JSON方法效率较低",
				suggestion = "使用lodash.cloneDeep或结构化克隆",
				category = "object"
			},
			{
				pattern = "new.*RegExp.*loop",
				severity = "high",
				message = "循环中创建正则表达式：重复编译",
				suggestion = "将正则表达式定义移到循环外",
				category = "regex"
			}
		}
	},
	
	python = {
		name = "Python",
		patterns = {
			{
				pattern = "%+%+.*['\"].*%+%+",
				severity = "medium",
				message = "字符串拼接性能问题：字符串不可变",
				suggestion = "使用join()或f-string格式化",
				category = "string"
			},
			{
				pattern = "for.*in.*range.*len",
				severity = "low",
				message = "非Pythonic循环：不必要的索引",
				suggestion = "直接迭代对象或使用enumerate()",
				category = "iteration"
			},
			{
				pattern = "list.*for.*in.*if",
				severity = "info",
				message = "列表推导式机会：可能提高性能",
				suggestion = "考虑使用列表推导式或生成器",
				category = "comprehension"
			},
			{
				pattern = "global.*[A-Za-z_][A-Za-z0-9_]*",
				severity = "medium",
				message = "全局变量访问：比局部变量慢",
				suggestion = "尽量使用局部变量或参数传递",
				category = "scope"
			},
			{
				pattern = "%%.*%s.*%%",
				severity = "low",
				message = "旧式字符串格式化：性能较差",
				suggestion = "使用f-string或str.format()",
				category = "string"
			},
			{
				pattern = "import.*%*",
				severity = "low",
				message = "导入性能：全量导入可能影响启动速度",
				suggestion = "只导入需要的函数或模块",
				category = "import"
			}
		}
	},
	
	go = {
		name = "Go",
		patterns = {
			{
				pattern = "make.*%[%].*append",
				severity = "medium",
				message = "切片性能：未预分配容量",
				suggestion = "使用make([]T, 0, capacity)预分配容量",
				category = "memory"
			},
			{
				pattern = "fmt%.Sprintf.*%+",
				severity = "medium",
				message = "字符串格式化性能：在循环中使用",
				suggestion = "考虑使用strings.Builder或预计算",
				category = "string"
			},
			{
				pattern = "interface{}.*type.*assertion",
				severity = "medium",
				message = "类型断言性能：空接口使用",
				suggestion = "使用具体类型或泛型(Go 1.18+)",
				category = "type"
			},
			{
				pattern = "sync%.Map.*range",
				severity = "low",
				message = "并发Map性能：Range操作需要注意",
				suggestion = "考虑使用带锁的普通map或其他数据结构",
				category = "concurrency"
			},
			{
				pattern = "reflect%.",
				severity = "high",
				message = "反射性能：反射操作成本较高",
				suggestion = "避免在热路径中使用反射",
				category = "reflection"
			}
		}
	},
	
	rust = {
		name = "Rust",
		patterns = {
			{
				pattern = "clone%(%).*loop",
				severity = "medium",
				message = "克隆性能：循环中的不必要克隆",
				suggestion = "使用引用或重构以避免克隆",
				category = "memory"
			},
			{
				pattern = "unwrap%(%).*loop",
				severity = "medium",
				message = "错误处理性能：循环中的panic风险",
				suggestion = "使用?操作符或match处理错误",
				category = "error"
			},
			{
				pattern = "Box::new.*Vec",
				severity = "low",
				message = "内存分配：可能的过度装箱",
				suggestion = "检查是否真的需要堆分配",
				category = "memory"
			},
			{
				pattern = "String::from.*%+",
				severity = "medium",
				message = "字符串性能：不必要的分配",
				suggestion = "使用format!宏或push_str方法",
				category = "string"
			}
		}
	},
	
	java = {
		name = "Java",
		patterns = {
			{
				pattern = "new.*String.*%+",
				severity = "medium",
				message = "字符串性能：频繁创建String对象",
				suggestion = "使用StringBuilder或StringBuffer",
				category = "string"
			},
			{
				pattern = "new.*ArrayList%(%).*add",
				severity = "low",
				message = "集合性能：未指定初始容量",
				suggestion = "预设合适的初始容量",
				category = "collection"
			},
			{
				pattern = "synchronized.*method",
				severity = "medium",
				message = "并发性能：方法级同步粒度较大",
				suggestion = "使用更细粒度的同步或并发集合",
				category = "concurrency"
			},
			{
				pattern = "Integer%.valueOf.*loop",
				severity = "medium",
				message = "装箱性能：循环中的自动装箱",
				suggestion = "使用基本类型或缓存装箱结果",
				category = "boxing"
			}
		}
	},
	
	lua = {
		name = "Lua",
		patterns = {
			{
				pattern = "table%.insert.*loop",
				severity = "medium",
				message = "表性能：循环中使用table.insert",
				suggestion = "直接使用索引赋值或预分配表大小",
				category = "table"
			},
			{
				pattern = "%.%..*%.%..*%.%.",
				severity = "medium",
				message = "字符串拼接：多次连接操作",
				suggestion = "使用table.concat或一次性拼接",
				category = "string"
			},
			{
				pattern = "_G%[.*%].*loop",
				severity = "high",
				message = "全局访问：循环中频繁全局变量访问",
				suggestion = "缓存全局变量到局部变量",
				category = "scope"
			},
			{
				pattern = "pairs.*ipairs",
				severity = "low",
				message = "迭代性能：混合使用pairs和ipairs",
				suggestion = "根据数据结构选择合适的迭代器",
				category = "iteration"
			}
		}
	}
}

-- Algorithm complexity patterns
local COMPLEXITY_PATTERNS = {
	{
		pattern = "for.*for.*for",
		complexity = "O(n³)",
		severity = "high",
		message = "三重嵌套循环：立方时间复杂度",
		suggestion = "考虑算法优化或使用更高效的数据结构"
	},
	{
		pattern = "for.*for.*if",
		complexity = "O(n²)",
		severity = "medium", 
		message = "双重嵌套循环：平方时间复杂度",
		suggestion = "考虑使用哈希表或其他优化方法"
	},
	{
		pattern = "while.*while",
		complexity = "O(n²)",
		severity = "medium",
		message = "嵌套while循环：可能的性能问题",
		suggestion = "分析循环条件，考虑合并或优化"
	},
	{
		pattern = "recursive.*call.*recursive",
		complexity = "exponential",
		severity = "high",
		message = "可能的指数复杂度递归",
		suggestion = "使用动态规划或记忆化避免重复计算"
	}
}

-- Memory usage patterns
local MEMORY_PATTERNS = {
	{
		pattern = "new.*%[.*%].*loop",
		severity = "medium",
		message = "循环中频繁分配数组",
		suggestion = "预分配数组或使用对象池",
		category = "allocation"
	},
	{
		pattern = "malloc.*loop",
		severity = "high",
		message = "循环中频繁内存分配",
		suggestion = "批量分配或使用内存池",
		category = "allocation"
	},
	{
		pattern = "cache.*miss",
		severity = "medium",
		message = "缓存未命中模式",
		suggestion = "优化数据访问模式或调整缓存策略",
		category = "cache"
	}
}

-- Performance analysis for content
function M.analyze_performance(content, language, file_path)
	local performance_issues = {}
	local lines = vim.split(content, "\n")
	
	-- Get language-specific patterns
	local lang_patterns = PERFORMANCE_PATTERNS[language]
	if lang_patterns then
		for _, pattern_config in ipairs(lang_patterns.patterns) do
			for line_num, line in ipairs(lines) do
				if line:match(pattern_config.pattern) then
					table.insert(performance_issues, {
						type = "performance",
						category = pattern_config.category,
						severity = pattern_config.severity,
						line = line_num,
						message = pattern_config.message,
						suggestion = pattern_config.suggestion,
						pattern = pattern_config.pattern,
						code_snippet = line:gsub("^%s+", ""):gsub("%s+$", ""),
						file_path = file_path
					})
				end
			end
		end
	end
	
	-- Check algorithm complexity patterns
	local content_normalized = content:gsub("%s+", " "):lower()
	for _, complexity_pattern in ipairs(COMPLEXITY_PATTERNS) do
		if content_normalized:match(complexity_pattern.pattern) then
			table.insert(performance_issues, {
				type = "complexity",
				category = "algorithm",
				severity = complexity_pattern.severity,
				complexity = complexity_pattern.complexity,
				message = complexity_pattern.message,
				suggestion = complexity_pattern.suggestion,
				pattern = complexity_pattern.pattern,
				file_path = file_path
			})
		end
	end
	
	-- Check memory usage patterns
	for _, memory_pattern in ipairs(MEMORY_PATTERNS) do
		for line_num, line in ipairs(lines) do
			if line:match(memory_pattern.pattern) then
				table.insert(performance_issues, {
					type = "memory",
					category = memory_pattern.category,
					severity = memory_pattern.severity,
					line = line_num,
					message = memory_pattern.message,
					suggestion = memory_pattern.suggestion,
					pattern = memory_pattern.pattern,
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", ""),
					file_path = file_path
				})
			end
		end
	end
	
	-- Calculate performance metrics
	local metrics = M.calculate_performance_metrics(content, language)
	
	return {
		issues = performance_issues,
		metrics = metrics,
		language = language,
		file_path = file_path
	}
end

-- Calculate performance metrics
function M.calculate_performance_metrics(content, language)
	local lines = vim.split(content, "\n")
	local metrics = {
		total_lines = #lines,
		complexity_score = 0,
		memory_score = 0,
		optimization_opportunities = {},
		hotspots = {}
	}
	
	-- Language-specific metric calculations
	if language == "javascript" then
		-- Count DOM operations
		local dom_operations = 0
		for _, line in ipairs(lines) do
			if line:match("document%.") or line:match("getElementById") or 
			   line:match("querySelector") or line:match("innerHTML") then
				dom_operations = dom_operations + 1
			end
		end
		metrics.dom_operations = dom_operations
		
		if dom_operations > 5 then
			table.insert(metrics.optimization_opportunities, "考虑缓存DOM查询结果")
		end
		
	elseif language == "python" then
		-- Count list operations
		local list_operations = 0
		for _, line in ipairs(lines) do
			if line:match("%.append") or line:match("%.extend") or line:match("%.insert") then
				list_operations = list_operations + 1
			end
		end
		metrics.list_operations = list_operations
		
		if list_operations > 10 then
			table.insert(metrics.optimization_opportunities, "考虑使用列表推导式或生成器")
		end
		
	elseif language == "go" then
		-- Count allocations
		local allocations = 0
		for _, line in ipairs(lines) do
			if line:match("make%(") or line:match("new%(") or line:match("&[A-Za-z]") then
				allocations = allocations + 1
			end
		end
		metrics.allocations = allocations
		
		if allocations > 5 then
			table.insert(metrics.optimization_opportunities, "考虑预分配或重用对象")
		end
	end
	
	-- Count nested loops (performance hotspots)
	local loop_depth = 0
	local max_loop_depth = 0
	for line_num, line in ipairs(lines) do
		if line:match("for") or line:match("while") then
			loop_depth = loop_depth + 1
			max_loop_depth = math.max(max_loop_depth, loop_depth)
			
			if loop_depth >= 2 then
				table.insert(metrics.hotspots, {
					line = line_num,
					type = "nested_loop",
					depth = loop_depth,
					severity = loop_depth >= 3 and "high" or "medium"
				})
			end
		elseif line:match("end") or line:match("}") then
			loop_depth = math.max(0, loop_depth - 1)
		end
	end
	
	metrics.max_loop_depth = max_loop_depth
	
	-- Calculate scores
	metrics.complexity_score = math.min(100, max_loop_depth * 20 + #metrics.hotspots * 10)
	metrics.memory_score = math.min(100, (metrics.allocations or 0) * 5)
	
	return metrics
end

-- Generate performance optimization suggestions
function M.generate_optimization_suggestions(analysis_results)
	local suggestions = {
		immediate = {},    -- Can implement now
		short_term = {},   -- Next sprint
		long_term = {}     -- Architecture changes
	}
	
	for _, analysis in ipairs(analysis_results) do
		for _, issue in ipairs(analysis.issues) do
			if issue.severity == "high" then
				table.insert(suggestions.immediate, {
					file = analysis.file_path,
					line = issue.line,
					issue = issue.message,
					action = issue.suggestion,
					impact = "高"
				})
			elseif issue.severity == "medium" then
				table.insert(suggestions.short_term, {
					file = analysis.file_path,
					line = issue.line, 
					issue = issue.message,
					action = issue.suggestion,
					impact = "中等"
				})
			else
				table.insert(suggestions.long_term, {
					file = analysis.file_path,
					line = issue.line,
					issue = issue.message,
					action = issue.suggestion,
					impact = "低"
				})
			end
		end
		
		-- Add metric-based suggestions
		for _, opportunity in ipairs(analysis.metrics.optimization_opportunities) do
			table.insert(suggestions.short_term, {
				file = analysis.file_path,
				issue = "性能优化机会",
				action = opportunity,
				impact = "中等"
			})
		end
	end
	
	return suggestions
end

-- Generate performance report
function M.generate_performance_report(analysis_results)
	if not analysis_results or #analysis_results == 0 then
		return "没有找到需要分析的文件"
	end
	
	local total_issues = 0
	local severity_counts = {high = 0, medium = 0, low = 0}
	local category_counts = {}
	local total_lines = 0
	local total_complexity = 0
	
	-- Aggregate statistics
	for _, analysis in ipairs(analysis_results) do
		total_lines = total_lines + analysis.metrics.total_lines
		total_complexity = total_complexity + analysis.metrics.complexity_score
		
		for _, issue in ipairs(analysis.issues) do
			total_issues = total_issues + 1
			severity_counts[issue.severity] = severity_counts[issue.severity] + 1
			
			if not category_counts[issue.category] then
				category_counts[issue.category] = 0
			end
			category_counts[issue.category] = category_counts[issue.category] + 1
		end
	end
	
	local avg_complexity = #analysis_results > 0 and (total_complexity / #analysis_results) or 0
	
	-- Calculate performance score
	local performance_score = math.max(0, 100 - (
		severity_counts.high * 15 +
		severity_counts.medium * 10 +
		severity_counts.low * 5 +
		avg_complexity * 0.3
	))
	
	-- Generate report
	local report = string.format([[
⚡ 性能分析报告

📊 性能评分: %.1f/100 (%s)
📁 分析文件: %d个
📏 代码总行数: %d行
🔍 性能问题: %d个
🧮 平均复杂度: %.1f

⚠️ 问题严重程度:
🔴 高: %d个
🟡 中等: %d个
🔵 低: %d个

]], 
		performance_score,
		performance_score >= 90 and "优秀" or performance_score >= 80 and "良好" or 
		performance_score >= 70 and "一般" or performance_score >= 60 and "需优化" or "严重",
		#analysis_results,
		total_lines,
		total_issues,
		avg_complexity,
		severity_counts.high,
		severity_counts.medium,
		severity_counts.low
	)
	
	-- Add category breakdown
	if next(category_counts) then
		report = report .. "📋 问题分类:\n"
		for category, count in pairs(category_counts) do
			local category_icons = {
				iteration = "🔄",
				dom = "🌐",
				string = "📝",
				memory = "💾",
				algorithm = "🧮",
				concurrency = "⚡"
			}
			local icon = category_icons[category] or "📊"
			report = report .. string.format("%s %s: %d个\n", icon, category, count)
		end
		report = report .. "\n"
	end
	
	-- Add optimization suggestions
	local suggestions = M.generate_optimization_suggestions(analysis_results)
	
	if #suggestions.immediate > 0 then
		report = report .. "🚨 立即优化建议:\n"
		for i, suggestion in ipairs(suggestions.immediate) do
			if i <= 3 then
				report = report .. string.format("• %s (L%s): %s\n", 
					suggestion.file, suggestion.line or "?", suggestion.action)
			end
		end
		report = report .. "\n"
	end
	
	if #suggestions.short_term > 0 then
		report = report .. "📅 短期优化建议:\n"
		for i, suggestion in ipairs(suggestions.short_term) do
			if i <= 3 then
				report = report .. string.format("• %s: %s\n", 
					suggestion.file, suggestion.action)
			end
		end
		report = report .. "\n"
	end
	
	-- Add overall recommendations
	report = report .. "💡 总体建议:\n"
	if performance_score >= 90 then
		report = report .. "✅ 性能表现优秀，继续保持代码质量\n"
	elseif performance_score >= 80 then
		report = report .. "👍 性能良好，关注高优先级优化点\n"
	else
		report = report .. "🔧 建议进行性能优化，关注热点代码\n"
		report = report .. "📊 考虑引入性能监控和基准测试\n"
	end
	
	if avg_complexity > 60 then
		report = report .. "🧮 代码复杂度较高，考虑重构简化\n"
	end
	
	return report
end

-- Quick performance scan for git changes
function M.quick_performance_scan(git_data)
	if not git_data or not git_data.diff then
		return {error = "没有找到Git变更数据"}
	end
	
	local analysis_results = {}
	
	-- Extract changed files from git diff
	local changed_files = {}
	local current_file = nil
	
	for line in git_data.diff:gmatch("[^\n]+") do
		if line:match("^diff --git") then
			local file_match = line:match("b/(.+)$")
			if file_match then
				current_file = file_match
				changed_files[current_file] = {}
			end
		elseif line:match("^%+") and current_file and not line:match("^%+%+%+") then
			table.insert(changed_files[current_file], line:sub(2)) -- Remove + prefix
		end
	end
	
	-- Analyze each changed file
	for file_path, added_lines in pairs(changed_files) do
		if #added_lines > 0 then
			local code_review_engine = require("code_review_engine")
			local language = code_review_engine.detect_language(file_path)
			local content = table.concat(added_lines, "\n")
			
			local analysis = M.analyze_performance(content, language, file_path)
			table.insert(analysis_results, analysis)
		end
	end
	
	return {
		analysis_results = analysis_results,
		performance_report = M.generate_performance_report(analysis_results),
		optimization_suggestions = M.generate_optimization_suggestions(analysis_results)
	}
end

-- Export patterns for external use
M.PERFORMANCE_PATTERNS = PERFORMANCE_PATTERNS
M.COMPLEXITY_PATTERNS = COMPLEXITY_PATTERNS
M.MEMORY_PATTERNS = MEMORY_PATTERNS

return M