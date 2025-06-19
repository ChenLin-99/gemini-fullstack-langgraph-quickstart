#!/bin/bash

# 高压力Gemini API配额测试脚本 - 目标触发429错误
API_KEY="AIzaSyDGFwI5t28VYFDV5KcEudGQhoWTI9acUMc"
PROXY="http://127.0.0.1:7890"
TEST_DURATION=300  # 5分钟
LOG_FILE="high_pressure_test_$(date +%Y%m%d_%H%M%S).log"
COUNTER_FILE="/tmp/api_counters_$$"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

start_time=$(date +%s)

# 初始化计数器文件
cat > $COUNTER_FILE << EOF
basic_success=0
basic_error=0
search_success=0
search_error=0
token_success=0
token_error=0
total_tokens=0
total_grounding=0
EOF

echo -e "${RED}🔥 高压力Gemini API配额测试 - 目标触发429！${NC}"
echo "=========================================="
echo "⏰ 开始时间: $(date)"
echo "🔑 API密钥: ${API_KEY:0:20}..."
echo "⏱️  测试时长: ${TEST_DURATION}秒 (5分钟)"
echo "🎯 目标: 触发429 RESOURCE_EXHAUSTED错误"
echo "💥 高压力模式: 最小间隔，最大并发"
echo "📄 日志文件: $LOG_FILE"
echo ""
echo -e "${BLUE}📊 官方限制 (要突破的目标):${NC}"
echo "   - RPM: 15请求/分钟 (目标: >20请求/分钟)"
echo "   - TPM: 1,000,000 Token/分钟"
echo "   - 搜索: 500次/日"
echo "=========================================="
echo ""

# 记录日志
{
    echo "🔥 高压力Gemini API配额测试"
    echo "开始时间: $(date)"
    echo "API密钥: ${API_KEY:0:20}..."
    echo "目标: 触发429错误"
    echo ""
} > $LOG_FILE

# 原子化计数器操作
function increment_counter() {
    local counter_name="$1"
    local increment="${2:-1}"
    (
        flock -x 200
        source $COUNTER_FILE
        eval "${counter_name}=\$((\$${counter_name} + $increment))"
        cat > $COUNTER_FILE << EOF
basic_success=$basic_success
basic_error=$basic_error
search_success=$search_success
search_error=$search_error
token_success=$token_success
token_error=$token_error
total_tokens=$total_tokens
total_grounding=$total_grounding
EOF
    ) 200>$COUNTER_FILE.lock
}

function get_counters() {
    (
        flock -s 200
        source $COUNTER_FILE
        echo "$basic_success $basic_error $search_success $search_error $token_success $token_error $total_tokens $total_grounding"
    ) 200>$COUNTER_FILE.lock
}

function log_result() {
    echo "$1" | tee -a $LOG_FILE
}

function test_basic_api() {
    local test_id="$1"
    local test_content="High pressure test #$test_id $(date +%s%N)"
    
    local start_req=$(date +%s.%N)
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$test_content\"}]}]}" \
        --connect-timeout 5 \
        --max-time 15 2>/dev/null)
    local end_req=$(date +%s.%N)
    local duration=$(echo "$end_req - $start_req" | bc 2>/dev/null || echo "0")
    
    current_time=$(date "+%H:%M:%S.%3N")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        error_msg=$(echo "$response" | jq -r '.error.message // "unknown"' 2>/dev/null | head -c 50)
        echo -e "[$current_time] ${RED}❌ 基础#$test_id - 错误$error_code: $error_msg (${duration}s)${NC}"
        log_result "[$current_time] ❌ 基础#$test_id - 错误$error_code: $error_msg"
        increment_counter "basic_error"
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        echo -e "[$current_time] ${GREEN}✅ 基础#$test_id - 成功 (${total_tokens}T, ${duration}s)${NC}"
        log_result "[$current_time] ✅ 基础#$test_id - 成功 (${total_tokens}T, ${duration}s)"
        increment_counter "basic_success"
        increment_counter "total_tokens" "$total_tokens"
        return 0
    else
        echo -e "[$current_time] ${YELLOW}⚠️  基础#$test_id - 响应异常 (${duration}s)${NC}"
        log_result "[$current_time] ⚠️  基础#$test_id - 响应异常"
        return 1
    fi
}

function test_search_api() {
    local test_id="$1"
    local queries=("AI trends 2025?" "Weather update?" "Breaking news?" "Tech review?" "Quick facts?")
    local query="${queries[$((test_id % 5))]} #$test_id"
    
    local start_req=$(date +%s.%N)
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$query\"}]}], \"tools\": [{\"google_search\": {}}]}" \
        --connect-timeout 8 \
        --max-time 25 2>/dev/null)
    local end_req=$(date +%s.%N)
    local duration=$(echo "$end_req - $start_req" | bc 2>/dev/null || echo "0")
    
    current_time=$(date "+%H:%M:%S.%3N")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        error_msg=$(echo "$response" | jq -r '.error.message // "unknown"' 2>/dev/null | head -c 50)
        echo -e "[$current_time] ${RED}🔍❌ 搜索#$test_id - 错误$error_code: $error_msg (${duration}s)${NC}"
        log_result "[$current_time] 🔍❌ 搜索#$test_id - 错误$error_code: $error_msg"
        increment_counter "search_error"
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        grounding_count=0
        if echo "$response" | jq -e '.candidates[0].grounding_metadata.grounding_chunks' >/dev/null 2>&1; then
            grounding_count=$(echo "$response" | jq -r '.candidates[0].grounding_metadata.grounding_chunks | length // 0' 2>/dev/null)
        fi
        echo -e "[$current_time] ${GREEN}🔍✅ 搜索#$test_id - 成功 (${total_tokens}T, ${grounding_count}引用, ${duration}s)${NC}"
        log_result "[$current_time] 🔍✅ 搜索#$test_id - 成功 (${total_tokens}T, ${grounding_count}引用, ${duration}s)"
        increment_counter "search_success"
        increment_counter "total_tokens" "$total_tokens"
        increment_counter "total_grounding" "$grounding_count"
        return 0
    else
        echo -e "[$current_time] ${YELLOW}🔍⚠️  搜索#$test_id - 响应异常 (${duration}s)${NC}"
        log_result "[$current_time] 🔍⚠️  搜索#$test_id - 响应异常"
        return 1
    fi
}

function test_token_burst() {
    local test_id="$1"
    local burst_content="BURST TEST: Provide detailed technical analysis of AI, ML, DL, NLP, computer vision, robotics, autonomous systems, quantum computing, blockchain, IoT, cloud computing, edge computing, 5G networks, cybersecurity, data science, big data analytics, and emerging technology trends for 2025. Include market analysis, investment opportunities, technical challenges, and future predictions. Test #$test_id timestamp $(date +%s%N)"
    
    local start_req=$(date +%s.%N)
    response=$(curl -s --proxy $PROXY \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"$burst_content\"}]}]}" \
        --connect-timeout 10 \
        --max-time 30 2>/dev/null)
    local end_req=$(date +%s.%N)
    local duration=$(echo "$end_req - $start_req" | bc 2>/dev/null || echo "0")
    
    current_time=$(date "+%H:%M:%S.%3N")
    
    if echo "$response" | grep -q '"error"'; then
        error_code=$(echo "$response" | jq -r '.error.code // "unknown"' 2>/dev/null)
        error_msg=$(echo "$response" | jq -r '.error.message // "unknown"' 2>/dev/null | head -c 50)
        echo -e "[$current_time] ${RED}💥❌ 爆发#$test_id - 错误$error_code: $error_msg (${duration}s)${NC}"
        log_result "[$current_time] 💥❌ 爆发#$test_id - 错误$error_code: $error_msg"
        increment_counter "token_error"
        return 1
    elif echo "$response" | grep -q '"candidates"'; then
        prompt_tokens=$(echo "$response" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
        output_tokens=$(echo "$response" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)
        total_tokens=$(echo "$response" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null)
        echo -e "[$current_time] ${GREEN}💥✅ 爆发#$test_id - 成功 (${prompt_tokens}T→${output_tokens}T=${total_tokens}T, ${duration}s)${NC}"
        log_result "[$current_time] 💥✅ 爆发#$test_id - 成功 (${prompt_tokens}T→${output_tokens}T=${total_tokens}T, ${duration}s)"
        increment_counter "token_success"
        increment_counter "total_tokens" "$total_tokens"
        return 0
    else
        echo -e "[$current_time] ${YELLOW}💥⚠️  爆发#$test_id - 响应异常 (${duration}s)${NC}"
        log_result "[$current_time] 💥⚠️  爆发#$test_id - 响应异常"
        return 1
    fi
}

function print_status() {
    local elapsed=$(($(date +%s) - start_time))
    local minute=$((elapsed / 60 + 1))
    
    read basic_success basic_error search_success search_error token_success token_error total_tokens total_grounding <<< "$(get_counters)"
    
    local total_requests=$((basic_success + basic_error + search_success + search_error + token_success + token_error))
    local total_success=$((basic_success + search_success + token_success))
    local total_errors=$((basic_error + search_error + token_error))
    local success_rate=0
    if [ $((total_success + total_errors)) -gt 0 ]; then
        success_rate=$(( total_success * 100 / (total_success + total_errors) ))
    fi
    local current_rpm=$(( total_requests * 60 / (elapsed + 1) ))
    local current_tpm=$(( total_tokens * 60 / (elapsed + 1) ))
    
    echo ""
    echo -e "${PURPLE}🔥 高压状态 (第${minute}分钟, ${elapsed}s):${NC}"
    echo -e "   ${CYAN}总请求: ${YELLOW}$total_requests${CYAN} | 成功: ${GREEN}$total_success${CYAN} | 失败: ${RED}$total_errors${CYAN} | 成功率: ${success_rate}%${NC}"
    echo -e "   ${CYAN}基础: ✅$basic_success ❌$basic_error | 搜索: ✅$search_success ❌$search_error | 爆发: ✅$token_success ❌$token_error${NC}"
    echo -e "   ${CYAN}当前RPM: ${YELLOW}$current_rpm${CYAN} (目标>15) | TPM: ${YELLOW}$current_tpm${CYAN} | 引用: $total_grounding${NC}"
    
    # 429错误检测
    if [ $total_errors -gt 0 ]; then
        echo -e "   ${RED}🚨 检测到错误！可能已触发配额限制${NC}"
    fi
    
    echo ""
    
    # 记录到日志
    {
        echo "🔥 高压状态 (第${minute}分钟):"
        echo "   总请求: $total_requests | 成功: $total_success | 失败: $total_errors | 成功率: ${success_rate}%"
        echo "   基础: ✅$basic_success ❌$basic_error | 搜索: ✅$search_success ❌$search_error | 爆发: ✅$token_success ❌$token_error"
        echo "   RPM: $current_rpm | TPM: $current_tpm | 引用: $total_grounding"
        echo ""
    } >> $LOG_FILE
}

# 极限并行测试函数
function run_extreme_parallel_tests() {
    local test_round=$1
    local base_id=$((test_round * 20))
    
    # 🔥 极限并发: 每轮10个并行请求！
    echo -e "${RED}💥 第$((test_round + 1))轮极限并发 (10个并行请求)${NC}"
    
    # 基础API爆发 (6个)
    test_basic_api $((base_id + 1)) &
    test_basic_api $((base_id + 2)) &
    test_basic_api $((base_id + 3)) &
    test_basic_api $((base_id + 4)) &
    test_basic_api $((base_id + 5)) &
    test_basic_api $((base_id + 6)) &
    
    # 搜索API (2个)
    test_search_api $((base_id + 7)) &
    test_search_api $((base_id + 8)) &
    
    # Token爆发 (2个)
    test_token_burst $((base_id + 9)) &
    test_token_burst $((base_id + 10)) &
    
    # 等待所有并行测试完成
    wait
}

echo -e "${RED}🚀 开始极限高压测试！目标: 触发429错误${NC}"
echo ""

test_round=0
last_status_time=$start_time

# 极限测试循环 - 最小间隔，最大并发
while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
    current_time=$(date +%s)
    current_minute=$(( (current_time - start_time) / 60 + 1))
    
    # 极限并行测试
    run_extreme_parallel_tests $test_round
    
    # 每10秒显示一次状态（更频繁）
    if [ $((current_time - last_status_time)) -ge 10 ]; then
        print_status
        last_status_time=$current_time
    fi
    
    ((test_round++))
    
    # 🔥 几乎无间隔 - 只等0.5秒！
    sleep 0.5
done

# 最终统计
elapsed_total=$(($(date +%s) - start_time))
read basic_success basic_error search_success search_error token_success token_error total_tokens total_grounding <<< "$(get_counters)"
total_requests=$((basic_success + basic_error + search_success + search_error + token_success + token_error))
total_success=$((basic_success + search_success + token_success))
total_errors=$((basic_error + search_error + token_error))
success_rate=$(( total_success * 100 / (total_success + total_errors) ))
final_rpm=$(( total_requests * 60 / elapsed_total ))
final_tpm=$(( total_tokens * 60 / elapsed_total ))

echo ""
echo -e "${RED}🔥 极限测试完成! 最终战果:${NC}"
echo "=========================================="
echo "⏰ 结束时间: $(date)"
echo "⏱️  总运行时间: ${elapsed_total}秒"
echo ""
echo -e "${CYAN}📊 请求统计:${NC}"
echo "   总请求数: ${YELLOW}$total_requests${NC}"
echo "   成功请求: ${GREEN}$total_success${NC}"
echo "   失败请求: ${RED}$total_errors${NC}"
echo "   成功率: ${success_rate}%"
echo ""
echo -e "${CYAN}📈 分类统计:${NC}"
echo "   基础API: ✅$basic_success ❌$basic_error"
echo "   搜索API: ✅$search_success ❌$search_error"
echo "   Token爆发: ✅$token_success ❌$token_error"
echo ""
echo -e "${CYAN}🔢 性能指标:${NC}"
echo "   实际RPM: ${YELLOW}$final_rpm${NC} (官方限制: 15)"
echo "   实际TPM: ${YELLOW}$final_tpm${NC} (官方限制: 1,000,000)"
echo "   总Token消耗: $total_tokens"
echo "   搜索引用: $total_grounding"
echo "   测试轮数: $test_round"
echo ""
if [ $total_errors -gt 0 ]; then
    echo -e "${RED}🎯 成功触发配额限制！检测到 $total_errors 个错误${NC}"
else
    echo -e "${YELLOW}🤔 未触发429错误，API承受能力超出预期${NC}"
fi
echo "=========================================="
echo "📄 详细日志: $LOG_FILE"

# 清理
rm -f $COUNTER_FILE $COUNTER_FILE.lock

# 最终总结写入日志
{
    echo ""
    echo "🔥 极限测试完成! 最终统计:"
    echo "结束时间: $(date)"
    echo "总运行时间: ${elapsed_total}秒"
    echo "总请求: $total_requests | 成功: $total_success | 失败: $total_errors | 成功率: ${success_rate}%"
    echo "实际RPM: $final_rpm (vs 官方15) | 实际TPM: $final_tpm"
    echo "基础API: ✅$basic_success ❌$basic_error"
    echo "搜索API: ✅$search_success ❌$search_error"
    echo "Token爆发: ✅$token_success ❌$token_error"
    echo "总Token: $total_tokens | 搜索引用: $total_grounding | 测试轮数: $test_round"
    if [ $total_errors -gt 0 ]; then
        echo "🎯 成功触发配额限制！"
    else
        echo "🤔 未触发429错误"
    fi
} >> $LOG_FILE 