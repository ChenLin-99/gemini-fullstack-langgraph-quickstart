#!/usr/bin/env python3
"""
分析Reflection Agent和Answer Agent的工作机制
"""

# 中文提示词模板
reflection_instructions = """你是一位专家研究助手，正在分析关于"{research_topic}"的总结内容。

指令：
- 识别知识空白或需要更深入探索的领域，并生成后续查询（一个或多个）。
- 如果提供的总结足以回答用户的问题，则不要生成后续查询。
- 如果存在知识空白，生成有助于扩展理解的后续查询。
- 重点关注未充分涵盖的技术细节、实现规范或新兴趋势。

要求：
- 确保后续查询是自包含的，并包含网络搜索所需的必要上下文。

输出格式：
- 将您的回复格式化为具有以下确切键的JSON对象：
   - "is_sufficient": true 或 false
   - "knowledge_gap": 描述缺失或需要澄清的信息
   - "follow_up_queries": 编写解决此空白的具体问题

仔细反思总结内容以识别知识空白并产生后续查询。然后，按照此JSON格式产生您的输出：

总结：
{summaries}
"""

answer_instructions = """基于提供的总结，为用户问题生成高质量的答案。

指令：
- 当前日期是 {current_date}。
- 您是多步研究过程的最后一步，不要提及您是最后一步。
- 您可以访问从之前步骤收集的所有信息。
- 您可以访问用户的问题。
- 基于提供的总结和用户问题，为用户问题生成高质量的答案。
- 您必须在答案中正确包含所有来自总结的引用。

用户上下文：
- {research_topic}

总结：
{summaries}"""

def analyze_agent_workflow():
    print("🔍 深度分析：Reflection Agent 和 Answer Agent 工作机制")
    print("=" * 80)
    
    print("\n📋 1. 数据流转架构分析：")
    print("-" * 40)
    print("状态管理：基于LangGraph的内存状态（无数据库缓存）")
    print("数据结构：")
    print("  • web_research_result: List[str] - 累积所有搜索结果")
    print("  • sources_gathered: List[dict] - 累积所有引用信息")
    print("  • research_loop_count: int - 跟踪研究轮数")
    
    print("\n🔄 2. Reflection Agent 工作机制：")
    print("-" * 40)
    print("输入数据：")
    print("  • research_topic: 用户原始问题")
    print("  • summaries: 所有web_research_result用'\\n\\n---\\n\\n'连接")
    print("  • current_date: 当前日期")
    
    print("\n中文提示词结构：")
    print("  • 角色定位：专家研究助手")
    print("  • 核心任务：识别知识空白，决定是否需要更多搜索")
    print("  • 输出格式：JSON结构化输出")
    print("  • 语言：完全中文化的指令和要求")
    
    print("\n反思内容：")
    print("  • 评估现有总结是否充分回答用户问题")
    print("  • 识别缺失的技术细节、实现规范或新趋势")
    print("  • 生成自包含的后续搜索查询")
    
    print("\n决策逻辑：")
    print("  • is_sufficient=true → 进入finalize_answer")
    print("  • is_sufficient=false → 继续web_research")
    print("  • 受max_research_loops限制（默认2轮）")
    
    print("\n📝 3. Answer Agent 工作机制：")
    print("-" * 40)
    print("输入数据：")
    print("  • research_topic: 用户原始问题")
    print("  • summaries: 所有web_research_result用'\\n---\\n\\n'连接")
    print("  • current_date: 当前日期")
    
    print("\n中文提示词结构：")
    print("  • 角色定位：最终报告生成器")
    print("  • 核心任务：基于所有搜索结果生成高质量中文答案")
    print("  • 引用要求：必须包含所有citations")
    print("  • 语言：完全中文化的指令体系")
    
    print("\n信息整合：")
    print("  • 结合所有轮次的搜索结果")
    print("  • 处理短链接到原始URL的映射")
    print("  • 保留使用的引用信息到sources_gathered")
    
    print("\n🔗 4. 引用处理流程：")
    print("-" * 40)
    print("1. 搜索阶段：grounding_metadata → citations → short_url")
    print("2. 累积阶段：sources_gathered列表持续追加")
    print("3. 最终阶段：短链接替换为原始URL")
    print("4. 输出阶段：只保留实际使用的引用")
    
    print("\n💾 5. 缓存机制分析：")
    print("-" * 40)
    print("❌ 无数据库缓存：搜索结果不持久化")
    print("✅ 内存状态：单次会话内累积数据")
    print("✅ 状态传递：通过LangGraph状态图管理")
    print("⚠️  会话结束：所有数据丢失")
    
    print("\n🔄 6. 多轮研究循环：")
    print("-" * 40)
    print("轮次1：初始搜索查询 → 搜索结果 → 中文反思")
    print("轮次2：后续查询 → 新搜索结果 → 再次中文反思")
    print("轮次N：直到is_sufficient=true或达到max_loops")
    print("最终：所有结果 → Answer Agent → 中文最终报告")
    
    print("\n🎯 7. 中文化关键发现：")
    print("-" * 40)
    print("• 无持久化：每次对话都是独立的研究过程")
    print("• 累积式：每轮搜索结果都会被保留和使用")
    print("• 智能化：Reflection Agent控制研究深度")
    print("• 可追溯：完整的引用链路保证信息可信")
    print("• 本地化：完全中文化的提示词和指令体系")

    print("\n📝 8. 完整中文提示词展示：")
    print("-" * 40)
    print("\n🤔 Reflection Agent 中文提示词：")
    print(reflection_instructions)
    print("\n📝 Answer Agent 中文提示词：")
    print(answer_instructions)

if __name__ == "__main__":
    analyze_agent_workflow() 