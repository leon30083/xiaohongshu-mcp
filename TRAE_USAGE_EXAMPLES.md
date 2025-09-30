# Trae 中使用 xiaohongshu-mcp 的完整指南

## 🚀 快速开始

### 1. 安装 MCP 工具
请参考 [Trae 安装指南](./TRAE_INSTALLATION.md) 完成安装。

### 2. 验证安装
```powershell
# 检查服务状态
Get-Process -Name "xiaohongshu-mcp"

# 测试 API 连接
Invoke-RestMethod -Uri "http://localhost:18060/health"
```

## 📝 在 Trae 中的使用示例

### 搜索小红书内容
```javascript
// 使用正确的 MCP 工具名称和方法
const searchResult = await mcp_xiaohongshu_mcp_search_feeds({
    keyword: '美食'
});

console.log('搜索结果:', searchResult);
```

### 获取用户资料
```javascript
// 获取指定用户的资料信息
const userProfile = await mcp_xiaohongshu_mcp_user_profile({
    user_id: '5b6e436ab5a2ff0001d2c477',
    xsec_token: 'your_xsec_token_here'
});

console.log('用户资料:', userProfile);
```

### 发布图文内容
```javascript
// 发布新的图文笔记
const publishResult = await mcp_xiaohongshu_mcp_publish_content({
    title: '我的美食分享',
    content: '今天尝试了一道新菜，味道很棒！',
    images: [
        './images/food1.jpg',
        './images/food2.jpg'
    ],
    tags: ['美食', '分享', '生活']
});

console.log('发布结果:', publishResult);
```

### 获取笔记详情
```javascript
// 获取指定笔记的详细信息
const noteDetail = await mcp_xiaohongshu_mcp_get_feed_detail({
    feed_id: '689f2d95000000001d01240c',
    xsec_token: 'your_xsec_token_here'
});

console.log('笔记详情:', noteDetail);
```

### 发表评论
```javascript
// 对指定笔记发表评论
const commentResult = await mcp_xiaohongshu_mcp_post_comment_to_feed({
    feed_id: '689f2d95000000001d01240c',
    xsec_token: 'your_xsec_token_here',
    content: '看起来很好吃！请问在哪里可以买到？'
});

console.log('评论结果:', commentResult);
```

### 检查登录状态
```javascript
// 检查当前登录状态
const loginStatus = await mcp_xiaohongshu_mcp_check_login_status();
console.log('登录状态:', loginStatus);
```

### 获取登录二维码
```javascript
// 获取登录二维码
const qrCode = await mcp_xiaohongshu_mcp_get_login_qrcode();
console.log('登录二维码:', qrCode);
```

## 🔧 高级用法

### 批量操作示例
```javascript
// 批量搜索多个关键词
const keywords = ['美食', '旅行', '摄影', '时尚'];
const batchResults = [];

for (const keyword of keywords) {
    try {
        const result = await mcp_xiaohongshu_mcp_search_feeds({
            keyword: keyword
        });
        batchResults.push({
            keyword: keyword,
            count: result.feeds?.length || 0,
            feeds: result.feeds || []
        });
    } catch (error) {
        console.error(`搜索 ${keyword} 失败:`, error);
    }
}

console.log('批量搜索结果:', batchResults);
```

### 错误处理示例
```javascript
// 带错误处理的操作
async function safePublishContent(noteData) {
    try {
        // 首先检查登录状态
        const loginStatus = await mcp_xiaohongshu_mcp_check_login_status();
        
        if (!loginStatus.success) {
            console.log('需要先登录');
            
            // 获取登录二维码
            const qrCode = await mcp_xiaohongshu_mcp_get_login_qrcode();
            console.log('请扫描二维码登录:', qrCode);
            
            return { success: false, message: '需要登录' };
        }
        
        // 发布图文内容
        const result = await mcp_xiaohongshu_mcp_publish_content(noteData);
        return result;
        
    } catch (error) {
        console.error('发布失败:', error);
        return { success: false, error: error.message };
    }
}

// 使用示例
const noteData = {
    title: '我的分享',
    content: '这是一个测试内容',
    images: ['./test.jpg'],
    tags: ['测试']
};

const result = await safePublishContent(noteData);
console.log('发布结果:', result);
```

### 数据处理示例
```javascript
// 搜索并分析数据
async function analyzeContent(keyword) {
    const searchResult = await mcp.call('xiaohongshu-mcp', 'search_feeds', {
        keyword: keyword,
        limit: 50
    });
    
    const feeds = searchResult.data?.feeds || [];
    
    // 分析数据
    const analysis = {
        totalCount: feeds.length,
        avgLikes: 0,
        avgComments: 0,
        topAuthors: {},
        popularTags: {}
    };
    
    let totalLikes = 0;
    let totalComments = 0;
    
    feeds.forEach(feed => {
        const likes = parseInt(feed.noteCard?.interactInfo?.likedCount || 0);
        const comments = parseInt(feed.noteCard?.interactInfo?.commentCount || 0);
        const author = feed.noteCard?.user?.nickname || 'Unknown';
        
        totalLikes += likes;
        totalComments += comments;
        
        // 统计作者
        analysis.topAuthors[author] = (analysis.topAuthors[author] || 0) + 1;
    });
    
    analysis.avgLikes = Math.round(totalLikes / feeds.length);
    analysis.avgComments = Math.round(totalComments / feeds.length);
    
    // 排序热门作者
    analysis.topAuthors = Object.entries(analysis.topAuthors)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 10)
        .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});
    
    return analysis;
}

// 使用示例
const analysis = await analyzeContent('美食');
console.log('内容分析结果:', analysis);
```

## ⚙️ 配置选项

### MCP 服务器配置
在 Trae 的 MCP 配置中，xiaohongshu-mcp 使用以下配置：

```json
{
  "mcpServers": {
    "xiaohongshu-mcp": {
      "type": "sse",
      "url": "https://mcp.api-inference.modelscope.cn/1bd266e3e1c47/sse",
      "fromGalleryId": "modelcontextprotocol.servers_xiaohongshu-mcp"
    }
  }
}
```

### 配置说明
- **type**: 使用 "sse" (Server-Sent Events) 连接类型
- **url**: ModelScope 提供的 MCP 服务端点
- **fromGalleryId**: 官方 MCP 服务器库中的标识符

### 环境变量（可选）
如果您使用本地部署，可以设置以下环境变量：

```bash
# 调试模式
DEBUG=false

# 日志级别
LOG_LEVEL=info

# 服务端口（本地部署时）
PORT=8080
```

## 🔍 调试和故障排除

### 检查服务状态
```javascript
// 在 Trae 中检查 MCP 工具状态
const tools = await mcp.listTools('xiaohongshu-mcp');
console.log('可用工具:', tools);

// 检查服务健康状态
const health = await fetch('http://localhost:18060/health').then(r => r.json());
console.log('服务状态:', health);
```

### 常见问题解决
```powershell
# 1. 服务未启动
Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if (!$?) { .\xiaohongshu-mcp.exe -headless=false }

# 2. 端口被占用
netstat -ano | findstr :18060
# 如果端口被占用，终止占用进程或更改端口

# 3. 配置文件错误
Test-Json -Path ".\.trae\mcp.json"

# 4. 重新安装
Remove-Item ".\.trae" -Recurse -Force
.\quick-install.ps1
```

## 📚 API 参考

### 搜索相关
- `mcp_xiaohongshu_mcp_search_feeds(keyword)` - 搜索笔记内容

### 用户相关
- `mcp_xiaohongshu_mcp_user_profile(user_id, xsec_token)` - 获取用户信息
- `mcp_xiaohongshu_mcp_list_feeds()` - 获取用户发布的内容列表

### 内容相关
- `mcp_xiaohongshu_mcp_get_feed_detail(feed_id, xsec_token)` - 获取笔记详情
- `mcp_xiaohongshu_mcp_publish_content(title, content, images, tags?)` - 发布图文内容
- `mcp_xiaohongshu_mcp_publish_with_video(title, content, video, tags?)` - 发布视频内容
- `mcp_xiaohongshu_mcp_post_comment_to_feed(feed_id, xsec_token, content)` - 发表评论

### 认证相关
- `mcp_xiaohongshu_mcp_check_login_status()` - 检查登录状态
- `mcp_xiaohongshu_mcp_get_login_qrcode()` - 获取登录二维码

### 参数说明
- `keyword`: 搜索关键词
- `user_id`: 用户ID
- `feed_id`: 笔记ID
- `xsec_token`: 访问令牌（从搜索结果或列表中获取）
- `title`: 内容标题（最多20个中文字符）
- `content`: 正文内容
- `images`: 图片路径数组（支持本地路径或HTTP链接）
- `video`: 视频文件路径（仅支持本地文件）
- `tags`: 话题标签数组（可选）

### 返回数据格式

#### 搜索结果
```json
{
  "feeds": [
    {
      "xsecToken": "token_string",
      "id": "689f2d95000000001d01240c",
      "modelType": "note",
      "noteCard": {
        "displayTitle": "美食分享",
        "user": {
          "userId": "user123",
          "nickname": "美食达人",
          "avatar": "https://..."
        },
        "cover": {
          "url": "https://...",
          "width": 1080,
          "height": 1440
        },
        "interactInfo": {
          "likedCount": "1234",
          "commentCount": "56",
          "collectedCount": "78"
        }
      },
      "index": 0
    }
  ]
}
```

#### 用户信息
```json
{
  "basicInfo": {
    "userId": "user123",
    "nickname": "用户昵称",
    "avatar": "https://...",
    "desc": "个人简介"
  },
  "interactions": {
    "followCount": "1000",
    "fansCount": "5000",
    "collectionCount": "2000",
    "noteCount": "500"
  },
  "tags": ["美食", "旅行"],
  "notes": [...]
}
```

#### 笔记详情
```json
{
  "noteId": "689f2d95000000001d01240c",
  "title": "笔记标题",
  "desc": "笔记内容",
  "user": {
    "userId": "user123",
    "nickname": "作者昵称"
  },
  "imageList": [
    {
      "url": "https://...",
      "width": 1080,
      "height": 1440
    }
  ],
  "interactInfo": {
    "likedCount": "1234",
    "commentCount": "56",
    "collectedCount": "78"
  },
  "comments": [...]
}
```

#### 标准返回格式
```javascript
// 成功返回格式
{
    "success": true,
    "data": {
        // 具体数据内容
    },
    "message": "操作成功"
}

// 错误返回格式
{
    "success": false,
    "error": "错误信息",
    "message": "操作失败"
}
```

## 💡 最佳实践

### 1. 错误处理
始终使用 try-catch 包装 MCP 调用，并检查返回结果的有效性：

```javascript
try {
    const result = await mcp_xiaohongshu_mcp_search_feeds({ keyword: '美食' });
    if (result && result.feeds) {
        // 处理成功结果
        console.log('搜索成功:', result.feeds.length, '条结果');
    } else {
        console.log('搜索结果为空');
    }
} catch (error) {
    console.error('搜索失败:', error.message);
}
```

### 2. 登录状态管理
在执行需要登录的操作前，先检查登录状态：

```javascript
const loginStatus = await mcp_xiaohongshu_mcp_check_login_status();
if (!loginStatus.success) {
    // 引导用户登录
    const qrCode = await mcp_xiaohongshu_mcp_get_login_qrcode();
    console.log('请扫描二维码登录');
}
```

### 3. 内容发布规范
- **图片要求**: 支持本地路径和HTTP链接，推荐使用本地路径
- **标题限制**: 最多20个中文字符或英文单词
- **内容规范**: 遵守小红书社区规范，避免违规内容
- **标签使用**: 合理使用话题标签，提高内容曝光度

### 4. Token 管理
正确使用 xsec_token 参数：

```javascript
// 从搜索结果中获取 token
const searchResult = await mcp_xiaohongshu_mcp_search_feeds({ keyword: '美食' });
const firstFeed = searchResult.feeds[0];

// 使用 token 获取详情
const detail = await mcp_xiaohongshu_mcp_get_feed_detail({
    feed_id: firstFeed.id,
    xsec_token: firstFeed.xsecToken
});
```

### 5. 频率控制
避免过于频繁的 API 调用，建议在批量操作间添加延迟：

```javascript
// 批量操作时添加延迟
for (const keyword of keywords) {
    const result = await mcp_xiaohongshu_mcp_search_feeds({ keyword });
    // 添加 1 秒延迟
    await new Promise(resolve => setTimeout(resolve, 1000));
}
```

### 6. 数据验证
对返回的数据进行适当验证：

```javascript
function validateFeedData(feed) {
    return feed && 
           feed.id && 
           feed.xsecToken && 
           feed.noteCard && 
           feed.noteCard.displayTitle;
}

const validFeeds = searchResult.feeds.filter(validateFeedData);
```

通过以上示例，您可以在 Trae 中充分利用 xiaohongshu-mcp 工具的强大功能！