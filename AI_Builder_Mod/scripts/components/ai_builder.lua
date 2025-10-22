-- AI建设组件
-- 负责处理建设相关的AI决策和执行

local AIBuilder = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    
    -- 建设状态
    self.current_project = nil      -- 当前建设项目
    self.project_queue = {}         -- 建设项目队列
    self.build_efficiency = TUNING.AI_BUILDER.WORK_EFFICIENCY or 1.5
    
    -- 建设偏好
    self.build_priorities = {
        survival = 1.0,     -- 生存建筑（火堆、帐篷等）
        defense = 0.8,      -- 防御建筑（围墙、陷阱等）
        production = 0.9,   -- 生产建筑（农场、箱子等）
        comfort = 0.6,      -- 舒适建筑（装饰品等）
    }
    
    -- 建设历史
    self.build_history = {}
    self.last_build_time = 0
    
    -- 工作模式
    self.work_mode = GLOBAL.AI_BUILDER_CONFIG.mode or "collaborative"
    
    -- 错误跟踪
    self.build_failures = {}
    self.max_failures_per_item = 3
end)

-- 设置当前建设项目
function AIBuilder:SetCurrentProject(project)
    self.current_project = project
    if project then
        self:RecordBuildAttempt(project.recipe_name)
        if self.inst.components.talker then
            self.inst.components.talker:Say("开始建设：" .. (project.display_name or project.recipe_name))
        end
    end
end

-- 添加建设项目到队列
function AIBuilder:AddProject(project)
    if not self:ValidateProject(project) then
        return false
    end
    
    -- 检查是否已经在队列中
    for _, existing in ipairs(self.project_queue) do
        if existing.recipe_name == project.recipe_name and 
           existing.position and project.position and
           self:GetDistance(existing.position, project.position) < 2 then
            return false -- 重复项目
        end
    end
    
    table.insert(self.project_queue, project)
    self:SortProjectQueue()
    return true
end

-- 验证建设项目
function AIBuilder:ValidateProject(project)
    if not project or not project.recipe_name then
        return false
    end
    
    -- 检查是否有配方
    local recipe = GetRecipe(project.recipe_name)
    if not recipe then
        return false
    end
    
    -- 检查失败次数
    local failure_count = self.build_failures[project.recipe_name] or 0
    if failure_count >= self.max_failures_per_item then
        return false
    end
    
    return true
end

-- 排序项目队列（按优先级）
function AIBuilder:SortProjectQueue()
    table.sort(self.project_queue, function(a, b)
        return self:GetProjectPriority(a) > self:GetProjectPriority(b)
    end)
end

-- 获取项目优先级
function AIBuilder:GetProjectPriority(project)
    local base_priority = project.priority or 0.5
    local category_priority = self.build_priorities[project.category] or 0.5
    local urgency = self:CalculateUrgency(project)
    
    return base_priority * category_priority * urgency
end

-- 计算紧急程度
function AIBuilder:CalculateUrgency(project)
    local urgency = 1.0
    
    -- 基于季节调整
    local season = TheWorld.state.season
    if season == "winter" and project.category == "survival" then
        urgency = urgency * 1.5
    elseif season == "summer" and project.category == "defense" then
        urgency = urgency * 1.3
    end
    
    -- 基于当前威胁调整
    local threats = self:AssessLocalThreats()
    if threats > 0.5 and project.category == "defense" then
        urgency = urgency * (1 + threats)
    end
    
    return urgency
end

-- 评估本地威胁
function AIBuilder:AssessLocalThreats()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local hostile_creatures = TheSim:FindEntities(x, y, z, 20, {"hostile"})
    local threat_level = #hostile_creatures * 0.1
    
    -- 检查是否接近夜晚
    if TheWorld.state.isnight or TheWorld.state.isdusk then
        threat_level = threat_level + 0.3
    end
    
    return math.min(threat_level, 1.0)
end

-- 获取下一个建设项目
function AIBuilder:GetNextProject()
    if #self.project_queue == 0 then
        return nil
    end
    
    -- 检查资源可用性
    for i, project in ipairs(self.project_queue) do
        if self:CanBuildProject(project) then
            table.remove(self.project_queue, i)
            return project
        end
    end
    
    return nil
end

-- 检查是否能建设项目
function AIBuilder:CanBuildProject(project)
    local recipe = GetRecipe(project.recipe_name)
    if not recipe then
        return false
    end
    
    -- 检查科技要求
    if not self.inst.components.builder:CanBuild(project.recipe_name) then
        return false
    end
    
    -- 检查材料
    return self:HasRequiredMaterials(recipe)
end

-- 检查是否有所需材料
function AIBuilder:HasRequiredMaterials(recipe)
    if not self.inst.components.inventory then
        return false
    end
    
    for _, ingredient in ipairs(recipe.ingredients) do
        local has_amount = self.inst.components.inventory:Has(ingredient.type, ingredient.amount)
        if has_amount < ingredient.amount then
            return false
        end
    end
    
    return true
end

-- 执行建设
function AIBuilder:ExecuteBuild(project)
    if not project or not self.inst.components.builder then
        return false
    end
    
    local recipe = GetRecipe(project.recipe_name)
    if not recipe then
        self:RecordBuildFailure(project.recipe_name, "配方不存在")
        return false
    end
    
    -- 尝试建造
    local success = false
    if project.position then
        local x, z = project.position.x, project.position.z
        success = self.inst.components.builder:DoBuild(recipe, Vector3(x, 0, z), project.rotation)
    else
        -- 在附近找个合适的位置
        local build_pos = self:FindBuildPosition(recipe)
        if build_pos then
            success = self.inst.components.builder:DoBuild(recipe, build_pos, project.rotation)
        end
    end
    
    if success then
        self:RecordBuildSuccess(project.recipe_name)
        self.last_build_time = GetTime()
        
        -- 更新建设历史
        table.insert(self.build_history, {
            recipe = project.recipe_name,
            time = GetTime(),
            position = project.position
        })
        
        if self.inst.components.talker then
            self.inst.components.talker:Say("建设完成：" .. (project.display_name or project.recipe_name))
        end
    else
        self:RecordBuildFailure(project.recipe_name, "建造失败")
    end
    
    return success
end

-- 寻找建造位置
function AIBuilder:FindBuildPosition(recipe)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local range = 10
    
    -- 尝试多个位置
    for i = 1, 10 do
        local angle = math.random() * 2 * PI
        local dist = math.random() * range
        local test_x = x + math.cos(angle) * dist
        local test_z = z + math.sin(angle) * dist
        local test_pos = Vector3(test_x, 0, test_z)
        
        -- 检查位置是否可用
        if self:IsValidBuildPosition(test_pos, recipe) then
            return test_pos
        end
    end
    
    return nil
end

-- 检查位置是否适合建造
function AIBuilder:IsValidBuildPosition(pos, recipe)
    -- 检查地面类型
    local tile = TheWorld.Map:GetTileAtPoint(pos.x, pos.y, pos.z)
    if tile == GROUND.IMPASSABLE or tile == GROUND.INVALID then
        return false
    end
    
    -- 检查是否有障碍物
    local obstacles = TheSim:FindEntities(pos.x, pos.y, pos.z, 2, nil, {"INLIMBO"})
    if #obstacles > 0 then
        return false
    end
    
    -- 检查水域
    if TheWorld.Map:IsOceanTileAtPoint(pos.x, pos.y, pos.z) then
        return false
    end
    
    return true
end

-- 记录建造成功
function AIBuilder:RecordBuildSuccess(recipe_name)
    -- 重置失败计数
    self.build_failures[recipe_name] = 0
end

-- 记录建造失败
function AIBuilder:RecordBuildFailure(recipe_name, reason)
    self.build_failures[recipe_name] = (self.build_failures[recipe_name] or 0) + 1
    print("[AI Builder] 建造失败: " .. recipe_name .. " - " .. (reason or "未知原因"))
end

-- 记录建造尝试
function AIBuilder:RecordBuildAttempt(recipe_name)
    -- 用于统计和学习
end

-- 获取建设统计
function AIBuilder:GetBuildStats()
    return {
        total_builds = #self.build_history,
        current_queue_size = #self.project_queue,
        failure_count = self:GetTotalFailures(),
        last_build_time = self.last_build_time
    }
end

-- 获取总失败次数
function AIBuilder:GetTotalFailures()
    local total = 0
    for _, count in pairs(self.build_failures) do
        total = total + count
    end
    return total
end

-- 计算距离
function AIBuilder:GetDistance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return math.sqrt(dx * dx + dz * dz)
end

-- 清空项目队列
function AIBuilder:ClearQueue()
    self.project_queue = {}
    self.current_project = nil
end

-- 设置工作模式
function AIBuilder:SetWorkMode(mode)
    self.work_mode = mode
    if self.inst.components.talker then
        local mode_names = {
            autonomous = "自主建设",
            collaborative = "协作建设", 
            advisor = "顾问模式"
        }
        self.inst.components.talker:Say("切换到" .. (mode_names[mode] or mode) .. "模式")
    end
end

-- 获取建设建议
function AIBuilder:GetBuildingSuggestions()
    local suggestions = {}
    
    -- 基于当前环境分析建议
    local analysis = self.inst:AnalyzeResources and self.inst:AnalyzeResources() or {}
    
    -- 生存建设建议
    if not self:HasNearbyStructure("campfire", 10) then
        table.insert(suggestions, {
            recipe_name = "campfire",
            category = "survival",
            priority = 0.9,
            reason = "需要火源来保暖和照明"
        })
    end
    
    -- 存储建设建议
    if not self:HasNearbyStructure("treasurechest", 15) then
        table.insert(suggestions, {
            recipe_name = "treasurechest",
            category = "production",
            priority = 0.7,
            reason = "需要存储空间来整理物品"
        })
    end
    
    return suggestions
end

-- 检查附近是否有特定建筑
function AIBuilder:HasNearbyStructure(structure_name, range)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local structures = TheSim:FindEntities(x, y, z, range, {structure_name})
    return #structures > 0
end

return AIBuilder