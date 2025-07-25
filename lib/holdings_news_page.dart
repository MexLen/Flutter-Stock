import 'package:flutter/material.dart';
import 'news.dart';
import 'fund_api.dart';
import 'package:url_launcher/url_launcher.dart';

class HoldingsNewsPage extends StatefulWidget {
  final List<HoldingItem> holdings;
  final String fundCode;

  const HoldingsNewsPage({
    Key? key,
    required this.holdings,
    required this.fundCode,
  }) : super(key: key);

  @override
  State<HoldingsNewsPage> createState() => _HoldingsNewsPageState();
}

class _HoldingsNewsPageState extends State<HoldingsNewsPage> {
  late Future<List<FundNews>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _newsFuture = fetchHoldingsNews(widget.holdings);
    });
  }

  Future<void> _refreshNews() async {
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓股票新闻'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        child: FutureBuilder<List<FundNews>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            } else if (snapshot.hasError) {
              return _buildErrorWidget(snapshot.error.toString());
            } else if (snapshot.hasData) {
              final newsList = snapshot.data!;
              if (newsList.isEmpty) {
                return _buildEmptyWidget();
              }
              return _buildNewsList(newsList, context); // 传递context
            } else {
              return _buildEmptyWidget();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载持仓股票新闻...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text('加载新闻失败: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadNews,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无相关股票新闻',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList(List<FundNews> newsList, BuildContext context) {
    return ListView.builder(
      itemCount: newsList.length,
      itemBuilder: (context, index) {
        final news = newsList[index];
        return _NewsItem(news: news, context: context); // 传递context
      },
    );
  }
}

class _NewsItem extends StatelessWidget {
  final FundNews news;
  final BuildContext context; // 添加context参数

  const _NewsItem({required this.news, required this.context});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _launchURL(news.url, context), // 传递context
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 情感标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getSentimentColor(news.sentiment),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getSentimentText(news.sentiment),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 来源
                  Text(
                    news.source,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  // 时间
                  Text(
                    news.publishTime,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 标题
              Text(
                news.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 摘要
              Text(
                news.summary,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // 阅读更多
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '阅读全文',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSentimentColor(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return Colors.green;
      case NewsSentiment.negative:
        return Colors.red;
      case NewsSentiment.neutral:
        return Colors.grey;
    }
  }

  String _getSentimentText(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return '利好';
      case NewsSentiment.negative:
        return '利空';
      case NewsSentiment.neutral:
        return '中性';
    }
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开链接: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}