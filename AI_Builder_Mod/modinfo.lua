-- AI建设助手MOD信息配置
name = "AI Builder Assistant"
description = "一个基于DeepSeek大模型的智能建设助手，能够帮助玩家规划和建设基地。\n\n功能特性：\n• 智能基地规划和布局优化\n• 自动资源收集和管理\n• 建设任务协作和分工\n• 学习玩家建设风格\n• 提供专业建设建议"

author = "AI Town Development Team"
version = "1.0.0"
forumthread = ""

api_version = 10
api_version_dst = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- MOD配置选项
configuration_options = {
    {
        name = "ai_mode",
        label = "AI工作模式",
        hover = "选择AI助手的工作模式",
        options = {
            {description = "自主建设", data = "autonomous"},
            {description = "协作建设", data = "collaborative"},
            {description = "顾问模式", data = "advisor"}
        },
        default = "collaborative"
    },
    {
        name = "ai_activity",
        label = "AI主动性",
        hover = "调整AI助手的主动性级别",
        options = {
            {description = "低", data = 0.3},
            {description = "中", data = 0.6},
            {description = "高", data = 0.9}
        },
        default = 0.6
    },
    {
        name = "ai_chat_frequency",
        label = "交流频率",
        hover = "AI助手汇报和建议的频率",
        options = {
            {description = "很少", data = 300},
            {description = "适中", data = 180},
            {description = "频繁", data = 60}
        },
        default = 180
    },
    {
        name = "enable_ai_service",
        label = "启用AI服务",
        hover = "是否连接到DeepSeek AI服务（需要本地服务运行）",
        options = {
            {description = "启用", data = true},
            {description = "禁用", data = false}
        },
        default = true
    },
    {
        name = "ai_service_url",
        label = "AI服务地址",
        hover = "本地AI服务的URL地址",
        options = {
            {description = "localhost:8000", data = "http://localhost:8000"},
            {description = "localhost:5000", data = "http://localhost:5000"},
            {description = "自定义", data = "custom"}
        },
        default = "http://localhost:8000"
    }
}

-- 服务器过滤标签
server_filter_tags = {
    "ai",
    "builder",
    "assistant",
    "automation"
}