-- AI Builder代码生成反射功能测试脚本
-- 在游戏控制台中运行此脚本来测试AI代码生成功能

print("=== AI Builder代码生成反射测试 ===")

-- 查找AI Builder角色
local function FindAIBuilder()
    for _, ent in ipairs(AllPlayers) do
        if ent.prefab == "builder_ed" then
            return ent
        end
    end
    
    -- 如果没有找到玩家实体，搜索所有实体
    local builders = TheSim:FindEntities(0, 0, 0, 1000, {"ai_builder"})
    return builders[1]
end

-- 测试代码生成功能
local function TestCodeGeneration()
    local builder = FindAIBuilder()
    if not builder then
        print("错误: 找不到AI Builder实体")
        return
    end
    
    print("找到AI Builder:", builder.prefab)
    
    -- 检查组件
    if not builder.components.ai_manager then
        print("错误: AI管理器组件未找到")
        return
    end
    
    if not builder.components.ai_code_executor then
        print("错误: 代码执行器组件未找到")
        return
    end
    
    if not builder.components.ai_builder_controller then
        print("错误: AI控制器组件未找到")
        return
    end
    
    print("所有必需组件已找到!")
    
    -- 测试代码生成
    print("\n--- 测试1: AI代码生成请求 ---")
    local result = builder.components.ai_manager:RequestAICodeGeneration("survival", {
        test_mode = true,
        urgency = 0.8
    })
    
    if result.success then
        print("✓ 代码生成成功!")
        print("执行结果:", result.result and result.result.message or "无消息")
        print("执行时间:", result.execution_time and string.format("%.2fs", result.execution_time) or "未记录")
    else
        print("✗ 代码生成失败:", result.error)
        if result.fallback_action then
            print("后备方案:", result.fallback_action.action, "-", result.fallback_action.message)
        end
    end
    
    -- 测试代码安全验证
    print("\n--- 测试2: 代码安全验证 ---")
    local safe_code = [[
function ExecuteAITask(inst)
    print("这是一个安全的测试代码")
    return {
        message = "测试成功",
        action = "test",
        priority = 0.5
    }
end
    ]]
    
    local dangerous_code = [[
function ExecuteAITask(inst)
    os.execute("rm -rf /")  -- 危险操作!
    return {}
end
    ]]
    
    local safe_result = builder.components.ai_code_executor:ValidateCodeSafety(safe_code)
    local dangerous_result = builder.components.ai_code_executor:ValidateCodeSafety(dangerous_code)
    
    print("安全代码验证:", safe_result and "✓ 通过" or "✗ 失败")
    print("危险代码验证:", dangerous_result and "✗ 误通过" or "✓ 正确拒绝")
    
    -- 测试控制器状态
    print("\n--- 测试3: 控制器状态 ---")
    local controller = builder.components.ai_builder_controller
    local performance = controller:GetPerformanceReport()
    
    print("AI请求总数:", performance.total_ai_requests)
    print("成功生成数:", performance.successful_generations)
    print("失败生成数:", performance.failed_generations)
    print("成功率:", string.format("%.1f%%", performance.success_rate * 100))
    print("代码生成模式:", performance.code_generation_enabled and "启用" or "禁用")
    print("当前任务:", performance.current_task)
    
    -- 测试模式切换
    print("\n--- 测试4: 模式切换 ---")
    local original_mode = performance.code_generation_enabled
    controller:ToggleCodeGeneration()
    
    local new_performance = controller:GetPerformanceReport()
    print("模式切换后:", new_performance.code_generation_enabled and "启用" or "禁用")
    
    -- 恢复原始模式
    if original_mode ~= new_performance.code_generation_enabled then
        controller:ToggleCodeGeneration()
    end
    
    print("\n--- 测试5: 直接代码执行 ---")
    local test_result = builder.components.ai_code_executor:ExecuteGeneratedCode(
        safe_code, 
        "test", 
        {test_mode = true}
    )
    
    if test_result.success then
        print("✓ 直接代码执行成功!")
        print("返回结果:", test_result.result.message)
    else
        print("✗ 直接代码执行失败:", test_result.error)
    end
    
    print("\n=== 测试完成 ===")
end

-- 运行测试
TestCodeGeneration()

-- 提供手动测试函数
GLOBAL.TestAIBuilder = TestCodeGeneration
GLOBAL.FindAIBuilder = FindAIBuilder

-- 提供快速访问函数
GLOBAL.GetAIBuilder = function()
    return FindAIBuilder()
end

GLOBAL.ToggleAICodeGeneration = function()
    local builder = FindAIBuilder()
    if builder and builder.components.ai_builder_controller then
        builder.components.ai_builder_controller:ToggleCodeGeneration()
        return true
    end
    return false
end

GLOBAL.GetAIPerformance = function()
    local builder = FindAIBuilder()
    if builder and builder.components.ai_builder_controller then
        return builder.components.ai_builder_controller:GetPerformanceReport()
    end
    return nil
end

GLOBAL.RequestAITask = function(task_type, context)
    local builder = FindAIBuilder()
    if builder and builder.components.ai_manager then
        return builder.components.ai_manager:RequestAICodeGeneration(task_type, context)
    end
    return nil
end

print("测试脚本已加载，可以使用以下全局函数:")
print("TestAIBuilder() - 运行完整测试")
print("GetAIBuilder() - 获取AI Builder实体")
print("ToggleAICodeGeneration() - 切换代码生成模式")
print("GetAIPerformance() - 获取性能报告")
print("RequestAITask(type, context) - 请求AI任务")