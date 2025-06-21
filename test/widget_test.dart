import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

// 示例：获取天天基金网某基金的净值信息
Future<Map<String, dynamic>> fetchFundNetValue(String fundCode) async {
  final url = Uri.parse(
    'https://fundgz.1234567.com.cn/js/$fundCode.js?rt=${DateTime.now().millisecondsSinceEpoch}',
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
    return json.decode(jsonStr);
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
  final url = Uri.parse(
    'https://api.fund.eastmoney.com/f10/lsjz?callback=&fundCode=$fundCode&pageIndex=$page&pageSize=$perPage&startDate=&endDate=&_=${DateTime.now().millisecondsSinceEpoch}',
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
    final List<dynamic> data = jsonMap['Data']['LSJZList'];
    return data.cast<Map<String, dynamic>>();
  } else {
    throw Exception('Failed to load fund history');
  }
}

/// 计算最近的最大回撤（最大回撤率）
/// [history] 为按时间倒序（最近在前）的历史净值数据
List<dynamic> calculateMaxDrawdown(List<Map<String, dynamic>> history) {
  double maxValue = 0;

  final List<double> draw_list = [];
  for (int i = 0; i < history.length; i++) {
    double curValue = double.tryParse(history[i]['DWJZ']) ?? 0.0;
    if (curValue > maxValue) {
      maxValue = curValue;
    }
    double draw = (maxValue - curValue) / maxValue;
    draw_list.add(draw);
  }
  return draw_list;
}

bool buyStrategy(List<dynamic> draw_list, int idx, {double downrate = 0.1}) {
  if (draw_list[idx] > downrate) {
    return true;
  }
  return false;
}

/// 按自定义策略模拟加仓，计算收益
/// [history] 历史净值数据（按时间倒序，最近在前）
/// [buyStrategy] 自定义加仓策略，返回true表示当天加仓
/// [initAmount] 初始投入金额
/// [buyAmount] 每次加仓金额
Map<String, dynamic> simulateBuyStrategy(
  List<Map<String, dynamic>> history, {
  required bool Function(List<dynamic> draw_list, int idx, {double downrate})
  buyStrategy,
  double initAmount = 1000.0,
  double buyAmount = 1000.0,
  double rate = 0.1,
}) {
  if (history.isEmpty) return {};
  final rhistory = history.reversed.toList();
  var draw_list = calculateMaxDrawdown(rhistory);
  double totalShares = 0.0;
  double totalInvested = 0.0;
  List<Map<String, dynamic>> actions = [];
  // 初始投入
  var first = rhistory.first;
  double firstNetValue = double.tryParse(first['DWJZ']) ?? 0.0;
  if (firstNetValue > 0) {
    totalShares += initAmount / firstNetValue;
    totalInvested += initAmount;
    actions.add({
      'date': first['FSRQ'],
      'action': 'init',
      'amount': initAmount,
      'netValue': firstNetValue,
      'shares': totalShares,
      'totalInvested': totalInvested,
    });
  }

  for (int i = 1; i < rhistory.length; i++) {
    var day = rhistory[i];
    double netValue = double.tryParse(day['DWJZ']) ?? 0.0;
    if (netValue <= 0) continue;
    if (buyStrategy(draw_list, i, downrate: rate)) {
      totalShares += buyAmount / netValue;
      totalInvested += buyAmount;
      actions.add({
        'date': day['FSRQ'],
        'action': 'buy',
        'amount': buyAmount,
        'netValue': netValue,
        'shares': totalShares,
        'totalInvested': totalInvested,
      });
    }
  }

  // 计算当前市值和收益
  var last = rhistory.last;
  double lastNetValue = double.tryParse(last['DWJZ']) ?? 0.0;
  double currentValue = totalShares * lastNetValue;
  double profit = currentValue - totalInvested;
  double profitRate = totalInvested > 0 ? profit / totalInvested : 0.0;

  return {
    'totalInvested': totalInvested,
    'currentValue': currentValue,
    'profit': profit,
    'profitRate': profitRate,
    'totalShares': totalShares,
    'lastNetValue': lastNetValue,
    'actions': actions,
  };
}

void main() async {
  List<String> codes = ['016573'];
  for (var code in codes) {
    var info = await fetchFundNetValue(code);

    var history = await fetchFundHistory(code, perPage: 30);
    var drawList = calculateMaxDrawdown(history);

    var gain = simulateBuyStrategy(
      history,
      initAmount: 5000.0,
      buyAmount: 500,
      buyStrategy: buyStrategy,
      rate: 0.005,
    );
    double rate = gain['profitRate'];
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print(info['name']);
    print("最近回撤 ${drawList.last}");
    print('总投入 ${gain['totalInvested']}');
    print('当前 ${gain['currentValue']}');
    print('收益 ${gain['profit']}');
    print('收益率 ${(rate.toStringAsFixed(3))}');
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print('');
  }
}
