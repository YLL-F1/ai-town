# AI建设助手MOD

## 项目概述

这是一个为《饥荒：联机版》(Don't Starve Together) 开发的AI建设助手MOD，基于DeepSeek大模型提供智能建设决策和协作功能。

## 功能特性

### 🤖 AI建造师角色
- **专业建设助手**: 基于威尔逊模型的AI建造师"艾德"
- **智能决策**: 通过DeepSeek API进行实时AI决策
- **自主工作**: 可独立完成建设、收集、规划任务
- **玩家协作**: 与玩家协同完成大型建设项目

### 🏗️ 建设规划系统
- **智能布局**: 自动分析地形，设计最优基地布局
- **功能分区**: 核心区、生产区、存储区、防御区规划
- **优先级管理**: 基于需求和紧急程度排序建设任务
- **资源优化**: 高效的资源收集和分配策略

### 💬 智能交互
- **自然对话**: 基于DeepSeek的自然语言处理
- **建设建议**: 主动提供专业的建设建议
- **状态汇报**: 实时汇报工作进度和发现
- **学习适应**: 学习玩家建设风格和偏好

### 🔧 本地降级支持
- **规则引擎**: AI服务不可用时使用本地规则
- **缓存机制**: 智能缓存减少API调用
- **错误恢复**: 自动重试和错误处理

## 安装指南

### 1. MOD安装

1. 下载MOD文件夹 `AI_Builder_Mod`
2. 将整个文件夹复制到饥荒MOD目录：
   - **Steam版本**: `steamapps/common/Don't Starve Together/mods/`
   - **独立版本**: `Documents/Klei/DoNotStarveTogether/mods/`

### 2. AI服务安装

#### 自动安装（推荐）

**Windows用户**:
```bash
cd AI_Builder_Mod/ai_service
start.bat
```

**Mac/Linux用户**:
```bash
cd AI_Builder_Mod/ai_service
./start.sh
```

#### 手动安装

1. **安装Python环境**（Python 3.8+）

2. **创建虚拟环境**:
```bash
cd AI_Builder_Mod/ai_service
python -m venv venv
```

3. **激活虚拟环境**:
```bash
# Windows
venv\Scripts\activate
# Mac/Linux  
source venv/bin/activate
```

4. **安装依赖**:
```bash
pip install -r requirements.txt
```

5. **配置API密钥**:
```bash
cp .env.example .env
# 编辑 .env 文件，设置您的DeepSeek API密钥
```

6. **启动服务**:
```bash
python app.py
```

### 3. DeepSeek API配置

1. 访问 [DeepSeek官网](https://platform.deepseek.com/) 注册账号
2. 获取API密钥
3. 在 `ai_service/.env` 文件中设置：
```
DEEPSEEK_API_KEY=your_actual_api_key_here
```

## 使用方法

### 1. 启动游戏

1. 确保AI服务正在运行（访问 http://localhost:8000/ping 检查）
2. 启动《饥荒：联机版》
3. 在MOD选项中启用"AI Builder Assistant"
4. 创建或加入游戏世界

### 2. 召唤AI建造师

1. 制作召唤装置（需要材料：齿轮×2，金块×4，木板×6，石砖×4）
2. 在魔法科技台制作"AI建造师召唤装置"
3. 放置召唤装置并激活
4. AI建造师"艾德"将出现并开始工作

### 3. 与AI建造师互动

- **自动工作**: AI会自主分析环境，执行建设任务
- **接受指令**: 与AI对话可以给出建设指令
- **查看进度**: AI会定期汇报工作进度
- **协作建设**: 在大型项目中与AI分工合作

## MOD配置选项

在游戏中可以调整以下设置：

- **AI工作模式**: 
  - 自主建设：AI完全自主工作
  - 协作建设：与玩家协同工作
  - 顾问模式：只提供建议

- **AI主动性**: 调整AI的主动工作程度（低/中/高）

- **交流频率**: 设置AI汇报和建议的频率

- **AI服务**: 启用/禁用DeepSeek API连接

## 文件结构

```
AI_Builder_Mod/
├── modinfo.lua              # MOD信息和配置
├── modmain.lua              # MOD主入口
├── scripts/
│   ├── prefabs/             # 游戏对象定义
│   │   ├── builder_ed.lua   # AI建造师角色
│   │   └── builder_summoner.lua # 召唤装置
│   ├── components/          # 游戏组件
│   │   ├── ai_builder.lua   # 建设AI组件
│   │   ├── ai_planner.lua   # 规划系统
│   │   ├── ai_manager.lua   # 资源管理
│   │   └── ai_communicator.lua # 通信组件
│   ├── brains/
│   │   └── builder_brain.lua # AI决策大脑
│   └── stategraphs/
│       └── SGbuilder_ed.lua # 角色状态图
├── ai_service/              # Python AI服务
│   ├── app.py              # 主服务文件
│   ├── requirements.txt    # Python依赖
│   ├── .env.example        # 环境配置模板
│   ├── start.sh           # Linux/Mac启动脚本
│   └── start.bat          # Windows启动脚本
└── README.md              # 使用说明
```

## 技术架构

### 游戏端（Lua）
- **角色系统**: 基于饥荒原生角色系统
- **AI组件**: 建设、规划、资源管理等模块化组件
- **决策树**: 基于优先级的行为决策系统
- **状态机**: 角色动画和行为状态管理

### 服务端（Python）
- **Flask Web服务**: 提供HTTP API接口
- **DeepSeek集成**: OpenAI兼容的API调用
- **本地降级**: 规则引擎和缓存机制
- **数据持久化**: SQLite数据库存储学习数据

### 通信协议
- **HTTP请求**: 游戏与AI服务的通信
- **JSON数据**: 结构化的状态和决策数据
- **异步处理**: 非阻塞的AI决策请求

## 开发和调试

### 启用调试模式

1. 在 `ai_service/.env` 中设置：
```
FLASK_DEBUG=1
LOG_LEVEL=DEBUG
```

2. 查看日志输出了解AI决策过程

### 自定义AI行为

1. 修改 `ai_service/app.py` 中的系统提示词
2. 调整本地规则引擎逻辑
3. 重启AI服务生效

### 添加新的建设项目

1. 在 `ai_planner.lua` 中添加新的规划逻辑
2. 在 `ai_builder.lua` 中添加建设处理
3. 更新AI服务的可选动作列表

## 故障排除

### AI服务无法启动
- 检查Python版本（需要3.8+）
- 确认所有依赖已安装
- 查看控制台错误信息

### API调用失败
- 验证DeepSeek API密钥是否正确
- 检查网络连接
- 确认API配额是否充足

### MOD无法加载
- 检查文件路径是否正确
- 查看饥荒客户端的错误日志
- 确认MOD兼容性设置

### AI行为异常
- 重启AI服务
- 清除决策缓存
- 检查游戏状态数据

## 更新日志

### v1.0.0 (当前版本)
- ✅ 基础AI建造师角色实现
- ✅ DeepSeek API集成
- ✅ 智能建设规划系统
- ✅ 资源管理和收集
- ✅ 玩家协作和交互
- ✅ 本地降级支持

### 计划功能
- 🔄 多AI建造师协作
- 🔄 高级建设模板
- 🔄 语音交互支持
- 🔄 可视化建设规划界面

## 许可证

本项目采用 MIT 许可证。

## 贡献

欢迎提交Bug报告和功能建议！

## 支持

如有问题请提交Issue或联系开发团队。

---

**注意**: 使用本MOD需要DeepSeek API密钥，可能产生API调用费用。请合理使用并监控API用量。