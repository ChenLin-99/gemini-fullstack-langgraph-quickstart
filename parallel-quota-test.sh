#!/bin/bash

# 并行实时Gemini API配额测试脚本
API_KEY="AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc"
PROXY="http://127.0.0.1:7890"
TEST_DURATION=300  # 5分钟
LOG_FILE="parallel_quota_test_$(date +%Y%m%d_%H%M%S).log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局计数器
declare -A counters
counters[basic_success]=0
counters[basic_error]=0
counters[search_success]=0
counters[search_error]=0
counters[token_success]=0
counters[token_error]=0
counters[total_tokens]=0
counters[total_grounding]=0

start_time=$(date +%s)

echo -e "${CYAN}🔬 并行实时Gemini API配额测试${NC}"
echo "=========================================="
echo "⏰ 开始时间: $(date)"
echo "🔑 API密钥: ${API_KEY:0:20}..."
echo "⏱️  测试时长: ${TEST_DURATION}秒 (5分钟)"
echo "📄 日志文件: $LOG_FILE"
echo ""
echo -e "${BLUE}📊 官方限制 (Gemini 2.0 Flash免费层):${NC}"
echo "   - RPM: 15请求/分钟"
echo "   - TPM: 1,000,000 Token/分钟"
echo "   - RPD: 1,500请求/日"
echo "   - 搜索: 500次/日"
echo "=========================================="
echo ""

# 记录日志
{
    echo "🔬 并行实时Gemini API配额测试"
    echo "开始时间: $(date)"
    echo "API密钥: ${API_KEY:0:20}..."
    echo "测试时长: ${TEST_DURATION}秒"
    echo ""
} > $LOG_FILE

function log_result() {
    echo "$1" | tee -a $LOG_FILE
}

function test_basic_api() {
    local test_id="$1"
    local test_content="Simple test request #$test_id"
    
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$test_content\"}]}]}" \
        --connect-timeout 10 \
        --max-time 30 2>/dev/null)
    
    current_time=$(date "+%H:%M:%S")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        echo -e "[$current_time] ${RED}❌ 基础#$test_id - 错误: $error_code${NC}"
        log_result "[$current_time] ❌ 基础#$test_id - 错误: $error_code"
        ((counters[basic_error]++))
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        echo -e "[$current_time] ${GREEN}✅ 基础#$test_id - 成功 (${total_tokens}T)${NC}"
        log_result "[$current_time] ✅ 基础#$test_id - 成功 (${total_tokens}T)"
        ((counters[basic_success]++))
        ((counters[total_tokens]+=total_tokens))
        return 0
    else
        echo -e "[$current_time] ${YELLOW}⚠️  基础#$test_id - 响应异常${NC}"
        log_result "[$current_time] ⚠️  基础#$test_id - 响应异常"
        return 1
    fi
}

function test_search_api() {
    local test_id="$1"
    local queries=("What is AI?" "Weather today?" "Latest tech news?" "Programming tips?" "Cooking recipes?")
    local query="${queries[$((test_id % 5))]}"
    
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$query\"}]}], \"tools\": [{\"google_search\": {}}]}" \
        --connect-timeout 15 \
        --max-time 45 2>/dev/null)
    
    current_time=$(date "+%H:%M:%S")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        echo -e "[$current_time] ${RED}🔍❌ 搜索#$test_id - 错误: $error_code${NC}"
        log_result "[$current_time] 🔍❌ 搜索#$test_id - 错误: $error_code"
        ((counters[search_error]++))
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        grounding_count=0
        if echo "$response" | jq -e '.candidates[0].grounding_metadata.grounding_chunks' >/dev/null 2>&1; then
            grounding_count=$(echo "$response" | jq -r '.candidates[0].grounding_metadata.grounding_chunks | length // 0' 2>/dev/null)
        fi
        echo -e "[$current_time] ${GREEN}🔍✅ 搜索#$test_id - 成功 (${total_tokens}T, ${grounding_count}引用)${NC}"
        log_result "[$current_time] 🔍✅ 搜索#$test_id - 成功 (${total_tokens}T, ${grounding_count}引用)"
        ((counters[search_success]++))
        ((counters[total_tokens]+=total_tokens))
        ((counters[total_grounding]+=grounding_count))
        return 0
    else
        echo -e "[$current_time] ${YELLOW}🔍⚠️  搜索#$test_id - 响应异常${NC}"
        log_result "[$current_time] 🔍⚠️  搜索#$test_id - 响应异常"
        return 1
    fi
}

function test_token_heavy() {
    local test_id="$1"
    local heavy_content="Please provide a detailed explanation about artificial intelligence, machine learning, deep learning, neural networks, natural language processing, computer vision, robotics, and their applications in modern technology. Include examples and future prospects. Request #$test_id"
    
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$heavy_content\"}]}]}" \
        --connect-timeout 15 \
        --max-time 60 2>/dev/null)
    
    current_time=$(date "+%H:%M:%S")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        echo -e "[$current_time] ${RED}📊❌ Token#$test_id - 错误: $error_code${NC}"
        log_result "[$current_time] 📊❌ Token#$test_id - 错误: $error_code"
        ((counters[token_error]++))
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        prompt_tokens=$(echo "$response" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
        output_tokens=$(echo "$response" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        echo -e "[$current_time] ${GREEN}📊✅ Token#$test_id - 成功 (输入:${prompt_tokens}T 输出:${output_tokens}T 总:${total_tokens}T)${NC}"
        log_result "[$current_time] 📊✅ Token#$test_id - 成功 (输入:${prompt_tokens}T 输出:${output_tokens}T 总:${total_tokens}T)"
        ((counters[token_success]++))
        ((counters[total_tokens]+=total_tokens))
        return 0
    else
        echo -e "[$current_time] ${YELLOW}📊⚠️  Token#$test_id - 响应异常${NC}"
        log_result "[$current_time] 📊⚠️  Token#$test_id - 响应异常"
        return 1
    fi
}

function print_status() {
    local elapsed=$(($(date +%s) - start_time))
    local minute=$((elapsed / 60 + 1))
    local total_requests=$((counters[basic_success] + counters[basic_error] + counters[search_success] + counters[search_error] + counters[token_success] + counters[token_error]))
    local total_success=$((counters[basic_success] + counters[search_success] + counters[token_success]))
    local total_errors=$((counters[basic_error] + counters[search_error] + counters[token_error]))
    local avg_rpm=$(( total_requests * 60 / (elapsed + 1) ))
    
    echo ""
    echo -e "${PURPLE}📈 实时状态 (第${minute}分钟, 运行${elapsed}秒):${NC}"
    echo -e "   ${CYAN}总请求: $total_requests | 成功: $total_success | 失败: $total_errors${NC}"
    echo -e "   ${CYAN}基础API: ✅${counters[basic_success]} ❌${counters[basic_error]} | 搜索: ✅${counters[search_success]} ❌${counters[search_error]} | Token: ✅${counters[token_success]} ❌${counters[token_error]}${NC}"
    echo -e "   ${CYAN}Token消耗: ${counters[total_tokens]} | 搜索引用: ${counters[total_grounding]} | 平均RPM: $avg_rpm${NC}"
    echo ""
    
    # 记录到日志
    {
        echo "📈 状态 (第${minute}分钟):"
        echo "   总请求: $total_requests | 成功: $total_success | 失败: $total_errors"
        echo "   基础: ✅${counters[basic_success]} ❌${counters[basic_error]} | 搜索: ✅${counters[search_success]} ❌${counters[search_error]} | Token: ✅${counters[token_success]} ❌${counters[token_error]}"
        echo "   Token: ${counters[total_tokens]} | 引用: ${counters[total_grounding]} | RPM: $avg_rpm"
        echo ""
    } >> $LOG_FILE
}

# 并行测试函数
function run_parallel_tests() {
    local test_round=$1
    local base_id=$((test_round * 10))
    
    # 并行启动不同类型的测试
    test_basic_api $((base_id + 1)) &
    test_basic_api $((base_id + 2)) &
    test_search_api $((base_id + 3)) &
    test_token_heavy $((base_id + 4)) &
    test_basic_api $((base_id + 5)) &
    
    # 等待所有并行测试完成
    wait
}

echo -e "${YELLOW}🚀 开始并行实时测试...${NC}"
echo ""

test_round=0
# 主测试循环 - 5分钟持续测试
while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
    current_minute=$(( ($(date +%s) - start_time) / 60 + 1))
    
    echo -e "${BLUE}🔄 第${current_minute}分钟 - 第$((test_round + 1))轮并行测试${NC}"
    
    # 并行运行多种测试
    run_parallel_tests $test_round
    
    # 每轮测试后显示状态
    print_status
    
    ((test_round++))
    
    # 短暂休息避免过度频繁请求
    sleep 3
done

# 最终总结
elapsed_total=$(($(date +%s) - start_time))
total_requests=$((counters[basic_success] + counters[basic_error] + counters[search_success] + counters[search_error] + counters[token_success] + counters[token_error]))
total_success=$((counters[basic_success] + counters[search_success] + counters[token_success]))
total_errors=$((counters[basic_error] + counters[search_error] + counters[token_error]))
success_rate=$(( total_success * 100 / (total_success + total_errors) ))
final_rpm=$(( total_requests * 60 / elapsed_total ))

echo ""
echo -e "${GREEN}🎉 测试完成! 最终统计:${NC}"
echo "=========================================="
echo "⏰ 结束时间: $(date)"
echo "⏱️  总运行时间: ${elapsed_total}秒"
echo ""
echo -e "${CYAN}📊 请求统计:${NC}"
echo "   总请求数: $total_requests"
echo "   成功请求: $total_success"
echo "   失败请求: $total_errors"
echo "   成功率: ${success_rate}%"
echo ""
echo -e "${CYAN}📈 分类统计:${NC}"
echo "   基础API: ✅${counters[basic_success]} ❌${counters[basic_error]}"
echo "   搜索API: ✅${counters[search_success]} ❌${counters[search_error]}"
echo "   Token测试: ✅${counters[token_success]} ❌${counters[token_error]}"
echo ""
echo -e "${CYAN}🔢 资源使用:${NC}"
echo "   总Token消耗: ${counters[total_tokens]}"
echo "   搜索引用总数: ${counters[total_grounding]}"
echo "   平均RPM: $final_rpm"
echo "   平均TPM: $(( counters[total_tokens] * 60 / elapsed_total ))"
echo ""
echo "=========================================="
echo "📄 详细日志: $LOG_FILE"

# 最终总结写入日志
{
    echo ""
    echo "🎉 测试完成! 最终统计:"
    echo "结束时间: $(date)"
    echo "总运行时间: ${elapsed_total}秒"
    echo "总请求: $total_requests | 成功: $total_success | 失败: $total_errors | 成功率: ${success_rate}%"
    echo "基础API: ✅${counters[basic_success]} ❌${counters[basic_error]}"
    echo "搜索API: ✅${counters[search_success]} ❌${counters[search_error]}"
    echo "Token测试: ✅${counters[token_success]} ❌${counters[token_error]}"
    echo "总Token: ${counters[total_tokens]} | 搜索引用: ${counters[total_grounding]}"
    echo "平均RPM: $final_rpm | 平均TPM: $(( counters[total_tokens] * 60 / elapsed_total ))"
} >> $LOG_FILE 