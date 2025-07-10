local M = {}

-- Impact categories and their descriptions
local impact_categories = {
	breaking_change = {
		name = "Breaking Changes",
		icon = "🚨",
		severity = "critical",
		description = "Changes that may break existing functionality"
	},
	api_change = {
		name = "API Changes",
		icon = "🔌",
		severity = "high",
		description = "Changes to public APIs or interfaces"
	},
	dependency_change = {
		name = "Dependency Changes",
		icon = "📦",
		severity = "medium",
		description = "Changes to dependencies or imports"
	},
	config_change = {
		name = "Configuration Changes",
		icon = "⚙️",
		severity = "medium",
		description = "Changes to configuration files"
	},
	test_change = {
		name = "Test Changes",
		icon = "🧪",
		severity = "low",
		description = "Changes to test files"
	},
	documentation_change = {
		name = "Documentation Changes",
		icon = "📚",
		severity = "low",
		description = "Changes to documentation"
	},
	performance_impact = {
		name = "Performance Impact",
		icon = "⚡",
		severity = "medium",
		description = "Changes that may affect performance"
	},
	security_impact = {
		name = "Security Impact",
		icon = "🔒",
		severity = "critical",
		description = "Changes that may affect security"
	}
}

-- Patterns for detecting different types of changes
local detection_patterns = {
	breaking_change = {
		-- Removal patterns
		{ pattern = "^%-%s*function", weight = 3, description = "Function removed" },
		{ pattern = "^%-%s*class", weight = 3, description = "Class removed" },
		{ pattern = "^%-%s*export", weight = 2, description = "Export removed" },
		{ pattern = "^%-%s*public", weight = 2, description = "Public member removed" },
		-- Signature changes
		{ pattern = "^%-%s*(%w+)%s*%([^)]*%)", weight = 2, description = "Function signature changed" },
		{ pattern = "^%+%s*(%w+)%s*%([^)]*%)", weight = 2, description = "Function signature changed" },
	},
	api_change = {
		{ pattern = "%.nvim_", weight = 2, description = "Neovim API usage" },
		{ pattern = "^[%+%-]%s*M%.%w+", weight = 3, description = "Module API changed" },
		{ pattern = "^[%+%-]%s*return%s+{", weight = 2, description = "Module exports changed" },
		{ pattern = "^[%+%-]%s*vim%.api", weight = 2, description = "Vim API usage changed" },
	},
	dependency_change = {
		{ pattern = "require%([\"']([^\"']+)", weight = 2, description = "Dependency changed" },
		{ pattern = "dependencies%s*=", weight = 3, description = "Dependencies updated" },
		{ pattern = "import%s+", weight = 2, description = "Import changed" },
	},
	config_change = {
		{ pattern = "%.config", weight = 2, description = "Configuration modified" },
		{ pattern = "%.setup", weight = 2, description = "Setup function changed" },
		{ pattern = "default.*=", weight = 1, description = "Default value changed" },
		{ pattern = "opts%.", weight = 1, description = "Options changed" },
	},
	test_change = {
		{ pattern = "_test%.lua", weight = 3, description = "Test file" },
		{ pattern = "_spec%.lua", weight = 3, description = "Spec file" },
		{ pattern = "describe%(", weight = 2, description = "Test case" },
		{ pattern = "it%(", weight = 2, description = "Test case" },
	},
	documentation_change = {
		{ pattern = "%.md$", weight = 3, description = "Markdown file" },
		{ pattern = "^[%+%-]%s*%-%-", weight = 1, description = "Comment changed" },
		{ pattern = "README", weight = 2, description = "README file" },
	},
	performance_impact = {
		{ pattern = "for%s+.-%s+in", weight = 1, description = "Loop structure" },
		{ pattern = "while%s+", weight = 1, description = "While loop" },
		{ pattern = "table%.sort", weight = 2, description = "Sorting operation" },
		{ pattern = "string%.match", weight = 1, description = "String matching" },
		{ pattern = "gsub", weight = 1, description = "String substitution" },
	},
	security_impact = {
		{ pattern = "api_key", weight = 3, description = "API key handling" },
		{ pattern = "password", weight = 3, description = "Password handling" },
		{ pattern = "token", weight = 3, description = "Token handling" },
		{ pattern = "secret", weight = 3, description = "Secret handling" },
		{ pattern = "vim%.fn%.system", weight = 2, description = "System command execution" },
		{ pattern = "io%.popen", weight = 3, description = "Command execution" },
	}
}

-- Analyze a single file diff
local function analyze_file_diff(file_path, diff_content)
	local impacts = {}
	local lines = vim.split(diff_content, "\n")
	
	-- Check file type impacts
	if file_path:match("%.lua$") then
		-- Lua file specific analysis
		for category, patterns in pairs(detection_patterns) do
			local category_impact = {
				category = category,
				matches = {},
				total_weight = 0
			}
			
			for _, line in ipairs(lines) do
				for _, pattern_info in ipairs(patterns) do
					if line:match(pattern_info.pattern) then
						table.insert(category_impact.matches, {
							line = line,
							description = pattern_info.description,
							weight = pattern_info.weight
						})
						category_impact.total_weight = category_impact.total_weight + pattern_info.weight
					end
				end
			end
			
			if #category_impact.matches > 0 then
				impacts[category] = category_impact
			end
		end
	end
	
	return impacts
end

-- Generate impact summary
local function generate_impact_summary(all_impacts)
	local summary = {
		total_score = 0,
		categories = {},
		critical_impacts = {},
		recommendations = {}
	}
	
	-- Aggregate impacts by category
	for file, file_impacts in pairs(all_impacts) do
		for category, impact_data in pairs(file_impacts) do
			if not summary.categories[category] then
				summary.categories[category] = {
					files = {},
					total_weight = 0,
					info = impact_categories[category]
				}
			end
			
			table.insert(summary.categories[category].files, {
				file = file,
				weight = impact_data.total_weight,
				matches = impact_data.matches
			})
			
			summary.categories[category].total_weight = summary.categories[category].total_weight + impact_data.total_weight
			summary.total_score = summary.total_score + impact_data.total_weight
			
			-- Track critical impacts
			if impact_categories[category].severity == "critical" and impact_data.total_weight > 0 then
				table.insert(summary.critical_impacts, {
					category = category,
					file = file,
					weight = impact_data.total_weight
				})
			end
		end
	end
	
	-- Generate recommendations
	if #summary.critical_impacts > 0 then
		table.insert(summary.recommendations, "⚠️  Critical changes detected! Consider:")
		table.insert(summary.recommendations, "  - Thorough testing before deployment")
		table.insert(summary.recommendations, "  - Updating documentation")
		table.insert(summary.recommendations, "  - Notifying team members")
		
		for _, impact in ipairs(summary.critical_impacts) do
			if impact.category == "breaking_change" then
				table.insert(summary.recommendations, "  - Version bump may be required (breaking changes)")
			elseif impact.category == "security_impact" then
				table.insert(summary.recommendations, "  - Security review recommended")
			end
		end
	end
	
	return summary
end

-- Format impact report for display
local function format_impact_report(summary)
	local lines = {}
	
	-- Header
	table.insert(lines, "═══════════════════════════════════════════════")
	table.insert(lines, "           COMMIT IMPACT ANALYSIS              ")
	table.insert(lines, "═══════════════════════════════════════════════")
	table.insert(lines, "")
	
	-- Overall score
	local score_indicator = summary.total_score > 20 and "🔴 HIGH" or 
							summary.total_score > 10 and "🟡 MEDIUM" or 
							"🟢 LOW"
	table.insert(lines, string.format("Overall Impact Score: %d %s", summary.total_score, score_indicator))
	table.insert(lines, "")
	
	-- Critical impacts
	if #summary.critical_impacts > 0 then
		table.insert(lines, "🚨 CRITICAL IMPACTS:")
		for _, impact in ipairs(summary.critical_impacts) do
			local info = impact_categories[impact.category]
			table.insert(lines, string.format("  %s %s in %s (score: %d)", 
				info.icon, info.name, impact.file, impact.weight))
		end
		table.insert(lines, "")
	end
	
	-- Category breakdown
	table.insert(lines, "📊 IMPACT BREAKDOWN:")
	
	-- Sort categories by weight
	local sorted_categories = {}
	for category, data in pairs(summary.categories) do
		table.insert(sorted_categories, {
			category = category,
			data = data
		})
	end
	table.sort(sorted_categories, function(a, b)
		return a.data.total_weight > b.data.total_weight
	end)
	
	for _, cat_info in ipairs(sorted_categories) do
		local data = cat_info.data
		local info = data.info
		table.insert(lines, "")
		table.insert(lines, string.format("%s %s (Impact: %d)", 
			info.icon, info.name, data.total_weight))
		table.insert(lines, string.format("   %s", info.description))
		
		-- Show affected files
		for _, file_info in ipairs(data.files) do
			table.insert(lines, string.format("   📄 %s (score: %d)", 
				file_info.file, file_info.weight))
			
			-- Show top 3 matches
			local match_count = math.min(3, #file_info.matches)
			for i = 1, match_count do
				local match = file_info.matches[i]
				table.insert(lines, string.format("      - %s", match.description))
			end
			
			if #file_info.matches > 3 then
				table.insert(lines, string.format("      ... and %d more", #file_info.matches - 3))
			end
		end
	end
	
	-- Recommendations
	if #summary.recommendations > 0 then
		table.insert(lines, "")
		table.insert(lines, "💡 RECOMMENDATIONS:")
		for _, rec in ipairs(summary.recommendations) do
			table.insert(lines, rec)
		end
	end
	
	table.insert(lines, "")
	table.insert(lines, "═══════════════════════════════════════════════")
	
	return table.concat(lines, "\n")
end

-- Main analysis function
function M.analyze_commit_impact()
	-- Get staged diff with file names
	local diff_output = vim.fn.system("git diff --cached --name-status")
	if diff_output == "" then
		vim.notify("No staged changes to analyze", vim.log.levels.WARN)
		return
	end
	
	local all_impacts = {}
	
	-- Parse changed files
	for line in diff_output:gmatch("[^\n]+") do
		local status, file = line:match("^([AMD])%s+(.+)$")
		if status and file then
			-- Get detailed diff for each file
			local file_diff = vim.fn.system("git diff --cached -- " .. vim.fn.shellescape(file))
			
			-- Analyze the file
			local impacts = analyze_file_diff(file, file_diff)
			if next(impacts) then
				all_impacts[file] = impacts
			end
		end
	end
	
	-- Generate summary
	local summary = generate_impact_summary(all_impacts)
	
	-- Format and display report
	local report = format_impact_report(summary)
	
	-- Create a new buffer for the report
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(report, "\n"))
	
	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	
	-- Open in a new window
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_option(0, "wrap", true)
	vim.api.nvim_win_set_option(0, "number", false)
	vim.api.nvim_win_set_option(0, "relativenumber", false)
	
	-- Add keymaps for the buffer
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
	
	return summary
end

-- AI-enhanced impact analysis
function M.analyze_commit_impact_with_ai(config)
	local summary = M.analyze_commit_impact()
	
	if not summary then
		return
	end
	
	-- If AI is configured, enhance the analysis
	if config.openrouter_api_key then
		-- TODO: Send summary to AI for deeper analysis
		-- This could provide more contextual insights
		vim.notify("AI-enhanced analysis coming soon!", vim.log.levels.INFO)
	end
end

return M