local M = {}
local ai_providers = require("ai_providers")

-- Request queue and management
local request_queue = {}
local active_requests = {}
local request_stats = {
	total_requests = 0,
	successful_requests = 0,
	failed_requests = 0,
	provider_stats = {},
	average_response_time = 0
}

-- Rate limiting configuration
local RATE_LIMITS = {
	deepseek = {requests_per_minute = 60, requests_per_hour = 1000},
	openrouter = {requests_per_minute = 100, requests_per_hour = 5000},
	openai = {requests_per_minute = 60, requests_per_hour = 3000},
	anthropic = {requests_per_minute = 50, requests_per_hour = 1000},
	google = {requests_per_minute = 60, requests_per_hour = 2000}
}

-- Provider health tracking
local provider_health = {}

-- Initialize provider health tracking
local function init_provider_health()
	for provider_name, _ in pairs(ai_providers.PROVIDERS) do
		provider_health[provider_name] = {
			last_success = 0,
			last_failure = 0,
			consecutive_failures = 0,
			average_response_time = 0,
			success_rate = 1.0,
			status = "healthy"
		}
	end
end

-- Update provider health
local function update_provider_health(provider_name, success, response_time)
	local health = provider_health[provider_name]
	if not health then return end
	
	local now = os.time()
	
	if success then
		health.last_success = now
		health.consecutive_failures = 0
		health.average_response_time = (health.average_response_time + response_time) / 2
		
		-- Gradually improve success rate
		health.success_rate = math.min(1.0, health.success_rate + 0.1)
		
		if health.status == "unhealthy" and health.success_rate > 0.7 then
			health.status = "recovering"
		elseif health.status == "recovering" and health.success_rate > 0.9 then
			health.status = "healthy"
		end
	else
		health.last_failure = now
		health.consecutive_failures = health.consecutive_failures + 1
		health.success_rate = math.max(0.0, health.success_rate - 0.2)
		
		-- Mark as unhealthy after 3 consecutive failures
		if health.consecutive_failures >= 3 then
			health.status = "unhealthy"
		elseif health.consecutive_failures >= 1 then
			health.status = "degraded"
		end
	end
end

-- Check if provider is available
local function is_provider_available(provider_name)
	local health = provider_health[provider_name]
	if not health then return false end
	
	-- Don't use unhealthy providers
	if health.status == "unhealthy" then
		-- Allow retry after 5 minutes
		return (os.time() - health.last_failure) > 300
	end
	
	return true
end

-- Smart provider selection with fallback
function M.select_smart_provider(config, task_type, fallback_attempt)
	fallback_attempt = fallback_attempt or 0
	
	-- Get provider selection from ai_providers
	local selection, error = ai_providers.select_provider(config, task_type)
	if not selection then
		return nil, error
	end
	
	-- Check if selected provider is healthy
	if is_provider_available(selection.provider) then
		return selection, nil
	end
	
	-- If primary provider is not available, try fallbacks
	if fallback_attempt < 3 then
		vim.notify(string.format("提供商 %s 暂时不可用，尝试备用方案...", selection.provider), vim.log.levels.WARN)
		
		-- Get list of available providers
		local all_providers = ai_providers.get_all_providers()
		for provider_name, _ in pairs(all_providers) do
			if provider_name ~= selection.provider and is_provider_available(provider_name) then
				local api_key, key_error = ai_providers.validate_api_key(provider_name, config)
				if api_key then
					local model = ai_providers.select_best_model(provider_name, "balanced")
					return {
						provider = provider_name,
						config = all_providers[provider_name],
						api_key = api_key,
						model = model
					}, nil
				end
			end
		end
	end
	
	return nil, "所有AI提供商暂时不可用"
end

-- Enhanced request function with retry and fallback
function M.send_ai_request(messages, config, options)
	options = options or {}
	local task_type = options.task_type or "general"
	local max_retries = options.max_retries or 2
	local timeout = options.timeout or 30000
	
	local function attempt_request(attempt_num)
		-- Select provider
		local selection, selection_error = M.select_smart_provider(config, task_type, attempt_num)
		if not selection then
			return nil, selection_error
		end
		
		local provider_name = selection.provider
		local provider_config = selection.config
		local api_key = selection.api_key
		local model = selection.model
		
		vim.notify(string.format("使用 %s (%s) 生成提交消息...", provider_config.name, model.name), vim.log.levels.INFO)
		
		-- Format request for the specific provider
		local request_data, format_error = ai_providers.format_request(
			provider_name, 
			messages, 
			model.name, 
			options
		)
		
		if not request_data then
			return nil, format_error
		end
		
		-- Record request start time
		local start_time = vim.loop.hrtime()
		
		-- Build endpoint URL
		local endpoint = provider_config.endpoint
		if provider_name == "google" then
			endpoint = string.format(endpoint, model.name, api_key)
		end
		
		-- Create response tracking
		local response_received = false
		local final_result = nil
		local final_error = nil
		
		-- Use plenary.curl for the request
		require("plenary.curl").post(endpoint, {
			headers = provider_config.headers(api_key),
			body = vim.json.encode(request_data),
			timeout = timeout,
			callback = vim.schedule_wrap(function(response)
				local response_time = (vim.loop.hrtime() - start_time) / 1000000 -- Convert to milliseconds
				
				if response.status == 200 then
					local content, parse_error = ai_providers.parse_response(provider_name, response.body)
					if content then
						-- Update statistics
						request_stats.successful_requests = request_stats.successful_requests + 1
						update_provider_health(provider_name, true, response_time)
						
						vim.notify(string.format("✅ %s 响应成功 (%.0fms)", provider_config.name, response_time), vim.log.levels.INFO)
						
						-- Process the successful response
						M.handle_successful_response(content, provider_name, model.name)
						
						final_result = content
					else
						update_provider_health(provider_name, false, response_time)
						final_error = parse_error or "响应解析失败"
					end
				else
					-- Enhanced error handling
					local error_message = M.parse_error_response(response, provider_name)
					update_provider_health(provider_name, false, response_time or 0)
					
					vim.notify(string.format("❌ %s 请求失败: %s", provider_config.name, error_message), vim.log.levels.ERROR)
					final_error = error_message
				end
				
				request_stats.total_requests = request_stats.total_requests + 1
				request_stats.average_response_time = (request_stats.average_response_time + (response_time or 0)) / 2
				response_received = true
			end)
		})
		
		-- Wait for response
		local success = vim.wait(timeout, function() return response_received end, 100)
		
		if not success then
			update_provider_health(provider_name, false, timeout)
			return nil, "请求超时"
		end
		
		return final_result, final_error
	end
	
	-- Retry logic with different providers
	for attempt = 0, max_retries do
		local result, error = attempt_request(attempt)
		if result then
			return result, nil
		end
		
		if attempt < max_retries then
			vim.notify(string.format("尝试 %d/%d 失败: %s", attempt + 1, max_retries + 1, error or "未知错误"), vim.log.levels.WARN)
			vim.wait(1000 * (attempt + 1)) -- Progressive delay
		else
			request_stats.failed_requests = request_stats.failed_requests + 1
			return nil, error or "所有重试均失败"
		end
	end
	
	return nil, "所有重试均失败"
end

-- Parse error responses with provider-specific handling
function M.parse_error_response(response, provider_name)
	local default_error = string.format("HTTP %d: %s", response.status, response.body or "Unknown error")
	
	-- Try to parse JSON error
	local ok, error_data = pcall(vim.json.decode, response.body or "{}")
	if not ok then
		return default_error
	end
	
	-- Provider-specific error handling
	if provider_name == "deepseek" then
		if error_data.error then
			if response.status == 401 then
				return "DeepSeek API密钥无效或已过期"
			elseif response.status == 429 then
				return "DeepSeek API请求频率限制，请稍后重试"
			elseif response.status == 402 then
				return "DeepSeek账户余额不足"
			end
			return error_data.error.message or "DeepSeek API错误"
		end
	elseif provider_name == "openrouter" then
		if error_data.error then
			if response.status == 402 then
				return "OpenRouter积分不足: " .. (error_data.error.message or "")
			elseif response.status == 429 then
				return "OpenRouter请求频率限制"
			end
			return error_data.error.message or "OpenRouter API错误"
		end
	elseif provider_name == "openai" then
		if error_data.error then
			if response.status == 401 then
				return "OpenAI API密钥无效"
			elseif response.status == 429 then
				return "OpenAI API配额已用完"
			elseif response.status == 400 then
				return "OpenAI请求格式错误: " .. (error_data.error.message or "")
			end
			return error_data.error.message or "OpenAI API错误"
		end
	end
	
	return default_error
end

-- Handle successful response with post-processing
function M.handle_successful_response(content, provider_name, model_name)
	-- Clean up the content
	local cleaned_content = content
		:gsub("^```[^%s]*%s*", "") -- Remove opening code block
		:gsub("%s*```$", "") -- Remove closing code block
		:gsub("^%d+%.%s*", "") -- Remove "1. "
		:gsub("^%*%*(.-)%*%*", "%1") -- Remove **text**
		:gsub("^%*%s*", "") -- Remove "* "
		:gsub("^%-+%s*", "") -- Remove "- "
		:gsub("^%s+", "") -- Remove leading whitespace
		:gsub("%s+$", "") -- Remove trailing whitespace
	
	-- Extract the first meaningful line as commit message
	local commit_message = ""
	for line in cleaned_content:gmatch("[^\n]+") do
		local clean_line = line:gsub("^%s+", ""):gsub("%s+$", "")
		if clean_line ~= "" and not clean_line:match("^[%u%s]+:$") and clean_line:match("%S") then
			commit_message = clean_line
			break
		end
	end
	
	if commit_message ~= "" then
		vim.notify(string.format("🎯 生成提交消息: %s", commit_message), vim.log.levels.INFO)
		
		-- Commit the changes
		local commit_generator = require("commit_generator")
		if commit_generator and commit_generator.commit_changes then
			commit_generator.commit_changes(commit_message)
		end
		
		-- Update provider stats
		if not request_stats.provider_stats[provider_name] then
			request_stats.provider_stats[provider_name] = {
				requests = 0,
				successes = 0,
				model_usage = {}
			}
		end
		
		local provider_stats = request_stats.provider_stats[provider_name]
		provider_stats.requests = provider_stats.requests + 1
		provider_stats.successes = provider_stats.successes + 1
		
		if not provider_stats.model_usage[model_name] then
			provider_stats.model_usage[model_name] = 0
		end
		provider_stats.model_usage[model_name] = provider_stats.model_usage[model_name] + 1
	else
		vim.notify("⚠️ 未能生成有效的提交消息", vim.log.levels.WARN)
	end
end

-- Get comprehensive system status
function M.get_system_status(config)
	local status = {
		timestamp = os.time(),
		request_stats = request_stats,
		provider_health = provider_health,
		available_providers = {},
		configuration_issues = {}
	}
	
	-- Check each provider
	for provider_name, provider_config in pairs(ai_providers.PROVIDERS) do
		local provider_status = ai_providers.get_provider_status(provider_name, config)
		provider_status.health = provider_health[provider_name]
		table.insert(status.available_providers, provider_status)
		
		-- Check for configuration issues
		if provider_status.status == "unavailable" then
			table.insert(status.configuration_issues, {
				provider = provider_name,
				issue = provider_status.error
			})
		end
	end
	
	return status
end

-- Generate detailed status report
function M.generate_status_report(config)
	local status = M.get_system_status(config)
	
	local report = string.format([[
🤖 AI提供商系统状态报告

📊 请求统计:
总请求数: %d
成功请求: %d (%.1f%%)
失败请求: %d (%.1f%%)
平均响应时间: %.0fms

🔧 提供商状态:
]], 
		status.request_stats.total_requests,
		status.request_stats.successful_requests,
		status.request_stats.total_requests > 0 and (status.request_stats.successful_requests * 100 / status.request_stats.total_requests) or 0,
		status.request_stats.failed_requests,
		status.request_stats.total_requests > 0 and (status.request_stats.failed_requests * 100 / status.request_stats.total_requests) or 0,
		status.request_stats.average_response_time
	)
	
	-- Provider details
	for _, provider in ipairs(status.available_providers) do
		local health_icon = "❌"
		if provider.status == "available" then
			if provider.health.status == "healthy" then
				health_icon = "✅"
			elseif provider.health.status == "degraded" then
				health_icon = "⚠️"
			elseif provider.health.status == "recovering" then
				health_icon = "🔄"
			end
		end
		
		report = report .. string.format([[
%s %s (%s)
   状态: %s
   成功率: %.1f%%
   平均响应: %.0fms
   模型数量: %d
]], 
			health_icon,
			provider.display_name or provider.name,
			provider.name,
			provider.status == "available" and provider.health.status or "不可用",
			provider.health.success_rate * 100,
			provider.health.average_response_time,
			provider.models_count or 0
		)
	end
	
	-- Configuration issues
	if #status.configuration_issues > 0 then
		report = report .. "\n⚠️ 配置问题:\n"
		for _, issue in ipairs(status.configuration_issues) do
			report = report .. string.format("- %s: %s\n", issue.provider, issue.issue)
		end
	end
	
	-- Recommendations
	report = report .. "\n💡 建议:\n"
	local available_count = 0
	for _, provider in ipairs(status.available_providers) do
		if provider.status == "available" then
			available_count = available_count + 1
		end
	end
	
	if available_count == 0 then
		report = report .. "- 🚨 没有可用的AI提供商，请检查API密钥配置\n"
	elseif available_count == 1 then
		report = report .. "- 💡 建议配置多个提供商以提高可靠性\n"
	else
		report = report .. "- ✅ 多提供商配置良好，系统具备故障转移能力\n"
	end
	
	return report
end

-- Initialize the system
function M.initialize()
	init_provider_health()
	vim.notify("🤖 AI提供商系统已初始化", vim.log.levels.INFO)
end

-- Health check for all providers
function M.health_check(config)
	vim.notify("🔍 开始AI提供商健康检查...", vim.log.levels.INFO)
	
	for provider_name, _ in pairs(ai_providers.PROVIDERS) do
		local api_key, error = ai_providers.validate_api_key(provider_name, config)
		if api_key then
			-- Test with a simple request
			local test_messages = {{
				role = "user",
				content = "Return only 'OK' if you receive this message."
			}}
			
			-- This would be an async call in practice
			vim.schedule(function()
				M.send_ai_request(test_messages, config, {
					task_type = "general",
					max_retries = 0,
					timeout = 10000
				})
			end)
		end
	end
end

return M