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

class BuyPointTooltip extends StatelessWidget {
  final String date;
  final double netValue;

  const BuyPointTooltip({Key? key, required this.date, required this.netValue})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '$date\n净值: ${netValue.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
}

class SimulateChartWithTooltip extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> actions;

  const SimulateChartWithTooltip({
    Key? key,
    required this.history,
    required this.actions,
  }) : super(key: key);

  @override
  State<SimulateChartWithTooltip> createState() =>
      _SimulateChartWithTooltipState();
}

class _SimulateChartWithTooltipState extends State<SimulateChartWithTooltip> {
  FlSpot? selectedSpot;
  String? selectedDate;
  double? selectedNetValue;
  Offset? tapPosition;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> netValueSpots = [];
    for (int i = 0; i < widget.history.length; i++) {
      double netValue = double.tryParse(widget.history[i]['DWJZ']) ?? 0.0;
      netValueSpots.add(FlSpot(i.toDouble(), netValue));
    }

    List<FlSpot> buySpots = [];
    List<String> buyDates = [];
    for (var action in widget.actions) {
      if (action['action'] == 'buy' ||
          action['action'] == 'init' ||
          action['action'] == 'dca') {
        int idx = widget.history.indexWhere((h) => h['FSRQ'] == action['date']);
        if (idx != -1) {
          double netValue = double.tryParse(widget.history[idx]['DWJZ']) ?? 0.0;
          buySpots.add(FlSpot(idx.toDouble(), netValue));
          buyDates.add(action['date']);
        }
      }
    }

    return GestureDetector(
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);

        final chartWidth = box.size.width;
        final chartHeight = box.size.height;

        // Find the closest buy spot to the tap
        double minDist = double.infinity;
        int? minIdx;
        for (int i = 0; i < buySpots.length; i++) {
          final spot = buySpots[i];
          // Map spot.x/y to pixel coordinates
          double x = spot.x / (netValueSpots.length - 1) * chartWidth;
          double minY =
              netValueSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b) *
              0.98;
          double maxY =
              netValueSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) *
              1.02;
          double y =
              chartHeight - ((spot.y - minY) / (maxY - minY) * chartHeight);

          double dist = (localPos.dx - x).abs() + (localPos.dy - y).abs();
          if (dist < minDist && dist < 30) {
            minDist = dist;
            minIdx = i;
          }
        }
        if (minIdx != null) {
          setState(() {
            selectedSpot = buySpots[minIdx!];
            selectedDate = buyDates[minIdx!];
            selectedNetValue = buySpots[minIdx!].y;
            tapPosition = details.globalPosition;
          });
        } else {
          setState(() {
            selectedSpot = null;
            selectedDate = null;
            selectedNetValue = null;
            tapPosition = null;
          });
        }
      },
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minY:
                  netValueSpots
                      .map((e) => e.y)
                      .reduce((a, b) => a < b ? a : b) *
                  0.98,
              maxY:
                  netValueSpots
                      .map((e) => e.y)
                      .reduce((a, b) => a > b ? a : b) *
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
          ),
          if (selectedSpot != null &&
              selectedDate != null &&
              tapPosition != null)
            Positioned(
              left: 20,
              top: 20,
              child: BuyPointTooltip(
                date: selectedDate!,
                netValue: selectedNetValue!,
              ),
            ),
        ],
      ),
    );
  }
}

class SmartBuyPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const SmartBuyPage({Key? key, required this.history}) : super(key: key);

  @override
  State<SmartBuyPage> createState() => _SmartBuyPageState();
}

class _SmartBuyPageState extends State<SmartBuyPage> {
  double initAmount = 1000.0;
  double buyAmount = 1000.0;
  double downRate = 0.01;
  late Map<String, dynamic> result;

  @override
  void initState() {
    super.initState();
    _simulate();
  }

  void _simulate() {
    // 示例策略：当最大回撤超过downRate时加仓
    bool buyStrategy(List<dynamic> drawList, int idx, {double downrate = 0.1}) {
      if (idx < 0 || idx >= drawList.length) return false;
      var draw = drawList[idx];
      if (drawList[idx] < drawList[idx - 1]) {
        return false;
      }
      if (draw > 0) {
        return (draw as double) >= downrate;
      }
      return false;
    }

    result = simulateBuyStrategy(
      widget.history,
      buyStrategy: buyStrategy,
      initAmount: initAmount,
      buyAmount: buyAmount,
      rate: downRate,
    );
  }

  @override
  void didUpdateWidget(covariant SmartBuyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      _simulate();
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? unit,
  }) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label:
                unit != null
                    ? '${(value * 100).toStringAsFixed(1)}$unit'
                    : value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            unit != null
                ? '${(value * 100).toStringAsFixed(1)}$unit'
                : value.toStringAsFixed(0),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> actions = result['actions'] ?? [];
    double profit = result['profit'] ?? 0.0;
    double profitRate = result['profitRate'] ?? 0.0;
    double totalInvested = result['totalInvested'] ?? 0.0;
    double currentValue = result['currentValue'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('智能定投模拟')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildSlider(
              label: '回撤阈值',
              value: downRate,
              min: 0.001,
              max: 0.1,
              divisions: 100,
              unit: '%',
              onChanged: (v) {
                setState(() {
                  downRate = v;
                  _simulate();
                });
              },
            ),
            Row(
              children: [
                Expanded(child: Text('初始投入: ${initAmount.toStringAsFixed(0)}')),
                Expanded(child: Text('每次加仓: ${buyAmount.toStringAsFixed(0)}')),
                Expanded(
                  child: Text('回撤阈值: ${(downRate * 100).toStringAsFixed(1)}%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('总投入: ${totalInvested.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: Text('当前市值: ${currentValue.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: Text(
                    '收益: ${profit.toStringAsFixed(2)} (${(profitRate * 100).toStringAsFixed(2)}%)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SimulateChartWithTooltip(
                history: widget.history,
                actions: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可选：美化页面，增加卡片、阴影、间距、字体等
class SmartBuyPageStyled extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const SmartBuyPageStyled({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 6,
            margin: const EdgeInsets.all(1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: SmartBuyPage(history: history),
            ),
          ),
        ),
      ),
    );
  }
}


//生成一个你认为最优的智能买入策略，类似上面的代码同样生成页面和显示买卖点