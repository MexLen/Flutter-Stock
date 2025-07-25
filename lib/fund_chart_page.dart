import 'dart:math';
import 'package:flutter/material.dart';
import 'fetch.dart';
import 'package:fl_chart/fl_chart.dart';

/// 时间范围枚举
enum TimeRange {
  oneMonth(30, '近一月'),
  threeMonths(90, '近三月'),
  sixMonths(180, '近半年'),
  oneYear(365, '近一年'),
  twoYears(730, '近两年'),
  threeYears(1095, '近三年');

  final int days;
  final String label;

  const TimeRange(this.days, this.label);
}

/// 图表轴值类
class AxisValue {
  final double value;
  final String text;

  AxisValue(this.value, this.text);
}

/// 基金分析指标
class FundMetrics {
  final double totalReturn; // 总收益率
  final double maxDrawdown; // 最大回撤
  final double volatility; // 波动率
  final double sharpeRatio; // 夏普比率 (假设无风险利率为3%)
  final double calmarRatio; // 卡尔玛比率

  FundMetrics({
    required this.totalReturn,
    required this.maxDrawdown,
    required this.volatility,
    required this.sharpeRatio,
    required this.calmarRatio,
  });
}

class FundChartPage extends StatefulWidget {
  final String fundCode;

  const FundChartPage({Key? key, required this.fundCode}) : super(key: key);

  @override
  State<FundChartPage> createState() => _FundChartPageState();
}

class _FundChartPageState extends State<FundChartPage> {
  TimeRange _selectedTimeRange = TimeRange.oneYear;
  late Future<Fund> _fundFuture = Future<Fund>.value(Fund(
    fundcode: '',
    name: '',
    jzrq: '',
    dwjz: 0.0,
    gsz: 0.0,
    gszzl: 0.0,
    gztime: '',
  ));
  late Future<List<Map<String, dynamic>>> _historyFuture = Future.value(<Map<String, dynamic>>[]);
  List<Map<String, dynamic>> _fullHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFundData();
  }

  Future<void> _loadFundData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取基金基本信息
      final fund = await findFund(widget.fundCode);
      
      // 获取基金历史净值数据 (获取足够多的数据以支持所有时间范围)
      final history = await fetchFundHistory(widget.fundCode, perPage: 1500);
      
      setState(() {
        _fundFuture = Future.value(fund);
        _fullHistory = history;
        _historyFuture = Future.value(_filterHistoryByTimeRange(history, _selectedTimeRange));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 根据选择的时间范围过滤历史数据
  List<Map<String, dynamic>> _filterHistoryByTimeRange(
      List<Map<String, dynamic>> history, TimeRange timeRange) {
    if (history.isEmpty) return [];

    // 获取最新的日期
    final latestDate = DateTime.parse(history.first['FSRQ']);

    // 计算目标日期
    final targetDate = latestDate.subtract(Duration(days: timeRange.days));

    // 过滤数据
    final filtered = history.where((item) {
      final itemDate = DateTime.parse(item['FSRQ']);
      return itemDate.isAfter(targetDate) || itemDate.isAtSameMomentAs(targetDate);
    }).toList();

    // 按日期排序（最新的在前面）
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['FSRQ']);
      final dateB = DateTime.parse(b['FSRQ']);
      return dateB.compareTo(dateA);
    });

    return filtered.reversed.toList(); // 图表需要从旧到新显示
  }

  /// 计算基金分析指标
  FundMetrics _calculateMetrics(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return FundMetrics(
        totalReturn: 0,
        maxDrawdown: 0,
        volatility: 0,
        sharpeRatio: 0,
        calmarRatio: 0,
      );
    }

    // 计算总收益率
    final firstValue = double.tryParse(history.first['DWJZ']) ?? 0;
    final lastValue = double.tryParse(history.last['DWJZ']) ?? 0;
    final totalReturn = (lastValue - firstValue) / firstValue;

    // 计算最大回撤
    double maxValue = 0;
    double maxDrawdown = 0;
    for (var item in history) {
      final value = double.tryParse(item['DWJZ']) ?? 0;
      if (value > maxValue) {
        maxValue = value;
      }
      final drawdown = (maxValue - value) / maxValue;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }

    // 计算波动率（日收益率的标准差）
    List<double> dailyReturns = [];
    for (int i = 1; i < history.length; i++) {
      final prevValue = double.tryParse(history[i - 1]['DWJZ']) ?? 0;
      final currentValue = double.tryParse(history[i]['DWJZ']) ?? 0;
      if (prevValue != 0) {
        final dailyReturn = (currentValue - prevValue) / prevValue;
        dailyReturns.add(dailyReturn);
      }
    }

    // 计算标准差
    double volatility = 0;
    if (dailyReturns.isNotEmpty) {
      final mean = dailyReturns.reduce((a, b) => a + b) / dailyReturns.length;
      final squaredDifferences = dailyReturns
          .map((r) => pow(r - mean, 2))
          .reduce((a, b) => a + b);
      final variance = squaredDifferences / dailyReturns.length;
      volatility = sqrt(variance) * sqrt(250); // 年化波动率
    }

    // 计算夏普比率（假设无风险利率为3%）
    final riskFreeRate = 0.03;
    final double sharpeRatio = volatility == 0 ? 0.0 : ((totalReturn - riskFreeRate) / volatility).toDouble();

    // 计算卡尔玛比率
    final double calmarRatio = maxDrawdown == 0 ? 0.0 : (totalReturn / maxDrawdown).toDouble();

    return FundMetrics(
      totalReturn: totalReturn,
      maxDrawdown: maxDrawdown,
      volatility: volatility,
      sharpeRatio: sharpeRatio,
      calmarRatio: calmarRatio,
    );
  }

  /// 构建图表数据
  List<FlSpot> _buildChartData(List<Map<String, dynamic>> history) {
    List<FlSpot> spots = [];
    if (history.isEmpty) return spots;

    for (int i = 0; i < history.length; i++) {
      final value = double.tryParse(history[i]['DWJZ']) ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return spots;
  }

  /// 构建图表底部标题
  List<AxisValue> _buildBottomTitles(List<Map<String, dynamic>> history) {
    List<AxisValue> titles = [];
    if (history.isEmpty) return titles;

    // 只显示开始、中间和结束日期
    if (history.length > 0) {
      final firstDate = history.first['FSRQ'].substring(5); // 去掉年份
      titles.add(AxisValue(0, firstDate));
    }

    if (history.length > 1) {
      final middleIndex = (history.length / 2).floor();
      final middleDate = history[middleIndex]['FSRQ'].substring(5);
      titles.add(AxisValue(middleIndex.toDouble(), middleDate));
    }

    if (history.length > 2) {
      final lastDate = history.last['FSRQ'].substring(5);
      titles.add(AxisValue((history.length - 1).toDouble(), lastDate));
    }

    return titles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('基金净值图表'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Fund>(
              future: _fundFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('加载失败: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFundData,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final fund = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基金基本信息
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fund.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '基金代码: ${fund.fundcode}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 时间范围选择器
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: TimeRange.values.map((timeRange) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(timeRange.label),
                              selected: _selectedTimeRange == timeRange,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTimeRange = timeRange;
                                    _historyFuture = Future.value(
                                        _filterHistoryByTimeRange(
                                            _fullHistory, timeRange));
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 图表和指标
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _historyFuture,
                        builder: (context, historySnapshot) {
                          if (historySnapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error, size: 48, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text('加载历史数据失败: ${historySnapshot.error}'),
                                ],
                              ),
                            );
                          }

                          if (!historySnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final history = historySnapshot.data!;
                          if (history.isEmpty) {
                            return const Center(
                              child: Text('暂无历史数据'),
                            );
                          }

                          final metrics = _calculateMetrics(history);
                          final chartData = _buildChartData(history);
                          final bottomTitles = _buildBottomTitles(history);

                          return Column(
                            children: [
                              // 分析指标
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildMetricItem('总收益率', metrics.totalReturn, true),
                                    _buildMetricItem('最大回撤', metrics.maxDrawdown, false),
                                    _buildMetricItem('年化波动率', metrics.volatility, false),
                                    _buildMetricItem('夏普比率', metrics.sharpeRatio, true),
                                    _buildMetricItem('卡尔玛比率', metrics.calmarRatio, true),
                                  ],
                                ),
                              ),

                              // 图表
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: LineChart(
                                    LineChartData(
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: chartData,
                                          isCurved: true,
                                          color: Colors.blue,
                                          barWidth: 2,
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Colors.blue.withOpacity(0.2),
                                          ),
                                          dotData: FlDotData(show: false),
                                        ),
                                      ],
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: true),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            getTitlesWidget: (value, meta) {
                                              for (var title in bottomTitles) {
                                                if (title.value == value) {
                                                  return Text(
                                                    title.text,
                                                    style: const TextStyle(fontSize: 12),
                                                  );
                                                }
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      gridData: FlGridData(show: true),
                                      borderData: FlBorderData(show: true),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// 构建指标显示项
  Widget _buildMetricItem(String label, double value, bool isPositiveGood) {
    final formattedValue = _formatMetricValue(value, label);
    Color valueColor = Colors.black;
    
    if (label == '总收益率' || label == '夏普比率' || label == '卡尔玛比率') {
      valueColor = value >= 0 ? Colors.green : Colors.red;
    } else if (label == '最大回撤' || label == '年化波动率') {
      valueColor = value >= 0 ? Colors.red : Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化指标值显示
  String _formatMetricValue(double value, String label) {
    if (label.contains('比率')) {
      return value.isNaN || value.isInfinite ? 'N/A' : value.toStringAsFixed(2);
    } else if (label == '总收益率' || label == '最大回撤') {
      return '${(value * 100).toStringAsFixed(2)}%';
    } else if (label == '年化波动率') {
      return '${(value * 100).toStringAsFixed(2)}%';
    }
    return value.toStringAsFixed(2);
  }
}