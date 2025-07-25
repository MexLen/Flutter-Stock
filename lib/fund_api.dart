import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

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
  final tables = doc.querySelectorAll('table.w782.comm.tzxq.t2');
  final List<HoldingItem> latestQuarterItems = [];

  // 我们只想要最新的一季（第一个 table）
  if (tables.isEmpty) return latestQuarterItems;
  final rows = tables.first.querySelectorAll('tr');

  for (var i = 1; i < rows.length; i++) {
    final cells = rows[i].querySelectorAll('td');
    if (cells.length < 6) continue;

    final name = cells[2].text.trim();
    final code = cells[1].text.trim();
    final percent = cells[4].text.trim();
    final mvWan = double.tryParse(cells[5].text.trim()) ?? 0.0;

    latestQuarterItems.add(
      HoldingItem(
        name: name,
        code: code,
        percent: percent,
        marketValue: mvWan / 10000, // 万元→亿元
      ),
    );
  }

  return latestQuarterItems;
}

/// 1️⃣ 天天基金网 – 基金前十大持仓
Future<List<HoldingItem>> fetchFundPortfolioHoldEm({
  required String symbol,
  String year = '2024',
}) async {
  String host = "";
  if (identical(0, 0.0)) {
    // Web
    host = 'http://localhost:8080/eastmoney';
  } else if (Platform.isAndroid) {
    host = 'https://fundmobapi.eastmoney.com';
  } else {
    host = 'http://localhost:8080/eastmoney';
  }
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
