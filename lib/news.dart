// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'fund_api.dart'; // 导入持仓数据结构

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

/// 获取基金相关新闻
Future<List<FundNews>> fetchFundNews(String fundCode, {int page = 1, int pageSize = 20}) async {
  try {
    // 根据平台选择HOST
    String host;
    if (identical(0, 0.0)) {
      // Web
      host = 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      host = 'http://localhost:8080';
    } else {
      host = 'http://localhost:8080';
    }
    
    // 请求天天基金网的基金新闻页面
    final url = Uri.parse('$host/news/fund_news').replace(queryParameters: {
      'fundCode': fundCode,
    });
    
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
        'Referer': 'https://fund.eastmoney.com/',
      },
    );
    
    if (response.statusCode == 200) {
      // 解析返回的HTML内容
      final document = parser.parse(response.body);
      
      // 查找新闻列表项 (根据天天基金网实际的HTML结构调整选择器)
      final newsItems = document.querySelectorAll('.newsList li') 
        ..addAll(document.querySelectorAll('.news-item'))
        ..addAll(document.querySelectorAll('.article-list li'));
      
      List<FundNews> newsList = [];
      
      // 限制返回数量
      int end = (pageSize < newsItems.length) ? pageSize : newsItems.length;
      
      for (int i = 0; i < end; i++) {
        final item = newsItems[i];
        final news = _parseNewsItem(item, fundCode);
        if (news != null) {
          newsList.add(news);
        }
      }
      
      // 如果没有找到新闻，尝试其他选择器
      if (newsList.isEmpty) {
        // 尝试更通用的选择器
        final generalItems = document.querySelectorAll('li');
        for (int i = 0; i < generalItems.length && newsList.length < pageSize; i++) {
          final item = generalItems[i];
          // 检查是否包含新闻相关的元素
          if (item.querySelector('a') != null && 
              (item.text.length > 10) && 
              item.querySelectorAll('a').isNotEmpty) {
            final news = _parseNewsItem(item, fundCode);
            if (news != null) {
              newsList.add(news);
            }
          }
        }
      }
      
      // 如果还是没有找到新闻，返回模拟数据
      if (newsList.isEmpty) {
        await Future.delayed(Duration(milliseconds: 500));
        return _getMockNews(fundCode);
      }
      
      return newsList;
    } else {
      throw Exception('获取新闻失败: ${response.statusCode}');
    }
  } catch (e) {
    print('获取基金新闻出错: $e');
    // 出错时返回模拟数据
    await Future.delayed(Duration(milliseconds: 800));
    return _getMockNews(fundCode);
  }
}

/// 获取基金持仓股票的新闻
Future<List<FundNews>> fetchHoldingsNews(List<HoldingItem> holdings, {int page = 1, int pageSize = 20}) async {
  try {
    List<FundNews> allNews = [];
    
    // 为每个持仓股票获取新闻（限制请求数量以避免过多请求）
    int requestCount = 0;
    const maxRequests = 5; // 最多请求5个股票的新闻
    
    for (var holding in holdings) {
      if (requestCount >= maxRequests) break;
      
      // 处理股票代码格式（去除SH/SZ/HK等后缀，获取纯数字代码）
      String stockCode = _normalizeStockCode(holding.code);
      if (stockCode.isEmpty || stockCode.length < 6) continue;
      
      // 获取股票新闻
      final stockNews = await _fetchSingleStockNews(stockCode, holding.name);
      allNews.addAll(stockNews);
      requestCount++;
      
      // 添加小延迟避免请求过于频繁
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    // 按时间排序，最新的在前面
    allNews.sort((a, b) => b.publishTime.compareTo(a.publishTime));
    
    // 去重（根据标题）
    Set<String> titles = {};
    List<FundNews> uniqueNews = [];
    for (var news in allNews) {
      if (!titles.contains(news.title)) {
        titles.add(news.title);
        uniqueNews.add(news);
      }
    }
    
    // 限制返回数量
    if (uniqueNews.length > pageSize) {
      uniqueNews = uniqueNews.sublist(0, pageSize);
    }
    
    // 如果没有找到新闻，返回模拟数据
    if (uniqueNews.isEmpty) {
      await Future.delayed(Duration(milliseconds: 500));
      return _getMockHoldingsNews(holdings);
    }
    
    return uniqueNews;
  } catch (e) {
    print('获取持仓股票新闻出错: $e');
    // 出错时返回模拟数据
    await Future.delayed(Duration(milliseconds: 800));
    return _getMockHoldingsNews(holdings);
  }
}

/// 获取单个股票的新闻
Future<List<FundNews>> _fetchSingleStockNews(String stockCode, String stockName) async {
  try {
    // 根据平台选择HOST
    String host;
    if (identical(0, 0.0)) {
      // Web
      host = 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      host = 'http://localhost:8080';
    } else {
      host = 'http://localhost:8080';
    }
    
    // 请求股票新闻页面
    final url = Uri.parse('$host/news/stock_news').replace(queryParameters: {
      'stockCode': stockCode,
    });
    
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
        'Referer': 'https://finance.eastmoney.com/',
      },
    );
    
    if (response.statusCode == 200) {
      // 解析返回的HTML内容
      final document = parser.parse(response.body);
      
      // 查找新闻列表项（根据东方财富网实际结构）
      List<dom.Element> newsItems = [];
      
      // 尝试多种选择器
      newsItems.addAll(document.querySelectorAll('.newslist li'));
      newsItems.addAll(document.querySelectorAll('.stocknews li'));
      newsItems.addAll(document.querySelectorAll('.news-item'));
      newsItems.addAll(document.querySelectorAll('.article-item'));
      
      // 如果还是找不到，尝试更通用的选择器
      if (newsItems.isEmpty) {
        final allListItems = document.querySelectorAll('li');
        for (var item in allListItems) {
          // 检查是否包含新闻相关的元素
          if (item.querySelector('a') != null && 
              item.text.length > 10 && 
              item.querySelectorAll('a').isNotEmpty) {
            newsItems.add(item);
          }
        }
      }
      
      List<FundNews> newsList = [];
      
      for (int i = 0; i < newsItems.length && i < 10; i++) { // 每个股票最多10条新闻
        final item = newsItems[i];
        final news = _parseStockNewsItem(item, stockCode, stockName);
        if (news != null) {
          newsList.add(news);
        }
      }
      
      return newsList;
    } else {
      throw Exception('获取股票新闻失败: ${response.statusCode}');
    }
  } catch (e) {
    print('获取单个股票新闻出错 ($stockCode): $e');
    return [];
  }
}

/// 解析单个股票新闻项
FundNews? _parseStockNewsItem(dom.Element item, String stockCode, String stockName) {
  try {
    // 查找新闻链接和标题
    final linkElements = item.querySelectorAll('a');
    if (linkElements.isEmpty) return null;
    
    final linkElement = linkElements.first;
    final title = linkElement.text.trim();
    var url = linkElement.attributes['href'] ?? '';
    
    // 如果标题为空或太短，跳过
    if (title.isEmpty || title.length < 5) {
      return null;
    }
    
    // 如果URL是相对路径，转换为绝对路径
    if (url.startsWith('/')) {
      url = 'https://finance.eastmoney.com$url';
    } else if (!url.startsWith('http') && url.isNotEmpty) {
      url = 'https://finance.eastmoney.com/news/$url';
    } else if (url.isEmpty) {
      // 如果没有URL，构造一个默认的
      url = 'https://finance.eastmoney.com/news,$stockCode}.html';
    }
    
    // 查找发布时间
    String publishTime = '';
    final timeElements = item.querySelectorAll('span, .time, .date');
    for (final elem in timeElements) {
      final text = elem.text.trim();
      // 简单的日期格式检查 (YYYY-MM-DD 或 MM-DD)
      if ((text.contains(RegExp(r'\d{4}-\d{2}-\d{2}')) || 
           text.contains(RegExp(r'\d{2}-\d{2}'))) && 
          text.contains(':')) {
        publishTime = text;
        break;
      }
    }
    
    // 如果没找到时间，尝试从文本中提取
    if (publishTime.isEmpty) {
      final itemText = item.text;
      // 匹配类似 2025-06-20 或 06-20 的日期格式
      final regExp = RegExp(r'(\d{4}-)?\d{2}-\d{2}');
      final match = regExp.firstMatch(itemText);
      if (match != null) {
        publishTime = match.group(0)!;
        // 如果只有月日，添加当前年份
        if (!publishTime.contains('-') && publishTime.length == 5) {
          publishTime = '${DateTime.now().year}-$publishTime';
        }
      }
    }
    
    // 简单的情感分析（基于标题关键词）
    final sentiment = _analyzeSentiment(title);
    
    return FundNews(
      id: '${stockCode}_${title.hashCode}',
      title: title,
      summary: '与持仓股票 $stockName ($stockCode) 相关的新闻',
      url: url,
      publishTime: publishTime.isNotEmpty ? publishTime : DateTime.now().toString().substring(0, 16).replaceAll('T', ' '),
      source: '东方财富网',
      sentiment: sentiment,
    );
  } catch (e) {
    print('解析股票新闻项出错: $e');
    return null;
  }
}

/// 标准化股票代码（去除市场标识符）
String _normalizeStockCode(String code) {
  // 去除SH、SZ、HK等后缀
  code = code.replaceAll(RegExp(r'[A-Za-z]+$'), '');
  // 确保代码是6位数字
  if (RegExp(r'^\d{6}$').hasMatch(code)) {
    return code;
  }
  return '';
}

/// 检查新闻是否与持仓股票相关
bool _isNewsRelevantToHoldings(FundNews news, List<HoldingItem> holdings) {
  // 检查新闻标题是否包含持仓股票名称或代码
  for (var holding in holdings) {
    if (news.title.contains(holding.name) || 
        news.title.contains(_normalizeStockCode(holding.code))) {
      return true;
    }
  }
  return false;
}

/// 解析单个新闻项
FundNews? _parseNewsItem(dom.Element item, String fundCode) {
  try {
    // 查找新闻链接和标题
    final linkElements = item.querySelectorAll('a');
    if (linkElements.isEmpty) return null;
    
    final linkElement = linkElements.first;
    final title = linkElement.text.trim();
    var url = linkElement.attributes['href'] ?? '';
    
    // 如果URL是相对路径，转换为绝对路径
    if (url.startsWith('/')) {
      url = 'https://fund.eastmoney.com$url';
    } else if (!url.startsWith('http')) {
      url = 'https://fund.eastmoney.com/news/$url';
    }
    
    if (title.isEmpty) {
      return null;
    }
    
    // 查找发布时间
    String publishTime = '';
    final timeElements = item.querySelectorAll('span');
    for (final elem in timeElements) {
      final text = elem.text.trim();
      // 简单的日期格式检查
      if (text.contains('-') && text.contains(':')) {
        publishTime = text;
        break;
      }
    }
    
    // 如果没找到时间，尝试从文本中提取
    if (publishTime.isEmpty) {
      final itemText = item.text;
      // 匹配类似 2025-06-20 的日期格式
      final regExp = RegExp(r'\d{4}-\d{2}-\d{2}');
      final match = regExp.firstMatch(itemText);
      if (match != null) {
        publishTime = match.group(0)!;
      }
    }
    
    // 简单的情感分析（基于标题关键词）
    final sentiment = _analyzeSentiment(title);
    
    return FundNews(
      id: DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
      title: title,
      summary: '点击阅读完整新闻内容',
      url: url,
      publishTime: publishTime.isNotEmpty ? publishTime : '未知时间',
      source: '天天基金网',
      sentiment: sentiment,
    );
  } catch (e) {
    print('解析新闻项出错: $e');
    return null;
  }
}

/// 简单的情感分析函数
NewsSentiment _analyzeSentiment(String title) {
  // 利好关键词
  final positiveKeywords = [
    '上涨', '增长', '盈利', '收益', '分红', '利好', '突破', '新高', 
    '增持', '买入', '看多', '乐观', '上涨', '反弹', '回升', '走强', '业绩优异'
  ];
  
  // 利空关键词
  final negativeKeywords = [
    '下跌', '亏损', '下降', '缩水', '利空', '暴跌', '大跌', '减持',
    '卖出', '看空', '悲观', '回调', '回落', '走弱', '低迷', '风险', '亏损'
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

/// 获取持仓股票的模拟新闻
List<FundNews> _getMockHoldingsNews(List<HoldingItem> holdings) {
  List<FundNews> mockNews = [];
  
  // 为前几个持仓股票生成模拟新闻
  for (int i = 0; i < holdings.length && i < 3; i++) {
    final holding = holdings[i];
    
    mockNews.addAll([
      FundNews(
        id: 'h${i}1',
        title: '${holding.name}发布最新财报，业绩超预期',
        summary: '${holding.name}今日发布财报，净利润同比增长15%，超出市场预期。分析师普遍上调目标价...',
        url: 'https://finance.eastmoney.com/a/h${i}1.html',
        publishTime: '2025-06-20 09:30',
        source: '财经网',
        sentiment: NewsSentiment.positive,
      ),
      FundNews(
        id: 'h${i}2',
        title: '${holding.name}获得机构增持评级',
        summary: '多家知名券商发布研报，给予${holding.name}增持评级。分析师认为公司在行业中具备竞争优势...',
        url: 'https://finance.eastmoney.com/a/h${i}2.html',
        publishTime: '2025-06-19 14:20',
        source: '证券时报',
        sentiment: NewsSentiment.positive,
      ),
      FundNews(
        id: 'h${i}3',
        title: '${holding.name}行业政策利好，板块整体上涨',
        summary: '相关行业政策出台，对${holding.name}所在行业形成利好。业内专家认为这将提升公司盈利能力...',
        url: 'https://finance.eastmoney.com/a/h${i}3.html',
        publishTime: '2025-06-18 10:15',
        source: '中国证券报',
        sentiment: NewsSentiment.positive,
      ),
    ]);
  }
  
  return mockNews;
}

/// 真实的新闻数据生成函数（模拟）
List<FundNews> _getMockNews(String fundCode) {
  List<FundNews> mockNews = [
    FundNews(
      id: '1',
      title: '市场震荡加剧，如何优化基金投资策略？',
      summary: '近期市场波动加大，投资者应如何调整基金投资组合以应对不确定性？专家建议关注长期价值投资...',
      url: 'https://finance.eastmoney.com/a/1.html',
      publishTime: '2025-06-20 09:30',
      source: '东方财富网',
      sentiment: NewsSentiment.neutral,
    ),
    FundNews(
      id: '2',
      title: '$fundCode 基金最新季报分析',
      summary: '该基金在最新季度中表现稳健，重仓股调整符合市场预期。基金经理表示看好未来市场机会...',
      url: 'https://finance.eastmoney.com/a/2.html',
      publishTime: '2025-06-19 14:20',
      source: '天天基金网',
      sentiment: NewsSentiment.positive,
    ),
    FundNews(
      id: '3',
      title: '行业监管政策收紧，相关基金面临调整压力',
      summary: '最新监管政策对相关行业产生影响，部分基金可能需要调整投资策略以适应新环境...',
      url: 'https://finance.eastmoney.com/a/3.html',
      publishTime: '2025-06-18 10:15',
      source: '中国证券报',
      sentiment: NewsSentiment.negative,
    ),
    FundNews(
      id: '4',
      title: '基金经理观点：市场处于估值底部区域',
      summary: '知名基金经理表示当前市场估值已经处于历史低位，具备长期投资价值，建议投资者保持耐心...',
      url: 'https://finance.eastmoney.com/a/4.html',
      publishTime: '2025-06-17 16:45',
      source: '上海证券报',
      sentiment: NewsSentiment.positive,
    ),
    FundNews(
      id: '5',
      title: '全球经济形势展望季度报告',
      summary: '国际机构发布最新全球经济展望报告，对主要经济体增长预期进行调整...',
      url: 'https://finance.eastmoney.com/a/5.html',
      publishTime: '2025-06-16 11:30',
      source: '证券时报',
      sentiment: NewsSentiment.neutral,
    ),
    FundNews(
      id: '6',
      title: '$fundCode 基金分红公告，单位份额分红0.2元',
      summary: '根据基金收益情况，决定向基金份额持有人进行分红，预计下周一派发...',
      url: 'https://fund.eastmoney.com/$fundCode.html',
      publishTime: '2025-06-15 09:00',
      source: '基金公司公告',
      sentiment: NewsSentiment.positive,
    ),
    FundNews(
      id: '7',
      title: '基金经理更换，对基金投资策略有何影响？',
      summary: '基金公司公告显示，原基金经理因个人原因离职，新任基金经理将维持现有投资策略...',
      url: 'https://finance.eastmoney.com/a/7.html',
      publishTime: '2025-06-14 15:40',
      source: '中国基金报',
      sentiment: NewsSentiment.neutral,
    ),
    FundNews(
      id: '8',
      title: '市场资金面宽松，债基收益有望提升',
      summary: '央行最新货币政策报告显示，将继续实施稳健的货币政策，市场流动性保持合理充裕...',
      url: 'https://finance.eastmoney.com/a/8.html',
      publishTime: '2025-06-13 10:25',
      source: '财经杂志',
      sentiment: NewsSentiment.positive,
    ),
  ];
  
  return mockNews;
}