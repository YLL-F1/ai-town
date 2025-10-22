-- AI规划组件
-- 负责基地规划、布局设计和长期建设策略

local AIPlanner = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    
    -- 规划数据
    self.base_center = nil          -- 基地中心点
    self.base_radius = 20           -- 基地半径
    self.zones = {}                 -- 功能区域
    self.planned_structures = {}    -- 已规划的建筑
    
    -- 区域类型
    self.zone_types = {
        core = {name = "核心区", priority = 1.0, radius = 8},
        production = {name = "生产区", priority = 0.8, radius = 12},
        storage = {name = "存储区", priority = 0.7, radius = 6},
        defense = {name = "防御区", priority = 0.9, radius = 15},
        expansion = {name = "扩展区", priority = 0.5, radius = 25}
    }
    
    -- 规划偏好
    self.planning_style = {
        efficiency_focus = 0.8,     -- 效率优先
        aesthetic_focus = 0.4,      -- 美观考虑
        defense_focus = 0.7,        -- 防御重视
        expansion_focus = 0.6       -- 扩展规划
    }
    
    -- 规划历史
    self.planning_history = {}
    self.last_plan_update = 0
end)

-- 初始化基地规划
function AIPlanner:InitializeBasePlanning(center_point)
    if not center_point then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        center_point = Vector3(x, y, z)
    end
    
    self.base_center = center_point
    self:AnalyzeTerrain()
    self:CreateZoneLayout()
    self:GenerateInitialPlan()
    
    if self.inst.components.talker then
        self.inst.components.talker:Say("基地规划已完成，开始执行建设计划。")
    end
end

-- 分析地形
function AIPlanner:AnalyzeTerrain()
    if not self.base_center then return end
    
    local terrain_analysis = {
        buildable_area = 0,
        water_tiles = 0,
        rocky_tiles = 0,
        resource_nodes = {}
    }
    
    local x, z = self.base_center.x, self.base_center.z
    local range = self.base_radius
    
    -- 扫描地形格子
    for dx = -range, range, 2 do
        for dz = -range, range, 2 do
            local test_x, test_z = x + dx, z + dz
            local tile = TheWorld.Map:GetTileAtPoint(test_x, 0, test_z)
            
            if tile and tile ~= GROUND.IMPASSABLE and tile ~= GROUND.INVALID then
                if TheWorld.Map:IsOceanTileAtPoint(test_x, 0, test_z) then
                    terrain_analysis.water_tiles = terrain_analysis.water_tiles + 1
                elseif tile == GROUND.ROCKY then
                    terrain_analysis.rocky_tiles = terrain_analysis.rocky_tiles + 1
                else
                    terrain_analysis.buildable_area = terrain_analysis.buildable_area + 1
                end
            end
        end
    end
    
    -- 扫描资源节点
    local resources = TheSim:FindEntities(x, 0, z, range, {"pickable", "choppable", "mineable"})
    for _, resource in ipairs(resources) do
        local rx, ry, rz = resource.Transform:GetWorldPosition()
        table.insert(terrain_analysis.resource_nodes, {
            type = self:GetResourceType(resource),
            position = Vector3(rx, ry, rz),
            prefab = resource.prefab
        })
    end
    
    self.terrain_analysis = terrain_analysis
end

-- 获取资源类型
function AIPlanner:GetResourceType(resource)
    if resource:HasTag("tree") then
        return "wood"
    elseif resource:HasTag("rock") then
        return "stone"
    elseif resource:HasTag("plant") then
        return "food"
    else
        return "other"
    end
end

-- 创建区域布局
function AIPlanner:CreateZoneLayout()
    if not self.base_center then return end
    
    local cx, cz = self.base_center.x, self.base_center.z
    
    -- 核心区（中心）
    self.zones.core = {
        center = Vector3(cx, 0, cz),
        radius = self.zone_types.core.radius,
        type = "core",
        priority = self.zone_types.core.priority,
        planned_structures = {}
    }
    
    -- 生产区（北部）
    self.zones.production = {
        center = Vector3(cx, 0, cz - 12),
        radius = self.zone_types.production.radius,
        type = "production",
        priority = self.zone_types.production.priority,
        planned_structures = {}
    }
    
    -- 存储区（东部）
    self.zones.storage = {
        center = Vector3(cx + 10, 0, cz),
        radius = self.zone_types.storage.radius,
        type = "storage",
        priority = self.zone_types.storage.priority,
        planned_structures = {}
    }
    
    -- 防御区（外围）
    self.zones.defense = {
        center = Vector3(cx, 0, cz),
        radius = self.zone_types.defense.radius,
        type = "defense",
        priority = self.zone_types.defense.priority,
        planned_structures = {}
    }
end

-- 生成初始规划
function AIPlanner:GenerateInitialPlan()
    -- 核心区规划
    self:PlanCoreStructures()
    
    -- 生产区规划
    self:PlanProductionStructures()
    
    -- 存储区规划
    self:PlanStorageStructures()
    
    -- 防御区规划
    self:PlanDefenseStructures()
    
    self.last_plan_update = GetTime()
end

-- 规划核心建筑
function AIPlanner:PlanCoreStructures()
    local core_zone = self.zones.core
    if not core_zone then return end
    
    local structures = {
        {recipe = "campfire", priority = 1.0, offset = Vector3(0, 0, 0)},
        {recipe = "tent", priority = 0.8, offset = Vector3(3, 0, 3)},
        {recipe = "researchlab", priority = 0.9, offset = Vector3(-4, 0, -2)},
        {recipe = "researchlab2", priority = 0.7, offset = Vector3(4, 0, -2)}
    }
    
    for _, struct in ipairs(structures) do
        local pos = core_zone.center + struct.offset
        if self:IsPositionSuitable(pos, struct.recipe) then
            table.insert(core_zone.planned_structures, {
                recipe_name = struct.recipe,
                position = pos,
                priority = struct.priority,
                zone = "core"
            })
        end
    end
end

-- 规划生产建筑
function AIPlanner:PlanProductionStructures()
    local prod_zone = self.zones.production
    if not prod_zone then return end
    
    local structures = {
        {recipe = "farm_soil", priority = 0.8, count = 4},
        {recipe = "slow_farmplot", priority = 0.6, count = 2},
        {recipe = "cookpot", priority = 0.9, count = 1},
        {recipe = "icebox", priority = 0.7, count = 1}
    }
    
    local grid_spacing = 4
    local current_x, current_z = 0, 0
    
    for _, struct in ipairs(structures) do
        for i = 1, (struct.count or 1) do
            local pos = prod_zone.center + Vector3(current_x, 0, current_z)
            if self:IsPositionSuitable(pos, struct.recipe) then
                table.insert(prod_zone.planned_structures, {
                    recipe_name = struct.recipe,
                    position = pos,
                    priority = struct.priority,
                    zone = "production"
                })
            end
            
            current_x = current_x + grid_spacing
            if current_x > 8 then
                current_x = 0
                current_z = current_z + grid_spacing
            end
        end
    end
end

-- 规划存储建筑
function AIPlanner:PlanStorageStructures()
    local storage_zone = self.zones.storage
    if not storage_zone then return end
    
    local structures = {
        {recipe = "treasurechest", priority = 0.8, count = 3},
        {recipe = "dragonflychest", priority = 0.9, count = 1},
        {recipe = "saltbox", priority = 0.7, count = 1}
    }
    
    local positions = {
        Vector3(0, 0, 0),
        Vector3(4, 0, 0),
        Vector3(0, 0, 4),
        Vector3(4, 0, 4),
        Vector3(-4, 0, 0)
    }
    
    local pos_index = 1
    for _, struct in ipairs(structures) do
        for i = 1, (struct.count or 1) do
            if pos_index <= #positions then
                local pos = storage_zone.center + positions[pos_index]
                if self:IsPositionSuitable(pos, struct.recipe) then
                    table.insert(storage_zone.planned_structures, {
                        recipe_name = struct.recipe,
                        position = pos,
                        priority = struct.priority,
                        zone = "storage"
                    })
                end
                pos_index = pos_index + 1
            end
        end
    end
end

-- 规划防御建筑
function AIPlanner:PlanDefenseStructures()
    local defense_zone = self.zones.defense
    if not defense_zone then return end
    
    -- 创建围墙圈
    local wall_radius = 14
    local wall_segments = 16
    
    for i = 0, wall_segments - 1 do
        local angle = (i / wall_segments) * 2 * PI
        local x = defense_zone.center.x + math.cos(angle) * wall_radius
        local z = defense_zone.center.z + math.sin(angle) * wall_radius
        local pos = Vector3(x, 0, z)
        
        if self:IsPositionSuitable(pos, "wall_hay") then
            table.insert(defense_zone.planned_structures, {
                recipe_name = "wall_hay",
                position = pos,
                priority = 0.6,
                zone = "defense"
            })
        end
    end
    
    -- 添加一些陷阱
    local trap_positions = {
        Vector3(12, 0, 0),
        Vector3(-12, 0, 0),
        Vector3(0, 0, 12),
        Vector3(0, 0, -12)
    }
    
    for _, offset in ipairs(trap_positions) do
        local pos = defense_zone.center + offset
        if self:IsPositionSuitable(pos, "trap") then
            table.insert(defense_zone.planned_structures, {
                recipe_name = "trap",
                position = pos,
                priority = 0.5,
                zone = "defense"
            })
        end
    end
end

-- 检查位置是否合适
function AIPlanner:IsPositionSuitable(pos, recipe_name)
    -- 检查地面类型
    local tile = TheWorld.Map:GetTileAtPoint(pos.x, pos.y, pos.z)
    if tile == GROUND.IMPASSABLE or tile == GROUND.INVALID then
        return false
    end
    
    -- 检查水域
    if TheWorld.Map:IsOceanTileAtPoint(pos.x, pos.y, pos.z) then
        return false
    end
    
    -- 检查是否有障碍物
    local obstacles = TheSim:FindEntities(pos.x, pos.y, pos.z, 2, nil, {"INLIMBO"})
    if #obstacles > 0 then
        return false
    end
    
    return true
end

-- 获取下一个规划建筑
function AIPlanner:GetNextPlannedStructure()
    local all_structures = {}
    
    -- 收集所有区域的规划建筑
    for zone_name, zone in pairs(self.zones) do
        for _, structure in ipairs(zone.planned_structures) do
            if not structure.built then
                table.insert(all_structures, structure)
            end
        end
    end
    
    -- 按优先级排序
    table.sort(all_structures, function(a, b)
        return a.priority > b.priority
    end)
    
    return all_structures[1]
end

-- 标记建筑为已建造
function AIPlanner:MarkStructureBuilt(structure)
    for zone_name, zone in pairs(self.zones) do
        for _, planned in ipairs(zone.planned_structures) do
            if planned.recipe_name == structure.recipe_name and
               planned.position and structure.position and
               self:GetDistance(planned.position, structure.position) < 3 then
                planned.built = true
                return true
            end
        end
    end
    return false
end

-- 更新规划
function AIPlanner:UpdatePlanning()
    local current_time = GetTime()
    if current_time - self.last_plan_update < 300 then -- 每5分钟更新一次
        return
    end
    
    -- 重新分析当前状况
    self:AnalyzeCurrentBase()
    self:GenerateAdditionalPlans()
    
    self.last_plan_update = current_time
end

-- 分析当前基地状况
function AIPlanner:AnalyzeCurrentBase()
    if not self.base_center then return end
    
    local x, z = self.base_center.x, self.base_center.z
    local structures = TheSim:FindEntities(x, 0, z, self.base_radius, {"structure"})
    
    local analysis = {
        total_structures = #structures,
        by_category = {}
    }
    
    for _, structure in ipairs(structures) do
        local category = self:GetStructureCategory(structure.prefab)
        analysis.by_category[category] = (analysis.by_category[category] or 0) + 1
    end
    
    self.base_analysis = analysis
end

-- 获取建筑类别
function AIPlanner:GetStructureCategory(prefab_name)
    local categories = {
        survival = {"campfire", "firepit", "tent", "bedroll"},
        production = {"farm_soil", "slow_farmplot", "cookpot", "icebox"},
        storage = {"treasurechest", "dragonflychest", "saltbox"},
        defense = {"wall_hay", "wall_wood", "wall_stone", "trap"},
        research = {"researchlab", "researchlab2", "researchlab3"}
    }
    
    for category, prefabs in pairs(categories) do
        for _, prefab in ipairs(prefabs) do
            if prefab == prefab_name then
                return category
            end
        end
    end
    
    return "other"
end

-- 生成额外规划
function AIPlanner:GenerateAdditionalPlans()
    if not self.base_analysis then return end
    
    -- 基于当前分析生成新的规划建议
    local suggestions = {}
    
    -- 检查是否需要更多存储
    local storage_count = self.base_analysis.by_category.storage or 0
    if storage_count < 3 then
        table.insert(suggestions, {
            recipe_name = "treasurechest",
            priority = 0.7,
            reason = "需要更多存储空间"
        })
    end
    
    -- 检查是否需要更多生产设施
    local production_count = self.base_analysis.by_category.production or 0
    if production_count < 5 then
        table.insert(suggestions, {
            recipe_name = "farm_soil",
            priority = 0.6,
            reason = "需要扩大农业生产"
        })
    end
    
    return suggestions
end

-- 获取建设建议
function AIPlanner:GetBuildingSuggestions()
    local suggestions = {}
    
    -- 获取下一个规划建筑
    local next_structure = self:GetNextPlannedStructure()
    if next_structure then
        table.insert(suggestions, {
            recipe_name = next_structure.recipe_name,
            position = next_structure.position,
            priority = next_structure.priority,
            zone = next_structure.zone,
            source = "planned"
        })
    end
    
    -- 添加动态建议
    local dynamic_suggestions = self:GenerateAdditionalPlans()
    if dynamic_suggestions then
        for _, suggestion in ipairs(dynamic_suggestions) do
            table.insert(suggestions, suggestion)
        end
    end
    
    return suggestions
end

-- 计算距离
function AIPlanner:GetDistance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return math.sqrt(dx * dx + dz * dz)
end

-- 获取规划统计
function AIPlanner:GetPlanningStats()
    local total_planned = 0
    local total_built = 0
    
    for zone_name, zone in pairs(self.zones) do
        for _, structure in ipairs(zone.planned_structures) do
            total_planned = total_planned + 1
            if structure.built then
                total_built = total_built + 1
            end
        end
    end
    
    return {
        total_planned = total_planned,
        total_built = total_built,
        completion_rate = total_planned > 0 and (total_built / total_planned) or 0,
        zones_count = table.getn(self.zones)
    }
end

return AIPlanner