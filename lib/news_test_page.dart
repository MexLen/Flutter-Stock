import 'package:flutter/material.dart';
import 'news.dart';

class NewsTestPage extends StatefulWidget {
  final String fundCode;
  
  const NewsTestPage({Key? key, required this.fundCode}) : super(key: key);

  @override
  State<NewsTestPage> createState() => _NewsTestPageState();
}

class _NewsTestPageState extends State<NewsTestPage> {
  late Future<List<FundNews>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = fetchFundNews(widget.fundCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新闻测试 - ${widget.fundCode}'),
      ),
      body: FutureBuilder<List<FundNews>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取新闻...'),
                ],
              ),
            );
          } else if (snapshot.hasError) {
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
                  Text('获取新闻失败: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _newsFuture = fetchFundNews(widget.fundCode);
                      });
                    },
                    child: const Text('重新获取'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final newsList = snapshot.data!;
            if (newsList.isEmpty) {
              return const Center(
                child: Text('暂无新闻'),
              );
            }
            
            return ListView.builder(
              itemCount: newsList.length,
              itemBuilder: (context, index) {
                final news = newsList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(news.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(news.summary),
                        const SizedBox(height: 4),
                        Row(
                          children: [
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
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${news.source} ${news.publishTime}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(
              child: Text('暂无数据'),
            );
          }
        },
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
}