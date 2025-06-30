/// 定投周期类型
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'smart_buy.dart';

enum DcaPeriodType { daily, weekly, monthly }

class DcaPeriodSetting {
  final DcaPeriodType type;
  final int? weekday; // 1-7, 周一到周日
  final int? monthDay; // 1-28

  DcaPeriodSetting.daily()
    : type = DcaPeriodType.daily,
      weekday = null,
      monthDay = null;
  DcaPeriodSetting.weekly(this.weekday)
    : type = DcaPeriodType.weekly,
      monthDay = null;
  DcaPeriodSetting.monthly(this.monthDay)
    : type = DcaPeriodType.monthly,
      weekday = null;
}

class DcaPeriodControl extends StatefulWidget {
  final void Function(DcaPeriodSetting) onChanged;
  final DcaPeriodSetting initial;

  const DcaPeriodControl({
    Key? key,
    required this.onChanged,
    required this.initial,
  }) : super(key: key);

  @override
  State<DcaPeriodControl> createState() => _DcaPeriodControlState();
}

class _DcaPeriodControlState extends State<DcaPeriodControl> {
  late String selectedPeriodType;
  late int selectedWeekday;
  late int selectedMonthDay;

  @override
  void initState() {
    super.initState();
    if (widget.initial.type == DcaPeriodType.daily) {
      selectedPeriodType = '每日';
      selectedWeekday = 4;
      selectedMonthDay = 23;
    } else if (widget.initial.type == DcaPeriodType.weekly) {
      selectedPeriodType = '每周';
      selectedWeekday = widget.initial.weekday ?? 4;
      selectedMonthDay = 23;
    } else {
      selectedPeriodType = '每月';
      selectedWeekday = 4;
      selectedMonthDay = widget.initial.monthDay ?? 23;
    }
  }

  void notifyParent() {
    if (selectedPeriodType == '每日') {
      widget.onChanged(DcaPeriodSetting.daily());
    } else if (selectedPeriodType == '每周') {
      widget.onChanged(DcaPeriodSetting.weekly(selectedWeekday));
    } else {
      widget.onChanged(DcaPeriodSetting.monthly(selectedMonthDay));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: selectedPeriodType,
          items:
              ['每日', '每周', '每月']
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
          onChanged: (value) {
            setState(() {
              selectedPeriodType = value!;
              notifyParent();
            });
          },
        ),
        if (selectedPeriodType == '每周')
          DropdownButton<int>(
            value: selectedWeekday,
            items: List.generate(
              5,
              (i) =>
                  DropdownMenuItem(value: i + 1, child: Text('周${'一二三四五'[i]}')),
            ),
            onChanged: (v) {
              setState(() {
                selectedWeekday = v!;
                notifyParent();
              });
            },
          ),
        if (selectedPeriodType == '每月')
          DropdownButton<int>(
            value: selectedMonthDay,
            items: List.generate(
              28,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}号')),
            ),
            onChanged: (v) {
              setState(() {
                selectedMonthDay = v!;
                notifyParent();
              });
            },
          ),
      ],
    );
  }
}

/// 定投模拟（支持周期设置）
Map<String, dynamic> simulateDCAWithPeriod(
  List<Map<String, dynamic>> history, {
  required DcaPeriodSetting period,
  double initAmount = 1000.0,
  double buyAmount = 1000.0,
}) {
  if (history.isEmpty) return {};
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
    DateTime date = DateTime.tryParse(day['FSRQ']) ?? DateTime(2000);
    bool shouldBuy = false;
    if (period.type == DcaPeriodType.daily) {
      shouldBuy = true;
    } else if (period.type == DcaPeriodType.weekly) {
      // DateTime.weekday: 1=Monday, ..., 7=Sunday
      shouldBuy = date.weekday == (period.weekday ?? 4);
    } else if (period.type == DcaPeriodType.monthly) {
      shouldBuy = date.day == (period.monthDay ?? 23);
    }
    if (shouldBuy) {
      totalShares += buyAmount / netValue;
      totalInvested += buyAmount;
      actions.add({
        'date': day['FSRQ'],
        'action': 'dca',
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

class SimulatedDCAPageWithControl extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const SimulatedDCAPageWithControl({Key? key, required this.history})
    : super(key: key);

  @override
  State<SimulatedDCAPageWithControl> createState() =>
      _SimulatedDCAPageWithControlState();
}

class _SimulatedDCAPageWithControlState
    extends State<SimulatedDCAPageWithControl> {
  late DcaPeriodSetting _period;
  late Map<String, dynamic> _result;

  @override
  void initState() {
    super.initState();
    _period = DcaPeriodSetting.weekly(4);
    _result = simulateDCAWithPeriod(widget.history, period: _period);
  }

  void _onPeriodChanged(DcaPeriodSetting newPeriod) {
    setState(() {
      _period = newPeriod;
      _result = simulateDCAWithPeriod(widget.history, period: _period);
    });
  }

  Widget _buildSummaryCard(
    String label,
    String value, {
    Color? color,
    IconData? icon,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color ?? Colors.blue, size: 22),
              SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profit = _result['profit'] ?? 0.0;
    final profitRate = (_result['profitRate'] ?? 0.0) * 100;
    final profitColor = profit >= 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: Text("模拟定投")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 周期选择控件
            Align(
              alignment: Alignment.centerLeft,
              child: DcaPeriodControl(
                initial: _period,
                onChanged: _onPeriodChanged,
              ),
            ),
            SizedBox(height: 12),
            // 汇总卡片
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryCard(
                    "总投资",
                    "${_result['totalInvested']?.toStringAsFixed(2) ?? '--'}",
                    icon: Icons.account_balance_wallet,
                  ),
                  _buildSummaryCard(
                    "当前市值",
                    "${_result['currentValue']?.toStringAsFixed(2) ?? '--'}",
                    icon: Icons.show_chart,
                  ),
                  _buildSummaryCard(
                    "盈利",
                    "${profit.toStringAsFixed(2)}",
                    color: profitColor,
                    icon: Icons.trending_up,
                  ),
                  _buildSummaryCard(
                    "收益率",
                    "${profitRate.toStringAsFixed(2)}%",
                    color: profitColor,
                    icon: Icons.percent,
                  ),
                  _buildSummaryCard(
                    "总份额",
                    "${_result['totalShares']?.toStringAsFixed(4) ?? '--'}",
                    icon: Icons.pie_chart,
                  ),
                  _buildSummaryCard(
                    "最后净值",
                    "${_result['lastNetValue']?.toStringAsFixed(4) ?? '--'}",
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // 图表
            if (_result['actions'] != null && _result['actions'].isNotEmpty)
              SizedBox(
                height: 180,
                child: SimulateChartWithTooltip(
                  history: widget.history,
                  actions: _result['actions'],
                ),
              ),
            SizedBox(height: 12),

            // 操作记录
          ],
        ),
      ),
    );
  }
}

class SimulatedDCAPage extends StatelessWidget {
  final List<Map<String, dynamic>> history; // 假设这是历史数据
  final DcaPeriodSetting period; // 假设这是定投周期设置

  SimulatedDCAPage({required this.history, required this.period});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> result = simulateDCAWithPeriod(
      history,
      period: period,
    );

    return Scaffold(
      appBar: AppBar(title: Text("模拟定投")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("总投资金额: ${result['totalInvested']}"),
            Text("当前市值: ${result['currentValue']}"),
            Text("盈利: ${result['profit']}"),
            Text("收益率: ${result['profitRate'] * 100}%"),
            Text("总份额: ${result['totalShares']}"),
            Text("最后净值: ${result['lastNetValue']}"),
            SizedBox(height: 16.0),
            Text("操作记录:"),
            Expanded(
              child: ListView.builder(
                itemCount: result['actions'].length,
                itemBuilder: (context, index) {
                  var action = result['actions'][index];
                  return ListTile(
                    title: Text(action['date']),
                    subtitle: Text(
                      "${action['action']}: 投资金额 ${action['amount']}",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
