#!/bin/bash

# 配额监控脚本
API_KEY="AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc"
PROXY="http://127.0.0.1:7890"

echo "🔄 开始监控Gemini API配额恢复状态..."
echo "⏰ 开始时间: $(date)"
echo "================================"

count=0
while true; do
    count=$((count + 1))
    current_time=$(date "+%H:%M:%S")
    
    # 测试简单API调用
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"contents":[{"parts":[{"text":"Hi"}]}]}' \
        --connect-timeout 10)
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"')
        error_message=$(echo "$response" | jq -r '.error.message // "unknown"')
        echo "[$current_time] ❌ 测试#$count - 错误: $error_code - $error_message"
        
        if [[ "$error_code" == "429" ]]; then
            echo "           配额仍未恢复，继续等待..."
        fi
    else
        if echo "$response" | grep -q '"candidates"'; then
            echo "[$current_time] ✅ 测试#$count - API已恢复！配额可用"
            
            # 测试agent是否也能工作
            echo "           🤖 测试agent功能..."
            agent_response=$(timeout 30 curl -s -X POST "http://localhost:50300/runs/wait" \
                -H "Content-Type: application/json" \
                -d '{"assistant_id": "agent", "input": {"messages": [{"role": "user", "content": "What is 1+1?"}]}, "config": {"max_research_loops": 0}, "metadata": {}, "multitask_strategy": "reject"}' \
                2>/dev/null)
            
            if echo "$agent_response" | grep -q '"messages"' && ! echo "$agent_response" | grep -q '"error"'; then
                echo "           ✅ Agent也已恢复正常！"
                echo "================================"
                echo "🎉 系统完全恢复！时间: $(date)"
                echo "📱 前端访问: http://localhost:50302/app/"
                echo "🔧 后端API: http://localhost:50300/"
                break
            else
                echo "           ⚠️  Agent仍有问题，但基础API已恢复"
            fi
        else
            echo "[$current_time] ⚠️  测试#$count - 响应异常: $(echo "$response" | head -c 100)"
        fi
    fi
    
    # 等待60秒再次测试
    sleep 60
done 