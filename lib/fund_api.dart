// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'news.dart';

/// 一条持仓记录的数据结构
class HoldingItem {
  final String name; // 股票名称
  final String code; // 股票代码（原始字符串，可能带 SH/SZ/HK）
  final String percent; // 占净值比例（已带 %）
  final double marketValue; // 持仓市值（亿元）
  double? changePct; // 当日涨跌幅(%)；null 表示未抓到行情

  HoldingItem({
    required this.name,
    required this.code,
    required this.percent,
    required this.marketValue,
    this.changePct,
  });

  factory HoldingItem.fromMap(Map<String, dynamic> map) => HoldingItem(
    name: map['name'],
    code: map['code'],
    percent: map['percent'],
    marketValue: map['marketValue'],
    changePct: map['changePct'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'code': code,
    'percent': percent,
    'marketValue': marketValue,
    'changePct': changePct,
  };
}

/// 解析形如 temp.log 的非标 JSON/HTML 混合格式
Future<List<FundNews>> fetchNews(String name) async {
  var param = {
    "uid": "",
    "keyword": name,
    "type": ["cmsArticleWebOld"],
    "client": "web",
    "clientType": "web",
    "clientVersion": "curr",
    "param": {
      "cmsArticleWebOld": {
        "searchScope": "title",
        "sort": "default",
        "pageIndex": 1,
        "pageSize": 10,
        "preTag": "<em>",
        "postTag": "</em>",
      },
    },
  };
  final jsonStr = jsonEncode(param);
  final uri = Uri.https("search-api-web.eastmoney.com", "/search/jsonp", {
    'cb': 'jQuery351029815737696449274_1753697613133',
    'param': jsonStr,
  });
  final response = await http.get(uri);
  final rawText = response.body;

  final openBrace = rawText.indexOf('{');
  final closeBrace = rawText.lastIndexOf('}');
  final jsonText = rawText.substring(openBrace, closeBrace + 1);
  List<FundNews> newsList = [];
  final json = jsonDecode(jsonText);
  for (var item in json['result']['cmsArticleWebOld'].sublist(0, 5)) {
    NewsSentiment newsSentiment = analyzeSentiment(item['content']);
    var curNew = FundNews(
      id: item['code'],
      title: item['title']
          .toString()
          .replaceAll('<em>', '')
          .replaceAll('</em>', ''),
      summary: item['content'],
      url: item['url'],
      publishTime: item['date'],
      source: item['mediaName'],
      sentiment: newsSentiment,
    );
    newsList.add(curNew);
  }
  return newsList;
}

NewsSentiment analyzeSentiment(item) {
  final content = item['content'] ?? '';
  final positiveWords = ['好', '上涨', '增长', '强劲', '利好'];
  final negativeWords = ['坏', '下跌', '减少', '疲软', '利空'];

  int positiveCount = 0;
  int negativeCount = 0;

  for (var word in positiveWords) {
    if (content.contains(word)) positiveCount++;
  }
  for (var word in negativeWords) {
    if (content.contains(word)) negativeCount++;
  }

  if (positiveCount > negativeCount) {
    return NewsSentiment.positive;
  } else if (negativeCount > positiveCount) {
    return NewsSentiment.negative;
  } else {
    return NewsSentiment.neutral;
  }
}

/// 解析形如 temp.log 的非标 JSON/HTML 混合格式
Future<List<HoldingItem>> parseQuarterlyHoldingsFromHtmlText(
  String rawText,
) async {
  // 1️⃣ 取出真正的 JSON 片段
  final openBrace = rawText.indexOf('"');
  final closeBrace = rawText.lastIndexOf('"');
  if (openBrace == -1 || closeBrace == -1) {
    throw FormatException('不是合法的 JSONP 格式');
  }
  final html = rawText.substring(openBrace, closeBrace + 1);
  // final map = jsonDecode(jsonPart) as Map<String, dynamic>;

  // 2️⃣ 拿到 HTML
  // final html = map['content'] as String;
  final doc = parser.parse(html);

  // 3️⃣ 遍历每一个 table（即每一季度）
  final tables = doc.querySelectorAll('table');
  final List<HoldingItem> latestQuarterItems = [];

  // 我们只想要最新的一季（第一个 table）
  if (tables.isEmpty) return latestQuarterItems;
  final rows = tables.first.querySelectorAll('tr');

  for (var i = 1; i < rows.length; i++) {
    final cells = rows[i].querySelectorAll('td');
    if (cells.length < 6) continue;

    final name = cells[2].text.trim();
    final code = cells[1].text.trim();
    final percent = cells[6].text.trim();
    final mvWan = double.tryParse(cells[8].text.trim()) ?? 0.0;

    latestQuarterItems.add(
      HoldingItem(
        name: name,
        code: code,
        percent: percent,
        marketValue: mvWan// 10000 , // 万元→亿元
      ),
    );
  }

  return latestQuarterItems;
}

/// 1️⃣ 天天基金网 – 基金前十大持仓
Future<List<HoldingItem>> fetchFundPortfolioHoldEm({
  required String symbol,
  String year = '2025',
}) async {
  String host = "";

  host = 'https://fundf10.eastmoney.com';

  final uri = Uri.parse('$host/FundArchivesDatas.aspx').replace(
    queryParameters: {
      'type': 'jjcc',
      'code': symbol,
      'topline': '100',
      'year': year,
      'month': '',
      'rt': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );

  final resp = await http.get(uri);
  final raw = resp.body;
  final List<HoldingItem> results = await parseQuarterlyHoldingsFromHtmlText(
    raw,
  );

  return results;
}

/// 2️⃣ 根据持仓代码实时抓取涨跌幅

/// 整合函数：先拿持仓，再补行情
Future<List<HoldingItem>> getFundHoldingsWithQuote(String fundCode) async {
  final holdings = await fetchFundPortfolioHoldEm(symbol: fundCode);
  return holdings;
}
