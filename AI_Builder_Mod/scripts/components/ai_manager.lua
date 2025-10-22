-- AI资源管理组件
-- 负责资源收集、分析和分配管理

local AIManager = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    
    -- 资源数据
    self.resource_inventory = {}    -- 资源清单
    self.resource_needs = {}        -- 资源需求
    self.collection_targets = {}    -- 收集目标
    
    -- 资源类型和优先级
    self.resource_types = {
        basic = {
            wood = {priority = 0.8, max_stack = 40},
            stone = {priority = 0.7, max_stack = 40},
            cutgrass = {priority = 0.6, max_stack = 40},
            twigs = {priority = 0.6, max_stack = 40}
        },
        food = {
            berries = {priority = 0.5, max_stack = 40},
            carrot = {priority = 0.4, max_stack = 40},
            seeds = {priority = 0.3, max_stack = 40}
        },
        advanced = {
            goldnugget = {priority = 0.9, max_stack = 40},
            gears = {priority = 1.0, max_stack = 40},
            rope = {priority = 0.7, max_stack = 40},
            boards = {priority = 0.8, max_stack = 40}
        }
    }
    
    -- 收集状态
    self.collection_cooldowns = {}
    self.last_inventory_scan = 0
    self.resource_scan_interval = 30 -- 30秒扫描一次
end)

-- 扫描当前资源库存
function AIManager:ScanInventory()
    if not self.inst.components.inventory then
        return
    end
    
    self.resource_inventory = {}
    local inventory = self.inst.components.inventory
    
    -- 扫描所有物品栏
    for i = 1, inventory.maxslots do
        local item = inventory:GetItemInSlot(i)
        if item then
            local prefab = item.prefab
            local stacksize = item.components.stackable and item.components.stackable:StackSize() or 1
            
            self.resource_inventory[prefab] = (self.resource_inventory[prefab] or 0) + stacksize
        end
    end
    
    self.last_inventory_scan = GetTime()
end

-- 分析资源需求
function AIManager:AnalyzeResourceNeeds()
    self.resource_needs = {}
    
    -- 基于当前建设项目分析需求
    if self.inst.components.ai_builder then
        local projects = self.inst.components.ai_builder.project_queue or {}
        for _, project in ipairs(projects) do
            local recipe = GetRecipe(project.recipe_name)
            if recipe then
                for _, ingredient in ipairs(recipe.ingredients) do
                    self.resource_needs[ingredient.type] = (self.resource_needs[ingredient.type] or 0) + ingredient.amount
                end
            end
        end
    end
    
    -- 基础生存需求
    self:AddBasicSurvivalNeeds()
    
    -- 季节性需求
    self:AddSeasonalNeeds()
end

-- 添加基础生存需求
function AIManager:AddBasicSurvivalNeeds()
    local basic_needs = {
        wood = 20,      -- 燃料和建设
        stone = 15,     -- 工具和建设
        cutgrass = 10,  -- 各种制作
        twigs = 10,     -- 工具制作
        goldnugget = 5, -- 高级工具
        rope = 3        -- 建设材料
    }
    
    for resource, amount in pairs(basic_needs) do
        local current = self.resource_inventory[resource] or 0
        if current < amount then
            self.resource_needs[resource] = (self.resource_needs[resource] or 0) + (amount - current)
        end
    end
end

-- 添加季节性需求
function AIManager:AddSeasonalNeeds()
    local season = TheWorld.state.season
    local seasonal_needs = {}
    
    if season == "winter" then
        seasonal_needs = {
            wood = 30,          -- 更多燃料
            thermal_stone = 2,  -- 保温石
            winterhat = 1       -- 保温帽
        }
    elseif season == "summer" then
        seasonal_needs = {
            ice = 10,           -- 降温
            nitre = 5,          -- 制作冰火
            luxury_fan = 1      -- 奢华扇子
        }
    elseif season == "spring" then
        seasonal_needs = {
            umbrella = 1,       -- 雨伞
            raincoat = 1        -- 雨衣
        }
    end
    
    for resource, amount in pairs(seasonal_needs) do
        self.resource_needs[resource] = (self.resource_needs[resource] or 0) + amount
    end
end

-- 寻找资源收集目标
function AIManager:FindCollectionTargets()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local search_range = 30
    
    self.collection_targets = {}
    
    -- 寻找不同类型的资源
    self:FindResourcesByType("wood", {"tree"}, search_range)
    self:FindResourcesByType("stone", {"rock", "mineable"}, search_range)
    self:FindResourcesByType("food", {"pickable"}, search_range)
    self:FindResourcesByType("grass", {"grass"}, search_range)
end

-- 按类型寻找资源
function AIManager:FindResourcesByType(resource_type, tags, range)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(x, y, z, range, tags)
    
    for _, entity in ipairs(entities) do
        if entity and entity:IsValid() then
            local prefab = entity.prefab
            local distance = self.inst:GetDistanceSqToInst(entity)
            
            -- 检查冷却时间
            local cooldown_key = entity.GUID
            if not self.collection_cooldowns[cooldown_key] or 
               GetTime() - self.collection_cooldowns[cooldown_key] > 60 then
                
                table.insert(self.collection_targets, {
                    entity = entity,
                    type = resource_type,
                    prefab = prefab,
                    distance = distance,
                    priority = self:GetResourcePriority(prefab)
                })
            end
        end
    end
end

-- 获取资源优先级
function AIManager:GetResourcePriority(prefab)
    -- 基于当前需求计算优先级
    local base_priority = 0.5
    local need_multiplier = 1.0
    
    -- 检查是否是急需资源
    local needed_amount = self.resource_needs[prefab] or 0
    local current_amount = self.resource_inventory[prefab] or 0
    
    if needed_amount > current_amount then
        need_multiplier = 2.0 + (needed_amount - current_amount) * 0.1
    end
    
    -- 基于资源类型的基础优先级
    for category, resources in pairs(self.resource_types) do
        if resources[prefab] then
            base_priority = resources[prefab].priority
            break
        end
    end
    
    return base_priority * need_multiplier
end

-- 获取最佳收集目标
function AIManager:GetBestCollectionTarget()
    if #self.collection_targets == 0 then
        self:FindCollectionTargets()
    end
    
    -- 按优先级和距离排序
    table.sort(self.collection_targets, function(a, b)
        local priority_diff = a.priority - b.priority
        if math.abs(priority_diff) > 0.1 then
            return a.priority > b.priority
        else
            return a.distance < b.distance
        end
    end)
    
    local best_target = self.collection_targets[1]
    if best_target then
        -- 移除已选择的目标
        table.remove(self.collection_targets, 1)
        -- 设置冷却时间
        self.collection_cooldowns[best_target.entity.GUID] = GetTime()
    end
    
    return best_target
end

-- 执行资源收集
function AIManager:CollectResource(target)
    if not target or not target.entity or not target.entity:IsValid() then
        return false
    end
    
    local entity = target.entity
    local action = self:GetCollectionAction(entity)
    
    if action and self.inst.components.locomotor then
        -- 移动到目标位置
        self.inst.components.locomotor:GoToEntity(entity)
        
        -- 执行收集动作
        self.inst:DoTaskInTime(2, function()
            if entity:IsValid() and self.inst:GetDistanceSqToInst(entity) < 9 then
                self.inst:PushEvent("doaction", {action = action, target = entity})
                
                if self.inst.components.talker then
                    local action_names = {
                        [ACTIONS.CHOP] = "砍伐",
                        [ACTIONS.MINE] = "挖掘", 
                        [ACTIONS.PICK] = "采集"
                    }
                    local action_name = action_names[action] or "收集"
                    self.inst.components.talker:Say("正在" .. action_name .. target.prefab .. "...")
                end
            end
        end)
        
        return true
    end
    
    return false
end

-- 获取收集动作
function AIManager:GetCollectionAction(entity)
    if entity:HasTag("CHOP_workable") then
        return ACTIONS.CHOP
    elseif entity:HasTag("MINE_workable") then
        return ACTIONS.MINE
    elseif entity:HasTag("pickable") then
        return ACTIONS.PICK
    end
    
    return nil
end

-- 整理库存
function AIManager:OrganizeInventory()
    if not self.inst.components.inventory then
        return
    end
    
    local inventory = self.inst.components.inventory
    
    -- 合并可堆叠物品
    for i = 1, inventory.maxslots do
        local item1 = inventory:GetItemInSlot(i)
        if item1 and item1.components.stackable then
            for j = i + 1, inventory.maxslots do
                local item2 = inventory:GetItemInSlot(j)
                if item2 and item2.prefab == item1.prefab and item2.components.stackable then
                    item1.components.stackable:Put(item2)
                    if item2.components.stackable:StackSize() == 0 then
                        item2:Remove()
                    end
                end
            end
        end
    end
    
    -- 丢弃多余的低优先级物品
    self:DropExcessItems()
end

-- 丢弃多余物品
function AIManager:DropExcessItems()
    if not self.inst.components.inventory then
        return
    end
    
    local inventory = self.inst.components.inventory
    local items_to_drop = {}
    
    -- 检查每种资源的数量
    for prefab, amount in pairs(self.resource_inventory) do
        local max_keep = self:GetMaxKeepAmount(prefab)
        if amount > max_keep then
            local excess = amount - max_keep
            table.insert(items_to_drop, {prefab = prefab, amount = excess})
        end
    end
    
    -- 执行丢弃
    for _, drop_info in ipairs(items_to_drop) do
        local dropped = 0
        for i = 1, inventory.maxslots do
            if dropped >= drop_info.amount then
                break
            end
            
            local item = inventory:GetItemInSlot(i)
            if item and item.prefab == drop_info.prefab then
                local drop_amount = math.min(drop_info.amount - dropped, 
                                           item.components.stackable and item.components.stackable:StackSize() or 1)
                
                if drop_amount > 0 then
                    inventory:DropItemBySlot(i, drop_amount)
                    dropped = dropped + drop_amount
                end
            end
        end
    end
end

-- 获取最大保留数量
function AIManager:GetMaxKeepAmount(prefab)
    -- 基于资源类型和优先级确定保留数量
    for category, resources in pairs(self.resource_types) do
        if resources[prefab] then
            return resources[prefab].max_stack
        end
    end
    
    -- 默认保留量
    return 20
end

-- 寻找附近的存储设施
function AIManager:FindNearbyStorage()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local storage_entities = TheSim:FindEntities(x, y, z, 20, {"chest"})
    
    local storages = {}
    for _, storage in ipairs(storage_entities) do
        if storage.components.container then
            table.insert(storages, {
                entity = storage,
                distance = self.inst:GetDistanceSqToInst(storage),
                free_slots = storage.components.container:GetNumFreeSlots()
            })
        end
    end
    
    -- 按距离排序
    table.sort(storages, function(a, b)
        return a.distance < b.distance
    end)
    
    return storages
end

-- 向存储设施存放物品
function AIManager:StoreItems(storage, items)
    if not storage or not storage.entity or not storage.entity.components.container then
        return false
    end
    
    local container = storage.entity.components.container
    local stored_any = false
    
    for _, item in ipairs(items) do
        if container:CanTakeItem(item) then
            container:GiveItem(item)
            stored_any = true
        end
    end
    
    return stored_any
end

-- 更新资源管理
function AIManager:Update()
    local current_time = GetTime()
    
    -- 定期扫描库存
    if current_time - self.last_inventory_scan > self.resource_scan_interval then
        self:ScanInventory()
        self:AnalyzeResourceNeeds()
    end
    
    -- 定期整理库存
    if math.random() < 0.1 then -- 10%几率整理
        self:OrganizeInventory()
    end
end

-- 获取资源状态报告
function AIManager:GetResourceReport()
    local report = {
        inventory_items = 0,
        high_priority_needs = {},
        collection_targets = #self.collection_targets
    }
    
    -- 统计库存物品数量
    for prefab, amount in pairs(self.resource_inventory) do
        report.inventory_items = report.inventory_items + amount
    end
    
    -- 找出高优先级需求
    for prefab, needed in pairs(self.resource_needs) do
        local current = self.resource_inventory[prefab] or 0
        if needed > current then
            table.insert(report.high_priority_needs, {
                resource = prefab,
                needed = needed,
                current = current,
                shortage = needed - current
            })
        end
    end
    
    -- 按短缺量排序
    table.sort(report.high_priority_needs, function(a, b)
        return a.shortage > b.shortage
    end)
    
    return report
end

-- 获取收集建议
function AIManager:GetCollectionSuggestion()
    local target = self:GetBestCollectionTarget()
    if target then
        return {
            action = "collect",
            target = target.entity,
            type = target.type,
            priority = target.priority,
            reason = "需要收集" .. target.prefab .. "来满足建设需求"
        }
    end
    
    return nil
end

return AIManager