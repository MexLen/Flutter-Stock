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

  @override
  String toString() {
    return 'FundNews{id: $id, title: $title, source: $source, publishTime: $publishTime, sentiment: $sentiment}';
  }
}