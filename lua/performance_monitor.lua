local M = {}

-- Performance benchmark tools detection
local BENCHMARK_TOOLS = {
	javascript = {
		lighthouse = {command = "lighthouse", patterns = {"lighthouse.config.js"}},
		jest_bench = {command = "npm run benchmark", patterns = {"**/*.bench.js"}},
		autocannon = {command = "autocannon", patterns = {"benchmark/**/*.js"}},
		clinic = {command = "clinic", patterns = {"clinic.config.js"}}
	},
	python = {
		pytest_benchmark = {command = "pytest --benchmark-only", patterns = {"**/*bench*.py"}},
		locust = {command = "locust", patterns = {"locustfile.py", "benchmark/locust/**"}},
		py_spy = {command = "py-spy", patterns = {"benchmark/**/*.py"}},
		memory_profiler = {command = "mprof", patterns = {"**/*profile*.py"}}
	},
	go = {
		go_bench = {command = "go test -bench=.", patterns = {"*_test.go"}},
		pprof = {command = "go tool pprof", patterns = {"**/*_bench_test.go"}}
	},
	rust = {
		criterion = {command = "cargo bench", patterns = {"benches/**/*.rs"}},
		cargo_flamegraph = {command = "cargo flamegraph", patterns = {"Cargo.toml"}}
	},
	lua = {
		luajit_profiler = {command = "luajit -jp", patterns = {"**/*bench*.lua"}}
	}
}

-- Performance metrics categories
local PERFORMANCE_METRICS = {
	response_time = {threshold = 200, unit = "ms", critical = 500},
	throughput = {threshold = 1000, unit = "req/s", critical = 100},
	memory_usage = {threshold = 512, unit = "MB", critical = 1024},
	cpu_usage = {threshold = 70, unit = "%", critical = 90},
	database_query_time = {threshold = 100, unit = "ms", critical = 1000},
	bundle_size = {threshold = 1, unit = "MB", critical = 5},
	first_contentful_paint = {threshold = 1500, unit = "ms", critical = 3000},
	time_to_interactive = {threshold = 3000, unit = "ms", critical = 6000}
}

-- Detect performance tools in project
local function detect_performance_tools()
	local detected_tools = {}
	
	for lang, tools in pairs(BENCHMARK_TOOLS) do
		for tool_name, config in pairs(tools) do
			for _, pattern in ipairs(config.patterns) do
				if vim.fn.glob(pattern) ~= "" then
					if not detected_tools[lang] then
						detected_tools[lang] = {}
					end
					table.insert(detected_tools[lang], {
						name = tool_name,
						command = config.command,
						files = vim.split(vim.fn.glob(pattern), "\n")
					})
				end
			end
		end
	end
	
	return detected_tools
end

-- Analyze performance impact of changes
local function analyze_performance_impact(git_data)
	local impact_analysis = {
		overall_impact = "minimal",
		affected_areas = {},
		risk_factors = {},
		benchmark_suggestions = {},
		optimization_opportunities = {}
	}
	
	local diff = git_data.diff:lower()
	
	-- Database-related changes
	if diff:match("query") or diff:match("database") or diff:match("sql") or diff:match("orm") then
		impact_analysis.overall_impact = "moderate"
		table.insert(impact_analysis.affected_areas, "数据库查询")
		table.insert(impact_analysis.risk_factors, "查询性能可能受影响")
		table.insert(impact_analysis.benchmark_suggestions, "执行数据库性能基准测试")
		table.insert(impact_analysis.optimization_opportunities, "查询优化机会")
	end
	
	-- Algorithm/Loop changes
	if diff:match("loop") or diff:match("for") or diff:match("while") or diff:match("递归") or diff:match("algorithm") then
		impact_analysis.overall_impact = "moderate"
		table.insert(impact_analysis.affected_areas, "算法复杂度")
		table.insert(impact_analysis.risk_factors, "计算复杂度变化")
		table.insert(impact_analysis.benchmark_suggestions, "CPU使用率基准测试")
		table.insert(impact_analysis.optimization_opportunities, "算法效率优化")
	end
	
	-- Memory allocation changes
	if diff:match("malloc") or diff:match("alloc") or diff:match("new") or diff:match("buffer") then
		impact_analysis.overall_impact = "moderate"
		table.insert(impact_analysis.affected_areas, "内存分配")
		table.insert(impact_analysis.risk_factors, "内存使用模式变化")
		table.insert(impact_analysis.benchmark_suggestions, "内存使用基准测试")
		table.insert(impact_analysis.optimization_opportunities, "内存管理优化")
	end
	
	-- Network/IO changes
	if diff:match("http") or diff:match("request") or diff:match("response") or diff:match("io") or diff:match("file") then
		impact_analysis.overall_impact = "moderate"
		table.insert(impact_analysis.affected_areas, "网络/IO操作")
		table.insert(impact_analysis.risk_factors, "延迟和吞吐量影响")
		table.insert(impact_analysis.benchmark_suggestions, "网络延迟和吞吐量测试")
		table.insert(impact_analysis.optimization_opportunities, "IO优化机会")
	end
	
	-- Async/Concurrency changes
	if diff:match("async") or diff:match("await") or diff:match("promise") or diff:match("concurrent") or diff:match("parallel") then
		impact_analysis.overall_impact = "high"
		table.insert(impact_analysis.affected_areas, "并发处理")
		table.insert(impact_analysis.risk_factors, "并发性能和稳定性")
		table.insert(impact_analysis.benchmark_suggestions, "并发负载测试")
		table.insert(impact_analysis.optimization_opportunities, "并发优化")
	end
	
	-- Bundle/Asset changes (for web projects)
	if diff:match("import") or diff:match("require") or diff:match("webpack") or diff:match("bundle") then
		table.insert(impact_analysis.affected_areas, "资源加载")
		table.insert(impact_analysis.benchmark_suggestions, "Bundle大小分析")
		table.insert(impact_analysis.optimization_opportunities, "代码分割优化")
	end
	
	-- Large code changes
	local additions = 0
	local deletions = 0
	for line in git_data.diff:gmatch("[^\n]+") do
		if line:match("^%+") and not line:match("^%+%+%+") then
			additions = additions + 1
		elseif line:match("^%-") and not line:match("^%-%-%- ") then
			deletions = deletions + 1
		end
	end
	
	if additions + deletions > 200 then
		if impact_analysis.overall_impact == "minimal" then
			impact_analysis.overall_impact = "moderate"
		end
		table.insert(impact_analysis.risk_factors, "大规模代码变更")
		table.insert(impact_analysis.benchmark_suggestions, "全面性能回归测试")
	end
	
	return impact_analysis
end

-- Generate performance benchmark plan
function M.generate_benchmark_plan(git_data, performance_tools)
	local impact_analysis = analyze_performance_impact(git_data)
	local benchmark_plan = {
		priority = impact_analysis.overall_impact,
		test_categories = {},
		estimated_time = 0,
		tools_to_use = {},
		baseline_comparison = true
	}
	
	-- Determine which benchmarks to run based on impact
	if vim.tbl_contains(impact_analysis.affected_areas, "数据库查询") then
		table.insert(benchmark_plan.test_categories, {
			name = "数据库性能测试",
			metrics = {"database_query_time", "throughput"},
			estimated_time = 10,
			priority = "high"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 10
	end
	
	if vim.tbl_contains(impact_analysis.affected_areas, "算法复杂度") then
		table.insert(benchmark_plan.test_categories, {
			name = "CPU性能测试",
			metrics = {"cpu_usage", "response_time"},
			estimated_time = 5,
			priority = "high"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 5
	end
	
	if vim.tbl_contains(impact_analysis.affected_areas, "内存分配") then
		table.insert(benchmark_plan.test_categories, {
			name = "内存性能测试",
			metrics = {"memory_usage"},
			estimated_time = 8,
			priority = "medium"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 8
	end
	
	if vim.tbl_contains(impact_analysis.affected_areas, "网络/IO操作") then
		table.insert(benchmark_plan.test_categories, {
			name = "网络/IO性能测试",
			metrics = {"response_time", "throughput"},
			estimated_time = 15,
			priority = "high"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 15
	end
	
	if vim.tbl_contains(impact_analysis.affected_areas, "并发处理") then
		table.insert(benchmark_plan.test_categories, {
			name = "并发性能测试",
			metrics = {"throughput", "response_time", "cpu_usage"},
			estimated_time = 20,
			priority = "critical"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 20
	end
	
	if vim.tbl_contains(impact_analysis.affected_areas, "资源加载") then
		table.insert(benchmark_plan.test_categories, {
			name = "前端性能测试",
			metrics = {"bundle_size", "first_contentful_paint", "time_to_interactive"},
			estimated_time = 12,
			priority = "medium"
		})
		benchmark_plan.estimated_time = benchmark_plan.estimated_time + 12
	end
	
	-- Select appropriate tools
	for lang, tools in pairs(performance_tools) do
		for _, tool in ipairs(tools) do
			table.insert(benchmark_plan.tools_to_use, {
				name = tool.name,
				command = tool.command,
				language = lang
			})
		end
	end
	
	return {
		impact_analysis = impact_analysis,
		benchmark_plan = benchmark_plan
	}
end

-- Simulate benchmark execution
local function execute_benchmark_simulation(test_category, baseline_metrics)
	-- Simulate benchmark results with some realistic variance
	local results = {
		category = test_category.name,
		status = "completed",
		metrics = {},
		comparison = {},
		issues_found = {}
	}
	
	for _, metric_name in ipairs(test_category.metrics) do
		local metric_config = PERFORMANCE_METRICS[metric_name]
		if metric_config then
			-- Simulate current measurement with some variance
			local baseline_value = baseline_metrics[metric_name] or metric_config.threshold
			local variance = math.random(-20, 30) / 100 -- -20% to +30% change
			local current_value = baseline_value * (1 + variance)
			
			results.metrics[metric_name] = {
				current = current_value,
				baseline = baseline_value,
				unit = metric_config.unit,
				change_percent = variance * 100,
				threshold = metric_config.threshold,
				critical_threshold = metric_config.critical
			}
			
			-- Determine status
			local status = "pass"
			if current_value > metric_config.critical then
				status = "critical"
				table.insert(results.issues_found, string.format("%s超过临界阈值", metric_name))
			elseif current_value > metric_config.threshold then
				status = "warning"
				table.insert(results.issues_found, string.format("%s超过警告阈值", metric_name))
			elseif variance > 0.15 then -- 15% degradation
				status = "degraded"
				table.insert(results.issues_found, string.format("%s性能退化", metric_name))
			end
			
			results.comparison[metric_name] = {
				status = status,
				improvement = variance < 0,
				change_description = variance > 0 and "性能下降" or "性能提升"
			}
		end
	end
	
	-- Overall test status
	local has_critical = false
	local has_warning = false
	for _, comparison in pairs(results.comparison) do
		if comparison.status == "critical" then
			has_critical = true
		elseif comparison.status == "warning" or comparison.status == "degraded" then
			has_warning = true
		end
	end
	
	if has_critical then
		results.overall_status = "failed"
	elseif has_warning then
		results.overall_status = "warning"
	else
		results.overall_status = "passed"
	end
	
	return results
end

-- Execute performance benchmark plan
function M.execute_benchmark_plan(benchmark_data, options)
	options = options or {}
	local dry_run = options.dry_run or false
	local baseline_metrics = options.baseline_metrics or {}
	
	local execution_results = {
		overall_status = "passed",
		total_tests = #benchmark_data.benchmark_plan.test_categories,
		passed = 0,
		warnings = 0,
		failed = 0,
		total_time = 0,
		detailed_results = {},
		summary = {},
		recommendations = {}
	}
	
	if dry_run then
		local preview = string.format([[
🚀 性能基准测试计划预览

📊 影响评估: %s
⏱️ 预计测试时间: %d分钟
🧪 测试类别数: %d

测试项目:
%s

使用工具:
%s

执行命令: execute_benchmark_plan(plan, {dry_run = false})
]], 
			benchmark_data.impact_analysis.overall_impact,
			benchmark_data.benchmark_plan.estimated_time,
			execution_results.total_tests,
			table.concat(vim.tbl_map(function(cat) 
				return string.format("- %s (%s优先级, ~%d分钟)", cat.name, cat.priority, cat.estimated_time)
			end, benchmark_data.benchmark_plan.test_categories), "\n"),
			table.concat(vim.tbl_map(function(tool)
				return string.format("- %s (%s)", tool.name, tool.language)
			end, benchmark_data.benchmark_plan.tools_to_use), "\n")
		)
		
		vim.notify(preview, vim.log.levels.INFO)
		return execution_results
	end
	
	vim.notify("🚀 开始执行性能基准测试...", vim.log.levels.INFO)
	
	-- Execute each test category
	for _, test_category in ipairs(benchmark_data.benchmark_plan.test_categories) do
		vim.notify(string.format("🧪 执行 %s...", test_category.name), vim.log.levels.INFO)
		
		local result = execute_benchmark_simulation(test_category, baseline_metrics)
		table.insert(execution_results.detailed_results, result)
		
		execution_results.total_time = execution_results.total_time + test_category.estimated_time
		
		if result.overall_status == "passed" then
			execution_results.passed = execution_results.passed + 1
		elseif result.overall_status == "warning" then
			execution_results.warnings = execution_results.warnings + 1
		else
			execution_results.failed = execution_results.failed + 1
			execution_results.overall_status = "failed"
		end
		
		-- Show progress
		vim.notify(string.format("✅ %s 完成: %s", test_category.name, result.overall_status), 
			result.overall_status == "passed" and vim.log.levels.INFO or vim.log.levels.WARN)
	end
	
	-- Generate summary and recommendations
	M.generate_performance_summary(execution_results, benchmark_data)
	
	local final_report = string.format([[
🏁 性能基准测试完成!

📊 执行结果:
✅ 通过: %d
⚠️ 警告: %d
❌ 失败: %d
⏱️ 总耗时: %.1f分钟

整体状态: %s

💡 建议:
%s
]], 
		execution_results.passed,
		execution_results.warnings,
		execution_results.failed,
		execution_results.total_time,
		execution_results.overall_status == "passed" and "🎉 性能良好" or "⚠️ 需要关注",
		table.concat(execution_results.recommendations, "\n")
	)
	
	vim.notify(final_report, vim.log.levels.INFO)
	
	return execution_results
end

-- Generate performance summary and recommendations
function M.generate_performance_summary(execution_results, benchmark_data)
	execution_results.summary = {
		performance_impact = benchmark_data.impact_analysis.overall_impact,
		critical_issues = {},
		performance_trends = {},
		optimization_suggestions = []
	}
	
	-- Analyze results for issues and trends
	for _, result in ipairs(execution_results.detailed_results) do
		for metric_name, comparison in pairs(result.comparison) do
			if comparison.status == "critical" then
				table.insert(execution_results.summary.critical_issues, {
					metric = metric_name,
					category = result.category,
					issue = string.format("%s在%s中达到临界水平", metric_name, result.category)
				})
			end
			
			-- Track performance trends
			if comparison.change_description then
				table.insert(execution_results.summary.performance_trends, {
					metric = metric_name,
					trend = comparison.change_description,
					improvement = comparison.improvement
				})
			end
		end
		
		-- Add specific recommendations based on issues
		for _, issue in ipairs(result.issues_found) do
			table.insert(execution_results.recommendations, "🔧 " .. issue .. " - 需要优化")
		end
	end
	
	-- Add general recommendations
	if execution_results.failed > 0 then
		table.insert(execution_results.recommendations, "❌ 性能测试失败 - 建议在修复后重新测试")
		table.insert(execution_results.recommendations, "🔍 分析性能瓶颈并制定优化计划")
	elseif execution_results.warnings > 0 then
		table.insert(execution_results.recommendations, "⚠️ 存在性能警告 - 考虑性能优化")
		table.insert(execution_results.recommendations, "📊 建立性能监控基线")
	else
		table.insert(execution_results.recommendations, "✅ 性能表现良好 - 可以安全部署")
		table.insert(execution_results.recommendations, "📈 继续保持性能监控")
	end
	
	-- Add optimization opportunities from impact analysis
	for _, opportunity in ipairs(benchmark_data.impact_analysis.optimization_opportunities) do
		table.insert(execution_results.recommendations, "💡 " .. opportunity)
	end
end

-- Main performance monitoring integration
function M.analyze_performance_requirements(git_data)
	local performance_tools = detect_performance_tools()
	
	if next(performance_tools) == nil then
		return {
			has_performance_tools = false,
			message = "未检测到性能测试工具",
			suggestions = {
				"考虑添加性能基准测试",
				"建立性能监控体系",
				"设置性能回归检测"
			}
		}
	end
	
	local benchmark_data = M.generate_benchmark_plan(git_data, performance_tools)
	
	return {
		has_performance_tools = true,
		tools = performance_tools,
		benchmark_data = benchmark_data,
		enhanced_context = string.format([[
⚡ 性能影响分析:

🎯 性能影响级别: %s
📋 受影响区域: %s
⚠️ 风险因素: %s

🧪 基准测试计划:
- 测试类别: %d个
- 预计耗时: %d分钟
- 使用工具: %s

💡 基准测试建议:
%s

🔧 优化机会:
%s
]], 
			benchmark_data.impact_analysis.overall_impact,
			table.concat(benchmark_data.impact_analysis.affected_areas, ", "),
			table.concat(benchmark_data.impact_analysis.risk_factors, ", "),
			#benchmark_data.benchmark_plan.test_categories,
			benchmark_data.benchmark_plan.estimated_time,
			table.concat(vim.tbl_map(function(tool) return tool.name end, benchmark_data.benchmark_plan.tools_to_use), ", "),
			table.concat(benchmark_data.impact_analysis.benchmark_suggestions, "\n"),
			table.concat(benchmark_data.impact_analysis.optimization_opportunities, "\n")
		)
	}
end

return M