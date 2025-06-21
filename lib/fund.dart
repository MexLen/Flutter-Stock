import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoryChange {
  DateTime date;
  double value;
  double ratio;
  HistoryChange({required this.date, required this.value, required this.ratio});
}

class Fund {
  String name;
  String code;
  String value;
  double ratio;
  List<HistoryChange> chane;
  Fund({
    required this.name,
    required this.code,
    required this.value,
    required this.ratio,
    required this.chane,
  });
}

class FundHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          SizedBox(width: 100, child: Text('名称')),
          SizedBox(width: 100, child: Text('涨跌')),
          SizedBox(width: 100, child: Text('净值')),
        ],
      ),
    );
  }
}

class FundDetail extends StatelessWidget {
  final Fund my_fund;
  const FundDetail({super.key, required this.my_fund});

  @override
  Widget build(BuildContext context) {
    return FundChart(fund: this.my_fund);
  }
}

class FundCard extends StatelessWidget {
  Fund my_fund;
  FundCard({required this.my_fund});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FundDetail(my_fund: my_fund),
                  ),
                );
              },
              child: Text(
                my_fund.name,
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              my_fund.ratio > 0
                  ? '+${my_fund.ratio.toStringAsFixed(2)}%'
                  : '${my_fund.ratio.toStringAsFixed(2)}%',
              // my_fund.ratio.toString(),
              style: TextStyle(
                color: my_fund.ratio < 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 100, child: Text(my_fund.value.toString())),
        ],
      ),
    );
  }
}

class FundChart extends StatelessWidget {
  final Fund fund;
  FundChart({required this.fund});

  @override
  Widget build(BuildContext context) {
    final data = fund.chane.reversed.toList();
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval:
                    (data.map((e) => e.value).reduce((a, b) => a > b ? a : b) -
                        data
                            .map((e) => e.value)
                            .reduce((a, b) => a < b ? a : b)) /
                    4,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toStringAsFixed(2),
                      style: TextStyle(fontSize: 10),
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return Container();
                  final date = data[idx].date;
                  return Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black12),
          ),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY:
              data.map((e) => e.value).reduce((a, b) => a < b ? a : b) * 0.995,
          maxY:
              data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.005,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].value),
              ),
              isCurved: true,
              color: fund.ratio >= 0 ? Colors.red : Colors.green,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: (fund.ratio >= 0 ? Colors.red : Colors.green)
                    .withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Fund> mockFunds = [
  Fund(
    name: '华夏成长混合',
    code: '000001',
    value: '2.345',
    ratio: 0.21,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 2.3 + (i * 0.003) + (i.isEven ? 0.01 : -0.01);
      final ratio =
          (i == 0)
              ? 0.012
              : ((value -
                      (2.3 +
                          ((i - 1) * 0.003) +
                          ((i - 1).isEven ? 0.01 : -0.01))) /
                  (2.3 + ((i - 1) * 0.003) + ((i - 1).isEven ? 0.01 : -0.01)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '易方达蓝筹精选',
    code: '000002',
    value: '3.120',
    ratio: -0.010,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 3.1 + (i * 0.004) + (i.isOdd ? 0.012 : -0.008);
      final ratio =
          (i == 0)
              ? 0.010
              : ((value -
                      (3.1 +
                          ((i - 1) * 0.004) +
                          ((i - 1).isOdd ? 0.012 : -0.008))) /
                  (3.1 + ((i - 1) * 0.004) + ((i - 1).isOdd ? 0.012 : -0.008)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '南方成长先锋',
    code: '000003',
    value: '1.980',
    ratio: 0.015,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 1.95 + (i * 0.002) + (i.isEven ? 0.008 : -0.006);
      final ratio =
          (i == 0)
              ? 0.008
              : ((value -
                      (1.95 +
                          ((i - 1) * 0.002) +
                          ((i - 1).isEven ? 0.008 : -0.006))) /
                  (1.95 +
                      ((i - 1) * 0.002) +
                      ((i - 1).isEven ? 0.008 : -0.006)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '嘉实新兴产业',
    code: '000004',
    value: '2.560',
    ratio: 0.03,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 2.5 + (i * 0.005) + (i.isOdd ? 0.009 : -0.007);
      final ratio =
          (i == 0)
              ? 0.009
              : ((value -
                      (2.5 +
                          ((i - 1) * 0.005) +
                          ((i - 1).isOdd ? 0.009 : -0.007))) /
                  (2.5 + ((i - 1) * 0.005) + ((i - 1).isOdd ? 0.009 : -0.007)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '广发科技先锋',
    code: '000005',
    value: '4.210',
    ratio: -0.018,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 4.2 + (i * 0.003) + (i.isEven ? 0.015 : -0.012);
      final ratio =
          (i == 0)
              ? 0.012
              : ((value -
                      (4.2 +
                          ((i - 1) * 0.003) +
                          ((i - 1).isEven ? 0.015 : -0.012))) /
                  (4.2 +
                      ((i - 1) * 0.003) +
                      ((i - 1).isEven ? 0.015 : -0.012)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '富国天惠成长',
    code: '000006',
    value: '3.670',
    ratio: 0.007,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 3.65 + (i * 0.004) + (i.isOdd ? 0.011 : -0.009);
      final ratio =
          (i == 0)
              ? 0.011
              : ((value -
                      (3.65 +
                          ((i - 1) * 0.004) +
                          ((i - 1).isOdd ? 0.011 : -0.009))) /
                  (3.65 +
                      ((i - 1) * 0.004) +
                      ((i - 1).isOdd ? 0.011 : -0.009)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '汇添富创新增长',
    code: '000007',
    value: '2.890',
    ratio: 0.019,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 2.85 + (i * 0.003) + (i.isEven ? 0.013 : -0.007);
      final ratio =
          (i == 0)
              ? 0.013
              : ((value -
                      (2.85 +
                          ((i - 1) * 0.003) +
                          ((i - 1).isEven ? 0.013 : -0.007))) /
                  (2.85 +
                      ((i - 1) * 0.003) +
                      ((i - 1).isEven ? 0.013 : -0.007)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '中欧医疗健康',
    code: '000008',
    value: '5.120',
    ratio: -0.022,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 5.1 + (i * 0.006) + (i.isOdd ? 0.014 : -0.011);
      final ratio =
          (i == 0)
              ? 0.014
              : ((value -
                      (5.1 +
                          ((i - 1) * 0.006) +
                          ((i - 1).isOdd ? 0.014 : -0.011))) /
                  (5.1 + ((i - 1) * 0.006) + ((i - 1).isOdd ? 0.014 : -0.011)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '景顺长城新兴成长',
    code: '000009',
    value: '2.340',
    ratio: 0.011,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 2.3 + (i * 0.002) + (i.isEven ? 0.01 : -0.008);
      final ratio =
          (i == 0)
              ? 0.01
              : ((value -
                      (2.3 +
                          ((i - 1) * 0.002) +
                          ((i - 1).isEven ? 0.01 : -0.008))) /
                  (2.3 + ((i - 1) * 0.002) + ((i - 1).isEven ? 0.01 : -0.008)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '鹏华价值优势',
    code: '000010',
    value: '1.760',
    ratio: -0.005,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 1.75 + (i * 0.003) + (i.isOdd ? 0.007 : -0.005);
      final ratio =
          (i == 0)
              ? 0.007
              : ((value -
                      (1.75 +
                          ((i - 1) * 0.003) +
                          ((i - 1).isOdd ? 0.007 : -0.005))) /
                  (1.75 +
                      ((i - 1) * 0.003) +
                      ((i - 1).isOdd ? 0.007 : -0.005)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '银华富裕主题',
    code: '000011',
    value: '3.430',
    ratio: 0.017,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 3.4 + (i * 0.004) + (i.isEven ? 0.012 : -0.009);
      final ratio =
          (i == 0)
              ? 0.012
              : ((value -
                      (3.4 +
                          ((i - 1) * 0.004) +
                          ((i - 1).isEven ? 0.012 : -0.009))) /
                  (3.4 +
                      ((i - 1) * 0.004) +
                      ((i - 1).isEven ? 0.012 : -0.009)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
  Fund(
    name: '华安媒体互联网',
    code: '000012',
    value: '2.670',
    ratio: -0.013,
    chane: List.generate(15, (i) {
      final date = DateTime(2024, 6, 1).subtract(Duration(days: i));
      final value = 2.65 + (i * 0.003) + (i.isOdd ? 0.01 : -0.007);
      final ratio =
          (i == 0)
              ? 0.01
              : ((value -
                      (2.65 +
                          ((i - 1) * 0.003) +
                          ((i - 1).isOdd ? 0.01 : -0.007))) /
                  (2.65 + ((i - 1) * 0.003) + ((i - 1).isOdd ? 0.01 : -0.007)));
      return HistoryChange(
        date: date,
        value: double.parse(value.toStringAsFixed(3)),
        ratio: double.parse(ratio.toStringAsFixed(3)),
      );
    }),
  ),
];
