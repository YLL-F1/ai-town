-- AI建设助手MOD主入口
-- 加载必要的资源和组件

-- 环境变量
local GLOBAL = GLOBAL
local require = GLOBAL.require
local TUNING = GLOBAL.TUNING

-- 获取MOD配置
local AI_MODE = GetModConfigData("ai_mode") or "collaborative"
local AI_ACTIVITY = GetModConfigData("ai_activity") or 0.6
local AI_CHAT_FREQUENCY = GetModConfigData("ai_chat_frequency") or 180
local ENABLE_AI_SERVICE = GetModConfigData("enable_ai_service") or true
local AI_SERVICE_URL = GetModConfigData("ai_service_url") or "http://localhost:8000"

-- 全局变量设置
GLOBAL.AI_BUILDER_CONFIG = {
    mode = AI_MODE,
    activity_level = AI_ACTIVITY,
    chat_frequency = AI_CHAT_FREQUENCY,
    ai_service_enabled = ENABLE_AI_SERVICE,
    ai_service_url = AI_SERVICE_URL
}

-- 预制件资源注册
PrefabFiles = {
    "builder_ed",           -- AI建造师角色
    "builder_summoner",     -- AI召唤装置
}

-- 资源文件注册
Assets = {
    -- 角色相关资源
    Asset("ANIM", "anim/builder_ed.zip"),
    Asset("ANIM", "anim/builder_ed_build.zip"),
    
    -- UI相关资源
    Asset("ATLAS", "images/builder_ui.xml"),
    Asset("IMAGE", "images/builder_ui.tex"),
    
    -- 音效资源
    Asset("SOUND", "sound/builder_sounds.fsb"),
    
    -- MOD图标
    Asset("ATLAS", "modicon.xml"),
    Asset("IMAGE", "modicon.tex"),
}

-- 组件注册
local components = {
    "ai_builder",
    "ai_planner", 
    "ai_manager",
    "ai_communicator",
    "ai_code_executor",      -- 新增：代码执行器
    "ai_builder_controller", -- 新增：主控制器
}

for _, component in ipairs(components) do
    modimport("scripts/components/" .. component .. ".lua")
end

-- 大脑和状态图注册
modimport("scripts/brains/builder_brain.lua")
modimport("scripts/stategraphs/SGbuilder_ed.lua")

-- 游戏数值调整
TUNING.AI_BUILDER = {
    -- 基础属性
    HEALTH = 150,
    HUNGER = 150,
    SANITY = 200,
    
    -- 建设相关
    BUILD_SPEED_MULT = 2.0,     -- 建设速度倍数
    WORK_EFFICIENCY = 1.5,      -- 工作效率
    CARRY_CAPACITY = 20,        -- 携带容量
    
    -- AI行为参数
    DECISION_INTERVAL = 30,     -- 决策间隔(秒)
    PLANNING_RANGE = 20,        -- 规划范围
    MEMORY_DURATION = 86400,    -- 记忆持续时间(秒)
    
    -- 交流参数
    CHAT_RANGE = 15,           -- 交流范围
    REPORT_INTERVAL = AI_CHAT_FREQUENCY, -- 汇报间隔
}

-- 调试功能
if GLOBAL.TheNet:IsDedicated() then
    print("[AI Builder] 服务器端MOD已加载")
else
    print("[AI Builder] 客户端MOD已加载")
end

-- 初始化函数
local function InitializeAIBuilder()
    -- 检查AI服务连接
    if ENABLE_AI_SERVICE then
        print("[AI Builder] AI服务已启用，地址：" .. AI_SERVICE_URL)
        -- 这里可以添加连接测试逻辑
    else
        print("[AI Builder] AI服务已禁用，将使用本地规则引擎")
    end
    
    -- 设置全局事件监听
    GLOBAL.TheWorld:ListenForEvent("ms_playerspawn", function(world, player)
        if player and player:HasTag("player") then
            print("[AI Builder] 玩家已加入，AI助手系统准备就绪")
        end
    end)
end

-- 服务器端初始化
AddSimPostInit(InitializeAIBuilder)

-- 玩家加入事件
AddPlayerPostInit(function(player)
    -- 为玩家添加AI建设助手相关组件
    if not player.components.ai_builder_manager then
        player:AddComponent("ai_builder_manager")
    end
end)

print("[AI Builder Mod] 版本1.0.0 加载完成")