import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class Fund {
  String fundcode; // "016573"
  String name; // -> "招商中证银行AH价格优选ETF发起式联接C"
  String jzrq; // -> "2025-06-20"  昨日时间
  double dwjz; //"1.4873"  昨日净值
  double gsz; // -> "1.5035"  净值估算
  double gszzl; // -> "1.09" 涨跌幅
  String gztime; // "2025-06-23 14:36" 当前时间
  List<dynamic> backdraw_list=[];
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
  double gain_rate(){
    if(history.isEmpty){
      return 0.0;
    }
    var base = double.parse(history.first["DWJZ"]);
    return (gsz - base) / base;
  }
}





/// 折线图版本的 FundChart（LineChart 已经是折线图）
/// 如果你想要更明显的折线效果（非平滑曲线），只需将 isCurved: false

class FundLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String title;

  const FundLineChart({
    Key? key,
    required this.history,
    this.title = '基金净值历史',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    final data = history;
    final spots = [
      for (int i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), double.tryParse(data[i]['DWJZ'] ?? '0') ?? 0)
    ];
    return Container(

      // elevation: 4,

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Colors.blueAccent,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withOpacity(0.08),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (spots.length / 4).clamp(1, spots.length.toDouble()),
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= data.length) return const SizedBox();
                          String date = data[idx]['FSRQ'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              date.length >= 5 ? date.substring(5) : date,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) -
                            spots.map((e) => e.y).reduce((a, b) => a < b ? a : b)) /
                        4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  // borderData: FlBorderData(
                  //   show: true,
                  //   border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  // ),
                  minY: spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.98,
                  maxY: spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.02,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class FundInfoHeader extends StatelessWidget {
  final Fund fund;
  const FundInfoHeader({Key? key, required this.fund}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rate = fund.gain_rate();
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(top: 60, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),        
        child: Text(
          '收益率 ${(rate * 100).toStringAsFixed(2)}%',
          style: TextStyle(
            color: rate >= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

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
  }  else {
    host = 'http://localhost:8080/search';
  }
  
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
      dwjz: double.parse(obj['dwjz']) ?? 0,
      gsz: double.parse(obj['gsz']) ?? 0,
      gszzl: double.parse(obj['gszzl']) ?? 0,
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
  }  else {
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
  final body = utf8.decode(response.bodyBytes);
  if (response.statusCode == 200) {
    final body = utf8.decode(response.bodyBytes);
    final jsonMap = json.decode(body);
    final List<dynamic> data = jsonMap['Data']['LSJZList'];
    return data.cast<Map<String, dynamic>>().reversed.toList();
  } else {
    throw Exception('Failed to load fund history');
  }
}


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


