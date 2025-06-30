local M = {}

-- Advanced project analysis for context-aware commits
local function analyze_project_structure()
	local project_info = {
		language = "unknown",
		framework = "none",
		has_tests = false,
		has_ci = false,
		project_type = "unknown"
	}
	
	-- Detect project language and framework
	local package_json = vim.fn.filereadable("package.json")
	local cargo_toml = vim.fn.filereadable("Cargo.toml")
	local go_mod = vim.fn.filereadable("go.mod")
	local requirements_txt = vim.fn.filereadable("requirements.txt")
	local gemfile = vim.fn.filereadable("Gemfile")
	
	if package_json == 1 then
		project_info.language = "javascript/typescript"
		local package_content = vim.fn.readfile("package.json")
		local package_str = table.concat(package_content, "\n")
		
		if package_str:match("react") then
			project_info.framework = "react"
		elseif package_str:match("vue") then
			project_info.framework = "vue"
		elseif package_str:match("angular") then
			project_info.framework = "angular"
		elseif package_str:match("express") then
			project_info.framework = "express"
		elseif package_str:match("next") then
			project_info.framework = "nextjs"
		end
		
		project_info.has_tests = package_str:match("jest") or package_str:match("vitest") or package_str:match("cypress")
	elseif cargo_toml == 1 then
		project_info.language = "rust"
		project_info.has_tests = true -- Rust has built-in testing
	elseif go_mod == 1 then
		project_info.language = "go"
		project_info.has_tests = vim.fn.glob("*_test.go") ~= ""
	elseif requirements_txt == 1 or vim.fn.filereadable("pyproject.toml") == 1 then
		project_info.language = "python"
		project_info.has_tests = vim.fn.isdirectory("tests") == 1 or vim.fn.glob("test_*.py") ~= ""
		
		if vim.fn.filereadable("manage.py") == 1 then
			project_info.framework = "django"
		elseif vim.fn.glob("**/app.py") ~= "" then
			project_info.framework = "flask"
		end
	elseif gemfile == 1 then
		project_info.language = "ruby"
		project_info.framework = "rails"
		project_info.has_tests = vim.fn.isdirectory("spec") == 1 or vim.fn.isdirectory("test") == 1
	end
	
	-- Detect CI/CD
	project_info.has_ci = vim.fn.isdirectory(".github/workflows") == 1 or 
		vim.fn.filereadable(".gitlab-ci.yml") == 1 or
		vim.fn.filereadable("jenkins") == 1
	
	-- Determine project type
	if vim.fn.filereadable("README.md") == 1 then
		local readme = vim.fn.readfile("README.md")
		local readme_str = table.concat(readme, "\n"):lower()
		
		if readme_str:match("library") or readme_str:match("package") then
			project_info.project_type = "library"
		elseif readme_str:match("api") or readme_str:match("service") then
			project_info.project_type = "api"
		elseif readme_str:match("cli") or readme_str:match("command") then
			project_info.project_type = "cli"
		else
			project_info.project_type = "application"
		end
	end
	
	return project_info
end

-- Analyze code quality and potential issues
local function analyze_code_quality(diff_content)
	local quality_info = {
		breaking_changes = false,
		performance_impact = false,
		security_concerns = false,
		test_changes = false,
		documentation_changes = false,
		migration_required = false
	}
	
	-- Check for breaking changes
	if diff_content:match("BREAKING CHANGE") or 
	   diff_content:match("breaking") or
	   diff_content:match("removed.*function") or
	   diff_content:match("deleted.*class") then
		quality_info.breaking_changes = true
	end
	
	-- Check for performance implications
	if diff_content:match("loop") or 
	   diff_content:match("query") or
	   diff_content:match("database") or
	   diff_content:match("async") or
	   diff_content:match("Promise") then
		quality_info.performance_impact = true
	end
	
	-- Security concerns
	if diff_content:match("password") or
	   diff_content:match("token") or
	   diff_content:match("key") or
	   diff_content:match("auth") or
	   diff_content:match("security") or
	   diff_content:match("cors") or
	   diff_content:match("sql") then
		quality_info.security_concerns = true
	end
	
	-- Test file changes
	if diff_content:match("test") or
	   diff_content:match("spec") or
	   diff_content:match("%.test%.") or
	   diff_content:match("_test%.") then
		quality_info.test_changes = true
	end
	
	-- Documentation changes
	if diff_content:match("README") or
	   diff_content:match("%.md") or
	   diff_content:match("docs/") or
	   diff_content:match("documentation") then
		quality_info.documentation_changes = true
	end
	
	-- Migration or schema changes
	if diff_content:match("migration") or
	   diff_content:match("schema") or
	   diff_content:match("database") or
	   diff_content:match("CREATE TABLE") or
	   diff_content:match("ALTER TABLE") then
		quality_info.migration_required = true
	end
	
	return quality_info
end

-- Generate semantic version suggestion
local function suggest_semantic_version(quality_info, project_info)
	if quality_info.breaking_changes then
		return "major", "Breaking changes detected - consider major version bump"
	elseif quality_info.migration_required then
		return "minor", "Database/schema changes - consider minor version bump"
	elseif quality_info.test_changes and not quality_info.documentation_changes then
		return "patch", "Test improvements - patch version appropriate"
	elseif quality_info.documentation_changes and not quality_info.test_changes then
		return "patch", "Documentation updates - patch version appropriate"
	else
		return "minor", "Feature additions/improvements - minor version appropriate"
	end
end

-- Generate impact assessment report
local function generate_impact_assessment(quality_info, project_info)
	local impacts = {}
	
	if quality_info.breaking_changes then
		table.insert(impacts, "⚠️ Breaking changes detected - API consumers may need updates")
	end
	
	if quality_info.performance_impact then
		table.insert(impacts, "🚀 Performance-related changes - monitor metrics after deployment")
	end
	
	if quality_info.security_concerns then
		table.insert(impacts, "🔒 Security-related changes - review access patterns and permissions")
	end
	
	if quality_info.migration_required then
		table.insert(impacts, "🗄️ Database changes - coordinate with DevOps for migration")
	end
	
	if project_info.has_ci and not quality_info.test_changes then
		table.insert(impacts, "🧪 Consider adding tests for new functionality")
	end
	
	return impacts
end

-- Enhanced commit analysis with project context
function M.analyze_commit_context(git_data)
	local project_info = analyze_project_structure()
	local quality_info = analyze_code_quality(git_data.diff)
	local version_type, version_reason = suggest_semantic_version(quality_info, project_info)
	local impacts = generate_impact_assessment(quality_info, project_info)
	
	return {
		project = project_info,
		quality = quality_info,
		version_suggestion = {
			type = version_type,
			reason = version_reason
		},
		impacts = impacts,
		enhanced_context = string.format([[
项目上下文:
- 语言/框架: %s/%s
- 项目类型: %s
- 包含测试: %s
- CI/CD: %s

代码质量分析:
- 破坏性变更: %s
- 性能影响: %s
- 安全相关: %s
- 测试变更: %s
- 文档变更: %s

版本建议: %s (%s)

影响评估:
%s
]], 
			project_info.language, 
			project_info.framework,
			project_info.project_type,
			project_info.has_tests and "是" or "否",
			project_info.has_ci and "已配置" or "未配置",
			quality_info.breaking_changes and "是" or "否",
			quality_info.performance_impact and "可能" or "否",
			quality_info.security_concerns and "是" or "否",
			quality_info.test_changes and "是" or "否",
			quality_info.documentation_changes and "是" or "否",
			version_type,
			version_reason,
			#impacts > 0 and table.concat(impacts, "\n") or "无特殊影响"
		)
	}
end

return M