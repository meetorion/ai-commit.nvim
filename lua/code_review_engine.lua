local M = {}

-- Code review categories and scoring weights
local REVIEW_CATEGORIES = {
	code_quality = {
		name = "代码质量",
		weight = 30,
		icon = "🔍",
		checks = {
			"函数复杂度",
			"代码重复",
			"命名规范",
			"注释完整性",
			"代码结构"
		}
	},
	security = {
		name = "安全性",
		weight = 40,
		icon = "🔒",
		checks = {
			"注入漏洞",
			"权限控制",
			"敏感信息泄露",
			"加密使用",
			"输入验证"
		}
	},
	performance = {
		name = "性能",
		weight = 25,
		icon = "⚡",
		checks = {
			"算法效率",
			"内存使用",
			"数据库查询",
			"并发处理",
			"资源管理"
		}
	},
	maintainability = {
		name = "可维护性",
		weight = 20,
		icon = "🔧",
		checks = {
			"代码耦合度",
			"测试覆盖",
			"文档完整性",
			"错误处理",
			"代码清晰度"
		}
	},
	best_practices = {
		name = "最佳实践",
		weight = 15,
		icon = "✨",
		checks = {
			"设计模式",
			"异常处理",
			"日志记录",
			"配置管理",
			"版本兼容性"
		}
	}
}

-- Programming language specific patterns
local LANGUAGE_PATTERNS = {
	javascript = {
		extensions = {".js", ".jsx", ".ts", ".tsx", ".vue"},
		common_issues = {
			"== vs ===",
			"var vs let/const",
			"callback hell",
			"memory leaks",
			"async/await usage"
		},
		security_patterns = {
			"eval(", "innerHTML", "document.write", "setTimeout.*string", "setInterval.*string"
		},
		performance_patterns = {
			"forEach", "nested loops", "DOM manipulation", "unnecessary re-renders"
		}
	},
	python = {
		extensions = {".py", ".pyw"},
		common_issues = {
			"global variables",
			"mutable defaults",
			"exception handling",
			"list comprehensions",
			"generator usage"
		},
		security_patterns = {
			"eval(", "exec(", "pickle.loads", "yaml.load", "shell=True"
		},
		performance_patterns = {
			"nested loops", "string concatenation", "global lookups", "unnecessary imports"
		}
	},
	go = {
		extensions = {".go"},
		common_issues = {
			"error handling",
			"goroutine leaks",
			"channel usage",
			"interface design",
			"nil pointer"
		},
		security_patterns = {
			"sql.Query.*fmt.Sprintf", "os.Exec", "filepath.Join", "http.Get.*string"
		},
		performance_patterns = {
			"sync.Map", "interface{}", "reflection", "unnecessary allocations"
		}
	},
	rust = {
		extensions = {".rs"},
		common_issues = {
			"ownership errors",
			"lifetime issues",
			"unsafe blocks",
			"error propagation",
			"pattern matching"
		},
		security_patterns = {
			"unsafe", "std::mem::transmute", "from_raw", "CString::from_raw"
		},
		performance_patterns = {
			"clone()", "to_string()", "unwrap()", "excessive allocations"
		}
	},
	java = {
		extensions = {".java"},
		common_issues = {
			"null pointer exceptions",
			"resource leaks",
			"thread safety",
			"exception handling",
			"generics usage"
		},
		security_patterns = {
			"Runtime.exec", "ProcessBuilder", "reflection", "deserialization"
		},
		performance_patterns = {
			"string concatenation", "autoboxing", "unnecessary objects", "blocking operations"
		}
	},
	lua = {
		extensions = {".lua"},
		common_issues = {
			"global pollution",
			"table performance",
			"coroutine usage",
			"error handling",
			"module structure"
		},
		security_patterns = {
			"loadstring", "dofile", "require.*string", "os.execute"
		},
		performance_patterns = {
			"table.insert", "string concatenation", "global access", "unnecessary metamethods"
		}
	}
}

-- Severity levels
local SEVERITY_LEVELS = {
	critical = {name = "严重", icon = "🚨", color = "red", score = 100},
	high = {name = "高", icon = "🔴", color = "red", score = 75},
	medium = {name = "中等", icon = "🟡", color = "yellow", score = 50},
	low = {name = "低", icon = "🔵", color = "blue", score = 25},
	info = {name = "信息", icon = "ℹ️", color = "gray", score = 10}
}

-- Detect programming language from file
local function detect_language(file_path)
	if not file_path then return "unknown" end
	
	local ext = file_path:match("%.([^%.]+)$")
	if not ext then return "unknown" end
	
	ext = "." .. ext:lower()
	
	for lang, config in pairs(LANGUAGE_PATTERNS) do
		if vim.tbl_contains(config.extensions, ext) then
			return lang
		end
	end
	
	return "unknown"
end

-- Analyze code for common issues
local function analyze_code_patterns(content, language)
	local issues = {}
	local lang_config = LANGUAGE_PATTERNS[language]
	
	if not lang_config then
		return issues
	end
	
	local lines = vim.split(content, "\n")
	
	for line_num, line in ipairs(lines) do
		-- Security pattern checks
		if lang_config.security_patterns then
			for _, pattern in ipairs(lang_config.security_patterns) do
				if line:match(pattern) then
					table.insert(issues, {
						category = "security",
						severity = "high",
						line = line_num,
						message = string.format("潜在安全风险: 发现可疑模式 '%s'", pattern),
						suggestion = "请验证此代码的安全性，考虑使用更安全的替代方案",
						code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
					})
				end
			end
		end
		
		-- Performance pattern checks
		if lang_config.performance_patterns then
			for _, pattern in ipairs(lang_config.performance_patterns) do
				if line:match(pattern) then
					table.insert(issues, {
						category = "performance",
						severity = "medium",
						line = line_num,
						message = string.format("性能关注点: 发现模式 '%s'", pattern),
						suggestion = "考虑优化此代码以提高性能",
						code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
					})
				end
			end
		end
		
		-- Language-specific common issues
		if language == "javascript" then
			if line:match("==") and not line:match("===") then
				table.insert(issues, {
					category = "code_quality",
					severity = "medium",
					line = line_num,
					message = "建议使用 === 而不是 ==",
					suggestion = "使用严格相等性比较以避免类型转换问题",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
			
			if line:match("var%s+") then
				table.insert(issues, {
					category = "best_practices",
					severity = "low",
					line = line_num,
					message = "建议使用 let 或 const 而不是 var",
					suggestion = "使用块级作用域变量声明",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
			
		elseif language == "python" then
			if line:match("except:") then
				table.insert(issues, {
					category = "best_practices",
					severity = "medium",
					line = line_num,
					message = "裸露的 except 子句",
					suggestion = "指定具体的异常类型以提高代码健壮性",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
			
			if line:match("print%(") then
				table.insert(issues, {
					category = "maintainability",
					severity = "low",
					line = line_num,
					message = "生产代码中的 print 语句",
					suggestion = "考虑使用logging模块替代print进行调试",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
			
		elseif language == "go" then
			if line:match("if%s+err%s*!=%s*nil") and lines[line_num + 1] and not lines[line_num + 1]:match("return") then
				table.insert(issues, {
					category = "best_practices",
					severity = "medium",
					line = line_num,
					message = "错误处理不完整",
					suggestion = "确保正确处理错误，通常应该返回或记录错误",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
			
		elseif language == "lua" then
			if line:match("[^%w_]_G%[") or line:match("_G%.") then
				table.insert(issues, {
					category = "best_practices",
					severity = "medium",
					line = line_num,
					message = "直接访问全局表 _G",
					suggestion = "避免直接操作 _G，使用局部变量或模块",
					code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
				})
			end
		end
		
		-- Generic code quality checks
		if #line > 120 then
			table.insert(issues, {
				category = "code_quality",
				severity = "low",
				line = line_num,
				message = "代码行过长",
				suggestion = "将长行分解为多行以提高可读性",
				code_snippet = line:sub(1, 50) .. "..."
			})
		end
		
		-- TODO/FIXME/HACK comments
		if line:match("TODO") or line:match("FIXME") or line:match("HACK") then
			table.insert(issues, {
				category = "maintainability",
				severity = "info",
				line = line_num,
				message = "发现待办事项注释",
				suggestion = "考虑解决此待办事项或创建issue跟踪",
				code_snippet = line:gsub("^%s+", ""):gsub("%s+$", "")
			})
		end
	end
	
	return issues
end

-- Calculate complexity score
local function calculate_complexity(content, language)
	local complexity = {
		cyclomatic = 1, -- Base complexity
		cognitive = 0,
		nesting_level = 0,
		max_nesting = 0
	}
	
	local lines = vim.split(content, "\n")
	local current_nesting = 0
	
	for _, line in ipairs(lines) do
		local trimmed = line:gsub("^%s+", "")
		
		-- Count decision points (cyclomatic complexity)
		local decision_keywords = {"if", "elif", "else", "for", "while", "case", "catch", "&&", "||", "?"}
		for _, keyword in ipairs(decision_keywords) do
			if trimmed:match("%f[%w]" .. keyword .. "%f[%W]") then
				complexity.cyclomatic = complexity.cyclomatic + 1
				complexity.cognitive = complexity.cognitive + (current_nesting + 1)
			end
		end
		
		-- Track nesting level
		if trimmed:match("^{") or trimmed:match("{%s*$") then
			current_nesting = current_nesting + 1
			complexity.max_nesting = math.max(complexity.max_nesting, current_nesting)
		elseif trimmed:match("^}") then
			current_nesting = math.max(0, current_nesting - 1)
		end
	end
	
	complexity.nesting_level = complexity.max_nesting
	
	return complexity
end

-- Generate AI-powered review using the multi-provider system
function M.generate_ai_review(file_path, content, git_data)
	local language = detect_language(file_path)
	local issues = analyze_code_patterns(content, language)
	local complexity = calculate_complexity(content, language)
	
	-- Prepare prompt for AI analysis
	local prompt = string.format([[
你是一位资深的代码审查专家。请分析以下代码并提供专业的审查意见。

文件路径: %s
编程语言: %s
代码复杂度: 圈复杂度=%d, 认知复杂度=%d, 最大嵌套=%d

代码内容:
```%s
%s
```

Git变更上下文:
%s

请从以下维度进行分析:
1. 🔍 代码质量 - 可读性、结构、命名规范
2. 🔒 安全性 - 潜在安全风险和漏洞
3. ⚡ 性能 - 算法效率、资源使用
4. 🔧 可维护性 - 耦合度、测试性、文档
5. ✨ 最佳实践 - 设计模式、错误处理

对于每个发现的问题，请提供:
- 问题描述
- 严重程度 (critical/high/medium/low/info)
- 具体建议
- 代码示例（如果适用）

请用中文回复，格式清晰，重点突出。
]], file_path, language, complexity.cyclomatic, complexity.cognitive, complexity.nesting_level, language, content, git_data.diff or "")

	-- Use multi-provider AI for analysis
	local ai_request_manager = require("ai_request_manager")
	local config = require("ai-commit").config
	
	local messages = {
		{
			role = "system",
			content = "你是一位资深的代码审查专家，专门帮助开发者提高代码质量、安全性和性能。"
		},
		{
			role = "user",
			content = prompt
		}
	}
	
	-- Return basic analysis immediately, AI analysis will be async
	local basic_analysis = {
		file_path = file_path,
		language = language,
		complexity = complexity,
		static_issues = issues,
		line_count = #vim.split(content, "\n"),
		categories_analyzed = vim.tbl_keys(REVIEW_CATEGORIES),
		ai_analysis_requested = true
	}
	
	-- Start AI analysis asynchronously
	vim.schedule(function()
		ai_request_manager.send_ai_request(messages, config, {
			task_type = "analysis",
			max_retries = 2,
			timeout = 45000 -- Longer timeout for complex analysis
		})
	end)
	
	return basic_analysis
end

-- Analyze all changed files
function M.analyze_changed_files(git_data)
	if not git_data or not git_data.diff then
		return {error = "没有找到Git变更数据"}
	end
	
	local changed_files = {}
	local current_file = nil
	
	-- Parse git diff to extract changed files
	for line in git_data.diff:gmatch("[^\n]+") do
		if line:match("^diff --git") then
			local file_match = line:match("b/(.+)$")
			if file_match then
				current_file = file_match
				changed_files[current_file] = {
					path = current_file,
					additions = 0,
					deletions = 0,
					changes = {}
				}
			end
		elseif line:match("^%+") and current_file and not line:match("^%+%+%+") then
			changed_files[current_file].additions = changed_files[current_file].additions + 1
			table.insert(changed_files[current_file].changes, {
				type = "addition",
				line = line:sub(2) -- Remove the + prefix
			})
		elseif line:match("^%-") and current_file and not line:match("^%-%-%- ") then
			changed_files[current_file].deletions = changed_files[current_file].deletions + 1
			table.insert(changed_files[current_file].changes, {
				type = "deletion", 
				line = line:sub(2) -- Remove the - prefix
			})
		end
	end
	
	local analysis_results = {}
	
	for file_path, file_data in pairs(changed_files) do
		-- Read file content
		local file_content = ""
		if vim.fn.filereadable(file_path) == 1 then
			local lines = vim.fn.readfile(file_path)
			file_content = table.concat(lines, "\n")
		else
			-- File might be deleted or new
			file_content = table.concat(vim.tbl_map(function(change) 
				return change.type == "addition" and change.line or ""
			end, file_data.changes), "\n")
		end
		
		if file_content ~= "" then
			local analysis = M.generate_ai_review(file_path, file_content, git_data)
			analysis.file_stats = file_data
			table.insert(analysis_results, analysis)
		end
	end
	
	return analysis_results
end

-- Generate comprehensive review report
function M.generate_review_report(analysis_results)
	if not analysis_results or #analysis_results == 0 then
		return "没有找到需要审查的文件"
	end
	
	local total_issues = 0
	local severity_counts = {critical = 0, high = 0, medium = 0, low = 0, info = 0}
	local category_scores = {}
	
	for category, config in pairs(REVIEW_CATEGORIES) do
		category_scores[category] = {count = 0, score = 0}
	end
	
	-- Aggregate statistics
	for _, analysis in ipairs(analysis_results) do
		for _, issue in ipairs(analysis.static_issues or {}) do
			total_issues = total_issues + 1
			severity_counts[issue.severity] = severity_counts[issue.severity] + 1
			
			if category_scores[issue.category] then
				category_scores[issue.category].count = category_scores[issue.category].count + 1
				category_scores[issue.category].score = category_scores[issue.category].score + 
					SEVERITY_LEVELS[issue.severity].score
			end
		end
	end
	
	-- Calculate overall score
	local max_possible_score = total_issues * 100
	local actual_score = 0
	for _, counts in pairs(severity_counts) do
		actual_score = actual_score + counts
	end
	
	local quality_score = max_possible_score > 0 and 
		math.max(0, 100 - (actual_score / max_possible_score * 100)) or 100
	
	-- Generate report
	local report = string.format([[
🧠 智能代码审查报告

📊 总体评分: %.1f/100 (%s)
📁 审查文件: %d个
🔍 发现问题: %d个

⚠️ 问题分布:
🚨 严重: %d个
🔴 高: %d个  
🟡 中等: %d个
🔵 低: %d个
ℹ️ 信息: %d个

📋 分类统计:
]], 
		quality_score,
		quality_score >= 90 and "优秀" or quality_score >= 80 and "良好" or 
		quality_score >= 70 and "一般" or quality_score >= 60 and "需改进" or "待优化",
		#analysis_results,
		total_issues,
		severity_counts.critical,
		severity_counts.high,
		severity_counts.medium,
		severity_counts.low,
		severity_counts.info
	)
	
	for category, config in pairs(REVIEW_CATEGORIES) do
		local cat_data = category_scores[category]
		if cat_data.count > 0 then
			report = report .. string.format("%s %s: %d个问题\n", 
				config.icon, config.name, cat_data.count)
		end
	end
	
	-- Add detailed file analysis
	report = report .. "\n📁 文件详情:\n"
	for _, analysis in ipairs(analysis_results) do
		local file_issues = #(analysis.static_issues or {})
		local complexity_text = ""
		if analysis.complexity then
			complexity_text = string.format(" (复杂度: %d)", analysis.complexity.cyclomatic)
		end
		
		report = report .. string.format("• %s: %d个问题, %d行%s\n", 
			analysis.file_path, file_issues, analysis.line_count, complexity_text)
		
		-- Show top issues for this file
		local sorted_issues = analysis.static_issues or {}
		table.sort(sorted_issues, function(a, b) 
			return SEVERITY_LEVELS[a.severity].score > SEVERITY_LEVELS[b.severity].score 
		end)
		
		for i, issue in ipairs(sorted_issues) do
			if i <= 3 then -- Show top 3 issues
				report = report .. string.format("  %s L%d: %s\n", 
					SEVERITY_LEVELS[issue.severity].icon, issue.line, issue.message)
			end
		end
	end
	
	-- Add recommendations
	report = report .. "\n💡 建议:\n"
	if quality_score >= 90 then
		report = report .. "✅ 代码质量优秀，继续保持!\n"
	elseif quality_score >= 80 then
		report = report .. "👍 代码质量良好，关注高优先级问题\n"
	else
		report = report .. "🔧 建议优先修复严重和高优先级问题\n"
		report = report .. "📚 考虑制定代码质量提升计划\n"
	end
	
	return report
end

-- Export utility functions
M.detect_language = detect_language
M.calculate_complexity = calculate_complexity
M.REVIEW_CATEGORIES = REVIEW_CATEGORIES
M.SEVERITY_LEVELS = SEVERITY_LEVELS
M.LANGUAGE_PATTERNS = LANGUAGE_PATTERNS

return M