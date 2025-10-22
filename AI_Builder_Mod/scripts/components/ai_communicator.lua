-- AI通信组件
-- 负责与DeepSeek API通信和本地决策

local json = require("util/json")
local AIComm = Class(function(self, inst)
    self.inst = inst
    self.enabled = GLOBAL.AI_BUILDER_CONFIG.ai_service_enabled or false
    
    -- API配置
    self.api_url = GLOBAL.AI_BUILDER_CONFIG.ai_service_url or "http://localhost:8000"
    self.api_timeout = 10
    self.max_retries = 3
    
    -- 通信状态
    self.last_request_time = 0
    self.request_interval = TUNING.AI_BUILDER.DECISION_INTERVAL or 30
    self.api_available = false
    self.consecutive_failures = 0
    
    -- 缓存系统
    self.decision_cache = {}
    self.cache_expiry = 300 -- 5分钟缓存
    
    -- 本地备用规则引擎
    self.fallback_enabled = true
    self.local_rules = {}
    
    -- 初始化本地规则
    self:InitializeLocalRules()
    
    -- 测试API连接
    if self.enabled then
        self:TestAPIConnection()
    end
end)

-- 初始化本地规则引擎
function AIComm:InitializeLocalRules()
    self.local_rules = {
        -- 基础生存规则
        survival = {
            {
                condition = function(context) 
                    return context.health < 50 
                end,
                action = "find_healing",
                priority = 1.0,
                message = "健康状况不佳，需要治疗。"
            },
            {
                condition = function(context) 
                    return context.hunger < 30 
                end,
                action = "find_food",
                priority = 0.9,
                message = "饥饿值过低，需要寻找食物。"
            }
        },
        
        -- 建设规则
        building = {
            {
                condition = function(context)
                    return not context.has_campfire and context.is_night
                end,
                action = "build_campfire",
                priority = 0.8,
                message = "夜晚来临，需要建造火堆。"
            },
            {
                condition = function(context)
                    return context.inventory_full
                end,
                action = "build_chest",
                priority = 0.7,
                message = "库存已满，建议建造箱子存储物品。"
            }
        },
        
        -- 资源收集规则
        resource = {
            {
                condition = function(context)
                    return context.wood_count < 10
                end,
                action = "collect_wood",
                priority = 0.6,
                message = "木材不足，去砍伐一些树木。"
            },
            {
                condition = function(context)
                    return context.stone_count < 5
                end,
                action = "collect_stone",
                priority = 0.5,
                message = "石头不足，去采集一些石料。"
            }
        }
    }
end

-- 测试API连接
function AIComm:TestAPIConnection()
    local test_data = {
        action = "ping",
        timestamp = GetTime()
    }
    
    self:SendRequest("/ping", test_data, function(success, response)
        if success then
            self.api_available = true
            self.consecutive_failures = 0
            print("[AI Builder] API连接成功")
        else
            self.api_available = false
            print("[AI Builder] API连接失败，使用本地规则引擎")
        end
    end)
end

-- 发送HTTP请求（模拟实现）
function AIComm:SendRequest(endpoint, data, callback)
    -- 这里是简化的HTTP请求实现
    -- 在实际MOD中需要使用饥荒的网络API或外部脚本
    
    local full_url = self.api_url .. endpoint
    local request_data = json.encode(data)
    
    -- 模拟异步请求
    self.inst:DoTaskInTime(1, function()
        if self.api_available and math.random() > 0.1 then -- 90%成功率模拟
            local mock_response = self:GenerateMockResponse(endpoint, data)
            callback(true, mock_response)
        else
            self.consecutive_failures = self.consecutive_failures + 1
            if self.consecutive_failures > 3 then
                self.api_available = false
            end
            callback(false, "请求失败")
        end
    end)
end

-- 生成模拟响应（用于测试）
function AIComm:GenerateMockResponse(endpoint, request_data)
    if endpoint == "/ping" then
        return {status = "ok", message = "AI服务运行正常"}
    elseif endpoint == "/decision" then
        return {
            action = "collect_wood",
            reasoning = "根据当前资源分析，建议优先收集木材来满足建设需求。",
            priority = 0.7,
            message = "我去收集一些木材，咱们的建设项目需要更多材料。"
        }
    elseif endpoint == "/chat" then
        return {
            message = "我正在分析当前情况，马上就有建设建议了。",
            tone = "professional"
        }
    end
    
    return {status = "unknown_endpoint"}
end

-- 请求AI决策
function AIComm:RequestDecision(context, callback)
    if not self.enabled or not self.api_available then
        -- 使用本地规则引擎
        local decision = self:GetLocalDecision(context)
        if callback then callback(true, decision) end
        return
    end
    
    -- 检查缓存
    local cache_key = self:GenerateCacheKey(context)
    local cached_decision = self.decision_cache[cache_key]
    if cached_decision and GetTime() - cached_decision.timestamp < self.cache_expiry then
        if callback then callback(true, cached_decision.decision) end
        return
    end
    
    -- 准备请求数据
    local request_data = {
        context = context,
        timestamp = GetTime(),
        mode = self.inst.components.ai_builder and self.inst.components.ai_builder.work_mode or "collaborative"
    }
    
    -- 发送请求
    self:SendRequest("/decision", request_data, function(success, response)
        if success and response then
            -- 缓存决策
            self.decision_cache[cache_key] = {
                decision = response,
                timestamp = GetTime()
            }
            
            if callback then callback(true, response) end
        else
            -- 降级到本地规则
            local local_decision = self:GetLocalDecision(context)
            if callback then callback(false, local_decision) end
        end
    end)
end

-- 生成缓存键
function AIComm:GenerateCacheKey(context)
    -- 基于关键上下文信息生成键
    local key_parts = {
        tostring(context.season or ""),
        tostring(context.time_phase or ""),
        tostring(math.floor(context.health or 0 / 10) * 10),
        tostring(math.floor(context.hunger or 0 / 10) * 10)
    }
    return table.concat(key_parts, "_")
end

-- 本地决策引擎
function AIComm:GetLocalDecision(context)
    local best_action = nil
    local best_priority = 0
    local best_message = "正在分析当前情况..."
    
    -- 遍历所有规则类别
    for category, rules in pairs(self.local_rules) do
        for _, rule in ipairs(rules) do
            if rule.condition(context) and rule.priority > best_priority then
                best_action = rule.action
                best_priority = rule.priority
                best_message = rule.message
            end
        end
    end
    
    return {
        action = best_action or "idle",
        reasoning = "基于本地规则引擎的决策",
        priority = best_priority,
        message = best_message,
        source = "local"
    }
end

-- 构建上下文信息
function AIComm:BuildContext()
    local context = {
        -- 基础状态
        health = self.inst.components.health and self.inst.components.health:GetPercent() * 100 or 100,
        hunger = self.inst.components.hunger and self.inst.components.hunger:GetPercent() * 100 or 100,
        sanity = self.inst.components.sanity and self.inst.components.sanity:GetPercent() * 100 or 100,
        
        -- 时间和环境
        day = TheWorld.state.cycles + 1,
        season = TheWorld.state.season,
        time_phase = TheWorld.state.phase,
        is_night = TheWorld.state.isnight,
        is_dusk = TheWorld.state.isdusk,
        
        -- 库存状态
        inventory_full = false,
        wood_count = 0,
        stone_count = 0,
        food_count = 0,
        
        -- 基地状态
        has_campfire = false,
        has_chest = false,
        base_center = nil
    }
    
    -- 填充库存信息
    if self.inst.components.inventory then
        local inventory = self.inst.components.inventory
        context.inventory_full = inventory:IsFull()
        
        context.wood_count = inventory:Has("log", 1)
        context.stone_count = inventory:Has("rocks", 1)
        context.food_count = inventory:Has("berries", 1) + inventory:Has("carrot", 1)
    end
    
    -- 检查基地设施
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local nearby_fires = TheSim:FindEntities(x, y, z, 20, {"campfire"})
    context.has_campfire = #nearby_fires > 0
    
    local nearby_chests = TheSim:FindEntities(x, y, z, 20, {"chest"})
    context.has_chest = #nearby_chests > 0
    
    -- 添加规划信息
    if self.inst.components.ai_planner then
        local planner = self.inst.components.ai_planner
        context.base_center = planner.base_center
        
        local stats = planner:GetPlanningStats()
        context.planning_progress = stats.completion_rate
        context.total_planned = stats.total_planned
    end
    
    -- 添加资源管理信息
    if self.inst.components.ai_manager then
        local manager = self.inst.components.ai_manager
        local report = manager:GetResourceReport()
        context.resource_needs = report.high_priority_needs
        context.collection_targets = report.collection_targets
    end
    
    return context
end

-- 请求对话响应
function AIComm:RequestChatResponse(player_message, callback)
    if not self.enabled or not self.api_available then
        local response = self:GetLocalChatResponse(player_message)
        if callback then callback(true, response) end
        return
    end
    
    local context = self:BuildContext()
    local request_data = {
        player_message = player_message,
        context = context,
        character_info = {
            name = "建造师艾德",
            role = "建设工程师",
            personality = "专业、务实、友善"
        }
    }
    
    self:SendRequest("/chat", request_data, function(success, response)
        if success and response then
            if callback then callback(true, response) end
        else
            local local_response = self:GetLocalChatResponse(player_message)
            if callback then callback(false, local_response) end
        end
    end)
end

-- 本地聊天响应
function AIComm:GetLocalChatResponse(player_message)
    local responses = {
        default = "我明白你的意思，让我想想最好的建设方案。",
        build = "好的，我会开始规划建设项目。",
        help = "我是建造师艾德，专门负责基地建设和规划。有什么建设需求请告诉我！",
        status = "目前建设工作进展顺利，有需要改进的地方我会及时调整。"
    }
    
    -- 简单的关键词匹配
    local message_lower = string.lower(player_message or "")
    if string.find(message_lower, "建") or string.find(message_lower, "造") then
        return {message = responses.build, tone = "professional"}
    elseif string.find(message_lower, "帮") or string.find(message_lower, "助") then
        return {message = responses.help, tone = "friendly"}
    elseif string.find(message_lower, "状") or string.find(message_lower, "况") then
        return {message = responses.status, tone = "informative"}
    else
        return {message = responses.default, tone = "neutral"}
    end
end

-- 定期更新
function AIComm:Update()
    local current_time = GetTime()
    
    -- 定期检查API可用性
    if not self.api_available and current_time - self.last_request_time > 60 then
        self:TestAPIConnection()
        self.last_request_time = current_time
    end
    
    -- 清理过期缓存
    self:CleanExpiredCache()
end

-- 清理过期缓存
function AIComm:CleanExpiredCache()
    local current_time = GetTime()
    for key, cached_item in pairs(self.decision_cache) do
        if current_time - cached_item.timestamp > self.cache_expiry then
            self.decision_cache[key] = nil
        end
    end
end

-- 获取AI决策（简化接口）
function AIComm:GetAIDecision()
    local context = self:BuildContext()
    
    if self.enabled and self.api_available then
        -- 异步请求，返回nil表示正在处理
        self:RequestDecision(context, function(success, decision)
            if success and decision then
                self:ExecuteDecision(decision)
            end
        end)
        return nil
    else
        -- 同步本地决策
        return self:GetLocalDecision(context)
    end
end

-- 执行AI决策
function AIComm:ExecuteDecision(decision)
    if not decision or not decision.action then
        return
    end
    
    -- 显示AI的思考过程
    if decision.message and self.inst.components.talker then
        self.inst.components.talker:Say(decision.message)
    end
    
    -- 根据决策类型执行相应操作
    if decision.action == "collect_wood" then
        self:ExecuteCollectWood()
    elseif decision.action == "build_campfire" then
        self:ExecuteBuildCampfire()
    elseif decision.action == "find_food" then
        self:ExecuteFindFood()
    else
        print("[AI Builder] 未知决策类型: " .. decision.action)
    end
end

-- 执行收集木材
function AIComm:ExecuteCollectWood()
    if self.inst.components.ai_manager then
        local target = self.inst.components.ai_manager:GetBestCollectionTarget()
        if target and target.type == "wood" then
            self.inst.components.ai_manager:CollectResource(target)
        end
    end
end

-- 执行建造火堆
function AIComm:ExecuteBuildCampfire()
    if self.inst.components.ai_builder then
        local project = {
            recipe_name = "campfire",
            category = "survival",
            priority = 0.9
        }
        self.inst.components.ai_builder:AddProject(project)
    end
end

-- 执行寻找食物
function AIComm:ExecuteFindFood()
    if self.inst.components.ai_manager then
        local target = self.inst.components.ai_manager:GetBestCollectionTarget()
        if target and target.type == "food" then
            self.inst.components.ai_manager:CollectResource(target)
        end
    end
end

-- 获取通信状态
function AIComm:GetStatus()
    return {
        api_enabled = self.enabled,
        api_available = self.api_available,
        consecutive_failures = self.consecutive_failures,
        cache_size = table.getn(self.decision_cache),
        fallback_active = not self.api_available and self.fallback_enabled
    }
end

return AIComm