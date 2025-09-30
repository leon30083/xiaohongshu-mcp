import json
import pandas as pd

# Load the search results
with open('儿童绘本数据.json', 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

# Extract feeds data
feeds = data['data']['feeds']

# Filter out hot_query entries and only keep note entries
notes = [feed for feed in feeds if feed['modelType'] == 'note']

# Create a list to store creator analysis
creators = []

for note in notes:
    note_card = note['noteCard']
    user = note_card['user']
    interact_info = note_card['interactInfo']
    
    # Convert string numbers to integers for calculation
    liked_count = int(interact_info['likedCount'].replace(',', '')) if interact_info['likedCount'] else 0
    shared_count = int(interact_info['sharedCount'].replace(',', '')) if interact_info['sharedCount'] else 0
    comment_count = int(interact_info['commentCount'].replace(',', '')) if interact_info['commentCount'] else 0
    collected_count = int(interact_info['collectedCount'].replace(',', '')) if interact_info['collectedCount'] else 0
    
    # Calculate engagement score (weighted sum)
    # Weights: likes(1), shares(3), comments(2), collections(4)
    engagement_score = liked_count * 1 + shared_count * 3 + comment_count * 2 + collected_count * 4
    
    creator_data = {
        'user_id': user['userId'],
        'nickname': user['nickname'],
        'note_id': note['id'],
        'note_title': note_card['displayTitle'],
        'note_type': note_card['type'],
        'liked_count': liked_count,
        'shared_count': shared_count,
        'comment_count': comment_count,
        'collected_count': collected_count,
        'engagement_score': engagement_score,
        'total_interactions': liked_count + shared_count + comment_count + collected_count
    }
    
    creators.append(creator_data)

# Create DataFrame
df = pd.DataFrame(creators)

# Group by creator and calculate aggregate metrics
creator_stats = df.groupby(['user_id', 'nickname']).agg({
    'liked_count': ['sum', 'mean', 'max'],
    'shared_count': ['sum', 'mean', 'max'],
    'comment_count': ['sum', 'mean', 'max'],
    'collected_count': ['sum', 'mean', 'max'],
    'engagement_score': ['sum', 'mean', 'max'],
    'total_interactions': ['sum', 'mean', 'max'],
    'note_id': 'count'  # Number of notes
}).round(2)

# Flatten column names
creator_stats.columns = ['_'.join(col).strip() for col in creator_stats.columns]
creator_stats = creator_stats.reset_index()

# Rename the count column
creator_stats.rename(columns={'note_id_count': 'note_count'}, inplace=True)

# Calculate comprehensive ranking score
# Factors: total engagement, average engagement, note count, max single note performance
creator_stats['comprehensive_score'] = (
    creator_stats['engagement_score_sum'] * 0.4 +  # Total engagement (40%)
    creator_stats['engagement_score_mean'] * 0.3 +  # Average engagement (30%)
    creator_stats['note_count'] * 1000 +  # Note count bonus (consistency)
    creator_stats['engagement_score_max'] * 0.3  # Best single note performance (30%)
)

# Sort by comprehensive score
creator_stats_sorted = creator_stats.sort_values('comprehensive_score', ascending=False)

print("=== 儿童绘本领域UP主综合排名分析 ===\n")
print("排名计算方法:")
print("- 总互动得分 (40%): 点赞×1 + 分享×3 + 评论×2 + 收藏×4")
print("- 平均互动得分 (30%): 单条内容平均表现")
print("- 内容数量奖励: 每条内容+1000分 (体现持续创作能力)")
print("- 最佳单条表现 (30%): 爆款内容能力\n")

print("TOP 10 UP主排名:")
print("=" * 100)

for i, (_, row) in enumerate(creator_stats_sorted.head(10).iterrows(), 1):
    print(f"第{i}名: {row['nickname']}")
    print(f"  用户ID: {row['user_id']}")
    print(f"  综合得分: {row['comprehensive_score']:,.0f}")
    print(f"  内容数量: {row['note_count']} 条")
    print(f"  总互动量: {row['total_interactions_sum']:,.0f}")
    print(f"  平均互动量: {row['total_interactions_mean']:,.0f}")
    print(f"  最高单条互动: {row['total_interactions_max']:,.0f}")
    print(f"  平均点赞: {row['liked_count_mean']:,.0f}")
    print(f"  平均收藏: {row['collected_count_mean']:,.0f}")
    print("-" * 80)

# Save detailed analysis
creator_stats_sorted.to_csv('UP主综合排名分析.csv', index=False, encoding='utf-8-sig')

# Get top creator details
top_creator = creator_stats_sorted.iloc[0]
print(f"\n🏆 综合排名第一的UP主: {top_creator['nickname']}")
print(f"用户ID: {top_creator['user_id']}")
print(f"综合得分: {top_creator['comprehensive_score']:,.0f}")

# Get all notes from top creator
top_creator_notes = df[df['user_id'] == top_creator['user_id']].sort_values('engagement_score', ascending=False)

print(f"\n该UP主的所有作品分析:")
for i, (_, note) in enumerate(top_creator_notes.iterrows(), 1):
    print(f"{i}. 《{note['note_title']}》")
    print(f"   类型: {note['note_type']}")
    print(f"   互动得分: {note['engagement_score']:,.0f}")
    print(f"   点赞: {note['liked_count']:,.0f} | 收藏: {note['collected_count']:,.0f} | 分享: {note['shared_count']:,.0f} | 评论: {note['comment_count']:,.0f}")

# Save top creator's notes
top_creator_notes.to_csv(f'{top_creator["nickname"]}_作品分析.csv', index=False, encoding='utf-8-sig')

print(f"\n✅ 分析完成！详细数据已保存到:")
print(f"- UP主综合排名分析.csv")
print(f"- {top_creator['nickname']}_作品分析.csv")