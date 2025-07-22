import 'fetch.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'detail.dart';
/// 根据基金历史净值数据绘制走势图并保存为JPG图片
/// 返回图片文件路径
Future<String> drawFundHistoryChartAsJpg(
  List<Map<String, dynamic>> history, {
  String? fileName,
}) async {
  if (history.isEmpty) throw Exception('历史数据为空');
  final width = 800.0;
  final height = 400.0;
  final padding = 40.0;

  // 解析净值数据
  final values =
      history.map((e) => double.tryParse(e['DWJZ'] ?? '0') ?? 0).toList();
  final minValue = values.reduce((a, b) => a < b ? a : b);
  final maxValue = values.reduce((a, b) => a > b ? a : b);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
  final paint =
      ui.Paint()
        ..color = const Color(0xFF1976D2)
        ..strokeWidth = 2
        ..style = ui.PaintingStyle.stroke;

  // 背景
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width, height),
    ui.Paint()..color = const Color(0xFFF5F5F5),
  );

  // 坐标轴
  final axisPaint =
      ui.Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 1;
  // Y轴
  canvas.drawLine(
    ui.Offset(padding, padding),
    ui.Offset(padding, height - padding),
    axisPaint,
  );
  // X轴
  canvas.drawLine(
    ui.Offset(padding, height - padding),
    ui.Offset(width - padding, height - padding),
    axisPaint,
  );

  // 画折线
  final stepX = (width - 2 * padding) / (values.length - 1);
  final scaleY =
      (height - 2 * padding) /
      (maxValue - minValue == 0 ? 1 : maxValue - minValue);

  final path = ui.Path();
  for (int i = 0; i < values.length; i++) {
    final x = padding + i * stepX;
    final y = height - padding - (values[i] - minValue) * scaleY;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  canvas.drawPath(path, paint);
  // 保存为图片
  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  // 转为JPG（Flutter不直接支持JPG编码，这里用PNG，若需JPG可用第三方库如 image/image.dart）
  // 这里用PNG保存，JPG可用image库转换
  final dir = await getTemporaryDirectory();
  final file = await File(
    '${dir.path}/${fileName ?? 'fund_chart'}.png',
  ).writeAsBytes(buffer);
  return file.path;
}

class FundHeader extends StatelessWidget {
  const FundHeader({super.key});

  @override
  Widget build(BuildContext context) {
  

    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          SizedBox(width: 80, child: Text('名称', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('涨跌', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('净值', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('回撤', textAlign: ui.TextAlign.start)),
          SizedBox(width: 80, child: Text('走势', textAlign: ui.TextAlign.start)),
        ],
      ),
    );
  }
}

class FundItem extends StatefulWidget {
  // const FundItem({super.key});
  Fund fund;
  FundItem({super.key, required this.fund});
  @override
  State<FundItem> createState() => FundItemState();
}

class FundItemState extends State<FundItem> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateBackTh(context, Fund fund) async {
    TextEditingController controller = TextEditingController(
      text: fund.back_th.toString(),
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("修改回撤阈值"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: "请输入新值"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("取消"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("确认"),
              onPressed: () {
                double newValue = double.parse(controller.text);
                fund.back_th = newValue;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Fund fund = widget.fund;
    double times = (fund.backdraw_list.last.abs() / fund.back_th);
    var notifiy = BadgeWid(times: times);
    return Container(
      padding: EdgeInsets.all(0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: () => {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context)=>
                    TopHoldingsPage(fundCode: fund.fundcode)
                  )
                )
              },

              child: Stack(
                children: [
                  Column(
                    children: [
                      Text(
                        fund.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                      Text(
                        fund.fundcode,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              fund.gszzl > 0
                  ? '+${fund.gszzl.toStringAsFixed(2)}%'
                  : '${fund.gszzl.toStringAsFixed(2)}%',
              // my_fund.ratio.toString(),
              style: TextStyle(
                color: fund.gszzl < 0 ? Colors.green : Colors.red,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              fund.gsz.toStringAsFixed(2),
              style: TextStyle(fontSize: 15),
            ),
          ),
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                TextButton(
                  child: Text(
                    fund.backdraw_list.last > 0
                        ? '-${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%'
                        : '${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%',
                    style: TextStyle(
                      color:
                          fund.backdraw_list.last > 0
                              ? Colors.green
                              : Colors.red,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () async {
                    await _updateBackTh(context, fund);
                    setState(() {
                      fund.back_th = fund.back_th;
                    });
                  },
                ),
                Positioned(top: 0, right: 0, child: notifiy),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 40,
            child: FutureBuilder<String>(
              future: drawFundHistoryChartAsJpg(
                fund.history,
                fileName: '${fund.fundcode}_thumb',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('暂无持仓数据'));
                }
                return Image.file(File(snapshot.data!), fit: BoxFit.contain);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MyFundList extends StatefulWidget {
  final List<Fund> allFunds;
  const MyFundList({super.key, required this.allFunds});

  @override
  State<MyFundList> createState() => _MyFundListState();
}

class _MyFundListState extends State<MyFundList> {
  List<String> _myFundCodes = [];
  List<Fund> _myFunds = [];

  @override
  void initState() {
    super.initState();
    _loadMyFunds();
  }

  Future<void> _loadMyFunds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myFundCodes = prefs.getStringList('my_fund_codes') ?? [];
    });
    // 优化：避免重复加载基金，使用Future.wait并行加载
    if (_myFundCodes.isNotEmpty) {
      final funds = await Future.wait(_myFundCodes.map(findFund));
      for (var fund in funds) {
        fund.history = await fetchFundHistory(fund.fundcode, perPage: 30);
        fund.backdraw_list = calculateMaxDrawdown(fund.history);
      }

      setState(() {
        _myFunds = funds;
      });
    }
  }

  Future<void> _removeFund(Fund fund) async {
    setState(() {
      _myFundCodes.remove(fund.fundcode);
      _myFunds.removeWhere((f) => f.fundcode == fund.fundcode);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_fund_codes', _myFundCodes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: Icon(Icons.search),
              label: Text('添加基金'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SearchPage(
                          allFunds: widget.allFunds,
                          fundCodes: _myFundCodes,
                        ),
                  ),
                );
                setState(() {
                  _loadMyFunds();
                });
              },
            ),
          ),
        ),
        const FundHeader(),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _myFunds.length,
            itemBuilder: (context, index) {
              final fund = _myFunds[index];
              return Dismissible(
                key: Key(fund.fundcode),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _removeFund(fund);
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                child: FundItem(fund: fund),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SearchPage extends StatefulWidget {
  final List<Fund> allFunds;
  final List<String> fundCodes;

  const SearchPage({super.key, required this.allFunds, required this.fundCodes});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchText = '';
  List<Fund> _filteredFunds = [];
  @override
  void initState() {
    super.initState();
  }

  Future<void> _addFund(Fund fund) async {
    if (!widget.fundCodes.contains(fund.fundcode)) {
      fund.history = await fetchFundHistory(fund.fundcode);
      fund.backdraw_list = calculateMaxDrawdown(fund.history);
      setState(() {
        widget.fundCodes.add(fund.fundcode);
        widget.allFunds.add(fund);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('my_fund_codes', widget.fundCodes);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
      _filteredFunds =
          widget.allFunds
              .where(
                (fund) =>
                    fund.name.contains(_searchText) ||
                    fund.fundcode.contains(_searchText),
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('搜索唧基金')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: '搜索基金名称或代码',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                if (value.length != 6) {
                  return;
                }
                _onSearchChanged(value);
                // 使用 findFund 方法获取基金信息并保存
                if (_filteredFunds.isEmpty) {
                  final fund = await findFund(value);
                  setState(() {
                    _filteredFunds.add(fund);
                  });
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredFunds.length,
              itemBuilder: (context, index) {
                final fund = _filteredFunds[index];
                return ListTile(
                  title: Text('${fund.name} (${fund.fundcode})'),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () async {
                      await _addFund(fund);
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _filteredFunds.clear();
                      });
                      // Navigator.pop(context);
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context, true); // 传递 true 表示需要刷新
                      }
                    },
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

class BadgeWid extends StatelessWidget {
  final double times;
  const BadgeWid({super.key, required this.times});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // color: Colors.red,
        // border: Border.all(width: 0),
        shape: BoxShape.circle,
      ),
      child: Text(
        'x${times.toStringAsFixed(1)}',
        style: TextStyle(color: Colors.red, fontSize: 8),
      ),
    );
  }
}
