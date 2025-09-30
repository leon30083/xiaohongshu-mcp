import json
import pandas as pd
from datetime import datetime

# Load the user profile data
with open('开挖掘机的小乐乐_用户资料.json', 'r', encoding='utf-8-sig') as f:
    user_data = json.load(f)

# Extract user basic info
user_info = user_data['data']['data']['userBasicInfo']
interactions = user_data['data']['data']['interactions']
feeds = user_data['data']['data']['feeds']

print("=" * 80)
print("🏆 TOP1 UP主深度分析报告：开挖掘机的小乐乐")
print("=" * 80)

print("\n📊 基本信息:")
print(f"昵称: {user_info['nickname']}")
print(f"小红书号: {user_info['redId']}")
print(f"性别: {'男' if user_info['gender'] == 1 else '女'}")
print(f"IP归属地: {user_info['ipLocation']}")
print(f"个人简介: {user_info['desc']}")

print("\n📈 账号数据:")
for interaction in interactions:
    print(f"{interaction['name']}: {interaction['count']}")

print("\n🎯 内容分析:")
print(f"总作品数: {len(feeds)} 条")

# Analyze content types
video_count = sum(1 for feed in feeds if feed['noteCard']['type'] == 'video')
normal_count = sum(1 for feed in feeds if feed['noteCard']['type'] == 'normal')

print(f"视频内容: {video_count} 条 ({video_count/len(feeds)*100:.1f}%)")
print(f"图文内容: {normal_count} 条 ({normal_count/len(feeds)*100:.1f}%)")

# Analyze content themes
story_count = 0
science_count = 0
daily_count = 0
travel_count = 0

content_analysis = []

for i, feed in enumerate(feeds):
    title = feed['noteCard']['displayTitle']
    content_type = feed['noteCard']['type']
    
    # Extract interaction data (some might be empty strings)
    liked_count = int(feed['noteCard']['interactInfo']['likedCount']) if feed['noteCard']['interactInfo']['likedCount'] else 0
    shared_count = int(feed['noteCard']['interactInfo']['sharedCount']) if feed['noteCard']['interactInfo']['sharedCount'] else 0
    comment_count = int(feed['noteCard']['interactInfo']['commentCount']) if feed['noteCard']['interactInfo']['commentCount'] else 0
    collected_count = int(feed['noteCard']['interactInfo']['collectedCount']) if feed['noteCard']['interactInfo']['collectedCount'] else 0
    
    # Categorize content
    category = "其他"
    if "儿童故事" in title or "故事" in title:
        story_count += 1
        category = "儿童故事"
    elif "科普" in title or "古" in title:
        science_count += 1
        category = "科普教育"
    elif "扬州" in title or "早市" in title or "遛娃" in title:
        daily_count += 1
        category = "日常生活"
    elif "扬州" in title:
        travel_count += 1
        category = "旅行分享"
    else:
        daily_count += 1
        category = "日常生活"
    
    content_analysis.append({
        'index': i + 1,
        'title': title,
        'type': content_type,
        'category': category,
        'liked_count': liked_count,
        'shared_count': shared_count,
        'comment_count': comment_count,
        'collected_count': collected_count,
        'total_interactions': liked_count + shared_count + comment_count + collected_count,
        'engagement_score': liked_count * 1 + shared_count * 3 + comment_count * 2 + collected_count * 4
    })

# Create DataFrame for analysis
df = pd.DataFrame(content_analysis)

print(f"\n🎭 内容主题分布:")
print(f"儿童故事: {story_count} 条 ({story_count/len(feeds)*100:.1f}%)")
print(f"科普教育: {science_count} 条 ({science_count/len(feeds)*100:.1f}%)")
print(f"日常生活: {daily_count} 条 ({daily_count/len(feeds)*100:.1f}%)")

# Top performing content
top_content = df.nlargest(5, 'engagement_score')

print(f"\n🔥 TOP 5 高价值作品:")
for i, (_, row) in enumerate(top_content.iterrows(), 1):
    print(f"{i}. 《{row['title']}》")
    print(f"   类型: {row['type']} | 主题: {row['category']}")
    print(f"   互动得分: {row['engagement_score']:,.0f}")
    print(f"   点赞: {row['liked_count']:,} | 收藏: {row['collected_count']:,} | 分享: {row['shared_count']:,} | 评论: {row['comment_count']:,}")
    print()

# Content pattern analysis
print("📋 内容创作模式分析:")

# Story numbering pattern
story_titles = [item['title'] for item in content_analysis if '儿童故事' in item['title']]
numbered_stories = [title for title in story_titles if any(char.isdigit() for char in title)]

print(f"1. 系列化创作: 儿童故事系列已创作 {len(numbered_stories)} 集")

# Extract story numbers
story_numbers = []
for title in numbered_stories:
    import re
    numbers = re.findall(r'\d+', title)
    if numbers:
        story_numbers.extend([int(num) for num in numbers])

if story_numbers:
    print(f"   最新集数: 第{max(story_numbers)}集")
    print(f"   更新频率: 持续更新中")

print(f"2. 内容形式: 以视频为主 ({video_count/len(feeds)*100:.1f}%)")
print(f"3. 主题聚焦: 儿童教育内容占比 {(story_count + science_count)/len(feeds)*100:.1f}%")

# Engagement analysis
avg_engagement = df['engagement_score'].mean()
print(f"4. 平均互动得分: {avg_engagement:,.0f}")

# Category performance
category_performance = df.groupby('category').agg({
    'engagement_score': ['mean', 'sum', 'count'],
    'liked_count': 'mean',
    'collected_count': 'mean'
}).round(2)

print(f"\n📊 各类内容表现:")
for category in df['category'].unique():
    cat_data = df[df['category'] == category]
    avg_score = cat_data['engagement_score'].mean()
    count = len(cat_data)
    print(f"{category}: 平均得分 {avg_score:,.0f} ({count}条)")

# Save detailed analysis
df.to_csv('开挖掘机的小乐乐_内容详细分析.csv', index=False, encoding='utf-8-sig')

print(f"\n✅ 详细分析数据已保存到: 开挖掘机的小乐乐_内容详细分析.csv")

# Content creation insights
print(f"\n🎯 内容创作洞察:")
print("1. 垂直定位明确: 专注儿童教育内容")
print("2. 系列化运营: 儿童故事编号化，便于用户追更")
print("3. 教育价值导向: 故事主题多涉及品格教育")
print("4. 持续更新: 保持稳定的内容输出")
print("5. 多元化内容: 故事+科普+生活，满足不同需求")

# Extract content creation formula
print(f"\n🔧 内容创作公式提取:")
print("标题公式: '儿童故事[编号]：[教育主题/价值观]'")
print("内容结构: 故事情节 + 教育意义 + 互动引导")
print("发布频率: 持续稳定更新")
print("内容时长: 适合儿童注意力的短视频")
print("互动策略: 通过故事引发家长共鸣和收藏")