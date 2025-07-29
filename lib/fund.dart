import 'package:flutter/foundation.dart';

import 'fetch.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'detail.dart';
import 'dart:typed_data';
import 'dart:ui' show Image, Picture;

// 添加图表缓存管理器
class ChartCacheManager {
  static final ChartCacheManager _instance = ChartCacheManager._internal();
  factory ChartCacheManager() => _instance;
  ChartCacheManager._internal();

  final Map<String, String> _chartPathCache = {};
  final Map<String, DateTime> _chartTimeCache = {};

  // 检查图表是否需要更新（缓存1小时）
  bool shouldUpdateChart(String fundCode) {
    if (!_chartTimeCache.containsKey(fundCode)) {
      return true;
    }
    
    final lastUpdate = _chartTimeCache[fundCode]!;
    final now = DateTime.now();
    return now.difference(lastUpdate).inHours >= 1;
  }

  // 获取缓存的图表路径
  String? getChartPath(String fundCode) {
    return _chartPathCache[fundCode];
  }

  // 保存图表路径
  void saveChartPath(String fundCode, String path) {
    _chartPathCache[fundCode] = path;
    _chartTimeCache[fundCode] = DateTime.now();
  }
}

/// 根据基金历史净值数据绘制走势图并保存为图片
/// 返回图片文件路径
Future<String> drawFundHistoryChartAsJpg(
  List<Map<String, dynamic>> history, {
  String? fileName,
}) async {
  // 检查参数
  if (history.isEmpty) throw Exception('历史数据为空');
  
  // 检查是否有缓存的图表
  final fundCode = fileName?.replaceAll('_thumb', '') ?? 'unknown';
  final cacheManager = ChartCacheManager();
  
  if (!cacheManager.shouldUpdateChart(fundCode)) {
    final cachedPath = cacheManager.getChartPath(fundCode);
    if (cachedPath != null && File(cachedPath).existsSync()) {
      return cachedPath;
    }
  }

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
  
  // 保存到缓存
  final dir = await getTemporaryDirectory();
  final fileNameToUse = fileName ?? 'fund_chart';
  final file = await File(
    '${dir.path}/${fileNameToUse}.png',
  ).writeAsBytes(buffer);
  
  // 更新缓存
  cacheManager.saveChartPath(fundCode, file.path);
  
  return file.path;
}

class FundHeader extends StatelessWidget {
  const FundHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          SizedBox(width: 80, child: Text('名称', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('涨跌', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('净值', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('回撤', textAlign: ui.TextAlign.start)),
          SizedBox(width: 60, child: Text('走势', textAlign: ui.TextAlign.start)),
        ],
      ),
    );
  }
}

class FundItem extends StatefulWidget {
  final Fund fund;
  
  const FundItem({super.key, required this.fund});

  @override
  State<FundItem> createState() => FundItemState();
}

class FundItemState extends State<FundItem> {
  // 添加缓存变量避免重复计算
  late double _cachedGszzl;
  late Color _cachedColor;
  late String _cachedGsz;
  late String _cachedBackdraw;

  @override
  void initState() {
    super.initState();
    _updateCachedValues();
  }

  // 当基金数据更新时更新缓存值
  @override
  void didUpdateWidget(covariant FundItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fund != widget.fund) {
      _updateCachedValues();
    }
  }

  void _updateCachedValues() {
    _cachedGszzl = widget.fund.gszzl;
    _cachedColor = _cachedGszzl < 0 ? Colors.green : Colors.red;
    _cachedGsz = widget.fund.gsz.toStringAsFixed(2);
    _cachedBackdraw = widget.fund.backdraw_list.isNotEmpty
        ? '${(widget.fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%'
        : '0.00%';
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
                // 更新缓存值
                setState(() {
                  _updateCachedValues();
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用缓存值而不是每次都计算
    final gszzlText = _cachedGszzl > 0
        ? '+${_cachedGszzl.toStringAsFixed(2)}%'
        : '${_cachedGszzl.toStringAsFixed(2)}%';

    Widget notifiy = const BadgeWid(times: 0);
    if (widget.fund.backdraw_list.last > widget.fund.back_th) {
      notifiy = BadgeWid(times: widget.fund.backdraw_list.last / widget.fund.back_th);
    }

    return Container(
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: () {
                // Handle fund name tap
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FundDetailPage(fund: widget.fund),
                  ),
                );
              },
              child: Text(
                widget.fund.name,
                style: TextStyle(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              gszzlText,
              style: TextStyle(
                color: _cachedColor,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              _cachedGsz,
              style: TextStyle(fontSize: 15),
            ),
          ),
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                TextButton(
                  child: Text(
                    widget.fund.backdraw_list.last > 0
                        ? '-${_cachedBackdraw}'
                        : _cachedBackdraw,
                    style: TextStyle(
                      color: widget.fund.backdraw_list.last > 0
                          ? Colors.green
                          : Colors.red,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () async {
                    await _updateBackTh(context, widget.fund);
                  },
                ),
                Positioned(top: 0, right: 0, child: notifiy),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 40,
            child: FutureBuilder<String>(
              future: drawFundHistoryChartAsJpg(
                widget.fund.history,
                fileName: '${widget.fund.fundcode}_thumb',
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
  final Function(VoidCallback)? onRefreshCallbackSet; // 新增回调参数

  const MyFundList({
    super.key,
    required this.allFunds,
    this.onRefreshCallbackSet,
  });

  @override
  State<MyFundList> createState() => _MyFundListState();
}

class _MyFundListState extends State<MyFundList> {
  List<String> _myFundCodes = [];
  List<Fund> _myFunds = [];
  bool _loading = true;
  final Map<String, Fund> _fundCache = {}; // 添加基金缓存

  // 添加基金数据加载控制器
  final Map<String, bool> _loadingStates = {};

  @override
  void initState() {
    super.initState();
    loadMyFunds();
    // 设置刷新回调函数
    if (widget.onRefreshCallbackSet != null) {
      widget.onRefreshCallbackSet!(loadMyFunds);
    }
  }

  // 公开此方法供外部调用
  Future<void> loadMyFunds() async {
    // 检查组件是否仍然挂载
    if (!mounted) return;
    
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList('my_fund_codes') ?? [];

    // 检查组件是否仍然挂载
    if (!mounted) return;
    
    setState(() {
      _myFundCodes = codes;
    });

    if (_myFundCodes.isNotEmpty) {
      try {
        // 使用缓存优化基金数据加载
        final funds = await _loadFundsFromCacheOrNetwork(_myFundCodes);
        
        // 检查组件是否仍然挂载
        if (!mounted) return;
        
        setState(() {
          _myFunds = funds;
        });
      } catch (e) {
        if (kDebugMode) {
          print('加载基金数据失败: $e');
        }
        // 检查组件是否仍然挂载
        if (!mounted) return;
      }
    } else {
      // 检查组件是否仍然挂载
      if (!mounted) return;
      
      setState(() {
        _myFunds = [];
      });
    }

    // 检查组件是否仍然挂载
    if (!mounted) return;
    
    setState(() => _loading = false);
  }

  // 优化基金数据加载，使用缓存机制
  Future<List<Fund>> _loadFundsFromCacheOrNetwork(List<String> codes) async {
    final List<Fund> funds = [];
    
    // 并行加载基金基础信息
    final fundFutures = codes.map((code) => _loadFundBasicInfo(code)).toList();
    final basicFunds = await Future.wait(fundFutures);
    
    // 为每个基金加载历史数据（如果需要）
    for (var fund in basicFunds) {
      if (fund != null) {
        // 检查是否有缓存的历史数据且数据较新
        if (_shouldRefreshHistoryData(fund)) {
          try {
            fund.history = await fetchFundHistory(fund.fundcode, month: 1);
            fund.backdraw_list = calculateMaxDrawdown(fund.history);
            // 更新缓存
            _fundCache[fund.fundcode] = fund;
          } catch (e) {
            // 如果加载失败，使用缓存数据
            if (_fundCache.containsKey(fund.fundcode)) {
              funds.add(_fundCache[fund.fundcode]!);
              continue;
            }
          }
        }
        funds.add(fund);
      }
    }
    
    return funds;
  }

  // 判断是否需要刷新历史数据
  bool _shouldRefreshHistoryData(Fund fund) {
    // 如果没有缓存数据，则需要加载
    if (!_fundCache.containsKey(fund.fundcode)) {
      return true;
    }
    
    // 如果缓存中没有历史数据，则需要加载
    final cachedFund = _fundCache[fund.fundcode]!;
    if (cachedFund.history.isEmpty) {
      return true;
    }
    
    // 简单策略：如果有缓存数据，则暂时不刷新（可根据需要调整）
    return false;
  }

  // 加载基金基础信息，优先使用缓存
  Future<Fund?> _loadFundBasicInfo(String fundCode) async {
    // 如果缓存中有且数据较新，则直接使用缓存
    if (_fundCache.containsKey(fundCode)) {
      return _fundCache[fundCode];
    }
    
    try {
      final fund = await findFund(fundCode);
      _fundCache[fundCode] = fund;
      return fund;
    } catch (e) {
      // 如果网络加载失败，但有缓存数据，则使用缓存
      if (_fundCache.containsKey(fundCode)) {
        return _fundCache[fundCode];
      }
      rethrow;
    }
  }

  Future<void> _removeFund(Fund fund) async {
    setState(() {
      _myFundCodes.remove(fund.fundcode);
      _myFunds.removeWhere((f) => f.fundcode == fund.fundcode);
      // 从缓存中移除
      _fundCache.remove(fund.fundcode);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_fund_codes', _myFundCodes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child:
          _loading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      '加载中...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
              : _myFunds.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '暂无自选基金',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '前往搜索页面添加基金',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: loadMyFunds,
                child: Column(
                  children: [
                    // 表头
                    Container(
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[50]!, Colors.blue[100]!],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!, width: 1),
                      ),
                      child: const FundHeader(),
                    ),

                    // 添加成功提示区域
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '共 ${_myFunds.length} 只基金',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '左滑删除',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 基金列表 - 使用虚拟化和懒加载
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _myFunds.length,
                        itemExtent: 80, // 固定高度，提高性能
                        cacheExtent: 500, // 提前加载可视区域外的项
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  spreadRadius: 1,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Dismissible(
                              key: Key(_myFunds[index].fundcode),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red[400]!,
                                      Colors.red[600]!,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 10),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '删除',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onDismissed: (direction) {
                                final fundName = _myFunds[index].name;
                                _removeFund(_myFunds[index]);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$fundName 已删除'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              },
                              // child: Padding(
                              // padding: const EdgeInsets.all(5),
                              child: FundItem(fund: _myFunds[index]),
                              // ),
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
