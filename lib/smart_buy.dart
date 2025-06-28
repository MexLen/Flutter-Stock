import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fetch.dart';
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
  var draw_list = calculateMaxDrawdown(history);
  double totalShares = 0.0;
  double totalInvested = 0.0;
  List<Map<String, dynamic>> actions = [];
  // 初始投入
  var first = history.first;
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

  for (int i = 1; i < history.length; i++) {
    var day = history[i];
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
  var last = history.last;
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





class SimulateChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> actions;

  const SimulateChart({Key? key, required this.history, required this.actions})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 净值线
    List<FlSpot> netValueSpots = [];
    for (int i = 0; i < history.length; i++) {
      double netValue = double.tryParse(history[i]['DWJZ']) ?? 0.0;
      netValueSpots.add(FlSpot(i.toDouble(), netValue));
    }

    // 买点
    List<FlSpot> buySpots = [];
    for (var action in actions) {
      if (action['action'] == 'buy' || action['action'] == 'init') {
        int idx = history.indexWhere((h) => h['FSRQ'] == action['date']);
        if (idx != -1) {
          double netValue = double.tryParse(history[idx]['DWJZ']) ?? 0.0;
          buySpots.add(FlSpot(idx.toDouble(), netValue));
        }
      }
    }

    return LineChart(
      LineChartData(
        minY:
            netValueSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b) *
            0.98,
        maxY:
            netValueSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) *
            1.02,
        lineBarsData: [
          LineChartBarData(
            spots: netValueSpots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: buySpots,
            isCurved: false,
            color: Colors.red,
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.red,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
            ),
          ),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}