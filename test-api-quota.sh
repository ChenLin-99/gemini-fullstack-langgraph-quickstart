#!/bin/bash

# API配额测试脚本
echo "🔍 测试Gemini API配额状态..."

# 测试简单API调用
echo "📊 测试1: 简单API调用 (不带搜索)"
curl -s --proxy http://127.0.0.1:7890 \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello, just say hi back briefly."}]}]}' \
  | jq '.error // {success: "OK", response: .candidates[0].content.parts[0].text[:50]}'

echo -e "\n📊 测试2: 带搜索的API调用"
curl -s --proxy http://127.0.0.1:7890 \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"What is the weather today?"}]}], "tools": [{"google_search": {}}]}' \
  | jq '.error // {success: "OK", has_grounding: (.candidates[0].grounding_metadata != null)}'

echo -e "\n⏱️  等待30秒后再次测试..."
sleep 30

echo "📊 测试3: 30秒后重试简单调用"
curl -s --proxy http://127.0.0.1:7890 \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"What is 1+1?"}]}]}' \
  | jq '.error // {success: "OK", answer: .candidates[0].content.parts[0].text[:100]}'

echo -e "\n📋 配额状态总结:"
echo "- 如果看到429错误: 配额已耗尽，需要等待重置"
echo "- 如果看到success: OK: API可正常使用"
echo "- 免费层限制: 15 RPM, 1500 RPD"
echo "- Google搜索限制: 500次/日" 