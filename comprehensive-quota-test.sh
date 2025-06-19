#!/bin/bash

# 全面的Gemini API配额测试脚本
API_KEY="AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc"
PROXY="http://127.0.0.1:7890"
LOG_FILE="quota_test_$(date +%Y%m%d_%H%M%S).log"
TEST_DURATION=300  # 5分钟 = 300秒

echo "🔬 全面Gemini API配额限制测试" | tee $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE
echo "⏰ 开始时间: $(date)" | tee -a $LOG_FILE
echo "🔑 API密钥: ${API_KEY:0:20}..." | tee -a $LOG_FILE
echo "⏱️  测试时长: ${TEST_DURATION}秒 (5分钟)" | tee -a $LOG_FILE
echo "📄 日志文件: $LOG_FILE" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE

# 测试计数器
rpm_count=0
search_count=0
token_count=0
error_count=0
success_count=0
start_time=$(date +%s)

# 记录测试开始
echo "" | tee -a $LOG_FILE
echo "📊 根据官方文档，Gemini 2.0 Flash免费层限制:" | tee -a $LOG_FILE
echo "   - RPM (每分钟请求): 15" | tee -a $LOG_FILE
echo "   - TPM (每分钟Token): 1,000,000" | tee -a $LOG_FILE
echo "   - RPD (每日请求): 1,500" | tee -a $LOG_FILE
echo "   - 搜索请求: 500/日" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

function test_basic_api() {
    local test_content="$1"
    local test_type="$2"
    
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$test_content\"}]}]}" \
        --connect-timeout 10 \
        --max-time 30)
    
    current_time=$(date "+%H:%M:%S")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"')
        error_message=$(echo "$response" | jq -r '.error.message // "unknown"')
        echo "[$current_time] ❌ $test_type - 错误: $error_code - $error_message" | tee -a $LOG_FILE
        ((error_count++))
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        # 提取token使用信息
        prompt_tokens=$(echo "$response" | jq -r '.usageMetadata.promptTokenCount // 0')
        output_tokens=$(echo "$response" | jq -r '.usageMetadata.candidatesTokenCount // 0')
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0')
        
        echo "[$current_time] ✅ $test_type - 成功 (输入:${prompt_tokens}T 输出:${output_tokens}T 总计:${total_tokens}T)" | tee -a $LOG_FILE
        ((success_count++))
        ((token_count+=total_tokens))
        return 0
    else
        echo "[$current_time] ⚠️  $test_type - 响应异常" | tee -a $LOG_FILE
        return 1
    fi
}

function test_search_api() {
    local search_query="$1"
    
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$search_query\"}]}], \"tools\": [{\"google_search\": {}}]}" \
        --connect-timeout 15 \
        --max-time 45)
    
    current_time=$(date "+%H:%M:%S")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"')
        error_message=$(echo "$response" | jq -r '.error.message // "unknown"')
        echo "[$current_time] 🔍❌ 搜索测试 - 错误: $error_code - $error_message" | tee -a $LOG_FILE
        ((error_count++))
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        has_grounding=$(echo "$response" | jq -r '.candidates[0].grounding_metadata != null')
        grounding_count=0
        if [[ "$has_grounding" == "true" ]]; then
            grounding_count=$(echo "$response" | jq -r '.candidates[0].grounding_metadata.grounding_chunks | length // 0')
        fi
        
        prompt_tokens=$(echo "$response" | jq -r '.usageMetadata.promptTokenCount // 0')
        output_tokens=$(echo "$response" | jq -r '.usageMetadata.candidatesTokenCount // 0')
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0')
        
        echo "[$current_time] 🔍✅ 搜索测试 - 成功 (引用:${grounding_count} Token:${total_tokens})" | tee -a $LOG_FILE
        ((success_count++))
        ((search_count++))
        ((token_count+=total_tokens))
        return 0
    else
        echo "[$current_time] 🔍⚠️  搜索测试 - 响应异常" | tee -a $LOG_FILE
        return 1
    fi
}

function test_rpm_limit() {
    echo "" | tee -a $LOG_FILE
    echo "🚀 测试RPM限制 (目标: 快速发送20个请求)" | tee -a $LOG_FILE
    
    for i in {1..20}; do
        test_basic_api "Test RPM request #$i" "RPM测试#$i"
        ((rpm_count++))
        sleep 0.1  # 很短的间隔
    done
}

function test_token_limit() {
    echo "" | tee -a $LOG_FILE
    echo "📊 测试Token限制 (发送大量Token的请求)" | tee -a $LOG_FILE
    
    # 生成较长的文本以测试token限制
    long_text="Explain in detail about artificial intelligence, machine learning, deep learning, neural networks, natural language processing, computer vision, and their applications in modern technology. Please provide comprehensive information about each topic."
    
    for i in {1..5}; do
        test_basic_api "$long_text Request #$i with many tokens to test the token per minute limit." "Token测试#$i"
        sleep 2
    done
}

function test_search_limit() {
    echo "" | tee -a $LOG_FILE
    echo "🔍 测试搜索功能限制" | tee -a $LOG_FILE
    
    search_queries=(
        "What is the weather today in Beijing?"
        "Latest news about artificial intelligence 2025"
        "Best programming languages to learn"
        "Current cryptocurrency prices Bitcoin"
        "How to cook traditional Chinese food"
    )
    
    for i in "${!search_queries[@]}"; do
        test_search_api "${search_queries[$i]}"
        sleep 3  # 搜索请求间隔更长
    done
}

function print_status() {
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    minute_elapsed=$((elapsed / 60))
    
    echo "" | tee -a $LOG_FILE
    echo "📈 当前状态 (运行${elapsed}秒):" | tee -a $LOG_FILE
    echo "   - 总请求数: $((rpm_count + search_count))" | tee -a $LOG_FILE
    echo "   - 成功请求: $success_count" | tee -a $LOG_FILE
    echo "   - 失败请求: $error_count" | tee -a $LOG_FILE
    echo "   - 基础请求: $rpm_count" | tee -a $LOG_FILE
    echo "   - 搜索请求: $search_count" | tee -a $LOG_FILE
    echo "   - 消耗Token: $token_count" | tee -a $LOG_FILE
    echo "   - 平均RPM: $(( (rpm_count + search_count) * 60 / (elapsed + 1) ))" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# 主测试循环
echo "🎯 开始系统性测试..." | tee -a $LOG_FILE

# 第1分钟: 测试RPM限制
echo "📍 第1分钟: 测试RPM限制" | tee -a $LOG_FILE
test_rpm_limit
print_status

# 等待到第2分钟
while [ $(($(date +%s) - start_time)) -lt 60 ]; do
    sleep 5
done

# 第2分钟: 测试Token限制
echo "📍 第2分钟: 测试Token限制" | tee -a $LOG_FILE
test_token_limit
print_status

# 等待到第3分钟
while [ $(($(date +%s) - start_time)) -lt 120 ]; do
    sleep 5
done

# 第3分钟: 测试搜索限制
echo "📍 第3分钟: 测试搜索功能" | tee -a $LOG_FILE
test_search_limit
print_status

# 第4-5分钟: 持续监控
echo "📍 第4-5分钟: 持续监控和恢复测试" | tee -a $LOG_FILE
while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
    current_minute=$(( ($(date +%s) - start_time) / 60 + 1))
    test_basic_api "Continuous monitoring test at minute $current_minute" "持续监控#$((rpm_count++))"
    
    # 每30秒打印一次状态
    if [ $(($(date +%s) - start_time)) -gt 0 ] && [ $(( ($(date +%s) - start_time) % 30 )) -eq 0 ]; then
        print_status
    fi
    
    sleep 10
done

# 最终总结
echo "" | tee -a $LOG_FILE
echo "🎉 测试完成! 最终统计:" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE
echo "⏰ 结束时间: $(date)" | tee -a $LOG_FILE
echo "⏱️  总运行时间: $(($(date +%s) - start_time))秒" | tee -a $LOG_FILE
echo "📊 总请求数: $((rpm_count + search_count))" | tee -a $LOG_FILE
echo "   - 基础API请求: $rpm_count" | tee -a $LOG_FILE
echo "   - 搜索API请求: $search_count" | tee -a $LOG_FILE
echo "✅ 成功请求: $success_count" | tee -a $LOG_FILE
echo "❌ 失败请求: $error_count" | tee -a $LOG_FILE
echo "📈 成功率: $(( success_count * 100 / (success_count + error_count) ))%" | tee -a $LOG_FILE
echo "🔢 总Token使用: $token_count" | tee -a $LOG_FILE
echo "⚡ 平均RPM: $(( (rpm_count + search_count) * 60 / ($(date +%s) - start_time) ))" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE
echo "📄 详细日志保存在: $LOG_FILE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "🔍 下一步: 请检查日志文件了解详细测试结果" | tee -a $LOG_FILE 