import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import
import 'db_helper.dart';
import 'fetch.dart';

class SearchPage extends StatefulWidget {
  final List<Fund> allFunds;
  final List<String> fundCodes;

  const SearchPage({
    super.key,
    required this.allFunds,
    required this.fundCodes,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  List<Fund> _results = []; // 当前搜索结果
  bool _loading = false; // 是否正在网络请求

  /* ------------------- 生命周期 ------------------- */
  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /* ------------------- 搜索入口 ------------------- */
  void _onTextChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(val.trim());
    });
  }

  Future<void> _performSearch(String key) async {
    if (key.isEmpty) {
      setState(() => _results = []);
      return;
    }

    // 1) 先在现有列表里过滤
    final localHits =
        widget.allFunds.where((f) {
          return f.name.contains(key) || f.fundcode.contains(key);
        }).toList();

    setState(() => _results = [...localHits]);

    // 2) 如果是 6 位数字且本地没命中，再走网络兜底
    final isCode = RegExp(r'^\d{6}$').hasMatch(key);
    if (isCode && !localHits.any((f) => f.fundcode == key)) {
      setState(() => _loading = true);
      try {
        final netFund = await findFund(key);
        if (!_results.any((f) => f.fundcode == netFund.fundcode)) {
          setState(() => _results.add(netFund));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  /* ------------------- 添加自选 ------------------- */
  Future<void> _addFund(Fund fund) async {
    if (widget.fundCodes.contains(fund.fundcode)) return;

    fund.history = await fetchFundHistory(fund.fundcode);
    
    fund.backdraw_list = calculateMaxDrawdown(fund.history);

    setState(() {
      widget.fundCodes.add(fund.fundcode);
      widget.allFunds.add(fund);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_fund_codes', widget.fundCodes);

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true); // 通知上一页刷新
    }
  }

  /* ------------------- UI ------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索基金')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '输入基金名称或 6 位代码',
                border: const OutlineInputBorder(),
                suffixIcon:
                    _loading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : null,
              ),
              onChanged: _onTextChanged,
            ),
          ),
          Expanded(
            child:
                _results.isEmpty && _controller.text.isNotEmpty
                    ? const Center(child: Text('未找到相关基金'))
                    : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final f = _results[i];
                        final alreadyAdded = widget.fundCodes.contains(
                          f.fundcode,
                        );
                        return ListTile(
                          title: Text(f.name),
                          subtitle: Text(f.fundcode),
                          trailing:
                              alreadyAdded
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addFund(f),
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
