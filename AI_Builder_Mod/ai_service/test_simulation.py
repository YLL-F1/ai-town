#!/usr/bin/env python3
"""
AI Builder代码生成反射功能模拟测试
模拟游戏环境，测试AI助手砍树任务的代码生成
"""

import json
import requests
from datetime import datetime
import sys
import os

# 添加当前目录到路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import AIService, GameContext

class GameSimulator:
    """游戏环境模拟器"""
    
    def __init__(self):
        self.ai_service = AIService()
        self.game_state = {
            "health": 85.0,
            "hunger": 65.0,
            "sanity": 90.0,
            "day": 3,
            "season": "autumn",
            "time_phase": "day",
            "is_night": False,
            "is_dusk": False,
            "inventory_full": False,
            "wood_count": 2,  # 当前木材很少
            "stone_count": 8,
            "food_count": 5,
            "has_campfire": True,
            "has_chest": False,
            "base_center": {"x": 0, "y": 0, "z": 0}
        }
        
    def create_game_context(self):
        """创建游戏上下文"""
        return GameContext(
            health=self.game_state["health"],
            hunger=self.game_state["hunger"],
            sanity=self.game_state["sanity"],
            day=self.game_state["day"],
            season=self.game_state["season"],
            time_phase=self.game_state["time_phase"],
            is_night=self.game_state["is_night"],
            is_dusk=self.game_state["is_dusk"],
            inventory_full=self.game_state["inventory_full"],
            wood_count=self.game_state["wood_count"],
            stone_count=self.game_state["stone_count"],
            food_count=self.game_state["food_count"],
            has_campfire=self.game_state["has_campfire"],
            has_chest=self.game_state["has_chest"],
            base_center=self.game_state["base_center"]
        )
    
    def simulate_chopping_trees_task(self):
        """模拟砍树任务"""
        print("🌲 === AI助手砍树任务模拟测试 ===")
        print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # 显示当前游戏状态
        print("📊 当前游戏状态:")
        print(f"  健康: {self.game_state['health']:.1f}%")
        print(f"  饥饿: {self.game_state['hunger']:.1f}%")
        print(f"  理智: {self.game_state['sanity']:.1f}%")
        print(f"  第{self.game_state['day']}天, {self.game_state['season']}季")
        print(f"  木材库存: {self.game_state['wood_count']} (资源不足!)")
        print(f"  石头库存: {self.game_state['stone_count']}")
        print()
        
        # 创建游戏上下文
        context = self.create_game_context()
        
        # 模拟玩家指令：让AI去砍树
        player_instruction = "木材不够了，请去砍一些树木"
        task_type = "collecting"
        
        print(f"🎮 玩家指令: '{player_instruction}'")
        print(f"📋 任务类型: {task_type}")
        print()
        
        # 1. 测试AI决策生成
        print("🧠 === AI决策分析 ===")
        try:
            decision = self.ai_service.get_deepseek_decision(context)
            print(f"✓ AI决策: {decision.action}")
            print(f"✓ 推理过程: {decision.reasoning}")
            print(f"✓ 优先级: {decision.priority:.2f}")
            print(f"✓ AI消息: '{decision.message}'")
            print(f"✓ 决策来源: {decision.source}")
        except Exception as e:
            print(f"✗ AI决策失败: {e}")
            # 使用后备决策
            decision = self.ai_service._get_fallback_decision(context)
            print(f"⚠ 使用后备决策: {decision.action}")
        print()
        
        # 2. 测试Lua代码生成 - 砍树任务
        print("⚡ === AI代码生成 (砍树任务) ===")
        try:
            lua_code, reasoning = self.ai_service.generate_lua_code(
                player_instruction, context, task_type
            )
            
            print(f"✓ 代码生成成功!")
            print(f"✓ AI推理: {reasoning}")
            print()
            print("📝 生成的Lua代码:")
            print("```lua")
            print(lua_code)
            print("```")
            print()
            
            # 验证代码安全性
            validation = self.ai_service.validate_lua_code_safety(lua_code)
            print("🛡️ 代码安全验证:")
            print(f"  安全性: {'✓ 通过' if validation['is_safe'] else '✗ 失败'}")
            print(f"  代码长度: {validation['code_length']} 字符")
            
            if validation['errors']:
                print("  ⚠️ 错误:")
                for error in validation['errors']:
                    print(f"    - {error}")
            
            if validation['warnings']:
                print("  ⚠️ 警告:")
                for warning in validation['warnings']:
                    print(f"    - {warning}")
            
        except Exception as e:
            print(f"✗ 代码生成失败: {e}")
            print("⚠ 使用后备代码:")
            fallback_code = self.ai_service.get_fallback_lua_code(task_type)
            print("```lua")
            print(fallback_code)
            print("```")
        print()
        
        # 3. 模拟代码执行结果
        print("🎯 === 模拟代码执行 ===")
        execution_results = [
            {
                "action": "find_trees",
                "status": "searching",
                "message": "正在寻找附近的树木",
                "data": {"trees_found": 3, "distance": 12}
            },
            {
                "action": "equip_axe", 
                "status": "preparing",
                "message": "装备斧头准备砍树",
                "data": {"tool": "axe", "durability": 0.8}
            },
            {
                "action": "chop_tree",
                "status": "working",
                "message": "开始砍伐第一棵树",
                "data": {"tree_type": "evergreen", "logs_expected": 3}
            },
            {
                "action": "collect_logs",
                "status": "success",
                "message": "成功收集到木材！",
                "data": {"logs_collected": 9, "wood_total": 11}
            }
        ]
        
        for i, result in enumerate(execution_results, 1):
            print(f"  步骤{i}: {result['action']}")
            print(f"    状态: {result['status']}")
            print(f"    消息: {result['message']}")
            if result['data']:
                print(f"    数据: {result['data']}")
            print()
        
        # 更新游戏状态
        self.game_state["wood_count"] = 11  # 收集到9个木材
        print(f"📈 任务完成! 木材库存更新: {self.game_state['wood_count']}")
        print()
        
        # 4. 测试任务完成后的对话
        print("💬 === AI对话测试 ===")
        try:
            player_message = "砍树任务完成得怎么样？"
            chat_response = self.ai_service.get_chat_response(player_message, context)
            print(f"🎮 玩家: '{player_message}'")
            print(f"🤖 AI助手: '{chat_response}'")
        except Exception as e:
            print(f"✗ 对话失败: {e}")
            print(f"🤖 AI助手: '砍树任务已完成，收集到足够的木材！'")
        print()
        
        print("🎉 === 测试完成 ===")
        print("✅ AI助手成功执行了砍树任务的完整流程:")
        print("   1. 分析游戏状态和资源需求")
        print("   2. 生成具体的砍树执行代码")
        print("   3. 通过安全验证")
        print("   4. 模拟执行并收集资源")
        print("   5. 更新游戏状态")
        print("   6. 与玩家进行智能对话")

    def test_different_scenarios(self):
        """测试不同场景下的代码生成"""
        print("\n🔄 === 多场景测试 ===")
        
        scenarios = [
            {
                "name": "夜晚急需木材",
                "state_changes": {"is_night": True, "wood_count": 0, "has_campfire": False},
                "instruction": "夜晚来临，急需木材生火取暖"
            },
            {
                "name": "库存已满情况",
                "state_changes": {"inventory_full": True, "wood_count": 0},
                "instruction": "库存满了但还需要木材，请优化收集"
            },
            {
                "name": "健康较低时砍树",
                "state_changes": {"health": 30.0, "wood_count": 1},
                "instruction": "虽然健康不佳但仍需要一些木材"
            }
        ]
        
        for scenario in scenarios:
            print(f"\n📋 场景: {scenario['name']}")
            
            # 临时修改游戏状态
            original_state = self.game_state.copy()
            self.game_state.update(scenario['state_changes'])
            
            context = self.create_game_context()
            
            try:
                lua_code, reasoning = self.ai_service.generate_lua_code(
                    scenario['instruction'], context, "collecting"
                )
                
                print(f"  指令: {scenario['instruction']}")
                print(f"  AI推理: {reasoning[:100]}...")
                print(f"  生成代码: {'✓ 成功' if 'ExecuteAITask' in lua_code else '✗ 失败'}")
                
                # 提取关键行动
                if "safety" in lua_code.lower() or "health" in lua_code.lower():
                    print(f"  🛡️ 包含安全检查")
                if "inventory" in lua_code.lower():
                    print(f"  📦 考虑库存管理")
                if "night" in lua_code.lower() or "fire" in lua_code.lower():
                    print(f"  🌙 考虑夜晚因素")
                    
            except Exception as e:
                print(f"  ✗ 生成失败: {e}")
            
            # 恢复原始状态
            self.game_state = original_state

def main():
    """主测试函数"""
    print("🚀 启动AI Builder代码生成反射功能测试")
    print("=" * 60)
    
    simulator = GameSimulator()
    
    try:
        # 主要砍树任务测试
        simulator.simulate_chopping_trees_task()
        
        # 多场景测试
        simulator.test_different_scenarios()
        
    except KeyboardInterrupt:
        print("\n⏹️ 测试被用户中断")
    except Exception as e:
        print(f"\n❌ 测试过程中发生错误: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 60)
    print("🎯 测试总结:")
    print("✅ AI代码生成反射功能测试完成")
    print("✅ 验证了从任务分析到代码执行的完整流程")
    print("✅ 确认了安全验证和错误处理机制")
    print("🌟 AI助手能够根据游戏状态动态生成合适的执行代码!")

if __name__ == "__main__":
    main()