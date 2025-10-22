-- AI建造师大脑系统
-- 负责决策逻辑和行为控制

require("behaviours/wander")
require("behaviours/follow")
require("behaviours/faceentity")
require("behaviours/chaseandattack")
require("behaviours/runaway")
require("behaviours/doaction")
require("behaviours/panic")

local BuilderBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    
    self.inst = inst
    
    -- 决策间隔
    self.decision_interval = TUNING.AI_BUILDER.DECISION_INTERVAL or 30
    self.last_decision_time = 0
    
    -- 当前任务
    self.current_task = nil
    self.task_start_time = 0
    self.task_timeout = 120 -- 2分钟任务超时
    
    -- 工作状态
    self.is_working = false
    self.work_target = nil
    
    -- 跟随目标（召唤者）
    self.follow_target = nil
    self.follow_distance = 8
    
    -- 紧急状态
    self.emergency_mode = false
    self.panic_threshold = 30 -- 生命值低于30%时恐慌
end)

-- 创建行为树
function BuilderBrain:OnStart()
    local root = PriorityNode({
        -- 紧急情况处理（最高优先级）
        self:CreateEmergencyBehaviors(),
        
        -- 主要工作行为
        self:CreateWorkBehaviors(),
        
        -- 社交行为
        self:CreateSocialBehaviors(),
        
        -- 默认行为（空闲状态）
        self:CreateIdleBehaviors()
    }, 1)
    
    self.bt = BT(self.inst, root)
end

-- 创建紧急情况行为
function BuilderBrain:CreateEmergencyBehaviors()
    return PriorityNode({
        -- 恐慌逃跑
        WhileNode(function()
            return self.inst.components.health:GetPercent() < (self.panic_threshold / 100)
        end, "health_panic", 
        Panic(self.inst)),
        
        -- 饥饿寻找食物
        WhileNode(function()
            return self.inst.components.hunger:GetPercent() < 0.2
        end, "hunger_emergency",
        self:CreateFindFoodBehavior()),
        
        -- 理智值过低
        WhileNode(function()
            return self.inst.components.sanity:GetPercent() < 0.3
        end, "sanity_emergency",
        self:CreateRestoreSanityBehavior()),
        
        -- 夜晚寻找光源
        WhileNode(function()
            return TheWorld.state.isnight and not self:IsNearLightSource()
        end, "night_safety",
        self:CreateSeekLightBehavior())
    }, 1)
end

-- 创建工作行为
function BuilderBrain:CreateWorkBehaviors()
    return PriorityNode({
        -- 执行建设任务
        WhileNode(function()
            return self:HasBuildingTask()
        end, "building_task",
        self:CreateBuildingBehavior()),
        
        -- 收集资源任务
        WhileNode(function()
            return self:HasCollectionTask()
        end, "collection_task",
        self:CreateCollectionBehavior()),
        
        -- 整理库存
        WhileNode(function()
            return self:NeedsInventoryManagement()
        end, "inventory_management",
        self:CreateInventoryBehavior()),
        
        -- AI决策请求
        WhileNode(function()
            return self:ShouldRequestAIDecision()
        end, "ai_decision",
        self:CreateAIDecisionBehavior())
    }, 1)
end

-- 创建社交行为
function BuilderBrain:CreateSocialBehaviors()
    return PriorityNode({
        -- 跟随召唤者
        WhileNode(function()
            return self:ShouldFollowPlayer()
        end, "follow_player",
        Follow(self.inst, self.follow_target, self.follow_distance, self.follow_distance + 2)),
        
        -- 主动交流
        WhileNode(function()
            return self:ShouldInitiateChat()
        end, "initiate_chat",
        self:CreateChatBehavior())
    }, 1)
end

-- 创建空闲行为
function BuilderBrain:CreateIdleBehaviors()
    return PriorityNode({
        -- 四处观察
        WhileNode(function()
            return math.random() < 0.3
        end, "observe_area",
        self:CreateObserveBehavior()),
        
        -- 随机漫步
        Wander(self.inst, self:GetWanderPoint, 10)
    }, 1)
end

-- === 行为检查函数 ===

-- 检查是否有建设任务
function BuilderBrain:HasBuildingTask()
    if not self.inst.components.ai_builder then
        return false
    end
    
    local builder = self.inst.components.ai_builder
    return builder.current_project ~= nil or #builder.project_queue > 0
end

-- 检查是否有收集任务
function BuilderBrain:HasCollectionTask()
    if not self.inst.components.ai_manager then
        return false
    end
    
    local manager = self.inst.components.ai_manager
    local suggestion = manager:GetCollectionSuggestion()
    return suggestion ~= nil
end

-- 检查是否需要整理库存
function BuilderBrain:NeedsInventoryManagement()
    if not self.inst.components.inventory then
        return false
    end
    
    local inventory = self.inst.components.inventory
    return inventory:IsFull() or math.random() < 0.1 -- 10%几率整理
end

-- 检查是否应该请求AI决策
function BuilderBrain:ShouldRequestAIDecision()
    local current_time = GetTime()
    if current_time - self.last_decision_time < self.decision_interval then
        return false
    end
    
    -- 只有在空闲时才请求AI决策
    return not self.is_working and not self.emergency_mode
end

-- 检查是否应该跟随玩家
function BuilderBrain:ShouldFollowPlayer()
    if not self.follow_target or not self.follow_target:IsValid() then
        self.follow_target = self:FindNearestPlayer()
        return false
    end
    
    local distance = self.inst:GetDistanceSqToInst(self.follow_target)
    return distance > (self.follow_distance + 5) * (self.follow_distance + 5)
end

-- 检查是否应该主动聊天
function BuilderBrain:ShouldInitiateChat()
    local player = self:FindNearestPlayer()
    if not player then
        return false
    end
    
    local distance = self.inst:GetDistanceSqToInst(player)
    return distance < 25 and math.random() < 0.05 -- 5%几率主动聊天
end

-- === 行为创建函数 ===

-- 创建建设行为
function BuilderBrain:CreateBuildingBehavior()
    return DoAction(self.inst, function()
        local builder = self.inst.components.ai_builder
        if not builder then return nil end
        
        -- 获取当前项目或下一个项目
        local project = builder.current_project or builder:GetNextProject()
        if not project then return nil end
        
        builder:SetCurrentProject(project)
        
        -- 执行建设
        local success = builder:ExecuteBuild(project)
        if success then
            self.is_working = true
            self.work_target = project
            self.task_start_time = GetTime()
        end
        
        return nil -- DoAction需要返回nil
    end)
end

-- 创建收集行为
function BuilderBrain:CreateCollectionBehavior()
    return DoAction(self.inst, function()
        local manager = self.inst.components.ai_manager
        if not manager then return nil end
        
        local suggestion = manager:GetCollectionSuggestion()
        if not suggestion or not suggestion.target then return nil end
        
        -- 移动到目标并执行收集
        local target = suggestion.target
        if target:IsValid() then
            self.is_working = true
            self.work_target = target
            self.task_start_time = GetTime()
            
            return BufferedAction(self.inst, target, self:GetCollectionAction(target))
        end
        
        return nil
    end)
end

-- 创建库存管理行为
function BuilderBrain:CreateInventoryBehavior()
    return DoAction(self.inst, function()
        local manager = self.inst.components.ai_manager
        if manager then
            manager:OrganizeInventory()
            
            if self.inst.components.talker then
                self.inst.components.talker:Say("整理了一下库存，现在井井有条了。")
            end
        end
        return nil
    end)
end

-- 创建AI决策行为
function BuilderBrain:CreateAIDecisionBehavior()
    return DoAction(self.inst, function()
        local communicator = self.inst.components.ai_communicator
        if communicator then
            local decision = communicator:GetAIDecision()
            if decision then
                self:ExecuteAIDecision(decision)
            end
            self.last_decision_time = GetTime()
        end
        return nil
    end)
end

-- 创建寻找食物行为
function BuilderBrain:CreateFindFoodBehavior()
    return DoAction(self.inst, function()
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local food = FindEntity(self.inst, 20, function(item)
            return item.components.edible and 
                   item.components.inventoryitem and
                   not item.components.inventoryitem:IsHeld()
        end)
        
        if food then
            return BufferedAction(self.inst, food, ACTIONS.PICKUP)
        end
        
        return nil
    end)
end

-- 创建恢复理智行为
function BuilderBrain:CreateRestoreSanityBehavior()
    return DoAction(self.inst, function()
        -- 寻找花朵或其他恢复理智的物品
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local flower = FindEntity(self.inst, 15, function(item)
            return item:HasTag("flower")
        end)
        
        if flower then
            return BufferedAction(self.inst, flower, ACTIONS.PICK)
        end
        
        return nil
    end)
end

-- 创建寻找光源行为
function BuilderBrain:CreateSeekLightBehavior()
    return DoAction(self.inst, function()
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local light_source = FindEntity(self.inst, 30, function(ent)
            return ent.components.burnable and ent.components.burnable:IsBurning()
        end)
        
        if light_source then
            self.inst.components.locomotor:GoToEntity(light_source)
        end
        
        return nil
    end)
end

-- 创建观察行为
function BuilderBrain:CreateObserveBehavior()
    return DoAction(self.inst, function()
        -- 随机观察周围环境
        if math.random() < 0.3 then
            local observations = {
                "这里的地形很适合建设。",
                "我注意到一些有用的资源。",
                "让我分析一下当前的建设需求。",
                "基地规划需要进一步优化。"
            }
            
            if self.inst.components.talker then
                local observation = observations[math.random(#observations)]
                self.inst.components.talker:Say(observation)
            end
        end
        
        return nil
    end)
end

-- 创建聊天行为
function BuilderBrain:CreateChatBehavior()
    return DoAction(self.inst, function()
        local player = self:FindNearestPlayer()
        if player and self.inst.components.talker then
            local messages = {
                "建设工作进展如何？有什么需要我帮助的吗？",
                "我正在规划下一阶段的建设项目。",
                "这里的资源分布很有意思，我们可以优化利用。",
                "有什么特殊的建设需求请告诉我。"
            }
            
            local message = messages[math.random(#messages)]
            self.inst.components.talker:Say(message)
        end
        
        return nil
    end)
end

-- === 辅助函数 ===

-- 寻找最近的玩家
function BuilderBrain:FindNearestPlayer()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local players = TheSim:FindEntities(x, y, z, 30, {"player"})
    
    if #players > 0 then
        local closest_player = nil
        local closest_dist = math.huge
        
        for _, player in ipairs(players) do
            local dist = self.inst:GetDistanceSqToInst(player)
            if dist < closest_dist then
                closest_dist = dist
                closest_player = player
            end
        end
        
        return closest_player
    end
    
    return nil
end

-- 检查是否靠近光源
function BuilderBrain:IsNearLightSource()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local light_sources = TheSim:FindEntities(x, y, z, 8, nil, nil, {"light"})
    
    for _, light in ipairs(light_sources) do
        if light.components.burnable and light.components.burnable:IsBurning() then
            return true
        end
    end
    
    return false
end

-- 获取收集动作
function BuilderBrain:GetCollectionAction(target)
    if target:HasTag("CHOP_workable") then
        return ACTIONS.CHOP
    elseif target:HasTag("MINE_workable") then
        return ACTIONS.MINE
    elseif target:HasTag("pickable") then
        return ACTIONS.PICK
    end
    
    return ACTIONS.PICKUP
end

-- 获取漫步点
function BuilderBrain:GetWanderPoint()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    
    -- 如果有基地中心，在基地附近漫步
    if self.inst.components.ai_planner and self.inst.components.ai_planner.base_center then
        local base = self.inst.components.ai_planner.base_center
        return Vector3(base.x + math.random(-15, 15), 0, base.z + math.random(-15, 15))
    end
    
    -- 否则在当前位置附近漫步
    return Vector3(x + math.random(-10, 10), 0, z + math.random(-10, 10))
end

-- 执行AI决策
function BuilderBrain:ExecuteAIDecision(decision)
    if not decision then return end
    
    if decision.action == "collect_wood" then
        -- 设置收集木材任务
        if self.inst.components.ai_manager then
            self.current_task = "collect_wood"
            self.task_start_time = GetTime()
        end
    elseif decision.action == "build_campfire" then
        -- 设置建造火堆任务
        if self.inst.components.ai_builder then
            local project = {
                recipe_name = "campfire",
                category = "survival",
                priority = 0.9
            }
            self.inst.components.ai_builder:AddProject(project)
        end
    end
end

-- 更新函数
function BuilderBrain:OnUpdate(dt)
    -- 检查任务超时
    if self.current_task and GetTime() - self.task_start_time > self.task_timeout then
        self.current_task = nil
        self.is_working = false
        self.work_target = nil
        
        if self.inst.components.talker then
            self.inst.components.talker:Say("当前任务耗时过长，切换到其他工作。")
        end
    end
    
    -- 更新跟随目标
    if not self.follow_target or not self.follow_target:IsValid() then
        self.follow_target = self.inst.summoner or self:FindNearestPlayer()
    end
end

return BuilderBrain