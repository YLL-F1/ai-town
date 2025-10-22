#!/usr/bin/env python3
"""
AI建设助手服务测试脚本
用于测试AI服务的各个功能接口
"""

import requests
import json
import time

# 服务地址
BASE_URL = "http://localhost:8000"

def test_ping():
    """测试服务健康检查"""
    print("🔍 测试服务连接...")
    try:
        response = requests.get(f"{BASE_URL}/ping")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 服务正常: {data['message']}")
            return True
        else:
            print(f"❌ 服务异常: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        return False

def test_decision():
    """测试AI决策接口"""
    print("\n🤖 测试AI决策...")
    
    # 模拟游戏状态
    test_context = {
        "health": 75.0,
        "hunger": 60.0,
        "sanity": 85.0,
        "day": 5,
        "season": "autumn",
        "time_phase": "day",
        "is_night": False,
        "is_dusk": False,
        "inventory_full": False,
        "wood_count": 8,
        "stone_count": 3,
        "food_count": 5,
        "has_campfire": True,
        "has_chest": False,
        "base_center": {"x": 100, "z": 200}
    }
    
    try:
        response = requests.post(f"{BASE_URL}/decision", 
                               json={"context": test_context},
                               headers={"Content-Type": "application/json"})
        
        if response.status_code == 200:
            decision = response.json()
            print(f"✅ 决策成功:")
            print(f"   行动: {decision['action']}")
            print(f"   理由: {decision['reasoning']}")
            print(f"   优先级: {decision['priority']}")
            print(f"   消息: {decision['message']}")
            print(f"   来源: {decision['source']}")
            return True
        else:
            print(f"❌ 决策失败: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ 请求失败: {e}")
        return False

def test_chat():
    """测试聊天接口"""
    print("\n💬 测试聊天功能...")
    
    test_messages = [
        "你好，建造师艾德！",
        "我们需要建设什么？",
        "当前基地状况如何？",
        "有什么建设建议吗？"
    ]
    
    test_context = {
        "health": 80.0,
        "hunger": 70.0,
        "sanity": 90.0,
        "day": 10,
        "season": "winter",
        "time_phase": "dusk",
        "has_campfire": True,
        "has_chest": True
    }
    
    for message in test_messages:
        try:
            response = requests.post(f"{BASE_URL}/chat",
                                   json={
                                       "player_message": message,
                                       "context": test_context
                                   },
                                   headers={"Content-Type": "application/json"})
            
            if response.status_code == 200:
                chat_response = response.json()
                print(f"👤 玩家: {message}")
                print(f"🤖 艾德: {chat_response['message']}")
                print()
                time.sleep(1)  # 避免请求过快
            else:
                print(f"❌ 聊天失败: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ 聊天请求失败: {e}")
            return False
    
    return True

def test_status():
    """测试状态接口"""
    print("\n📊 测试服务状态...")
    try:
        response = requests.get(f"{BASE_URL}/status")
        if response.status_code == 200:
            status = response.json()
            print(f"✅ 服务状态:")
            print(f"   服务: {status['service']}")
            print(f"   状态: {status['status']}")
            print(f"   API可用: {status['api_available']}")
            print(f"   时间: {status['timestamp']}")
            return True
        else:
            print(f"❌ 状态查询失败: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ 状态请求失败: {e}")
        return False

def run_all_tests():
    """运行所有测试"""
    print("🚀 开始AI建设助手服务测试")
    print("=" * 50)
    
    tests = [
        ("服务连接", test_ping),
        ("AI决策", test_decision),
        ("聊天功能", test_chat),
        ("服务状态", test_status)
    ]
    
    results = []
    for test_name, test_func in tests:
        result = test_func()
        results.append((test_name, result))
    
    print("\n" + "=" * 50)
    print("📋 测试结果总结:")
    
    all_passed = True
    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"   {test_name}: {status}")
        if not result:
            all_passed = False
    
    print("\n" + "=" * 50)
    if all_passed:
        print("🎉 所有测试通过！AI建设助手服务运行正常。")
    else:
        print("⚠️  部分测试失败，请检查服务配置。")
    
    return all_passed

if __name__ == "__main__":
    run_all_tests()