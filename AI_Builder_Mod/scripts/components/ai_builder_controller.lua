-- AI Builder角色的主要行为控制脚本
-- 整合代码生成反射功能

local AiBuilderController = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    
    -- 核心组件引用
    self.ai_manager = nil
    self.ai_planner = nil
    self.ai_builder = nil
    self.ai_communicator = nil
    self.code_executor = nil
    
    -- 控制参数
    self.ai_decision_interval = 10  -- AI决策间隔（秒）
    self.last_ai_decision = 0
    self.current_ai_task = nil
    self.ai_task_timeout = 60  -- AI任务超时时间
    
    -- 代码生成模式
    self.code_generation_enabled = true
    self.fallback_to_manual = true
    
    -- 性能监控
    self.performance_stats = {
        total_ai_requests = 0,
        successful_generations = 0,
        failed_generations = 0,
        average_execution_time = 0
    }
end)

function AiBuilderController:OnEntitySpawn()
    """实体生成时初始化"""
    
    -- 获取组件引用
    self.ai_manager = self.inst.components.ai_manager
    self.ai_planner = self.inst.components.ai_planner  
    self.ai_builder = self.inst.components.ai_builder
    self.ai_communicator = self.inst.components.ai_communicator
    self.code_executor = self.inst.components.ai_code_executor
    
    -- 启动AI控制循环
    self:StartAILoop()
    
    print("[AI构建者控制器] AI角色已启动，代码生成模式:", self.code_generation_enabled and "启用" or "禁用")
end

function AiBuilderController:StartAILoop()
    """启动AI决策循环"""
    
    self.inst:DoPeriodicTask(1, function()
        if self.enabled and GetTime() - self.last_ai_decision >= self.ai_decision_interval then
            self:MakeAIDecision()
            self.last_ai_decision = GetTime()
        end
    end)
end

function AiBuilderController:MakeAIDecision()
    """执行AI决策"""
    
    -- 检查当前任务状态
    if self.current_ai_task and self:IsTaskCompleted(self.current_ai_task) then
        print("[AI控制器] 当前任务已完成:", self.current_ai_task.type)
        self.current_ai_task = nil
    end
    
    -- 如果有正在进行的任务，检查是否超时
    if self.current_ai_task and GetTime() - self.current_ai_task.start_time > self.ai_task_timeout then
        print("[AI控制器] 任务超时，放弃当前任务:", self.current_ai_task.type)
        self.current_ai_task = nil
    end
    
    -- 如果没有当前任务，生成新任务
    if not self.current_ai_task then
        local task_type = self:DetermineNextTaskType()
        
        if task_type and self.code_generation_enabled then
            -- 使用AI代码生成
            self:ExecuteAIGeneratedTask(task_type)
        elseif task_type then
            -- 使用传统逻辑
            self:ExecuteTraditionalTask(task_type)
        else
            -- 没有合适的任务
            self:HandleIdleState()
        end
    end
end

function AiBuilderController:DetermineNextTaskType()
    """确定下一个任务类型"""
    
    -- 检查生存需求
    if self:NeedsSurvivalAction() then
        return "survival"
    end
    
    -- 检查资源需求
    if self.ai_manager and self.ai_manager:HasResourceShortage() then
        return "collecting"
    end
    
    -- 检查建设需求
    if self.ai_planner and self.ai_planner:HasPendingProjects() then
        return "building"
    end
    
    -- 农业需求
    if self:ShouldDoFarming() then
        return "farming"
    end
    
    -- 探索需求
    if self:ShouldExplore() then
        return "exploring"
    end
    
    return nil
end

function AiBuilderController:ExecuteAIGeneratedTask(task_type)
    """执行AI生成的任务"""
    
    print("[AI控制器] 请求AI生成任务代码:", task_type)
    
    -- 准备上下文信息
    local context = {
        previous_task = self.current_ai_task,
        failure_count = self.performance_stats.failed_generations,
        world_state = self:GetWorldState(),
        character_preferences = self:GetCharacterPreferences()
    }
    
    self.performance_stats.total_ai_requests = self.performance_stats.total_ai_requests + 1
    local start_time = GetTime()
    
    -- 请求AI代码生成
    local result = self.ai_manager:RequestAICodeGeneration(task_type, context)
    
    local execution_time = GetTime() - start_time
    self:UpdatePerformanceStats(result.success, execution_time)
    
    if result.success then
        print("[AI控制器] AI生成任务成功执行")
        self.current_ai_task = {
            type = task_type,
            start_time = GetTime(),
            source = "ai_generated",
            result = result.result,
            generated_code = result.code
        }
        
        self.performance_stats.successful_generations = self.performance_stats.successful_generations + 1
        
        -- 如果AI返回了具体的行动指令，执行它
        if result.result and result.result.action then
            self:ExecuteAIAction(result.result)
        end
        
    else
        print("[AI控制器] AI生成任务失败，错误:", result.error)
        self.performance_stats.failed_generations = self.performance_stats.failed_generations + 1
        
        -- 如果AI生成失败，使用后备方案
        if result.fallback_action and self.fallback_to_manual then
            self:ExecuteFallbackAction(result.fallback_action, task_type)
        else
            self:ExecuteTraditionalTask(task_type)
        end
    end
end

function AiBuilderController:ExecuteTraditionalTask(task_type)
    """执行传统逻辑任务"""
    
    print("[AI控制器] 执行传统任务逻辑:", task_type)
    
    local action = nil
    
    if task_type == "survival" then
        action = self:GetSurvivalAction()
    elseif task_type == "collecting" then
        action = self.ai_manager:GetCollectionSuggestion()
    elseif task_type == "building" then
        action = self.ai_planner:GetNextBuildAction()
    elseif task_type == "farming" then
        action = self:GetFarmingAction()
    elseif task_type == "exploring" then
        action = self:GetExplorationAction()
    end
    
    if action then
        self.current_ai_task = {
            type = task_type,
            start_time = GetTime(),
            source = "traditional",
            action = action
        }
        
        self:ExecuteAction(action)
    end
end

function AiBuilderController:ExecuteAIAction(ai_result)
    """执行AI返回的行动"""
    
    if ai_result.action == "goto_food" then
        -- AI指示前往食物
        print("[AI控制器] 执行AI指令: 前往食物")
        
    elseif ai_result.action == "collect_resource" then
        -- AI指示收集资源
        print("[AI控制器] 执行AI指令: 收集资源")
        
    elseif ai_result.action == "build_structure" then
        -- AI指示建造结构
        print("[AI控制器] 执行AI指令: 建造结构")
        
    elseif ai_result.action == "idle" then
        -- AI指示待机
        print("[AI控制器] 执行AI指令: 待机模式")
        
    else
        print("[AI控制器] 未知的AI行动指令:", ai_result.action)
    end
    
    -- 输出AI的决策消息
    if ai_result.message then
        if self.ai_communicator then
            self.ai_communicator:SayMessage(ai_result.message)
        else
            print("[AI消息]", ai_result.message)
        end
    end
end

function AiBuilderController:ExecuteFallbackAction(fallback_action, original_task_type)
    """执行后备行动"""
    
    print("[AI控制器] 执行后备行动:", fallback_action.action)
    
    self.current_ai_task = {
        type = original_task_type,
        start_time = GetTime(),
        source = "fallback",
        action = fallback_action
    }
    
    if self.ai_communicator then
        self.ai_communicator:SayMessage(fallback_action.message or "执行后备方案")
    end
end

function AiBuilderController:NeedsSurvivalAction()
    """检查是否需要生存行动"""
    
    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity
    
    return (health and health.currenthealth < 80) or
           (hunger and hunger.current < 70) or
           (sanity and sanity.current < 60)
end

function AiBuilderController:ShouldDoFarming()
    """检查是否应该进行农业活动"""
    
    -- 简单的农业判断逻辑
    local season = TheWorld.state.season
    return season == "spring" or season == "summer"
end

function AiBuilderController:ShouldExplore()
    """检查是否应该探索"""
    
    -- 如果库存不满且没有明确的收集目标，考虑探索
    local inventory = self.inst.components.inventory
    return inventory and not inventory:IsFull() and math.random() < 0.3
end

function AiBuilderController:GetWorldState()
    """获取世界状态信息"""
    
    return {
        season = TheWorld.state.season,
        time_of_day = TheWorld.state.clock and TheWorld.state.clock:GetNormTime() or 0,
        weather = TheWorld.state.weather and TheWorld.state.weather:GetWeatherPercent() or 0,
        day_number = TheWorld.state.clock and TheWorld.state.clock:GetNumCycles() or 1
    }
end

function AiBuilderController:GetCharacterPreferences()
    """获取角色偏好设置"""
    
    return {
        preferred_building_style = "efficient",
        risk_tolerance = 0.7,
        exploration_tendency = 0.5,
        social_interaction = 0.8
    }
end

function AiBuilderController:IsTaskCompleted(task)
    """检查任务是否完成"""
    
    if not task then return true end
    
    -- 根据任务类型检查完成条件
    if task.type == "survival" then
        return not self:NeedsSurvivalAction()
    elseif task.type == "collecting" then
        -- 检查是否收集到足够资源
        return GetTime() - task.start_time > 30 -- 简单的时间检查
    elseif task.type == "building" then
        -- 检查建设是否完成
        return GetTime() - task.start_time > 60
    end
    
    return GetTime() - task.start_time > 45 -- 默认45秒超时
end

function AiBuilderController:UpdatePerformanceStats(success, execution_time)
    """更新性能统计"""
    
    local total = self.performance_stats.successful_generations + self.performance_stats.failed_generations
    if total > 0 then
        self.performance_stats.average_execution_time = 
            (self.performance_stats.average_execution_time * (total - 1) + execution_time) / total
    else
        self.performance_stats.average_execution_time = execution_time
    end
end

function AiBuilderController:HandleIdleState()
    """处理空闲状态"""
    
    -- 空闲时的默认行为
    if math.random() < 0.1 then -- 10%概率说话
        if self.ai_communicator then
            local idle_messages = {
                "我在思考下一步该做什么...",
                "这里的环境看起来不错",
                "也许我应该建造一些有用的东西",
                "让我检查一下资源情况"
            }
            local message = idle_messages[math.random(#idle_messages)]
            self.ai_communicator:SayMessage(message)
        end
    end
end

function AiBuilderController:GetPerformanceReport()
    """获取性能报告"""
    
    local total_requests = self.performance_stats.total_ai_requests
    local success_rate = total_requests > 0 and 
        (self.performance_stats.successful_generations / total_requests) or 0
    
    return {
        total_ai_requests = total_requests,
        successful_generations = self.performance_stats.successful_generations,
        failed_generations = self.performance_stats.failed_generations,
        success_rate = success_rate,
        average_execution_time = self.performance_stats.average_execution_time,
        current_task = self.current_ai_task and self.current_ai_task.type or "none",
        code_generation_enabled = self.code_generation_enabled
    }
end

function AiBuilderController:ToggleCodeGeneration()
    """切换代码生成模式"""
    
    self.code_generation_enabled = not self.code_generation_enabled
    print("[AI控制器] 代码生成模式", self.code_generation_enabled and "已启用" or "已禁用")
    
    if self.ai_communicator then
        local message = self.code_generation_enabled and 
            "AI代码生成已启用，我将使用更智能的决策" or
            "AI代码生成已禁用，使用传统逻辑模式"
        self.ai_communicator:SayMessage(message)
    end
end

function AiBuilderController:SetAIDecisionInterval(interval)
    """设置AI决策间隔"""
    
    self.ai_decision_interval = math.max(1, interval)
    print("[AI控制器] AI决策间隔设置为", self.ai_decision_interval, "秒")
end

function AiBuilderController:EnableAI()
    """启用AI控制"""
    
    self.enabled = true
    print("[AI控制器] AI控制已启用")
end

function AiBuilderController:DisableAI()
    """禁用AI控制"""
    
    self.enabled = false
    self.current_ai_task = nil
    print("[AI控制器] AI控制已禁用")
end

return AiBuilderController