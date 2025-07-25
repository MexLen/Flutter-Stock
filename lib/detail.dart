// … 头部 import 不变 …

/* =========== 新增：空页组件 =========== */
import 'package:flutter/material.dart';
import 'fund_api.dart';
import 'fetch.dart';
import 'holdings_news_page.dart';
import 'fund_chart_page.dart';

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

/* =========== 新增：骨架屏盒子 =========== */
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/* =========== 新增：基金信息项 =========== */
class _FundInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final bool? isPositive;

  const _FundInfoItem({
    required this.label,
    required this.value,
    this.subValue,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(width: 8),
              Text(
                subValue!,
                style: TextStyle(
                  fontSize: 14,
                  color: isPositive == null 
                    ? Colors.grey 
                    : isPositive! 
                      ? Colors.red 
                      : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
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

  const _BodyCell(this.value);
  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      
    );
  }
}

class TopHoldingsPage extends StatefulWidget {
  final String fundCode;
  final String fundName;

  const TopHoldingsPage({super.key, required this.fundCode, this.fundName = ''});

  @override
  _TopHoldingsPageState createState() => _TopHoldingsPageState();
}

/* =========== 主要界面改造 =========== */
class _TopHoldingsPageState extends State<TopHoldingsPage> with SingleTickerProviderStateMixin {
  Future<List<Map<String, dynamic>>>? _topHoldings;
  Future<Fund>? _fundFuture;
  late TabController _tabController;
  List<HoldingItem> _holdings = []; // 保存持仓数据

  Future<void> loadTopHoldings() async {
    try {
      // 同时获取基金基本信息和持仓信息
      final fund = await findFund(widget.fundCode);
      final holdings = await getFundHoldingsWithQuote(
        widget.fundCode,
      ); // ← 新 API
      // await attachChangePct(holdings);
      setState(() {
        _fundFuture = Future.value(fund); // 保存基金信息
        _holdings = holdings; // 保存持仓信息
        
        // 将 List<HoldingItem> 转成原来的 Map 形式，UI 零改动
        _topHoldings = Future.value(
          holdings
              .map(
                (e) => {
                  'name': e.name,
                  'code': e.code,
                  'percent': e.percent,
                  'marketValue': e.marketValue,
                  'changePct': e.changePct?.toStringAsFixed(2) ?? '--',
                },
              )
              .toList(),
        );
      });
    } catch (e) {
      setState(() {
        _topHoldings = Future.error(e);
        _fundFuture = Future.error(e);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadTopHoldings();
    _tabController = TabController(length: 3, vsync: this); // 更新标签页数量为3
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('基金详情'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '持仓'),
            Tab(text: '持仓新闻'),
            Tab(text: '基金图表'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 持仓页面
          _buildHoldingsPage(),
          // 持仓股票新闻页面
          HoldingsNewsPage(
            holdings: _holdings,
            fundCode: widget.fundCode,
          ),
          // 基金图表页面
          FundChartPage(fundCode: widget.fundCode),
        ],
      ),
    );
  }

  Widget _buildHoldingsPage() {
    return Column(
      children: [
        // 添加基金基本信息展示区域
        FutureBuilder<Fund>(
          future: _fundFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final fund = snapshot.data!;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          fund.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fund.fundcode,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FundInfoItem(
                          label: '最新净值',
                          value: fund.gsz.toStringAsFixed(4),
                          subValue:
                              '${fund.gszzl > 0 ? '+' : ''}${fund.gszzl.toStringAsFixed(2)}%',
                          isPositive: fund.gszzl > 0,
                        ),
                        _FundInfoItem(
                          label: '更新时间',
                          value: fund.gztime.substring(5), // 去掉年份显示
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Text('加载基金信息失败: ${snapshot.error}'),
              );
            }
            // 加载中状态
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 120, height: 20),
                  SizedBox(height: 8),
                  _SkeletonBox(width: 200, height: 16),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SkeletonBox(width: 100, height: 16),
                      _SkeletonBox(width: 100, height: 16),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // 原有的持仓信息部分
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _topHoldings,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView.separated(
                  padding: const EdgeInsets.only(top: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, __) => const _SkeletonHoldingTile(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '加载失败',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: loadTopHoldings,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重新加载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const _EmptyPlaceholder();
              }

              final data = snapshot.data!;
              return Column(
                children: [
                  // 表头卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
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
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, idx) {
                        final s = data[idx];
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
                                    _BodyCell(s['name']),
                                    _BodyCell(s['code']),
                                    _BodyCell(s['percent']),
                                    _BodyCell('${s['marketValue']}'),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
