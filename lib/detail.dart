import 'package:flutter/material.dart';
import 'fetch.dart';

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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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

class TopHoldingsPage extends StatefulWidget {
  final String fundCode;

  const TopHoldingsPage({super.key, required this.fundCode});

  @override
  _TopHoldingsPageState createState() => _TopHoldingsPageState();
}

class _TopHoldingsPageState extends State<TopHoldingsPage> {
  Future<List<Map<String, dynamic>>>? _topHoldings;

  Future<void> loadTopHoldings() async {
    try {
      var holdings = await fetchFundTopHoldingsFromEastmoney(widget.fundCode);
      setState(() {
        _topHoldings = Future.value(holdings);
      });
    } catch (e) {
      throw Exception('加载持仓数据失败: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    loadTopHoldings();
  }

  Widget getHeader(BuildContext context) {
    var headers = ['基金名称', '占比', '涨跌'];
    return ListView.builder(
      itemCount: headers.length,
      itemBuilder: (context, int index) => Text(headers[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _topHoldings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('暂无持仓数据'));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('基金持仓')),
          body: Column(
            children: [
              // 表头 ── 放在 Card 顶部
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: Colors.blueGrey.shade50,
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.transparent,
                        ),
                        children: const [
                          _HeaderCell('股票名称'),
                          _HeaderCell('股票代码'),
                          _HeaderCell('涨跌'),
                          _HeaderCell('市值'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 列表主体 ── 带分隔线 & 隔行变色
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final s = snapshot.data![idx];
                    final percent =
                        double.tryParse(s['percent'].toString().replaceAll('%', '')) ?? 0;
                    final isUp = percent > 0;

                    return Card(
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: idx.isEven ? Colors.white : Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                _BodyCell(
                                  '${percent > 0 ? '+' : ''}${s['percent']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isUp ? Colors.redAccent : Colors.green,
                                  ),
                                ),
                                _BodyCell('${s['marketValue']} 亿'),
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
      },
    );
  }
}
