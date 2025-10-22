-- AI代码执行器组件
-- 负责安全执行AI生成的Lua代码

local AiCodeExecutor = Class(function(self, inst)
    self.inst = inst
    self.generated_functions = {}
    self.execution_history = {}
    self.max_execution_time = 5 -- 最大执行时间（秒）
    self.security_enabled = true
end)

function AiCodeExecutor:ExecuteGeneratedCode(lua_code, task_type, context)
    """执行AI生成的代码"""
    
    -- 安全性检查
    if not self:ValidateCodeSafety(lua_code) then
        print("[AI代码执行器] 代码安全检查失败")
        return {
            success = false,
            error = "代码安全检查失败",
            fallback_action = self:GetFallbackAction(task_type)
        }
    end
    
    -- 编译代码
    local compiled_func, compile_error = self:CompileCode(lua_code)
    if not compiled_func then
        print("[AI代码执行器] 代码编译失败:", compile_error)
        return {
            success = false,
            error = "代码编译失败: " .. tostring(compile_error),
            fallback_action = self:GetFallbackAction(task_type)
        }
    end
    
    -- 创建安全执行环境
    local safe_env = self:CreateSafeEnvironment(context)
    setfenv(compiled_func, safe_env)
    
    -- 执行代码（带超时保护）
    local success, result = self:ExecuteWithTimeout(compiled_func, self.max_execution_time)
    
    if success and result then
        -- 记录执行历史
        self:RecordExecution(lua_code, result, true)
        
        print("[AI代码执行器] 代码执行成功:", result.message or "无消息")
        return {
            success = true,
            result = result,
            execution_time = GetTime()
        }
    else
        print("[AI代码执行器] 代码执行失败:", tostring(result))
        return {
            success = false,
            error = "代码执行失败: " .. tostring(result),
            fallback_action = self:GetFallbackAction(task_type)
        }
    end
end

function AiCodeExecutor:ValidateCodeSafety(lua_code)
    """验证代码安全性"""
    
    if not self.security_enabled then
        return true
    end
    
    -- 危险函数模式检查
    local dangerous_patterns = {
        "io%.",           -- 文件操作
        "os%.",           -- 系统操作
        "require",        -- 模块加载
        "dofile",         -- 文件执行
        "loadfile",       -- 文件加载
        "loadstring",     -- 字符串执行
        "debug%.",        -- 调试接口
        "getfenv",        -- 环境获取
        "setfenv",        -- 环境设置
        "_G",             -- 全局环境
        "%.%.",           -- 目录遍历
        "while%s+true",   -- 潜在无限循环
    }
    
    for _, pattern in ipairs(dangerous_patterns) do
        if string.match(lua_code, pattern) then
            print("[安全检查] 发现危险模式:", pattern)
            return false
        end
    end
    
    -- 检查必需的函数结构
    if not string.match(lua_code, "function%s+ExecuteAITask") then
        print("[安全检查] 缺少必需的ExecuteAITask函数")
        return false
    end
    
    -- 代码长度检查
    if #lua_code > 5000 then
        print("[安全检查] 代码过长")
        return false
    end
    
    return true
end

function AiCodeExecutor:CompileCode(lua_code)
    """编译Lua代码"""
    
    local func, err = loadstring(lua_code)
    if not func then
        return nil, err
    end
    
    return func, nil
end

function AiCodeExecutor:CreateSafeEnvironment(context)
    """创建安全的执行环境"""
    
    local safe_env = {
        -- 基础Lua函数（安全的）
        print = function(...)
            print("[AI生成代码]:", ...)
        end,
        tostring = tostring,
        tonumber = tonumber,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        
        -- 数学库
        math = math,
        
        -- 字符串库（部分）
        string = {
            len = string.len,
            sub = string.sub,
            find = string.find,
            match = string.match,
            format = string.format,
            lower = string.lower,
            upper = string.upper,
        },
        
        -- 表操作
        table = {
            insert = table.insert,
            remove = table.remove,
            sort = table.sort,
        },
        
        -- 游戏相关API（受限制的）
        inst = self.inst,
        TheWorld = TheWorld,
        Vector3 = Vector3,
        GROUND = GROUND,
        GetTime = GetTime,
        
        -- 自定义游戏函数
        FindEntity = function(inst, radius, musthavetags, canthavetags, musthaveoneoftags)
            if radius > 50 then radius = 50 end -- 限制搜索范围
            return FindEntity(inst, radius, musthavetags, canthavetags, musthaveoneoftags)
        end,
        
        -- 受限的组件访问
        GetComponent = function(entity, component_name)
            local allowed_components = {
                "inventory", "health", "hunger", "sanity", 
                "locomotor", "transform", "builder"
            }
            
            for _, allowed in ipairs(allowed_components) do
                if component_name == allowed then
                    return entity.components[component_name]
                end
            end
            
            print("[安全环境] 禁止访问组件:", component_name)
            return nil
        end,
        
        -- 禁止的操作
        io = nil,
        os = nil,
        require = nil,
        dofile = nil,
        loadfile = nil,
        loadstring = nil,
        debug = nil,
        _G = nil,
        getfenv = nil,
        setfenv = nil,
    }
    
    return safe_env
end

function AiCodeExecutor:ExecuteWithTimeout(func, timeout)
    """带超时保护的代码执行"""
    
    local start_time = GetTime()
    local result = nil
    local success = false
    
    -- 简单的超时检查（在没有协程的情况下）
    local function timeout_check()
        if GetTime() - start_time > timeout then
            error("代码执行超时")
        end
    end
    
    -- 执行函数
    success, result = pcall(function()
        timeout_check()
        return func(self.inst)
    end)
    
    return success, result
end

function AiCodeExecutor:GetFallbackAction(task_type)
    """获取后备行动"""
    
    local fallback_actions = {
        farming = {
            action = "manual_farming",
            message = "切换到手动耕地模式",
            priority = 0.7
        },
        building = {
            action = "manual_building", 
            message = "切换到手动建设模式",
            priority = 0.6
        },
        collecting = {
            action = "manual_collecting",
            message = "切换到手动收集模式", 
            priority = 0.5
        },
        general = {
            action = "idle",
            message = "等待新的指令",
            priority = 0.3
        }
    }
    
    return fallback_actions[task_type] or fallback_actions.general
end

function AiCodeExecutor:RecordExecution(code, result, success)
    """记录执行历史"""
    
    local record = {
        timestamp = GetTime(),
        code_hash = self:HashCode(code),
        result = result,
        success = success,
        execution_time = GetTime()
    }
    
    table.insert(self.execution_history, record)
    
    -- 保持历史记录在合理范围内
    if #self.execution_history > 50 then
        table.remove(self.execution_history, 1)
    end
end

function AiCodeExecutor:HashCode(code)
    """生成代码哈希（简单版本）"""
    local hash = 0
    for i = 1, #code do
        hash = hash + string.byte(code, i)
    end
    return hash % 10000
end

function AiCodeExecutor:GetExecutionStats()
    """获取执行统计"""
    
    local total = #self.execution_history
    local successful = 0
    
    for _, record in ipairs(self.execution_history) do
        if record.success then
            successful = successful + 1
        end
    end
    
    return {
        total_executions = total,
        successful_executions = successful,
        success_rate = total > 0 and (successful / total) or 0,
        last_execution = self.execution_history[#self.execution_history]
    }
end

function AiCodeExecutor:ClearHistory()
    """清除执行历史"""
    self.execution_history = {}
end

function AiCodeExecutor:SetSecurityEnabled(enabled)
    """设置安全检查开关"""
    self.security_enabled = enabled
    print("[AI代码执行器] 安全检查", enabled and "已启用" or "已禁用")
end

return AiCodeExecutor