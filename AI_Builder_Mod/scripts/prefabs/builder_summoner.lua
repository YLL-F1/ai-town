-- AI建造师召唤装置预制件
local assets = {
    Asset("ANIM", "anim/builder_summoner.zip"),
    Asset("ANIM", "anim/builder_summoner_build.zip"),
}

local prefabs = {
    "builder_ed",
}

-- 召唤AI建造师
local function SummonBuilder(inst, doer)
    if not doer or not doer:HasTag("player") then
        return false
    end
    
    -- 检查是否已经存在AI建造师
    local existing_builders = TheSim:FindEntities(inst.Transform:GetWorldPosition(), 0, 0, 100, {"ai_builder"})
    if #existing_builders > 0 then
        if doer.components.talker then
            doer.components.talker:Say("AI建造师已经在工作中了！")
        end
        return false
    end
    
    -- 检查召唤材料
    local required_items = {
        {item = "gears", count = 2},
        {item = "goldnugget", count = 4},
        {item = "boards", count = 6},
        {item = "cutstone", count = 4}
    }
    
    local inventory = doer.components.inventory
    if not inventory then
        return false
    end
    
    -- 验证材料充足
    for _, req in ipairs(required_items) do
        if inventory:Has(req.item, req.count) < req.count then
            if doer.components.talker then
                doer.components.talker:Say("材料不足！需要：" .. req.count .. "个" .. req.item)
            end
            return false
        end
    end
    
    -- 消耗材料
    for _, req in ipairs(required_items) do
        inventory:ConsumeByName(req.item, req.count)
    end
    
    -- 创建特效
    local fx = SpawnPrefab("collapse_small")
    if fx then
        local x, y, z = inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y, z)
    end
    
    -- 召唤AI建造师
    inst:DoTaskInTime(2, function()
        local x, y, z = inst.Transform:GetWorldPosition()
        local builder = SpawnPrefab("builder_ed")
        if builder then
            builder.Transform:SetPosition(x + math.random(-2, 2), y, z + math.random(-2, 2))
            builder.summoner = doer -- 记录召唤者
            
            -- AI建造师向召唤者问候
            builder:DoTaskInTime(1, function()
                if builder.components.talker then
                    builder.components.talker:Say("建造师艾德报到！准备开始建设工作。")
                end
            end)
            
            if doer.components.talker then
                doer.components.talker:Say("AI建造师召唤成功！")
            end
        end
    end)
    
    return true
end

-- 召唤装置创建函数
local function fn()
    local inst = CreateEntity()
    
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddMiniMapEntity()
    
    -- 物理碰撞
    inst.entity:AddPhysics()
    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(5)
    inst.Physics:SetCollisionGroup(COLLISION.WORLD)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.ITEMS)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:SetCylinder(0.5, 1)
    
    -- 动画设置
    inst.AnimState:SetBank("builder_summoner")
    inst.AnimState:SetBuild("builder_summoner_build")
    inst.AnimState:PlayAnimation("idle", true)
    
    -- 小地图图标
    inst.MiniMapEntity:SetIcon("builder_summoner.png")
    inst.MiniMapEntity:SetPriority(5)
    
    -- 基础标签
    inst:AddTag("structure")
    inst:AddTag("summoner")
    inst:AddTag("ai_builder_summoner")
    
    inst.entity:SetPristine()
    
    if not TheWorld.ismastersim then
        return inst
    end
    
    -- === 服务器端组件 ===
    
    -- 可检查组件
    inst:AddComponent("inspectable")
    inst.components.inspectable:SetDescription("一个神秘的装置，似乎可以召唤AI建造师。需要齿轮、金块、木板和石砖。")
    
    -- 可操作组件
    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = SummonBuilder
    inst.components.activatable.quickaction = true
    
    -- 生命值组件
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(200)
    inst.components.health:SetCurrentHealth(200)
    
    -- 可建造的锤子打击
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(function(inst, worker)
        -- 掉落一些材料
        local drops = {"gears", "goldnugget", "boards"}
        for _, drop in ipairs(drops) do
            local item = SpawnPrefab(drop)
            if item then
                local x, y, z = inst.Transform:GetWorldPosition()
                item.Transform:SetPosition(x + math.random(-1, 1), y, z + math.random(-1, 1))
            end
        end
        
        inst:Remove()
    end)
    
    return inst
end

-- 召唤装置配方
local function MakeSummonerRecipe()
    return Recipe("builder_summoner",
        {
            Ingredient("gears", 1),
            Ingredient("goldnugget", 2),
            Ingredient("boards", 4),
            Ingredient("cutstone", 2)
        },
        RECIPETABS.MAGIC,  -- 魔法标签页
        TECH.MAGIC_TWO,    -- 需要魔法二级科技
        nil,
        nil,
        nil,
        nil,
        "builder_summoner"
    )
end

-- 注册配方
AddRecipe2("builder_summoner", 
    {
        Ingredient("gears", 1),
        Ingredient("goldnugget", 2), 
        Ingredient("boards", 4),
        Ingredient("cutstone", 2)
    },
    RECIPETABS.MAGIC,
    TECH.MAGIC_TWO,
    nil,
    nil,
    nil,
    nil,
    "builder_summoner",
    "builder_summoner.tex"
)

return Prefab("builder_summoner", fn, assets, prefabs)