import 'package:Fund/news_page.dart';
import 'package:flutter/material.dart';
import 'fund_api.dart';
import 'fetch.dart';
import 'fund.dart';
import 'news.dart';

// 基金详情页面
class FundDetailPage extends StatefulWidget {
  final Fund fund;

  const FundDetailPage({super.key, required this.fund});

  @override
  State<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends State<FundDetailPage> {
  late Future<List<Map<String, dynamic>>> _historyData;
  late Future<List<HoldingItem>> _holdingsData;
  late Future<List<FundNews>> _newsData;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _historyData = fetch3MonthFundHistory(widget.fund.fundcode);
      _holdingsData = getFundHoldingsWithQuote(widget.fund.fundcode);
      _newsData = fetchNews(widget.fund.name);
    });
  }

  // 计算指定时间段的收益和最大回撤
  Map<String, dynamic> _calculateReturnAndDrawdown(
    List<Map<String, dynamic>> history,
    int days,
  ) {
    if (history.length < days) {
      return {'return': 0.0, 'drawdown': 0.0};
    }

    // 获取指定时间段的数据
    final periodData = history.sublist(0, days);
    final startValue = double.parse(periodData.last['DWJZ']);
    final endValue = double.parse(periodData.first['DWJZ']);

    // 计算收益
    final periodReturn = (endValue - startValue) / startValue;

    // 计算最大回撤
    double maxValue = 0;
    double maxDrawdown = 0;
    for (int i = periodData.length - 1; i >= 0; i--) {
      double curValue = double.parse(periodData[i]['DWJZ']);
      if (curValue > maxValue) {
        maxValue = curValue;
      }
      double drawdown = (maxValue - curValue) / maxValue;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }

    return {'return': periodReturn, 'drawdown': maxDrawdown};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fund.name), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基金简介部分
            _buildFundInfoCard(),

            // 今年净值变化图表
            _buildYearChart(),

            // 收益展示部分
            _buildReturnsSection(),

            // 基金持仓信息
            _buildHoldingsSection(),

            // 基金持仓股新闻
            _buildNewsSection(),
          ],
        ),
      ),
    );
  }

  // 构建基金简介卡片
  Widget _buildFundInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '基金代码: ${widget.fund.fundcode}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoItem('最新净值', widget.fund.gsz.toStringAsFixed(4)),
                _buildInfoItem(
                  '涨跌幅',
                  '${widget.fund.gszzl > 0 ? '+' : ''}${widget.fund.gszzl.toStringAsFixed(2)}%',
                  isRate: true,
                  rate: widget.fund.gszzl,
                ),
                _buildInfoItem('更新时间', widget.fund.gztime.substring(5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建信息项
  Widget _buildInfoItem(
    String label,
    String value, {
    bool isRate = false,
    double rate = 0,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                isRate ? (rate > 0 ? Colors.red : Colors.green) : Colors.black,
          ),
        ),
      ],
    );
  }

  // 构建今年净值变化图表
  Widget _buildYearChart() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今年净值走势',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _historyData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('加载失败: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('暂无数据'));
                  }

                  final history = snapshot.data!;
                  // 只取今年的数据
                  final currentYear = DateTime.now().year;
                  final yearData =
                      history.where((item) {
                        return item['FSRQ'].toString().startsWith(
                          currentYear.toString(),
                        );
                      }).toList();

                  if (yearData.isEmpty) {
                    return const Center(child: Text('暂无今年数据'));
                  }

                  return CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: LineChartPainter(yearData),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建收益展示部分
  Widget _buildReturnsSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '区间收益表现',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _historyData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('加载失败: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('暂无数据'));
                }

                final history = snapshot.data!;
                final return30 = _calculateReturnAndDrawdown(history, 20);
                final return90 = _calculateReturnAndDrawdown(history, 40);
                final return180 = _calculateReturnAndDrawdown(history, 60);

                return Column(
                  children: [
                    _buildReturnRow(
                      '近1个月',
                      return30['return'],
                      return30['drawdown'],
                    ),
                    const Divider(),
                    _buildReturnRow(
                      '近3个月',
                      return90['return'],
                      return90['drawdown'],
                    ),
                    const Divider(),
                    _buildReturnRow(
                      '近6个月',
                      return180['return'],
                      return180['drawdown'],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建收益行
  Widget _buildReturnRow(String period, double returnRate, double drawdown) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(period, style: const TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildReturnItem('收益', returnRate),
              _buildReturnItem('回撤', drawdown, isDrawdown: true),
            ],
          ),
        ),
      ],
    );
  }

  // 构建收益项
  Widget _buildReturnItem(
    String label,
    double value, {
    bool isDrawdown = false,
  }) {
    final isPositive = value >= 0;
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${isDrawdown ? "" : (isPositive ? "+" : "")}${(value * 100).toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                isDrawdown
                    ? Colors.orange
                    : (isPositive ? Colors.red : Colors.green),
          ),
        ),
      ],
    );
  }

  // 构建基金持仓部分
  Widget _buildHoldingsSection() {
    return FutureBuilder<List<HoldingItem>>(
      future: _holdingsData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('暂无持仓数据'));
        }

        final holdings = snapshot.data!;
        return TopHoldingsPage(holdings: holdings);
      },
    );
  }

  Widget _buildNewsSection() {
    return Card(
      child: FutureBuilder<List<FundNews>>(
        future: _newsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('暂无持仓数据'));
          }

          final news_list = snapshot.data!;
          return FundNewsPage(news_list: news_list);
        },
      ),
    );
  }

  // 构建单个持仓项
}

// 构建新闻部分

// 折线图绘制器
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    final values = data.map((e) => double.parse(e['DWJZ'])).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final dx = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final value = double.parse(data[i]['DWJZ']);
      final dy = size.height - ((value - minVal) / range) * size.height;
      points.add(Offset(i * dx, dy));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/* =========== 新增：空页组件 =========== */

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 96,
            color: Colors.blue.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无持仓数据',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '该组合暂未公布最新持仓',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

/* =========== 新增：骨架屏 =========== */
class _SkeletonHoldingTile extends StatelessWidget {
  const _SkeletonHoldingTile();
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _shimmerBox(
                double.infinity,
                14,
                radius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _shimmerBox(48, 14, radius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _shimmerBox(36, 14, radius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _shimmerBox(44, 14, radius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {BorderRadius? radius}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: radius ?? BorderRadius.circular(4),
    ),
  );
}

/* =========== HeaderCell 微调 =========== */
class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey.shade700,
        ),
      ),
    );
  }
}

/* =========== BodyCell 微调 =========== */
class _BodyCell extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const _BodyCell(this.value, {this.style});
  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style:
          style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }
}

class TopHoldingsPage extends StatelessWidget {
  final List<HoldingItem> holdings;

  const TopHoldingsPage({super.key, required this.holdings});

  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Column(
        children: [
          const SizedBox(height: kToolbarHeight + 8),
          // 表头卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue.shade50,
              margin: EdgeInsets.zero,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: const [
                      _HeaderCell('股票名称'),
                      _HeaderCell('代码'),
                      _HeaderCell('占比'),
                      _HeaderCell('市值(亿)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 列表主体
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: holdings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, idx) {
                final s = holdings[idx];
                return Card(
                  elevation: 0.5,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: idx.isEven ? Colors.white : Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _BodyCell(s.name),
                            _BodyCell(s.code),
                            _BodyCell(s.percent),
                            _BodyCell('${s.marketValue}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
