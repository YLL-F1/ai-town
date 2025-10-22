-- AI建造师预制件定义
local assets = {
    Asset("ANIM", "anim/builder_ed.zip"),
    Asset("ANIM", "anim/builder_ed_build.zip"),
    Asset("SOUND", "sound/builder_sounds.fsb"),
}

local prefabs = {
    "log",
    "rocks",
    "cutstone",
    "boards",
    "hammer",
    "axe",
}

-- 建造师大脑逻辑
local function BuilderBrain(inst)
    return require("brains/builder_brain")
end

-- 建造师对话系统
local function SayMessage(inst, message, color)
    if inst.components.talker then
        inst.components.talker:Say(message, nil, nil, nil, color)
    end
end

-- 获取附近的玩家
local function GetNearbyPlayer(inst, range)
    range = range or 15
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = TheSim:FindEntities(x, y, z, range, {"player"})
    
    -- 返回最近的玩家
    if #players > 0 then
        local closest_player = nil
        local closest_dist = math.huge
        
        for _, player in ipairs(players) do
            local dist = inst:GetDistanceSqToInst(player)
            if dist < closest_dist then
                closest_dist = dist
                closest_player = player
            end
        end
        
        return closest_player
    end
    
    return nil
end

-- 建造师创建函数
local function fn()
    local inst = CreateEntity()
    
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddMiniMapEntity()

    -- 网络同步
    inst.Transform:SetFourFaced()
    
    -- 动画设置
    inst.AnimState:SetBank("builder_ed")
    inst.AnimState:SetBuild("builder_ed_build")
    inst.AnimState:PlayAnimation("idle_loop", true)
    
    -- 小地图图标
    inst.MiniMapEntity:SetIcon("builder_ed.png")
    inst.MiniMapEntity:SetPriority(5)
    
    -- 基础标签
    inst:AddTag("character")
    inst:AddTag("ai_builder")
    inst:AddTag("worker")
    inst:AddTag("builder")
    inst:AddTag("scarytoprey")
    
    -- 网络变量
    inst.entity:SetPristine()
    
    if not TheWorld.ismastersim then
        return inst
    end
    
    -- === 服务器端组件 ===
    
    -- 基础生存组件
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.AI_BUILDER.HEALTH)
    inst.components.health:SetCurrentHealth(TUNING.AI_BUILDER.HEALTH)
    
    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.AI_BUILDER.HUNGER)
    inst.components.hunger:SetCurrent(TUNING.AI_BUILDER.HUNGER)
    inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE * 0.8) -- 饥饿速度比威尔逊慢
    
    inst:AddComponent("sanity")
    inst.components.sanity:SetMax(TUNING.AI_BUILDER.SANITY)
    inst.components.sanity:SetCurrent(TUNING.AI_BUILDER.SANITY)
    inst.components.sanity:SetRate(-TUNING.SANITY_MED) -- 基础理智消耗
    
    -- 运动组件
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED * 1.1
    inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 1.1
    
    -- 库存组件
    inst:AddComponent("inventory")
    inst.components.inventory.maxslots = TUNING.AI_BUILDER.CARRY_CAPACITY
    
    -- 对话组件
    inst:AddComponent("talker")
    inst.components.talker.colour = Vector3(0.8, 0.8, 1.0) -- 淡蓝色
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.offset = Vector3(0, -400, 0)
    
    -- 工作组件
    inst:AddComponent("worker")
    inst.components.worker:SetAction(ACTIONS.CHOP, TUNING.AI_BUILDER.WORK_EFFICIENCY)
    inst.components.worker:SetAction(ACTIONS.DIG, TUNING.AI_BUILDER.WORK_EFFICIENCY)
    inst.components.worker:SetAction(ACTIONS.MINE, TUNING.AI_BUILDER.WORK_EFFICIENCY)
    inst.components.worker:SetAction(ACTIONS.HAMMER, TUNING.AI_BUILDER.WORK_EFFICIENCY)
    
    -- 建造组件
    inst:AddComponent("builder")
    inst.components.builder.science_bonus = 1
    inst.components.builder.magic_bonus = 0
    
    -- AI核心组件
    inst:AddComponent("ai_builder")
    inst:AddComponent("ai_planner")
    inst:AddComponent("ai_manager")
    inst:AddComponent("ai_communicator")
    inst:AddComponent("ai_code_executor")  -- 代码执行器
    inst:AddComponent("ai_builder_controller")  -- 主控制器
    
    -- 大脑组件
    inst:SetBrain(BuilderBrain)
    inst:SetStateGraph("SGbuilder_ed")
    
    -- 初始化AI控制器
    inst:DoTaskInTime(1, function()
        if inst.components.ai_builder_controller then
            inst.components.ai_builder_controller:OnEntitySpawn()
        end
    end)
    
    -- 死亡处理
    inst.components.health:SetOnDeathCallback(function(inst)
        SayMessage(inst, "我需要休息一下...很快会回来继续建设工作。", {1, 0.5, 0.5})
        -- 掉落一些建设材料
        if inst.components.inventory then
            inst.components.inventory:DropEverything()
        end
    end)
    
    -- 饥饿处理
    inst.components.hunger:SetOnDamageCallback(function(inst)
        if inst.components.health:GetPercent() < 0.8 then
            SayMessage(inst, "我需要一些食物来保持工作效率。", {1, 1, 0.5})
        end
    end)
    
    -- 理智处理
    inst.components.sanity:SetOnDamageCallback(function(inst)
        if inst.components.sanity:GetPercent() < 0.3 then
            SayMessage(inst, "工作压力有点大，我需要调整一下。", {0.8, 0.8, 1})
        end
    end)
    
    -- 初始装备
    local function EquipInitialTools(inst)
        -- 给予基础工具
        local hammer = SpawnPrefab("hammer")
        if hammer then
            inst.components.inventory:GiveItem(hammer)
            inst.components.inventory:Equip(hammer)
        end
        
        local axe = SpawnPrefab("axe")
        if axe then
            inst.components.inventory:GiveItem(axe)
        end
        
        -- 给予一些初始材料
        local materials = {"log", "log", "log", "rocks", "rocks", "cutgrass", "cutgrass"}
        for _, material in ipairs(materials) do
            local item = SpawnPrefab(material)
            if item then
                inst.components.inventory:GiveItem(item)
            end
        end
    end
    
    -- 初始化时装备工具
    inst:DoTaskInTime(1, EquipInitialTools)
    
    -- 定期自我介绍
    local function PeriodicIntroduction(inst)
        local player = GetNearbyPlayer(inst)
        if player and not inst.introduced_to_player then
            SayMessage(inst, "你好！我是建造师艾德，专门负责基地建设和规划。需要建设帮助随时告诉我！", {0.5, 1, 0.5})
            inst.introduced_to_player = true
        end
    end
    
    inst:DoPeriodicTask(30, PeriodicIntroduction)
    
    -- AI建造师特殊能力
    
    -- 快速建造能力
    local old_build_fn = inst.components.builder.DoBuild
    inst.components.builder.DoBuild = function(self, recipe, pt, rotation, skin)
        -- 建造速度提升
        local result = old_build_fn(self, recipe, pt, rotation, skin)
        if result then
            SayMessage(inst, "建造完成！这个" .. recipe.name .. "应该很有用。", {0.5, 1, 0.8})
        end
        return result
    end
    
    -- 资源分析能力
    inst.AnalyzeResources = function(inst, range)
        range = range or 20
        local x, y, z = inst.Transform:GetWorldPosition()
        local resources = TheSim:FindEntities(x, y, z, range, {"pickable", "choppable", "mineable"})
        
        local analysis = {
            wood_sources = 0,
            stone_sources = 0,
            food_sources = 0,
            total_resources = #resources
        }
        
        for _, resource in ipairs(resources) do
            if resource:HasTag("choppable") then
                analysis.wood_sources = analysis.wood_sources + 1
            elseif resource:HasTag("mineable") then
                analysis.stone_sources = analysis.stone_sources + 1
            elseif resource:HasTag("pickable") then
                analysis.food_sources = analysis.food_sources + 1
            end
        end
        
        return analysis
    end
    
    -- 建设建议功能
    inst.GiveBuildingSuggestion = function(inst)
        local player = GetNearbyPlayer(inst)
        if not player then return end
        
        local analysis = inst:AnalyzeResources()
        local suggestions = {}
        
        -- 基于资源分析给出建议
        if analysis.wood_sources < 3 then
            table.insert(suggestions, "附近木材资源较少，建议种植一些树木。")
        end
        
        if analysis.stone_sources < 2 then
            table.insert(suggestions, "石头资源稀缺，我们应该寻找新的采石地点。")
        end
        
        if #suggestions > 0 then
            local suggestion = suggestions[math.random(#suggestions)]
            SayMessage(inst, suggestion, {1, 1, 0.8})
        else
            SayMessage(inst, "目前资源情况良好，可以考虑扩建基地了。", {0.8, 1, 0.8})
        end
    end
    
    -- AI调试功能
    inst:AddComponent("debuggable")
    inst.components.debuggable.OnDebugRMB = function(inst)
        if inst.components.ai_builder_controller then
            local report = inst.components.ai_builder_controller:GetPerformanceReport()
            print("=== AI Builder性能报告 ===")
            print("总AI请求:", report.total_ai_requests)
            print("成功生成:", report.successful_generations)
            print("失败生成:", report.failed_generations)
            print("成功率:", string.format("%.2f%%", report.success_rate * 100))
            print("平均执行时间:", string.format("%.2fs", report.average_execution_time))
            print("当前任务:", report.current_task)
            print("代码生成模式:", report.code_generation_enabled and "启用" or "禁用")
            
            -- 也在游戏中显示信息
            SayMessage(inst, string.format("AI成功率: %.1f%%, 当前任务: %s", 
                report.success_rate * 100, report.current_task), {0.8, 0.8, 1})
        end
    end
    
    -- 定期给出建设建议
    inst:DoPeriodicTask(120, function(inst)
        if math.random() < 0.3 then -- 30%几率给出建议
            inst:GiveBuildingSuggestion()
        end
    end)
    
    return inst
end

-- 注册预制件
return Prefab("builder_ed", fn, assets, prefabs)