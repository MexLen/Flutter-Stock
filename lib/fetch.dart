import 'dart:convert';
import 'package:http/http.dart' as http;

class Fund {
  String fundcode; // "016573"
  String name; // -> "招商中证银行AH价格优选ETF发起式联接C"
  String jzrq; // -> "2025-06-20"  昨日时间
  double dwjz; //"1.4873"  昨日净值
  double gsz; // -> "1.5035"  净值估算
  double gszzl; // -> "1.09" 涨跌幅
  double back_th = 1.0; //回撤超过多少进行提示加仓
  String gztime; // "2025-06-23 14:36" 当前时间

  List<dynamic> backdraw_list = [];
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> history90 = [];

  // 原有的 fromMap 工厂方法
  factory Fund.fromMap(Map<String, dynamic> m) => Fund(
    fundcode: m['code'].toString(),
    name: m['name'],
    jzrq: "",
    dwjz: 0,
    gsz: 0,
    gszzl: 0,
    gztime: "0000 00:00:00",
  );

  // 新增：从数据库 Map 创建 Fund 对象的工厂方法
  factory Fund.fromDbMap(Map<String, dynamic> map) => Fund(
    fundcode: map['fundcode'] as String? ?? '',
    name: map['name'] as String? ?? '',
    jzrq: "",
    dwjz: 0,
    gsz: 0,
    gszzl: 0,
    gztime: "0000-00-00 00:00:00",
  );

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

  // 新增：转换为数据库 Map（只包含需要存储的字段）
  Map<String, dynamic> toDbMap() {
    return {'fundcode': fundcode, 'name': name};
  }

  @override
  String toString() {
    return 'Fund{fundcode: $fundcode, name: $name}';
  }
}

Future<Fund> findFund(String fundCode) async {
  // 根据平台或者是否是浏览器选择HOST
  // dart:io 的 Platform 不能在 web 上用，需判断 kIsWeb
  String host;
  host = 'https://fundgz.1234567.com.cn';

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

DateTime getPeriod(int months) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - months, now.day-1);
}

Future<List<Map<String, dynamic>>> fetchFundHistory(
  String fundCode, {
  int month = 1,
}) async {
  // 新浪财经基金历史净值接口

  final url = Uri.parse(
    'http://stock.finance.sina.com.cn/fundInfo/api/openapi.php/CaihuiFundInfoService.getNav?symbol=$fundCode&page=1&num=200',
  );
  DateTime startDate = getPeriod(month);
  final response = await http.get(url);
  List<Map<String, dynamic>> history = [];
  if (response.statusCode == 200) {
    final body = utf8.decode(response.bodyBytes);
    final jsonMap = json.decode(body);

    // 检查返回结果是否成功
    if (jsonMap['result'] != null && jsonMap['result']['data'] != null) {
      final data = jsonMap['result']['data']['data'];
      for (var his in data) {
        var date = DateTime.parse(his['fbrq'].toString());
        if (date.isBefore(startDate)) {
          break;
        }
        history.add({
          'DATE': his['fbrq'],
          'DWJZ': his['jjjz'],
          'LJJZ': his['ljjz'],
        });
      }
      if (data != null) {
        return history.reversed.toList();
      }
    }

    throw Exception('Failed to parse fund history data from Sina');
  } else {
    throw Exception('Failed to load fund history from Sina');
  }
}
/// 获取基金持仓信息（前十大重仓股）
/// 返回格式：List<Map<String, dynamic>>，每个map包含股票名称、代码、占比等

List<dynamic> calculateMaxDrawdown(List<Map<String, dynamic>> history) {
  double maxValue = 0;
  final List<double> drawList = [];
  for (int i = 0; i < history.length; i++) {
    double curValue = double.parse(history[i]['DWJZ'] ?? '0');
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

// lib/top_holdings_page.dart
