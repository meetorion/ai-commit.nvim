local M = {}

-- AI Provider configurations
local AI_PROVIDERS = {
	openrouter = {
		name = "OpenRouter",
		endpoint = "https://openrouter.ai/api/v1/chat/completions",
		api_key_env = "OPENROUTER_API_KEY",
		api_key_config = "openrouter_api_key",
		format = "openai", -- Compatible with OpenAI format
		models = {
			{name = "qwen/qwen-2.5-72b-instruct:free", cost = 0, speed = "fast", quality = "high"},
			{name = "anthropic/claude-3.5-sonnet", cost = 3, speed = "medium", quality = "excellent"},
			{name = "openai/gpt-4o", cost = 5, speed = "medium", quality = "excellent"},
			{name = "meta-llama/llama-3.1-70b-instruct", cost = 1, speed = "fast", quality = "high"}
		},
		headers = function(api_key)
			return {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. api_key
			}
		end
	},
	
	deepseek = {
		name = "DeepSeek",
		endpoint = "https://api.deepseek.com/v1/chat/completions",
		api_key_env = "DEEPSEEK_API_KEY", 
		api_key_config = "deepseek_api_key",
		format = "openai", -- Compatible with OpenAI format
		models = {
			{name = "deepseek-chat", cost = 0.1, speed = "fast", quality = "excellent"},
			{name = "deepseek-coder", cost = 0.1, speed = "fast", quality = "excellent"} -- 专门用于代码
		},
		headers = function(api_key)
			return {
				["Content-Type"] = "application/json", 
				["Authorization"] = "Bearer " .. api_key
			}
		end
	},
	
	openai = {
		name = "OpenAI",
		endpoint = "https://api.openai.com/v1/chat/completions",
		api_key_env = "OPENAI_API_KEY",
		api_key_config = "openai_api_key", 
		format = "openai",
		models = {
			{name = "gpt-4o", cost = 5, speed = "medium", quality = "excellent"},
			{name = "gpt-4o-mini", cost = 0.15, speed = "fast", quality = "high"},
			{name = "gpt-3.5-turbo", cost = 0.5, speed = "fast", quality = "good"}
		},
		headers = function(api_key)
			return {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. api_key
			}
		end
	},
	
	anthropic = {
		name = "Anthropic",
		endpoint = "https://api.anthropic.com/v1/messages",
		api_key_env = "ANTHROPIC_API_KEY",
		api_key_config = "anthropic_api_key",
		format = "anthropic", -- Different format
		models = {
			{name = "claude-3-opus-20240229", cost = 15, speed = "slow", quality = "excellent"},
			{name = "claude-3-sonnet-20240229", cost = 3, speed = "medium", quality = "excellent"},
			{name = "claude-3-haiku-20240307", cost = 0.25, speed = "fast", quality = "good"}
		},
		headers = function(api_key)
			return {
				["Content-Type"] = "application/json",
				["x-api-key"] = api_key,
				["anthropic-version"] = "2023-06-01"
			}
		end
	},
	
	google = {
		name = "Google Gemini",
		endpoint = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
		api_key_env = "GOOGLE_API_KEY",
		api_key_config = "google_api_key",
		format = "google", -- Different format
		models = {
			{name = "gemini-pro", cost = 0.5, speed = "fast", quality = "high"},
			{name = "gemini-pro-vision", cost = 2, speed = "medium", quality = "high"}
		},
		headers = function(api_key)
			return {
				["Content-Type"] = "application/json"
			}
		end
	}
}

-- Provider selection strategies
local SELECTION_STRATEGIES = {
	cost_optimized = "cost", -- 选择最便宜的
	performance_optimized = "speed", -- 选择最快的
	quality_optimized = "quality", -- 选择质量最高的
	balanced = "balanced", -- 平衡成本、速度和质量
	primary_fallback = "fallback" -- 主提供商 + 故障转移
}

-- Default configuration
local default_config = {
	primary_provider = "deepseek", -- 默认使用DeepSeek
	fallback_providers = {"openrouter", "openai"}, -- 故障转移顺序
	selection_strategy = "balanced",
	auto_fallback = true, -- 自动故障转移
	cost_threshold = 1.0, -- 成本阈值（美分/请求）
	timeout = 30000, -- 30秒超时
	retry_attempts = 2,
	model_preferences = {
		coding = {"deepseek-coder", "qwen/qwen-2.5-72b-instruct:free"}, -- 编程任务首选
		general = {"deepseek-chat", "claude-3-sonnet-20240229"}, -- 通用任务首选
		analysis = {"claude-3-opus-20240229", "gpt-4o"} -- 分析任务首选
	}
}

-- Get provider configuration
function M.get_provider(provider_name)
	return AI_PROVIDERS[provider_name]
end

-- Get all available providers
function M.get_all_providers()
	return AI_PROVIDERS
end

-- Validate API key for provider
function M.validate_api_key(provider_name, config)
	local provider = AI_PROVIDERS[provider_name]
	if not provider then
		return nil, "未知的AI提供商: " .. provider_name
	end
	
	-- Check config first, then environment variable
	local api_key = config[provider.api_key_config] or vim.env[provider.api_key_env]
	
	if not api_key then
		return nil, string.format("未找到%s的API密钥。请设置%s环境变量或在配置中设置%s", 
			provider.name, provider.api_key_env, provider.api_key_config)
	end
	
	return api_key, nil
end

-- Get available models for provider
function M.get_provider_models(provider_name)
	local provider = AI_PROVIDERS[provider_name]
	return provider and provider.models or {}
end

-- Select best model based on criteria
function M.select_best_model(provider_name, criteria)
	criteria = criteria or "balanced"
	local models = M.get_provider_models(provider_name)
	
	if #models == 0 then
		return nil
	end
	
	if criteria == "cost" then
		-- 选择成本最低的模型
		table.sort(models, function(a, b) return a.cost < b.cost end)
		return models[1]
	elseif criteria == "speed" then
		-- 选择速度最快的模型
		local speed_order = {fast = 3, medium = 2, slow = 1}
		table.sort(models, function(a, b) 
			return speed_order[a.speed] > speed_order[b.speed] 
		end)
		return models[1]
	elseif criteria == "quality" then
		-- 选择质量最高的模型
		local quality_order = {excellent = 4, high = 3, good = 2, basic = 1}
		table.sort(models, function(a, b)
			return quality_order[a.quality] > quality_order[b.quality]
		end)
		return models[1]
	else
		-- 平衡选择：综合考虑成本、速度、质量
		local function calculate_score(model)
			local speed_score = {fast = 3, medium = 2, slow = 1}
			local quality_score = {excellent = 4, high = 3, good = 2, basic = 1}
			local cost_score = math.max(0, 10 - model.cost) -- 成本越低分数越高
			
			return (speed_score[model.speed] or 1) + 
				   (quality_score[model.quality] or 1) + 
				   cost_score
		end
		
		table.sort(models, function(a, b)
			return calculate_score(a) > calculate_score(b)
		end)
		return models[1]
	end
end

-- Select provider based on strategy
function M.select_provider(config, task_type)
	config = vim.tbl_deep_extend("force", default_config, config or {})
	task_type = task_type or "general"
	
	local strategy = config.selection_strategy
	local available_providers = {}
	
	-- 检查哪些提供商有可用的API密钥
	for provider_name, provider_config in pairs(AI_PROVIDERS) do
		local api_key, error = M.validate_api_key(provider_name, config)
		if api_key then
			table.insert(available_providers, {
				name = provider_name,
				config = provider_config,
				api_key = api_key
			})
		end
	end
	
	if #available_providers == 0 then
		return nil, "没有找到可用的AI提供商API密钥"
	end
	
	-- 根据任务类型选择首选模型
	local preferred_models = config.model_preferences[task_type] or config.model_preferences.general
	
	-- 查找首选模型对应的提供商
	for _, model_name in ipairs(preferred_models) do
		for _, provider in ipairs(available_providers) do
			for _, model in ipairs(provider.config.models) do
				if model.name == model_name then
					return {
						provider = provider.name,
						config = provider.config,
						api_key = provider.api_key,
						model = model
					}, nil
				end
			end
		end
	end
	
	-- 如果没有找到首选模型，按策略选择
	if strategy == "cost_optimized" then
		-- 选择成本最低的可用提供商和模型
		local best_option = nil
		local lowest_cost = math.huge
		
		for _, provider in ipairs(available_providers) do
			local best_model = M.select_best_model(provider.name, "cost")
			if best_model and best_model.cost < lowest_cost then
				lowest_cost = best_model.cost
				best_option = {
					provider = provider.name,
					config = provider.config,
					api_key = provider.api_key,
					model = best_model
				}
			end
		end
		return best_option, nil
		
	elseif strategy == "primary_fallback" then
		-- 使用主提供商，如果不可用则使用备用
		local primary = config.primary_provider
		for _, provider in ipairs(available_providers) do
			if provider.name == primary then
				local model = M.select_best_model(primary, "balanced")
				return {
					provider = provider.name,
					config = provider.config,
					api_key = provider.api_key,
					model = model
				}, nil
			end
		end
		
		-- 主提供商不可用，使用第一个备用提供商
		for _, fallback_name in ipairs(config.fallback_providers) do
			for _, provider in ipairs(available_providers) do
				if provider.name == fallback_name then
					local model = M.select_best_model(fallback_name, "balanced")
					return {
						provider = provider.name,
						config = provider.config,
						api_key = provider.api_key,
						model = model
					}, nil
				end
			end
		end
	end
	
	-- 默认返回第一个可用的提供商
	local first_provider = available_providers[1]
	local model = M.select_best_model(first_provider.name, "balanced")
	return {
		provider = first_provider.name,
		config = first_provider.config,
		api_key = first_provider.api_key,
		model = model
	}, nil
end

-- Format request for different providers
function M.format_request(provider_name, messages, model_name, options)
	local provider = AI_PROVIDERS[provider_name]
	if not provider then
		return nil, "未知的提供商格式"
	end
	
	options = options or {}
	
	if provider.format == "openai" then
		-- OpenAI compatible format (OpenRouter, DeepSeek, OpenAI)
		return {
			model = model_name,
			messages = messages,
			temperature = options.temperature or 0.7,
			max_tokens = options.max_tokens or 1000,
			top_p = options.top_p or 1.0,
			frequency_penalty = options.frequency_penalty or 0,
			presence_penalty = options.presence_penalty or 0
		}
		
	elseif provider.format == "anthropic" then
		-- Anthropic format
		local system_message = ""
		local user_messages = {}
		
		for _, message in ipairs(messages) do
			if message.role == "system" then
				system_message = message.content
			else
				table.insert(user_messages, message)
			end
		end
		
		return {
			model = model_name,
			max_tokens = options.max_tokens or 1000,
			system = system_message,
			messages = user_messages,
			temperature = options.temperature or 0.7
		}
		
	elseif provider.format == "google" then
		-- Google Gemini format
		local contents = {}
		for _, message in ipairs(messages) do
			if message.role ~= "system" then -- Gemini doesn't have system role
				table.insert(contents, {
					role = message.role == "assistant" and "model" or "user",
					parts = {{text = message.content}}
				})
			end
		end
		
		return {
			contents = contents,
			generationConfig = {
				temperature = options.temperature or 0.7,
				maxOutputTokens = options.max_tokens or 1000,
				topP = options.top_p or 1.0
			}
		}
	end
	
	return nil, "不支持的提供商格式: " .. provider.format
end

-- Parse response from different providers  
function M.parse_response(provider_name, response_body)
	local provider = AI_PROVIDERS[provider_name]
	if not provider then
		return nil, "未知的提供商"
	end
	
	local ok, data = pcall(vim.json.decode, response_body)
	if not ok then
		return nil, "响应解析失败"
	end
	
	if provider.format == "openai" then
		-- OpenAI compatible format
		if data.choices and #data.choices > 0 and data.choices[1].message then
			return data.choices[1].message.content, nil
		end
		
	elseif provider.format == "anthropic" then
		-- Anthropic format
		if data.content and #data.content > 0 then
			return data.content[1].text, nil
		end
		
	elseif provider.format == "google" then
		-- Google Gemini format
		if data.candidates and #data.candidates > 0 and 
		   data.candidates[1].content and data.candidates[1].content.parts then
			return data.candidates[1].content.parts[1].text, nil
		end
	end
	
	-- Check for error in response
	if data.error then
		return nil, data.error.message or "API错误"
	end
	
	return nil, "无法解析响应内容"
end

-- Get provider status and health check
function M.get_provider_status(provider_name, config)
	local api_key, error = M.validate_api_key(provider_name, config)
	if not api_key then
		return {
			status = "unavailable",
			error = error,
			models = {}
		}
	end
	
	local provider = AI_PROVIDERS[provider_name]
	return {
		status = "available", 
		name = provider.name,
		endpoint = provider.endpoint,
		models = provider.models,
		api_key_configured = true
	}
end

-- Generate provider comparison report
function M.generate_provider_report(config)
	local report = {
		timestamp = os.time(),
		available_providers = {},
		recommended_setup = {},
		cost_analysis = {}
	}
	
	for provider_name, provider_config in pairs(AI_PROVIDERS) do
		local status = M.get_provider_status(provider_name, config)
		table.insert(report.available_providers, {
			name = provider_name,
			display_name = provider_config.name,
			status = status.status,
			models_count = #status.models,
			cheapest_model = M.select_best_model(provider_name, "cost"),
			fastest_model = M.select_best_model(provider_name, "speed"),
			best_quality_model = M.select_best_model(provider_name, "quality")
		})
	end
	
	-- 生成推荐配置
	local has_deepseek = M.validate_api_key("deepseek", config)
	local has_openrouter = M.validate_api_key("openrouter", config)
	
	if has_deepseek then
		table.insert(report.recommended_setup, "✅ DeepSeek: 推荐用于编程任务（高质量，低成本）")
	else
		table.insert(report.recommended_setup, "💡 建议配置DeepSeek API以获得最佳编程体验")
	end
	
	if has_openrouter then
		table.insert(report.recommended_setup, "✅ OpenRouter: 提供多种免费模型选择")
	else
		table.insert(report.recommended_setup, "💡 建议配置OpenRouter作为免费备选方案")
	end
	
	return report
end

-- Export default configuration for easy setup
M.default_config = default_config
M.PROVIDERS = AI_PROVIDERS
M.STRATEGIES = SELECTION_STRATEGIES

return M