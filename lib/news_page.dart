// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'news.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io'; // 添加平台特定功能支持

class FundNewsPage extends StatefulWidget {
  final String fundCode;
  final String fundName;

  const FundNewsPage({
    Key? key,
    required this.fundCode,
    required this.fundName,
  }) : super(key: key);

  @override
  State<FundNewsPage> createState() => _FundNewsPageState();
}

class _FundNewsPageState extends State<FundNewsPage> {
  late Future<List<FundNews>> _newsFuture;
  final ScrollController _scrollController = ScrollController();
  final List<FundNews> _newsList = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
    
    // 添加滚动监听器以实现无限滚动加载
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNews();
    }
  }

  Future<void> _loadNews() async {
    setState(() {
      _newsFuture = fetchFundNews(widget.fundCode, page: 1, pageSize: 10);
    });
    
    try {
      final news = await _newsFuture;
      if (!mounted) return; // 检查组件是否仍然挂载
      
      setState(() {
        _newsList.clear();
        _newsList.addAll(news);
        _currentPage = 1;
        _hasMore = news.length == 10; // 如果返回少于请求数量，说明没有更多数据
      });
    } catch (e) {
      if (!mounted) return; // 检查组件是否仍然挂载
      // 错误处理在FutureBuilder中完成
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final news = await fetchFundNews(
        widget.fundCode, 
        page: _currentPage + 1, 
        pageSize: 10
      );
      
      if (!mounted) return; // 检查组件是否仍然挂载
      
      setState(() {
        _newsList.addAll(news);
        _currentPage++;
        _hasMore = news.length == 10; // 如果返回少于请求数量，说明没有更多数据
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return; // 检查组件是否仍然挂载
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载更多新闻失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshNews() async {
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              return _buildNewsList();
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
          Text('正在加载新闻...'),
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
            '暂无相关新闻',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _newsList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _newsList.length) {
          // 显示加载指示器
          return _isLoading 
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            : Container();
        }
        
        final news = _newsList[index];
        return _NewsItem(news: news);
      },
    );
  }
}

class _NewsItem extends StatelessWidget {
  final FundNews news;

  const _NewsItem({required this.news});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _launchURL(news.url, context),
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