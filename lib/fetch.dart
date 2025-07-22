import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class Fund {
  String fundcode; // "016573"
  String name; // -> "招商中证银行AH价格优选ETF发起式联接C"
  String jzrq; // -> "2025-06-20"  昨日时间
  double dwjz; //"1.4873"  昨日净值
  double gsz; // -> "1.5035"  净值估算
  double gszzl; // -> "1.09" 涨跌幅
  double back_th=1.0;//回撤超过多少进行提示加仓
  String gztime; // "2025-06-23 14:36" 当前时间
  
  List<dynamic> backdraw_list = [];
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> history90 = [];
  Fund({
    required this.fundcode,
    required this.name,
    required this.jzrq,
    required this.dwjz,
    required this.gsz,
    required this.gszzl,
    required this.gztime,
  });
  double gain_rate() {
    if (history.isEmpty) {
      return 0.0;
    }
    var base = double.parse(history.first["DWJZ"]);
    return (gsz - base) / base;
  }
}


/// 折线图版本的 FundChart（LineChart 已经是折线图）
/// 如果你想要更明显的折线效果（非平滑曲线），只需将 isCurved: false



// 用法示例：在FundLineChart外部包裹Stack，并传入Fund对象
// Stack(
//   children: [
//     FundLineChart(history: fund.history),
//     FundInfoHeader(fund: fund),
//   ],
// )
Future<Fund> findFund(String fundCode) async {
  // 根据平台或者是否是浏览器选择HOST
  // dart:io 的 Platform 不能在 web 上用，需判断 kIsWeb
  String host;
  if (identical(0, 0.0)) {
    // 运行在 Web
    host = 'http://localhost:8080/search';
  } else if (Platform.isAndroid) {
    host = 'https://fundgz.1234567.com.cn';
  } else {
    host = 'http://localhost:8080/search';
  }
  // #016343
  final url = Uri.parse(
    '$host/js/$fundCode.js?rt=${DateTime.now().millisecondsSinceEpoch}',
  );
  final response = await http.get(
    url,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
      'Content-Type': 'application/javascript',

      // 可以根据需要添加更多header
    },
  );
  if (response.statusCode == 200) {
    // 设置header并用utf-8解码响应体
    final body = utf8.decode(response.bodyBytes);
    final jsonStr = body.substring(
      body.indexOf('{'),
      body.lastIndexOf('}') + 1,
    );
    var obj = json.decode(jsonStr);
    var fund = Fund(
      fundcode: obj['fundcode'],
      name: obj['name'],
      jzrq: obj['jzrq'],
      dwjz: double.parse(obj['dwjz']),
      gsz: double.parse(obj['gsz']),
      gszzl: double.parse(obj['gszzl']),
      gztime: obj['gztime'],
    );
    return fund;
  } else {
    throw Exception('Failed to load fund data');
  }
}

// 获取基金历史净值数据
Future<List<Map<String, dynamic>>> fetchFundHistory(
  String fundCode, {
  int page = 1,
  int perPage = 20,
}) async {
  // 天天基金历史净值接口
  String host;
  if (identical(0, 0.0)) {
    // 运行在 Web
    host = 'http://localhost:8080/api';
  } else if (Platform.isAndroid) {
    host = 'https://api.fund.eastmoney.com';
  } else {
    host = 'http://localhost:8080/api';
  }
  final url = Uri.parse(
    '$host/f10/lsjz?callback=&fundCode=$fundCode&pageIndex=$page&pageSize=$perPage&startDate=&endDate=&_=${DateTime.now().millisecondsSinceEpoch}',
  );
  final response = await http.get(
    url,
    headers: {
      'Referer': 'https://fundf10.eastmoney.com/',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    },
  );
  utf8.decode(response.bodyBytes);
  if (response.statusCode == 200) {
    final body = utf8.decode(response.bodyBytes);
    final jsonMap = json.decode(body);
    final List<dynamic> data = jsonMap['Data']['LSJZList'];
    return data.cast<Map<String, dynamic>>().reversed.toList();
  } else {
    throw Exception('Failed to load fund history');
  }
}

/// 获取基金持仓信息（前十大重仓股）
/// 返回格式：List<Map<String, dynamic>>，每个map包含股票名称、代码、占比等
Future<List<Map<String, dynamic>>> fetchFundHoldings(String fundCode) async {
  String host;
  if (identical(0, 0.0)) {
    // Web
    host = 'http://localhost:8080/api';
  } else if (Platform.isAndroid) {
    host = 'https://fundmobapi.eastmoney.com';
  } else {
    host = 'http://localhost:8080/api';
  }
  final url = Uri.parse(
    '$host/FundMNewApi/FundMNInverstPositionList?FCODE=$fundCode',
  );
  final response = await http.get(
    url,
    headers: {
      'Referer': 'https://fundf10.eastmoney.com/',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    },
  );
  if (response.statusCode == 200) {
    final body = utf8.decode(response.bodyBytes);
    final jsonMap = json.decode(body);
    // 解析前十大重仓股
    final List<dynamic> stocks = jsonMap['Datas']?[0]?['GPList'] ?? [];
    return stocks.cast<Map<String, dynamic>>();
  } else {
    throw Exception('Failed to load fund holdings');
  }
}

List<dynamic> calculateMaxDrawdown(List<Map<String, dynamic>> history) {
  double maxValue = 0;
  final List<double> drawList = [];
  for (int i = 0; i < history.length; i++) {
    double curValue = double.tryParse(history[i]['DWJZ']) ?? 0.0;
    if (curValue > maxValue) {
      maxValue = curValue;
    }
    double draw = (maxValue - curValue) / maxValue;
    drawList.add(draw);
  }
  return drawList;
}

bool buyStrategy(List<dynamic> drawList, int idx, {double downrate = 0.1}) {
  if (drawList[idx] > downrate) {
    return true;
  }
  return false;
}

Future<List<Map<String, dynamic>>> fetchFundTopHoldingsFromEastmoney(
  String fundCode,
) async {
  String host;
  if (identical(0, 0.0)) {
    // Web
    host = 'http://localhost:8080/find';
  } else if (Platform.isAndroid) {
    host = 'https://www.dayfund.cn';
  } else {
    host = 'http://localhost:8080/find';
  }
  final url = Uri.parse('$host/fundinfo/$fundCode.html');
  final response = await http.get(
    url,
    headers: {
      'Referer': 'https://www.dayfund.cn/',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    },
  );//https://fund.eastmoney.com/017867.html?spm=search
  if (response.statusCode == 200) {
    final body = utf8.decode(response.bodyBytes);
    var doc = parser.parse(body);
    var trs = doc.querySelectorAll('div.ownstock tr').sublist(1, 11);
    List<Map<String, dynamic>> holdings = [];
    for (final tr in trs) {
      var tds = tr.querySelectorAll('td');
      holdings.add({
        'code':tds.elementAt(0).text.trim(),
        'name': tds.elementAt(1).text.trim(),
        'percent': tds.elementAt(3).text.trim(),
        'marketValue': tds.elementAt(4).text.trim(),
      });
    }
    // 提取持仓表格数据
    return holdings;
  }
  return [];
}

// lib/top_holdings_page.dart


