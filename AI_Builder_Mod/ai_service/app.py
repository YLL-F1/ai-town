# AI建设助手服务
# 提供DeepSeek API集成和本地决策服务

from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json
import time
import logging
from typing import Dict, Any, Optional
import os
from dataclasses import dataclass, asdict
import sqlite3
from datetime import datetime, timedelta

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建Flask应用
app = Flask(__name__)
CORS(app)

# DeepSeek API配置
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "your_api_key_here")
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1"
DEEPSEEK_CHAT_URL = f"{DEEPSEEK_BASE_URL}/chat/completions"

@dataclass
class GameContext:
    """游戏上下文数据结构"""
    health: float
    hunger: float  
    sanity: float
    day: int
    season: str
    time_phase: str
    is_night: bool
    is_dusk: bool
    inventory_full: bool
    wood_count: int
    stone_count: int
    food_count: int
    has_campfire: bool
    has_chest: bool
    base_center: Optional[Dict]
    planning_progress: Optional[float] = None
    total_planned: Optional[int] = None
    resource_needs: Optional[list] = None
    collection_targets: Optional[int] = None

@dataclass
class AIDecision:
    """AI决策结果"""
    action: str
    reasoning: str
    priority: float
    message: str
    source: str = "deepseek"
    confidence: float = 0.8

class AIService:
    """AI服务主类"""
    
    def __init__(self):
        self.db_path = "ai_builder.db"
        self.init_database()
        self.decision_cache = {}
        self.cache_expiry = 300  # 5分钟缓存
        
        # 系统提示词模板
        self.system_prompt = """
你是饥荒世界中的AI建造师艾德，一个专业的建设工程师。你的特点：
1. 专精建筑规划和资源管理
2. 注重效率和实用性  
3. 语言风格专业但友善
4. 善于分析和优化建设方案

你的主要职责：
- 分析当前游戏状况
- 提供建设和资源管理建议
- 协助玩家进行基地规划
- 在保证生存的前提下优化建设效率

请根据当前游戏状态，选择最合适的行动并说明理由。
"""
        
        # 预定义的决策动作
        self.available_actions = [
            "collect_wood", "collect_stone", "collect_food",
            "build_campfire", "build_chest", "build_farm",
            "organize_inventory", "plan_base", "rest",
            "seek_safety", "find_resources"
        ]
        
    def init_database(self):
        """初始化数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 创建决策历史表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS decision_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                context TEXT,
                decision TEXT,
                outcome TEXT
            )
        ''')
        
        # 创建学习数据表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS learning_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                situation_type TEXT,
                action_taken TEXT,
                success_rate REAL,
                notes TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
        
    def get_deepseek_decision(self, context: GameContext) -> AIDecision:
        """使用DeepSeek API获取AI决策"""
        try:
            # 构建上下文描述
            context_description = self._build_context_description(context)
            
            # 构建提示词
            user_prompt = f"""
当前游戏状态：
{context_description}

可选行动：{', '.join(self.available_actions)}

请基于当前情况，选择最合适的行动并说明理由。
回应格式：
{{
    "action": "选择的行动",
    "reasoning": "详细的分析理由",
    "priority": 0.0-1.0的优先级数值,
    "message": "对玩家说的话（50字以内）"
}}
"""
            
            # 调用DeepSeek API
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": self.system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=500
            )
            
            # 解析响应
            content = response.choices[0].message.content
            decision_data = self._parse_decision_response(content)
            
            decision = AIDecision(
                action=decision_data.get("action", "idle"),
                reasoning=decision_data.get("reasoning", "AI正在分析情况"),
                priority=decision_data.get("priority", 0.5),
                message=decision_data.get("message", "让我想想..."),
                source="deepseek",
                confidence=0.9
            )
            
            # 记录决策
            self._record_decision(context, decision)
            
            return decision
            
        except Exception as e:
            logger.error(f"DeepSeek API调用失败: {e}")
            return self._get_fallback_decision(context)
    
    def _build_context_description(self, context: GameContext) -> str:
        """构建上下文描述"""
        description = f"""
- 健康状况: {context.health:.1f}%
- 饥饿程度: {context.hunger:.1f}%
- 理智状态: {context.sanity:.1f}%
- 游戏进度: 第{context.day}天，{context.season}季，{context.time_phase}
- 库存状态: {'已满' if context.inventory_full else '未满'}
- 资源储备: 木材{context.wood_count}，石头{context.stone_count}，食物{context.food_count}
- 基地设施: {'有火堆' if context.has_campfire else '无火堆'}，{'有箱子' if context.has_chest else '无箱子'}
"""
        
        if context.is_night:
            description += "- 特殊状况: 当前是夜晚，需要注意安全\n"
        
        if context.planning_progress is not None:
            description += f"- 建设进度: {context.planning_progress:.1%}完成\n"
            
        if context.resource_needs:
            needs = [f"{need['resource']}缺{need['shortage']}" for need in context.resource_needs[:3]]
            description += f"- 资源需求: {', '.join(needs)}\n"
            
        return description
    
    def _parse_decision_response(self, content: str) -> Dict[str, Any]:
        """解析AI响应"""
        try:
            # 尝试解析JSON
            if '{' in content and '}' in content:
                json_start = content.find('{')
                json_end = content.rfind('}') + 1
                json_str = content[json_start:json_end]
                return json.loads(json_str)
        except:
            pass
        
        # 如果JSON解析失败，使用正则表达式提取信息
        decision_data = {
            "action": "idle",
            "reasoning": "AI正在分析情况",
            "priority": 0.5,
            "message": "让我想想最好的方案..."
        }
        
        # 简单的关键词匹配
        content_lower = content.lower()
        if "wood" in content_lower or "砍" in content:
            decision_data["action"] = "collect_wood"
            decision_data["message"] = "我去收集一些木材。"
        elif "stone" in content_lower or "石" in content:
            decision_data["action"] = "collect_stone"
            decision_data["message"] = "需要采集一些石料。"
        elif "food" in content_lower or "食" in content:
            decision_data["action"] = "collect_food"
            decision_data["message"] = "寻找一些食物来补充。"
        elif "fire" in content_lower or "火" in content:
            decision_data["action"] = "build_campfire"
            decision_data["message"] = "建造一个火堆很重要。"
        
        return decision_data
    
    def _get_fallback_decision(self, context: GameContext) -> AIDecision:
        """获取后备决策（本地规则引擎）"""
        # 紧急情况处理
        if context.health < 30:
            return AIDecision(
                action="seek_safety",
                reasoning="生命值过低，需要寻找安全地点",
                priority=1.0,
                message="健康状况不佳，我需要找个安全的地方。",
                source="fallback"
            )
        
        if context.hunger < 20:
            return AIDecision(
                action="collect_food",
                reasoning="饥饿值过低，急需食物",
                priority=0.9,
                message="太饿了，需要马上找些食物。",
                source="fallback"
            )
        
        # 夜晚安全
        if context.is_night and not context.has_campfire:
            return AIDecision(
                action="build_campfire",
                reasoning="夜晚需要火源照明和保护",
                priority=0.8,
                message="夜晚来临，建个火堆比较安全。",
                source="fallback"
            )
        
        # 资源收集
        if context.wood_count < 10:
            return AIDecision(
                action="collect_wood",
                reasoning="木材储备不足",
                priority=0.6,
                message="木材不够了，去砍些树木。",
                source="fallback"
            )
        
        if context.stone_count < 5:
            return AIDecision(
                action="collect_stone",
                reasoning="石头储备不足",
                priority=0.5,
                message="需要收集一些石料。",
                source="fallback"
            )
        
        # 基地建设
        if not context.has_chest and context.inventory_full:
            return AIDecision(
                action="build_chest",
                reasoning="库存已满，需要存储空间",
                priority=0.7,
                message="库存满了，建个箱子存放物品。",
                source="fallback"
            )
        
        # 默认行为
        return AIDecision(
            action="plan_base",
            reasoning="当前状况稳定，进行基地规划",
            priority=0.4,
            message="让我规划一下基地的建设方案。",
            source="fallback"
        )
    
    def _record_decision(self, context: GameContext, decision: AIDecision):
        """记录决策到数据库"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO decision_history (context, decision)
                VALUES (?, ?)
            ''', (json.dumps(asdict(context)), json.dumps(asdict(decision))))
            
            conn.commit()
            conn.close()
        except Exception as e:
            logger.error(f"记录决策失败: {e}")
    
    def get_chat_response(self, player_message: str, context: GameContext) -> str:
        """获取聊天响应"""
        try:
            context_description = self._build_context_description(context)
            
            user_prompt = f"""
玩家对你说："{player_message}"

当前情况：
{context_description}

请以建造师艾德的身份回应，要求：
1. 符合建设工程师的专业形象
2. 回应长度控制在50字以内
3. 如果涉及建设建议，给出具体可行的方案
4. 语气友善专业
"""
            
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": self.system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.8,
                max_tokens=200
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"聊天响应失败: {e}")
            return self._get_fallback_chat_response(player_message)
    
    def _get_fallback_chat_response(self, player_message: str) -> str:
        """后备聊天响应"""
        message_lower = player_message.lower()
        
        if "建" in player_message or "造" in player_message:
            return "好的，我会制定一个详细的建设计划。"
        elif "帮" in player_message or "助" in player_message:
            return "我是建造师艾德，随时为您的建设需求服务！"
        elif "状况" in player_message or "情况" in player_message:
            return "目前基地建设进展良好，有什么特殊需求请告诉我。"
        else:
            return "我明白，让我分析一下最佳的建设方案。"

# 创建AI服务实例
ai_service = AIService()

@app.route('/ping', methods=['GET', 'POST'])
def ping():
    """健康检查接口"""
    return jsonify({
        "status": "ok",
        "message": "AI建设助手服务运行正常",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/decision', methods=['POST'])
def get_decision():
    """获取AI决策"""
    try:
        data = request.get_json()
        context_data = data.get('context', {})
        
        # 构建游戏上下文
        context = GameContext(
            health=context_data.get('health', 100),
            hunger=context_data.get('hunger', 100),
            sanity=context_data.get('sanity', 100),
            day=context_data.get('day', 1),
            season=context_data.get('season', 'autumn'),
            time_phase=context_data.get('time_phase', 'day'),
            is_night=context_data.get('is_night', False),
            is_dusk=context_data.get('is_dusk', False),
            inventory_full=context_data.get('inventory_full', False),
            wood_count=context_data.get('wood_count', 0),
            stone_count=context_data.get('stone_count', 0),
            food_count=context_data.get('food_count', 0),
            has_campfire=context_data.get('has_campfire', False),
            has_chest=context_data.get('has_chest', False),
            base_center=context_data.get('base_center'),
            planning_progress=context_data.get('planning_progress'),
            total_planned=context_data.get('total_planned'),
            resource_needs=context_data.get('resource_needs'),
            collection_targets=context_data.get('collection_targets')
        )
        
        # 获取AI决策
        decision = ai_service.get_deepseek_decision(context)
        
        return jsonify(asdict(decision))
        
    except Exception as e:
        logger.error(f"决策请求处理失败: {e}")
        return jsonify({
            "action": "idle",
            "reasoning": "服务器处理错误",
            "priority": 0.1,
            "message": "遇到了一些技术问题，稍后再试。",
            "source": "error"
        }), 500

@app.route('/chat', methods=['POST'])
def chat():
    """聊天接口"""
    try:
        data = request.get_json()
        player_message = data.get('player_message', '')
        context_data = data.get('context', {})
        
        # 构建游戏上下文
        context = GameContext(
            health=context_data.get('health', 100),
            hunger=context_data.get('hunger', 100),
            sanity=context_data.get('sanity', 100),
            day=context_data.get('day', 1),
            season=context_data.get('season', 'autumn'),
            time_phase=context_data.get('time_phase', 'day'),
            is_night=context_data.get('is_night', False),
            is_dusk=context_data.get('is_dusk', False),
            inventory_full=context_data.get('inventory_full', False),
            wood_count=context_data.get('wood_count', 0),
            stone_count=context_data.get('stone_count', 0),
            food_count=context_data.get('food_count', 0),
            has_campfire=context_data.get('has_campfire', False),
            has_chest=context_data.get('has_chest', False),
            base_center=context_data.get('base_center')
        )
        
        # 获取聊天响应
        response_message = ai_service.get_chat_response(player_message, context)
        
        return jsonify({
            "message": response_message,
            "tone": "professional"
        })
        
    except Exception as e:
        logger.error(f"聊天请求处理失败: {e}")
        return jsonify({
            "message": "抱歉，我现在有点忙，稍后再聊。",
            "tone": "apologetic"
        }), 500

@app.route('/status', methods=['GET'])
def get_status():
    """获取服务状态"""
    return jsonify({
        "service": "AI Builder Assistant",
        "status": "running",
        "api_available": DEEPSEEK_API_KEY != "your_api_key_here",
        "timestamp": datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("启动AI建设助手服务...")
    print(f"DeepSeek API Key: {'已配置' if DEEPSEEK_API_KEY != 'your_api_key_here' else '未配置'}")
    print("访问 http://localhost:8000/ping 检查服务状态")
    
    app.run(host='0.0.0.0', port=8000, debug=True)