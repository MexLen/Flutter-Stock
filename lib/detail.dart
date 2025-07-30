import 'package:flutter/material.dart';
import 'fund_api.dart';
import 'fetch.dart';
import 'news.dart';
import 'trading_strategy.dart';
import 'package:url_launcher/url_launcher.dart';

// 基金详情页面
class FundDetailPage extends StatefulWidget {
  final Fund fund;

  const FundDetailPage({super.key, required this.fund});

  @override
  State<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends State<FundDetailPage> {
  late Future<List<FundHistory>> _historyData;
  late Future<List<HoldingItem>> _holdingsData;

  // 添加策略对象
  final FundTradingStrategy _tradingStrategy = FundTradingStrategy();
  final MovingAverageStrategy _maStrategy = MovingAverageStrategy();
  final RSIStrategy _rsiStrategy = RSIStrategy();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      // 默认使用天天基金接口
      _historyData = fetchFundHistory(widget.fund.fundcode, month: 6);
      _holdingsData = getFundHoldingsWithQuote(widget.fund.fundcode);
    });
  }

  // 计算指定时间段的收益和最大回撤
  Map<String, dynamic> _calculateReturnAndDrawdown(
    List<FundHistory> history,
    int month,
  ) {
    DateTime start_date = getPeriod(month);

    // 获取指定时间段的数据
    final periodData =
        history.where((item) {
          DateTime date = DateTime.parse(item.date);
          return date.isAfter(start_date);
        }).toList();

    final startValue = periodData.first.dwjz;
    final endValue = periodData.last.dwjz;

    // 计算收益
    final periodReturn = (endValue - startValue) / startValue;

    // 计算最大回撤
    double maxValue = 0;
    double maxDrawdown = 0;

    for (int i = 0; i < periodData.length; i++) {
      double curValue = periodData[i].dwjz;
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

            // 交易信号部分
            _buildTradingSignalSection(),

            // 今年净值变化图表
            _buildYearChart(),

            // 收益展示部分
            _buildReturnsSection(),

            // 基金持仓信息
            _buildHoldingsSection(),
          ],
        ),
      ),
    );
  }

  // 构建交易信号部分
  Widget _buildTradingSignalSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '交易信号',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<FundHistory>>(
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
                return _buildTradingSignals(history);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建交易信号展示
  Widget _buildTradingSignals(List<FundHistory> history) {
    // 获取净值数据
    final prices = history.map((e) => e.dwjz).toList();

    if (prices.isEmpty) {
      return const Center(child: Text('无净值数据'));
    }

    // 计算回撤
    final drawdownList = _calculateDrawdownList(history);
    
    // 获取最新的信号
    final latestIndex = prices.length - 1;
    
    // 基于回撤的信号
    final drawdownSignal = _tradingStrategy.getTradingSignal(
      drawdownList: drawdownList,
      currentIndex: latestIndex,
    );
    
    // 均线策略信号
    final maSignal = _maStrategy.checkSignal(prices, latestIndex);
    
    // RSI策略信号
    final rsiSignal = _rsiStrategy.checkSignal(prices, latestIndex);
    
    // 计算当前收益（相对于最早日期）
    final currentReturn = (prices.last - prices.first) / prices.first;
    
    return Column(
      children: [
        _buildSignalItem('回撤策略', drawdownSignal, currentReturn),
        const Divider(),
        _buildSignalItem('均线策略', maSignal, currentReturn),
        const Divider(),
        _buildSignalItem('RSI策略', rsiSignal, currentReturn),
        const SizedBox(height: 16),
        _buildOverallRecommendation([
          drawdownSignal,
          maSignal,
          rsiSignal,
        ]),
      ],
    );
  }

  // 构建单个交易信号项
  Widget _buildSignalItem(String strategyName, StrategyResult signal, double currentReturn) {
    Color signalColor;
    IconData signalIcon;
    
    switch (signal.signal) {
      case TradingSignal.buy:
        signalColor = Colors.red;
        signalIcon = Icons.trending_up;
        break;
      case TradingSignal.sell:
        signalColor = Colors.green;
        signalIcon = Icons.trending_down;
        break;
      case TradingSignal.hold:
        signalColor = Colors.blue;
        signalIcon = Icons.remove;
        break;
      default:
        signalColor = Colors.grey;
        signalIcon = Icons.help_outline;
    }
    
    return Row(
      children: [
        Icon(signalIcon, color: signalColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strategyName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                signal.reason,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (signal.confidence < 1.0)
                Text(
                  '置信度: ${(signal.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
        Text(
          _getSignalText(signal.signal),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: signalColor,
          ),
        ),
      ],
    );
  }

  // 获取信号文本
  String _getSignalText(TradingSignal signal) {
    switch (signal) {
      case TradingSignal.buy:
        return '买入';
      case TradingSignal.sell:
        return '卖出';
      case TradingSignal.hold:
        return '持有';
      default:
        return '观望';
    }
  }

  // 构建总体建议
  Widget _buildOverallRecommendation(List<StrategyResult> signals) {
    int buySignals = signals.where((s) => s.signal == TradingSignal.buy).length;
    int sellSignals = signals.where((s) => s.signal == TradingSignal.sell).length;
    int holdSignals = signals.where((s) => s.signal == TradingSignal.hold).length;
    
    String recommendation;
    Color recommendationColor;
    IconData recommendationIcon;
    
    if (buySignals > sellSignals && buySignals >= holdSignals) {
      recommendation = '总体建议：买入';
      recommendationColor = Colors.red;
      recommendationIcon = Icons.trending_up;
    } else if (sellSignals > buySignals && sellSignals >= holdSignals) {
      recommendation = '总体建议：卖出';
      recommendationColor = Colors.green;
      recommendationIcon = Icons.trending_down;
    } else {
      recommendation = '总体建议：持有';
      recommendationColor = Colors.blue;
      recommendationIcon = Icons.remove;
    }
    
    return Row(
      children: [
        Icon(recommendationIcon, color: recommendationColor),
        const SizedBox(width: 8),
        Text(
          recommendation,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: recommendationColor,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '买入:$buySignals 卖出:$sellSignals 持有:$holdSignals',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // 计算回撤列表
  List<double> _calculateDrawdownList(List<FundHistory> history) {
    double maxValue = 0;
    final List<double> drawdownList = [];
    
    for (int i = 0; i < history.length; i++) {
      double curValue = history[i].dwjz ?? 0;
      if (curValue > maxValue) {
        maxValue = curValue;
      }
      double drawdown = (maxValue - curValue) / maxValue;
      drawdownList.add(drawdown);
    }
    
    return drawdownList;
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
              '近6月净值走势',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<FundHistory>>(
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
                  final yearData = history;

                  return SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(painter: LineChartPainter(yearData)),
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
            FutureBuilder<List<FundHistory>>(
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
                final return30 = _calculateReturnAndDrawdown(history, 1);
                final return90 = _calculateReturnAndDrawdown(history, 3);
                final return180 = _calculateReturnAndDrawdown(history, 6);

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
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 0, 0),
              child: const Text(
                '基金持仓',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<HoldingItem>>(
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
            ),
          ],
        ),
      ),
    );
  }

  // 构建单个持仓项
}

// 构建新闻部分

// 折线图绘制器
class LineChartPainter extends CustomPainter {
  final List<FundHistory> data;

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
    final values = data.map((e) => e.dwjz).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final dx = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final value = data[i].dwjz;
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Column(
        children: [
          // const SizedBox(height: kToolbarHeight + 8),
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
                      _HeaderCell('新闻'),
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
                            GestureDetector(
                              onTap: () {
                                // 跳转到新闻页面
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => StockNewsPage(
                                          stockCode: s.code,
                                          stockName: s.name,
                                        ),
                                  ),
                                );
                              },
                              child: _BodyCell(
                                '查看',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
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

// 新闻项组件，从news_page.dart中复制并修改
class _NewsItem extends StatelessWidget {
  final FundNews news;

  const _NewsItem({required this.news});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _launchURL(news.url, context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 情感标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getSentimentColor(news.sentiment),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getSentimentText(news.sentiment),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 来源
                  Text(
                    news.source,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  // 时间
                  Text(
                    news.publishTime,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 标题
              Text(
                news.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 摘要
              Text(
                news.summary,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // 阅读更多
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '阅读全文',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSentimentColor(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return Colors.green;
      case NewsSentiment.negative:
        return Colors.red;
      case NewsSentiment.neutral:
        return Colors.grey;
    }
  }

  String _getSentimentText(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return '利好';
      case NewsSentiment.negative:
        return '利空';
      case NewsSentiment.neutral:
        return '中性';
    }
  }
}

Future<void> _launchURL(String url, BuildContext context) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接: $url'), backgroundColor: Colors.red),
      );
    }
  }
}

// 股票新闻页面
class StockNewsPage extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const StockNewsPage({
    super.key,
    required this.stockCode,
    required this.stockName,
  });

  @override
  State<StockNewsPage> createState() => _StockNewsPageState();
}

class _StockNewsPageState extends State<StockNewsPage> {
  late Future<List<FundNews>> _newsData;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  void _loadNews() {
    // 模拟获取股票新闻数据
    // 实际项目中这里应该调用真实的API获取数据
    setState(() {
      _newsData = fetchNews(widget.stockName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stockName} 相关新闻'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<FundNews>>(
        future: _newsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('暂无相关新闻'));
          }

          final newsList = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: newsList.length,
            itemBuilder: (context, index) {
              return _NewsItem(news: newsList[index]);
            },
          );
        },
      ),
    );
  }
}
