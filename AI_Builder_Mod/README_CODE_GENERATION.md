# AI Builder MOD - 智能建设助手 (代码生成反射版)

一个集成了DeepSeek AI代码生成反射功能的《饥荒联机版》MOD，能够动态生成和执行Lua代码来实现智能决策。

## 🚀 核心功能

### 1. AI代码生成反射
- **动态代码生成**: 使用DeepSeek AI根据游戏情况实时生成Lua代码
- **安全执行**: 内置代码安全验证，防止恶意代码执行
- **自适应决策**: AI根据角色状态、环境信息、资源需求生成最优行动策略

### 2. 智能建设系统
- **自动资源管理**: 智能收集和分配建设资源
- **建设规划**: 根据地形和需求制定建设计划
- **效率优化**: 优化建设顺序和资源利用

### 3. 高级AI组件
- **ai_code_executor**: 代码执行器，安全执行AI生成的代码
- **ai_builder_controller**: 主控制器，协调所有AI功能
- **ai_manager**: 资源和任务管理
- **ai_planner**: 建设规划
- **ai_communicator**: 智能对话系统

## 📦 安装说明

### 1. MOD安装
```bash
# 将整个AI_Builder_Mod文件夹复制到饥荒MOD目录
# Windows: Documents/Klei/DoNotStarveTogether/mods/
# Mac: ~/Documents/Klei/DoNotStarveTogether/mods/
# Linux: ~/.klei/DoNotStarveTogether/mods/
```

### 2. AI服务安装
```bash
cd AI_Builder_Mod/ai_service

# 安装Python依赖
pip install flask requests python-dotenv

# 配置DeepSeek API密钥
echo "DEEPSEEK_API_KEY=your_api_key_here" > .env

# 启动AI服务
python app.py
```

### 3. 游戏中启用
1. 在MOD列表中启用"AI Builder MOD"
2. 创建世界并进入游戏
3. 使用`builder_summoner`召唤AI Builder角色

## 🎮 使用方法

### 基本操作
1. **召唤AI Builder**: 制作并使用`builder_summoner`
2. **观察AI行为**: AI会自动分析环境并执行任务
3. **调试信息**: 右键点击AI Builder查看性能报告

### 控制台命令
在游戏控制台中输入以下命令来测试功能：

```lua
-- 加载测试脚本
dofile("mods/AI_Builder_Mod/test_code_generation.lua")

-- 运行完整测试
TestAIBuilder()

-- 切换代码生成模式
ToggleAICodeGeneration()

-- 查看性能报告
local perf = GetAIPerformance()
print("成功率:", perf.success_rate * 100, "%")

-- 手动请求AI任务
local result = RequestAITask("survival", {urgency = 0.8})
```

### AI任务类型
- **survival**: 生存优先任务（食物、血量、理智）
- **collecting**: 资源收集任务
- **building**: 建设任务
- **farming**: 农业任务
- **exploring**: 探索任务

## 🔧 配置选项

### MOD配置
在MOD设置中可以调整：
- **AI模式**: 协作/独立
- **活跃度**: 0.1-1.0
- **对话频率**: 60-600秒
- **AI服务**: 启用/禁用

### AI服务配置
编辑`ai_service/.env`文件：
```env
DEEPSEEK_API_KEY=your_api_key_here
FLASK_PORT=5000
DEBUG_MODE=false
MAX_CODE_LENGTH=5000
SAFETY_CHECK_ENABLED=true
```

## 🛡️ 安全特性

### 代码安全验证
AI生成的代码经过多层安全检查：

1. **危险函数检测**: 禁止`io.*`, `os.*`, `require`等危险操作
2. **代码结构验证**: 确保包含必需的`ExecuteAITask`函数
3. **长度限制**: 代码长度不超过5000字符
4. **执行环境隔离**: 在受限的沙盒环境中执行

### 安全执行环境
```lua
-- 允许的API
- 基础Lua函数 (print, tostring, math.*)
- 游戏API (FindEntity, Vector3, GROUND)
- 受限组件访问 (inventory, health, locomotor)

-- 禁止的操作
- 文件系统访问
- 系统命令执行
- 模块动态加载
- 全局环境修改
```

## 🎯 代码生成示例

### AI生成的生存任务代码
```lua
function ExecuteAITask(inst)
    -- AI分析角色状态
    if inst.components.hunger and inst.components.hunger.current < 50 then
        -- 寻找食物
        local food = FindEntity(inst, 10, {"_inventoryitem"}, {"INLIMBO"}, {"edible_VEGGIE"})
        if food then
            inst.components.locomotor:GoToEntity(food)
            return {
                message = "正在前往食物: " .. tostring(food.prefab),
                action = "goto_food",
                priority = 0.8
            }
        end
    end
    
    -- 收集基础资源
    local target = FindEntity(inst, 15, {"pickable"}, {"INLIMBO"})
    if target then
        inst.components.locomotor:GoToEntity(target)
        return {
            message = "正在收集: " .. tostring(target.prefab),
            action = "collect_resource", 
            priority = 0.6
        }
    end
    
    return {message = "寻找任务中...", action = "idle", priority = 0.1}
end
```

## 📊 性能监控

### 性能指标
- **总AI请求数**: 发送给AI服务的请求总数
- **成功生成数**: 成功生成并执行的代码数量
- **失败生成数**: 生成失败或执行失败的数量
- **成功率**: 成功率百分比
- **平均执行时间**: 代码生成和执行的平均时间

### 调试功能
```lua
-- 获取详细性能报告
local builder = GetAIBuilder()
local stats = builder.components.ai_code_executor:GetExecutionStats()
print("执行历史:", #builder.components.ai_code_executor.execution_history)

-- 清除执行历史
builder.components.ai_manager:ClearCodeExecutionHistory()

-- 启用/禁用安全检查
builder.components.ai_manager:SetAISecurityMode(false)
```

## 🔄 工作流程

```
1. AI控制器分析游戏状态
    ↓
2. 确定任务类型和优先级
    ↓
3. 向DeepSeek AI请求代码生成
    ↓
4. 安全验证生成的代码
    ↓
5. 在沙盒环境中执行代码
    ↓
6. 根据执行结果采取行动
    ↓
7. 记录性能统计并反馈学习
```

## 🚨 故障排除

### 常见问题

1. **AI服务连接失败**
   - 检查Python服务是否启动
   - 确认端口5000未被占用
   - 验证API密钥配置

2. **代码生成失败**
   - 检查DeepSeek API配额
   - 查看控制台错误信息
   - 尝试切换到传统模式

3. **安全验证过严**
   - 调整安全检查参数
   - 查看被拒绝的代码模式
   - 更新安全白名单

### 日志查看
```lua
-- 游戏内日志
print(builder.components.ai_code_executor.execution_history)

-- Python服务日志
tail -f ai_service/app.log
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发环境
1. Fork此仓库
2. 设置开发环境
3. 运行测试确保功能正常
4. 提交更改

### 测试
```bash
# MOD测试
在游戏中运行test_code_generation.lua

# AI服务测试  
curl -X POST http://localhost:5000/generate_lua_code \
  -H "Content-Type: application/json" \
  -d '{"task_type":"test","character_state":{}}'
```

## 📄 许可证

MIT License - 详见LICENSE文件

## 🙏 致谢

- DeepSeek AI提供强大的代码生成能力
- Don't Starve Together MOD社区
- Flask和Python生态系统

---

**注意**: 此MOD包含AI代码生成功能，请确保在受控环境中使用，并定期检查生成的代码以确保安全性。