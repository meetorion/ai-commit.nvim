local M = {}

-- Security vulnerability patterns by category
local SECURITY_PATTERNS = {
	injection = {
		name = "注入攻击",
		severity = "critical",
		icon = "💉",
		patterns = {
			-- SQL Injection
			{
				pattern = "SELECT.*%+.*['\"]",
				message = "潜在SQL注入风险：字符串拼接构建SQL查询",
				suggestion = "使用参数化查询或ORM防止SQL注入",
				languages = {"javascript", "python", "php", "java", "csharp"}
			},
			{
				pattern = "query.*fmt%.Sprintf",
				message = "Go SQL注入风险：使用fmt.Sprintf构建查询",
				suggestion = "使用database/sql包的参数化查询",
				languages = {"go"}
			},
			-- Command Injection
			{
				pattern = "exec.*%+.*['\"]",
				message = "命令注入风险：动态构建系统命令",
				suggestion = "避免执行用户输入的命令，使用白名单验证",
				languages = {"javascript", "python", "go", "java"}
			},
			{
				pattern = "os%.system.*%+",
				message = "命令注入风险：动态系统调用",
				suggestion = "使用subprocess模块或类似的安全替代方案",
				languages = {"python"}
			},
			-- XSS
			{
				pattern = "innerHTML.*%+",
				message = "XSS风险：动态HTML内容注入",
				suggestion = "使用textContent或进行HTML转义",
				languages = {"javascript"}
			},
			{
				pattern = "document%.write.*%+",
				message = "XSS风险：动态文档写入",
				suggestion = "避免使用document.write，使用DOM操作",
				languages = {"javascript"}
			}
		}
	},
	
	authentication = {
		name = "认证安全",
		severity = "high",
		icon = "🔐",
		patterns = {
			{
				pattern = "password.*==.*['\"]",
				message = "硬编码密码：密码直接写在代码中",
				suggestion = "使用环境变量或安全的配置管理系统",
				languages = {"all"}
			},
			{
				pattern = "token.*['\"][a-zA-Z0-9]{20,}['\"]",
				message = "硬编码令牌：API令牌直接写在代码中",
				suggestion = "将敏感信息存储在环境变量中",
				languages = {"all"}
			},
			{
				pattern = "jwt%.sign.*['\"][^'\"]*['\"]",
				message = "JWT密钥安全：检查密钥强度",
				suggestion = "使用强密钥并从环境变量读取",
				languages = {"javascript"}
			},
			{
				pattern = "md5.*password",
				message = "弱哈希算法：MD5不适合密码哈希",
				suggestion = "使用bcrypt、scrypt或Argon2等安全哈希算法",
				languages = {"all"}
			}
		}
	},
	
	cryptography = {
		name = "加密安全", 
		severity = "high",
		icon = "🔒",
		patterns = {
			{
				pattern = "AES.*ECB",
				message = "不安全的加密模式：ECB模式存在安全风险",
				suggestion = "使用CBC、GCM或其他安全的加密模式",
				languages = {"all"}
			},
			{
				pattern = "crypto%.createCipher",
				message = "已弃用的加密函数：createCipher不安全",
				suggestion = "使用createCipheriv并提供明确的IV",
				languages = {"javascript"}
			},
			{
				pattern = "Random%(%)",
				message = "弱随机数生成：普通Random不适合加密用途",
				suggestion = "使用SecureRandom或crypto安全随机数生成器",
				languages = {"java"}
			},
			{
				pattern = "DES.*Cipher",
				message = "弱加密算法：DES已被认为不安全",
				suggestion = "使用AES-256或其他现代加密算法",
				languages = {"java", "csharp"}
			}
		}
	},
	
	input_validation = {
		name = "输入验证",
		severity = "medium",
		icon = "🛡️",
		patterns = {
			{
				pattern = "eval%s*%(",
				message = "危险函数：eval执行任意代码",
				suggestion = "避免使用eval，使用JSON.parse或其他安全解析方法",
				languages = {"javascript", "python"}
			},
			{
				pattern = "pickle%.loads?%s*%(",
				message = "不安全的反序列化：pickle.loads存在代码执行风险",
				suggestion = "使用json模块或其他安全的序列化方法",
				languages = {"python"}
			},
			{
				pattern = "yaml%.load%s*%(",
				message = "不安全的YAML解析：可能执行任意代码",
				suggestion = "使用yaml.safe_load替代yaml.load",
				languages = {"python"}
			},
			{
				pattern = "\\$\\{.*\\}",
				message = "模板注入风险：动态模板可能存在注入",
				suggestion = "验证和转义模板变量",
				languages = {"javascript", "java"}
			}
		}
	},
	
	information_disclosure = {
		name = "信息泄露",
		severity = "medium", 
		icon = "📤",
		patterns = {
			{
				pattern = "console%.log.*password",
				message = "敏感信息记录：密码可能泄露到日志",
				suggestion = "避免记录敏感信息",
				languages = {"javascript"}
			},
			{
				pattern = "print.*password",
				message = "敏感信息输出：密码可能泄露到输出",
				suggestion = "移除或屏蔽敏感信息的输出",
				languages = {"python"}
			},
			{
				pattern = "stack[Tt]race",
				message = "堆栈跟踪泄露：可能暴露系统信息",
				suggestion = "在生产环境中禁用详细错误信息",
				languages = {"all"}
			},
			{
				pattern = "[aA]pi[_-]?[kK]ey.*['\"][A-Za-z0-9]{20,}['\"]",
				message = "API密钥泄露：代码中包含API密钥",
				suggestion = "将API密钥移至环境变量",
				languages = {"all"}
			}
		}
	},
	
	resource_management = {
		name = "资源管理",
		severity = "medium",
		icon = "🏗️", 
		patterns = {
			{
				pattern = "while.*true.*%)",
				message = "潜在的无限循环：可能导致资源耗尽",
				suggestion = "确保循环有明确的退出条件",
				languages = {"all"}
			},
			{
				pattern = "recursion.*without.*limit",
				message = "无限递归风险：可能导致栈溢出",
				suggestion = "添加递归深度限制",
				languages = {"all"}
			},
			{
				pattern = "setTimeout.*0",
				message = "性能问题：可能导致事件循环阻塞",
				suggestion = "考虑使用requestAnimationFrame或其他替代方案",
				languages = {"javascript"}
			}
		}
	}
}

-- Common sensitive data patterns
local SENSITIVE_DATA_PATTERNS = {
	{
		pattern = "password.*['\"][^'\"]{6,}['\"]",
		message = "硬编码密码",
		severity = "critical"
	},
	{
		pattern = "[aA]ccess[_-]?[kK]ey.*['\"][A-Za-z0-9]{16,}['\"]",
		message = "硬编码访问密钥",
		severity = "critical"
	},
	{
		pattern = "[sS]ecret[_-]?[kK]ey.*['\"][A-Za-z0-9]{16,}['\"]",
		message = "硬编码密钥",
		severity = "critical"
	},
	{
		pattern = "jwt.*['\"][A-Za-z0-9_-]{100,}['\"]",
		message = "硬编码JWT令牌",
		severity = "high"
	},
	{
		pattern = "bearer.*['\"][A-Za-z0-9_-]{20,}['\"]",
		message = "硬编码Bearer令牌",
		severity = "high"
	},
	{
		pattern = "ssh.*rsa.*BEGIN",
		message = "嵌入的SSH私钥",
		severity = "critical"
	},
	{
		pattern = "-----BEGIN.*PRIVATE.*KEY-----",
		message = "嵌入的私钥",
		severity = "critical"
	}
}

-- Scan content for security vulnerabilities
function M.scan_content(content, language, file_path)
	local vulnerabilities = {}
	local lines = vim.split(content, "\n")
	
	-- Check each security pattern category
	for category_name, category_data in pairs(SECURITY_PATTERNS) do
		for _, pattern_config in ipairs(category_data.patterns) do
			-- Check if pattern applies to current language
			if vim.tbl_contains(pattern_config.languages, language) or 
			   vim.tbl_contains(pattern_config.languages, "all") then
				
				for line_num, line in ipairs(lines) do
					if line:match(pattern_config.pattern) then
						table.insert(vulnerabilities, {
							category = category_name,
							severity = category_data.severity,
							line = line_num,
							message = pattern_config.message,
							suggestion = pattern_config.suggestion,
							pattern = pattern_config.pattern,
							code_snippet = line:gsub("^%s+", ""):gsub("%s+$", ""),
							file_path = file_path,
							icon = category_data.icon
						})
					end
				end
			end
		end
	end
	
	-- Check for sensitive data patterns
	for _, sensitive_pattern in ipairs(SENSITIVE_DATA_PATTERNS) do
		for line_num, line in ipairs(lines) do
			if line:match(sensitive_pattern.pattern) then
				table.insert(vulnerabilities, {
					category = "information_disclosure",
					severity = sensitive_pattern.severity,
					line = line_num,
					message = sensitive_pattern.message,
					suggestion = "将敏感信息移至环境变量或安全配置文件",
					pattern = sensitive_pattern.pattern,
					code_snippet = "***敏感信息已隐藏***",
					file_path = file_path,
					icon = "🔐"
				})
			end
		end
	end
	
	return vulnerabilities
end

-- Perform dependency security analysis
function M.analyze_dependencies(file_path)
	local dependency_issues = {}
	
	-- Check package files for known vulnerable packages
	local vulnerable_packages = {
		javascript = {
			["lodash"] = {version = "<4.17.21", issue = "原型污染漏洞"},
			["moment"] = {version = "all", issue = "不再维护，建议迁移到dayjs"},
			["request"] = {version = "all", issue = "已弃用，存在安全风险"},
			["node-sass"] = {version = "<6.0.0", issue = "已知安全漏洞"}
		},
		python = {
			["requests"] = {version = "<2.25.0", issue = "SSL验证绕过漏洞"},
			["flask"] = {version = "<1.1.2", issue = "XSS和open redirect漏洞"},
			["django"] = {version = "<3.1.12", issue = "SQL注入和XSS漏洞"},
			["pyyaml"] = {version = "<5.4", issue = "任意代码执行漏洞"}
		},
		go = {
			["golang.org/x/text"] = {version = "<0.3.7", issue = "DoS漏洞"},
			["github.com/dgrijalva/jwt-go"] = {version = "all", issue = "不再维护，使用golang-jwt/jwt"}
		}
	}
	
	if file_path:match("package%.json$") then
		-- Analyze JavaScript dependencies
		if vim.fn.filereadable(file_path) == 1 then
			local content = table.concat(vim.fn.readfile(file_path), "\n")
			local packages = vulnerable_packages.javascript
			
			for package_name, vuln_info in pairs(packages) do
				if content:match('"' .. package_name .. '"') then
					table.insert(dependency_issues, {
						type = "vulnerable_dependency",
						package = package_name,
						issue = vuln_info.issue,
						version_constraint = vuln_info.version,
						severity = "high",
						suggestion = string.format("更新 %s 到安全版本", package_name)
					})
				end
			end
		end
		
	elseif file_path:match("requirements%.txt$") or file_path:match("setup%.py$") then
		-- Analyze Python dependencies
		if vim.fn.filereadable(file_path) == 1 then
			local content = table.concat(vim.fn.readfile(file_path), "\n")
			local packages = vulnerable_packages.python
			
			for package_name, vuln_info in pairs(packages) do
				if content:match(package_name) then
					table.insert(dependency_issues, {
						type = "vulnerable_dependency", 
						package = package_name,
						issue = vuln_info.issue,
						version_constraint = vuln_info.version,
						severity = "high",
						suggestion = string.format("更新 %s 到安全版本", package_name)
					})
				end
			end
		end
		
	elseif file_path:match("go%.mod$") then
		-- Analyze Go dependencies
		if vim.fn.filereadable(file_path) == 1 then
			local content = table.concat(vim.fn.readfile(file_path), "\n")
			local packages = vulnerable_packages.go
			
			for package_name, vuln_info in pairs(packages) do
				if content:match(package_name) then
					table.insert(dependency_issues, {
						type = "vulnerable_dependency",
						package = package_name,
						issue = vuln_info.issue,
						version_constraint = vuln_info.version,
						severity = "high",
						suggestion = string.format("更新或替换 %s", package_name)
					})
				end
			end
		end
	end
	
	return dependency_issues
end

-- Generate security report
function M.generate_security_report(vulnerabilities, dependency_issues)
	local total_issues = #vulnerabilities + #dependency_issues
	
	if total_issues == 0 then
		return "✅ 未发现安全问题，代码安全性良好！"
	end
	
	-- Categorize vulnerabilities by severity
	local severity_counts = {critical = 0, high = 0, medium = 0, low = 0}
	local category_counts = {}
	
	for _, vuln in ipairs(vulnerabilities) do
		severity_counts[vuln.severity] = severity_counts[vuln.severity] + 1
		if not category_counts[vuln.category] then
			category_counts[vuln.category] = 0
		end
		category_counts[vuln.category] = category_counts[vuln.category] + 1
	end
	
	for _, dep_issue in ipairs(dependency_issues) do
		severity_counts[dep_issue.severity] = severity_counts[dep_issue.severity] + 1
	end
	
	-- Calculate security score
	local security_score = math.max(0, 100 - (
		severity_counts.critical * 30 +
		severity_counts.high * 20 +
		severity_counts.medium * 10 +
		severity_counts.low * 5
	))
	
	-- Generate report header
	local report = string.format([[
🔒 安全扫描报告

📊 安全评分: %.1f/100 (%s)
🔍 发现问题: %d个
📦 依赖问题: %d个

⚠️ 严重程度分布:
🚨 严重: %d个
🔴 高: %d个
🟡 中等: %d个
🔵 低: %d个

]], 
		security_score,
		security_score >= 90 and "优秀" or security_score >= 80 and "良好" or 
		security_score >= 70 and "一般" or security_score >= 60 and "需关注" or "高风险",
		#vulnerabilities,
		#dependency_issues,
		severity_counts.critical,
		severity_counts.high,
		severity_counts.medium,
		severity_counts.low
	)
	
	-- Add category breakdown
	if next(category_counts) then
		report = report .. "📋 问题分类:\n"
		for category, count in pairs(category_counts) do
			local category_data = SECURITY_PATTERNS[category]
			if category_data then
				report = report .. string.format("%s %s: %d个\n", 
					category_data.icon, category_data.name, count)
			end
		end
		report = report .. "\n"
	end
	
	-- Add top vulnerabilities
	if #vulnerabilities > 0 then
		report = report .. "🔍 主要安全问题:\n"
		
		-- Sort by severity
		local sorted_vulns = vim.deepcopy(vulnerabilities)
		table.sort(sorted_vulns, function(a, b)
			local severity_order = {critical = 4, high = 3, medium = 2, low = 1}
			return severity_order[a.severity] > severity_order[b.severity]
		end)
		
		for i, vuln in ipairs(sorted_vulns) do
			if i <= 5 then -- Show top 5 issues
				report = report .. string.format("%s [%s] L%d: %s\n", 
					vuln.icon, vuln.severity:upper(), vuln.line, vuln.message)
				report = report .. string.format("   💡 %s\n", vuln.suggestion)
				if vuln.file_path then
					report = report .. string.format("   📁 %s\n", vuln.file_path)
				end
				report = report .. "\n"
			end
		end
	end
	
	-- Add dependency issues
	if #dependency_issues > 0 then
		report = report .. "📦 依赖安全问题:\n"
		for _, issue in ipairs(dependency_issues) do
			report = report .. string.format("🔴 %s: %s\n", issue.package, issue.issue)
			report = report .. string.format("   💡 %s\n", issue.suggestion)
		end
		report = report .. "\n"
	end
	
	-- Add recommendations
	report = report .. "💡 安全建议:\n"
	if security_score >= 90 then
		report = report .. "✅ 安全状况优秀，继续保持最佳实践\n"
	elseif security_score >= 80 then
		report = report .. "👍 安全状况良好，关注高优先级问题\n"
	else
		report = report .. "🚨 发现严重安全风险，建议立即修复\n"
		report = report .. "🛡️ 建立安全代码审查流程\n"
		report = report .. "📚 团队安全培训和意识提升\n"
	end
	
	if #dependency_issues > 0 then
		report = report .. "📦 定期更新依赖并使用安全扫描工具\n"
	end
	
	return report
end

-- Quick security check for git changes
function M.quick_security_scan(git_data)
	if not git_data or not git_data.diff then
		return {error = "没有找到Git变更数据"}
	end
	
	local total_vulnerabilities = {}
	local files_scanned = 0
	
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
	
	-- Scan each changed file
	for file_path, added_lines in pairs(changed_files) do
		if #added_lines > 0 then
			local code_review_engine = require("code_review_engine")
			local language = code_review_engine.detect_language(file_path)
			local content = table.concat(added_lines, "\n")
			
			local vulnerabilities = M.scan_content(content, language, file_path)
			local dependency_issues = M.analyze_dependencies(file_path)
			
			vim.list_extend(total_vulnerabilities, vulnerabilities)
			vim.list_extend(total_vulnerabilities, vim.tbl_map(function(issue)
				return {
					category = "dependency",
					severity = issue.severity,
					message = string.format("依赖问题: %s - %s", issue.package, issue.issue),
					suggestion = issue.suggestion,
					file_path = file_path,
					icon = "📦"
				}
			end, dependency_issues))
			
			files_scanned = files_scanned + 1
		end
	end
	
	return {
		vulnerabilities = total_vulnerabilities,
		files_scanned = files_scanned,
		scan_summary = M.generate_security_report(total_vulnerabilities, {})
	}
end

-- Export patterns for external use
M.SECURITY_PATTERNS = SECURITY_PATTERNS
M.SENSITIVE_DATA_PATTERNS = SENSITIVE_DATA_PATTERNS

return M