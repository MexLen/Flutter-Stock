// 添加foundation包用于平台检测

/// 新闻情感类型枚举
enum NewsSentiment {
  positive,  // 利好
  negative,  // 利空
  neutral    // 中性
}

/// 基金新闻数据模型
class FundNews {
  final String id;           // 新闻ID
  final String title;        // 新闻标题
  final String summary;      // 新闻摘要
  final String url;          // 新闻链接
  final String publishTime;  // 发布时间
  final String source;       // 新闻来源
  final NewsSentiment sentiment; // 新闻情感类型

  FundNews({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.publishTime,
    required this.source,
    required this.sentiment,
  });

  factory FundNews.fromJson(Map<String, dynamic> json) {
    return FundNews(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      url: json['url'] as String,
      publishTime: json['publishTime'] as String,
      source: json['source'] as String,
      sentiment: _parseSentiment(json['sentiment'] as String? ?? 'neutral'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'url': url,
      'publishTime': publishTime,
      'source': source,
      'sentiment': _sentimentToString(sentiment),
    };
  }

  static NewsSentiment _parseSentiment(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return NewsSentiment.positive;
      case 'negative':
        return NewsSentiment.negative;
      default:
        return NewsSentiment.neutral;
    }
  }

  static String _sentimentToString(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return 'positive';
      case NewsSentiment.negative:
        return 'negative';
      case NewsSentiment.neutral:
        return 'neutral';
    }
  }
}

// 获取个股新闻（参考akshare实现）



/// 简单的情感分析函数
NewsSentiment analyzeSentiment(String title) {
  // 利好关键词
  final positiveKeywords = [
    '上涨', '增长', '盈利', '收益', '分红', '利好', '突破', '新高', 
    '增持', '买入', '看多', '乐观', '反弹', '回升', '走强'
  ];
  
  // 利空关键词
  final negativeKeywords = [
    '下跌', '亏损', '下降', '缩水', '利空', '暴跌', '大跌', '减持',
    '卖出', '看空', '悲观', '回调', '回落', '走弱', '低迷', '风险'
  ];
  
  // 检查是否包含利好关键词
  for (final keyword in positiveKeywords) {
    if (title.contains(keyword)) {
      return NewsSentiment.positive;
    }
  }
  
  // 检查是否包含利空关键词
  for (final keyword in negativeKeywords) {
    if (title.contains(keyword)) {
      return NewsSentiment.negative;
    }
  }
  
  // 默认返回中性
  return NewsSentiment.neutral;
}


