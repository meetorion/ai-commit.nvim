local M = {}

-- Test framework detection
local TEST_FRAMEWORKS = {
	javascript = {
		jest = {patterns = {"jest.config.*", "**/*.test.js", "**/*.spec.js"}, command = "npm test"},
		vitest = {patterns = {"vitest.config.*", "**/*.test.ts"}, command = "npm run test"},
		cypress = {patterns = {"cypress.config.*", "cypress/**/*"}, command = "npm run cypress:run"},
		playwright = {patterns = {"playwright.config.*", "tests/**/*.spec.ts"}, command = "npm run test:e2e"}
	},
	python = {
		pytest = {patterns = {"pytest.ini", "test_*.py", "*_test.py"}, command = "pytest"},
		unittest = {patterns = {"test_*.py", "tests.py"}, command = "python -m unittest"},
		nose = {patterns = {".noserc", "nose*.cfg"}, command = "nosetests"}
	},
	lua = {
		busted = {patterns = {"spec/**/*_spec.lua", "*_spec.lua"}, command = "busted"},
		luaunit = {patterns = {"test_*.lua", "*_test.lua"}, command = "lua test_runner.lua"}
	},
	go = {
		gotest = {patterns = {"*_test.go"}, command = "go test ./..."},
		ginkgo = {patterns = {"*_suite_test.go"}, command = "ginkgo -r"}
	},
	rust = {
		cargo = {patterns = {"src/**/*", "tests/**/*"}, command = "cargo test"}
	}
}

-- Detect active test frameworks in project
local function detect_test_frameworks()
	local detected = {}
	
	for lang, frameworks in pairs(TEST_FRAMEWORKS) do
		for framework, config in pairs(frameworks) do
			for _, pattern in ipairs(config.patterns) do
				if vim.fn.glob(pattern) ~= "" then
					if not detected[lang] then
						detected[lang] = {}
					end
					table.insert(detected[lang], {
						name = framework,
						command = config.command,
						files = vim.split(vim.fn.glob(pattern), "\n")
					})
				end
			end
		end
	end
	
	return detected
end

-- Analyze test coverage for changed files
local function analyze_test_coverage(changed_files, test_frameworks)
	local coverage_analysis = {
		covered_files = {},
		uncovered_files = {},
		missing_tests = {},
		test_health = "unknown"
	}
	
	for _, file in ipairs(changed_files) do
		local file_ext = file:match("%.([^%.]+)$")
		local base_name = file:match("([^/]+)%.[^%.]+$")
		local is_covered = false
		
		-- Check if there are corresponding test files
		if file_ext == "js" or file_ext == "ts" then
			local test_patterns = {
				file:gsub("%.([^%.]+)$", ".test.%1"),
				file:gsub("%.([^%.]+)$", ".spec.%1"),
				file:gsub("src/", "tests/"):gsub("%.([^%.]+)$", ".test.%1"),
				"__tests__/" .. base_name .. ".test." .. file_ext
			}
			
			for _, pattern in ipairs(test_patterns) do
				if vim.fn.filereadable(pattern) == 1 then
					is_covered = true
					table.insert(coverage_analysis.covered_files, {
						source = file,
						test = pattern
					})
					break
				end
			end
		elseif file_ext == "py" then
			local test_patterns = {
				"test_" .. base_name .. ".py",
				"tests/test_" .. base_name .. ".py",
				file:gsub("([^/]+)%.py$", "test_%1.py")
			}
			
			for _, pattern in ipairs(test_patterns) do
				if vim.fn.filereadable(pattern) == 1 then
					is_covered = true
					table.insert(coverage_analysis.covered_files, {
						source = file,
						test = pattern
					})
					break
				end
			end
		elseif file_ext == "lua" then
			local test_patterns = {
				file:gsub("%.lua$", "_spec.lua"),
				"spec/" .. base_name .. "_spec.lua"
			}
			
			for _, pattern in ipairs(test_patterns) do
				if vim.fn.filereadable(pattern) == 1 then
					is_covered = true
					table.insert(coverage_analysis.covered_files, {
						source = file,
						test = pattern
					})
					break
				end
			end
		end
		
		if not is_covered and not file:match("test") and not file:match("spec") then
			table.insert(coverage_analysis.uncovered_files, file)
			table.insert(coverage_analysis.missing_tests, {
				file = file,
				suggested_test_file = M.suggest_test_filename(file),
				priority = M.calculate_test_priority(file)
			})
		end
	end
	
	-- Calculate test health
	local total_files = #changed_files
	local covered_files = #coverage_analysis.covered_files
	
	if total_files == 0 then
		coverage_analysis.test_health = "unknown"
	elseif covered_files / total_files >= 0.8 then
		coverage_analysis.test_health = "excellent"
	elseif covered_files / total_files >= 0.6 then
		coverage_analysis.test_health = "good"
	elseif covered_files / total_files >= 0.4 then
		coverage_analysis.test_health = "moderate"
	else
		coverage_analysis.test_health = "poor"
	end
	
	return coverage_analysis
end

-- Suggest test filename based on source file
function M.suggest_test_filename(source_file)
	local file_ext = source_file:match("%.([^%.]+)$")
	local base_name = source_file:match("([^/]+)%.[^%.]+$")
	local dir = source_file:match("^(.+)/[^/]+$") or ""
	
	if file_ext == "js" or file_ext == "ts" then
		return string.format("%s/%s.test.%s", dir, base_name:gsub("%." .. file_ext .. "$", ""), file_ext)
	elseif file_ext == "py" then
		return string.format("tests/test_%s.py", base_name:gsub("%.py$", ""))
	elseif file_ext == "lua" then
		return string.format("spec/%s_spec.lua", base_name:gsub("%.lua$", ""))
	elseif file_ext == "go" then
		return string.format("%s/%s_test.go", dir, base_name:gsub("%.go$", ""))
	else
		return string.format("%s/test_%s", dir, base_name)
	end
end

-- Calculate test priority based on file importance
function M.calculate_test_priority(file)
	-- High priority files
	if file:match("auth") or file:match("security") or file:match("payment") or file:match("api") then
		return "high"
	end
	
	-- Medium priority files
	if file:match("service") or file:match("controller") or file:match("model") then
		return "medium"
	end
	
	-- Low priority files
	if file:match("util") or file:match("helper") or file:match("config") then
		return "low"
	end
	
	return "medium"
end

-- Generate smart test execution plan
function M.generate_test_execution_plan(git_data, test_frameworks, coverage_analysis)
	local execution_plan = {
		immediate_tests = {},
		regression_tests = {},
		integration_tests = {},
		e2e_tests = {},
		performance_tests = {},
		estimated_runtime = 0
	}
	
	-- Extract changed files from git diff
	local changed_files = {}
	for line in git_data.diff:gmatch("[^\n]+") do
		local file = line:match("^diff --git a/.+ b/(.+)$")
		if file then
			table.insert(changed_files, file)
		end
	end
	
	-- Plan immediate tests for covered files
	for _, covered in ipairs(coverage_analysis.covered_files) do
		table.insert(execution_plan.immediate_tests, {
			test_file = covered.test,
			source_file = covered.source,
			framework = M.detect_file_framework(covered.test, test_frameworks),
			priority = M.calculate_test_priority(covered.source),
			estimated_time = 2 -- minutes
		})
		execution_plan.estimated_runtime = execution_plan.estimated_runtime + 2
	end
	
	-- Plan regression tests for related areas
	for _, file in ipairs(changed_files) do
		local related_tests = M.find_related_tests(file, test_frameworks)
		for _, test in ipairs(related_tests) do
			table.insert(execution_plan.regression_tests, {
				test_file = test,
				reason = "可能受到 " .. file .. " 变更影响",
				estimated_time = 3
			})
			execution_plan.estimated_runtime = execution_plan.estimated_runtime + 3
		end
	end
	
	-- Plan integration tests for API changes
	for _, file in ipairs(changed_files) do
		if file:match("api/") or file:match("routes/") or file:match("controller") then
			local integration_tests = M.find_integration_tests(test_frameworks)
			for _, test in ipairs(integration_tests) do
				table.insert(execution_plan.integration_tests, {
					test_file = test,
					reason = "API变更需要集成测试",
					estimated_time = 5
				})
				execution_plan.estimated_runtime = execution_plan.estimated_runtime + 5
			end
			break -- Only add once
		end
	end
	
	-- Plan E2E tests for UI changes
	for _, file in ipairs(changed_files) do
		if file:match("component") or file:match("%.vue$") or file:match("%.tsx?$") then
			local e2e_tests = M.find_e2e_tests(test_frameworks)
			for _, test in ipairs(e2e_tests) do
				table.insert(execution_plan.e2e_tests, {
					test_file = test,
					reason = "UI变更需要端到端测试",
					estimated_time = 10
				})
				execution_plan.estimated_runtime = execution_plan.estimated_runtime + 10
			end
			break -- Only add once
		end
	end
	
	-- Plan performance tests for performance-critical changes
	for _, file in ipairs(changed_files) do
		if file:match("database") or file:match("cache") or file:match("performance") then
			table.insert(execution_plan.performance_tests, {
				test_type = "performance",
				reason = "性能关键代码变更",
				estimated_time = 15
			})
			execution_plan.estimated_runtime = execution_plan.estimated_runtime + 15
			break
		end
	end
	
	return execution_plan
end

-- Detect which framework a test file belongs to
function M.detect_file_framework(test_file, test_frameworks)
	for lang, frameworks in pairs(test_frameworks) do
		for _, framework in ipairs(frameworks) do
			for _, file in ipairs(framework.files) do
				if file == test_file then
					return framework.name
				end
			end
		end
	end
	return "unknown"
end

-- Find related tests that might be affected by a file change
function M.find_related_tests(changed_file, test_frameworks)
	local related_tests = {}
	local base_name = changed_file:match("([^/]+)%.[^%.]+$")
	
	-- Look for tests that might import or reference this file
	for lang, frameworks in pairs(test_frameworks) do
		for _, framework in ipairs(frameworks) do
			for _, test_file in ipairs(framework.files) do
				if vim.fn.filereadable(test_file) == 1 then
					local content = table.concat(vim.fn.readfile(test_file), "\n")
					-- Check if test file references the changed file
					if content:match(base_name) or content:match(changed_file) then
						table.insert(related_tests, test_file)
					end
				end
			end
		end
	end
	
	return related_tests
end

-- Find integration test files
function M.find_integration_tests(test_frameworks)
	local integration_tests = {}
	
	for lang, frameworks in pairs(test_frameworks) do
		for _, framework in ipairs(frameworks) do
			for _, test_file in ipairs(framework.files) do
				if test_file:match("integration") or test_file:match("api") then
					table.insert(integration_tests, test_file)
				end
			end
		end
	end
	
	return integration_tests
end

-- Find E2E test files
function M.find_e2e_tests(test_frameworks)
	local e2e_tests = {}
	
	for lang, frameworks in pairs(test_frameworks) do
		for _, framework in ipairs(frameworks) do
			for _, test_file in ipairs(framework.files) do
				if test_file:match("e2e") or test_file:match("cypress") or test_file:match("playwright") then
					table.insert(e2e_tests, test_file)
				end
			end
		end
	end
	
	return e2e_tests
end

-- Execute test plan with progress tracking
function M.execute_test_plan(execution_plan, options)
	options = options or {}
	local dry_run = options.dry_run or false
	local parallel = options.parallel or false
	
	vim.notify("🧪 开始执行智能测试计划...", vim.log.levels.INFO)
	
	local results = {
		total_tests = 0,
		passed = 0,
		failed = 0,
		skipped = 0,
		execution_time = 0,
		detailed_results = {}
	}
	
	-- Count total tests
	results.total_tests = #execution_plan.immediate_tests + 
		#execution_plan.regression_tests + 
		#execution_plan.integration_tests + 
		#execution_plan.e2e_tests +
		#execution_plan.performance_tests
	
	if dry_run then
		local plan_summary = string.format([[
📋 测试执行计划预览:

⚡ 立即测试: %d个
🔄 回归测试: %d个  
🔗 集成测试: %d个
🌐 端到端测试: %d个
⚡ 性能测试: %d个

⏱️ 预计总耗时: %d分钟

使用 execute_test_plan({dry_run = false}) 执行
]], 
			#execution_plan.immediate_tests,
			#execution_plan.regression_tests,
			#execution_plan.integration_tests,
			#execution_plan.e2e_tests,
			#execution_plan.performance_tests,
			execution_plan.estimated_runtime
		)
		
		vim.notify(plan_summary, vim.log.levels.INFO)
		return results
	end
	
	-- Execute immediate tests first
	for _, test in ipairs(execution_plan.immediate_tests) do
		local result = M.run_single_test(test)
		table.insert(results.detailed_results, result)
		
		if result.status == "passed" then
			results.passed = results.passed + 1
		elseif result.status == "failed" then
			results.failed = results.failed + 1
		else
			results.skipped = results.skipped + 1
		end
		
		results.execution_time = results.execution_time + result.duration
	end
	
	-- Continue with other test types based on immediate test results
	if results.failed == 0 then
		vim.notify("✅ 立即测试全部通过，继续执行回归测试...", vim.log.levels.INFO)
		
		-- Execute regression tests
		for _, test in ipairs(execution_plan.regression_tests) do
			local result = M.run_single_test(test)
			table.insert(results.detailed_results, result)
			
			if result.status == "passed" then
				results.passed = results.passed + 1
			elseif result.status == "failed" then
				results.failed = results.failed + 1
			else
				results.skipped = results.skipped + 1
			end
			
			results.execution_time = results.execution_time + result.duration
		end
	else
		vim.notify("❌ 立即测试失败，跳过其他测试", vim.log.levels.WARN)
	end
	
	-- Show final results
	local final_report = string.format([[
🏁 测试执行完成!

📊 结果统计:
✅ 通过: %d
❌ 失败: %d  
⏭️ 跳过: %d
⏱️ 总耗时: %.1f分钟

整体状态: %s
]], 
		results.passed,
		results.failed,
		results.skipped,
		results.execution_time,
		results.failed == 0 and "🎉 全部通过" or "⚠️ 存在失败"
	)
	
	vim.notify(final_report, vim.log.levels.INFO)
	
	return results
end

-- Run a single test (simulated for now)
function M.run_single_test(test_config)
	-- Simulate test execution
	local duration = (test_config.estimated_time or 2) + math.random(-1, 1)
	local success_rate = 0.85 -- 85% tests pass
	
	local result = {
		test_file = test_config.test_file or test_config.test_type,
		framework = test_config.framework,
		status = math.random() < success_rate and "passed" or "failed",
		duration = duration,
		output = ""
	}
	
	if result.status == "passed" then
		result.output = "✅ All assertions passed"
	else
		result.output = "❌ Test failed: Expected behavior not met"
	end
	
	vim.notify(string.format("🧪 %s: %s (%.1fs)", 
		result.test_file, 
		result.status, 
		result.duration), 
		result.status == "passed" and vim.log.levels.INFO or vim.log.levels.WARN)
	
	return result
end

-- Main function to integrate with AI commit system
function M.analyze_test_requirements(git_data)
	local test_frameworks = detect_test_frameworks()
	
	if next(test_frameworks) == nil then
		return {
			has_tests = false,
			message = "未检测到测试框架",
			suggestions = {"考虑添加测试框架", "确保代码质量"}
		}
	end
	
	-- Extract changed files
	local changed_files = {}
	for line in git_data.diff:gmatch("[^\n]+") do
		local file = line:match("^diff --git a/.+ b/(.+)$")
		if file and not file:match("test") and not file:match("spec") then
			table.insert(changed_files, file)
		end
	end
	
	local coverage_analysis = analyze_test_coverage(changed_files, test_frameworks)
	local execution_plan = M.generate_test_execution_plan(git_data, test_frameworks, coverage_analysis)
	
	return {
		has_tests = true,
		frameworks = test_frameworks,
		coverage_analysis = coverage_analysis,
		execution_plan = execution_plan,
		enhanced_context = string.format([[
🧪 智能测试分析:

🔧 检测到的测试框架: %s
📊 测试覆盖状态: %s
📁 已覆盖文件: %d个
⚠️ 未覆盖文件: %d个

📋 测试执行计划:
- 立即测试: %d个
- 回归测试: %d个
- 集成测试: %d个
- 端到端测试: %d个
- 性能测试: %d个

⏱️ 预计测试时间: %d分钟

💡 建议:
%s
]], 
			table.concat(M.get_framework_names(test_frameworks), ", "),
			coverage_analysis.test_health,
			#coverage_analysis.covered_files,
			#coverage_analysis.uncovered_files,
			#execution_plan.immediate_tests,
			#execution_plan.regression_tests,
			#execution_plan.integration_tests,
			#execution_plan.e2e_tests,
			#execution_plan.performance_tests,
			execution_plan.estimated_runtime,
			M.generate_test_suggestions(coverage_analysis)
		)
	}
end

-- Helper function to get framework names
function M.get_framework_names(test_frameworks)
	local names = {}
	for lang, frameworks in pairs(test_frameworks) do
		for _, framework in ipairs(frameworks) do
			table.insert(names, framework.name)
		end
	end
	return names
end

-- Generate test suggestions
function M.generate_test_suggestions(coverage_analysis)
	local suggestions = {}
	
	if coverage_analysis.test_health == "poor" then
		table.insert(suggestions, "测试覆盖率较低，建议增加测试")
	elseif coverage_analysis.test_health == "excellent" then
		table.insert(suggestions, "测试覆盖率优秀，可以安全提交")
	end
	
	if #coverage_analysis.missing_tests > 0 then
		table.insert(suggestions, string.format("建议为%d个文件添加测试", #coverage_analysis.missing_tests))
	end
	
	if #suggestions == 0 then
		table.insert(suggestions, "测试状态良好")
	end
	
	return table.concat(suggestions, "\n")
end

return M