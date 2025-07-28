// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'news.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io'; // 添加平台特定功能支持
import 'news.dart';

class FundNewsPage extends StatelessWidget {
  final List<FundNews> news_list;

  const FundNewsPage({Key? key, required this.news_list}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('相关新闻'), centerTitle: true),
      body: ListView.builder(
        itemCount: news_list.length,
        itemBuilder: (context, index) {
          return _NewsItem(news: news_list[index]);
        },
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  // 时间
                  Text(
                    news.publishTime,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
          SnackBar(content: Text('无法打开链接: $url'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
