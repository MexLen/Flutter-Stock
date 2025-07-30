import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'fetch.dart';
import 'fund.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '基金助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const FundHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FundHomePage extends StatefulWidget {
  const FundHomePage({super.key});

  @override
  State<FundHomePage> createState() => _FundHomePageState();
}

class _FundHomePageState extends State<FundHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dbHelper = FundDbHelper();
  // 使用回调函数替代 GlobalKey
  VoidCallback? _refreshMyFundList;
  final _searchController = TextEditingController();
  List<Fund> _searchResults = [];
  bool _searching = false;
  bool _loadingSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this); // 只需要一个标签页
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dbHelper.close();
    _searchController.dispose();
    super.dispose();
  }

  // 设置刷新回调函数
  void _setRefreshCallback(VoidCallback callback) {
    _refreshMyFundList = callback;
  }

  // 添加基金并切换到我的基金页面
  Future<void> _addFundAndSwitchTab(Fund fund) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> myFundCodes = prefs.getStringList('my_fund_codes') ?? [];

      // 检查是否已经添加过
      if (myFundCodes.contains(fund.fundcode)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fund.name} 已在我的基金中'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      // 添加基金代码到本地存储
      myFundCodes.add(fund.fundcode);
      await prefs.setStringList('my_fund_codes', myFundCodes);

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fund.name} 已添加到自选'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // 刷新我的基金列表
      if (_refreshMyFundList != null) {
        _refreshMyFundList!();
      }
    } catch (e) {
      print('添加基金失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败，请重试'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (_refreshMyFundList != null) {
        _refreshMyFundList!();
      }
    }
  }

  // 搜索基金
  Future<void> _searchFunds(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _loadingSearch = true;
    });

    try {
      final results = await _dbHelper.search(keyword);
      if (results.isEmpty && _isFundCode(keyword)) {
        var fund = await findFund(keyword);
        setState(() => _searchResults = [fund]);
      } else {
        setState(
          () =>
              _searchResults =
                  results.map((map) => Fund.fromDbMap(map)).toList(),
        );
      }
    } catch (e) {
      try {
        var fund = await findFund(keyword);
        setState(() => _searchResults = [fund]);
      } catch (e) {
        setState(() => _searchResults = []);
      }
    } finally {
      setState(() => _loadingSearch = false);
    }
  }

  // 判断是否为基金代码
  bool _isFundCode(String input) {
    if (input.isEmpty) return false;
    final cleanInput = input.trim();
    final fundCodeRegex = RegExp(r'^\d{6}$');
    return fundCodeRegex.hasMatch(cleanInput);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '基金助手',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        // 移除 TabBar
      ),
      body: Column(
        children: [
          // 搜索框区域
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: '搜索基金代码或名称...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.blue[400],
                  size: 24,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                            _searchFunds('');
                            setState(() {});
                          },
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onChanged: (value) {
                _searchFunds(value);
                setState(() {});
              },
            ),
          ),

          // 主要内容区域
          Expanded(
            child:
                _searching
                    ? _buildSearchResults() // 显示搜索结果
                    : MyFundList(
                      allFunds: const [],
                      onRefreshCallbackSet: _setRefreshCallback,
                      dbHelper: _dbHelper,
                    ), // 显示我的基金
          ),
        ],
      ),
    );
  }

  // 构建搜索结果
  Widget _buildSearchResults() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child:
          _loadingSearch
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      '搜索中...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
              : _searchResults.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isEmpty
                          ? Icons.search
                          : Icons.search_off,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _searchController.text.isEmpty ? '请输入关键词搜索基金' : '未找到相关基金',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final fund = _searchResults[index];
                  return _FundSearchCard(
                    fund: fund,
                    onAdd: () => _addFundAndSwitchTab(fund),
                  );
                },
              ),
    );
  }
}

// 基金搜索卡片组件
class _FundSearchCard extends StatelessWidget {
  final Fund fund;
  final VoidCallback onAdd;

  const _FundSearchCard({required this.fund, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              fund.fundcode.length >= 2
                  ? fund.fundcode.substring(fund.fundcode.length - 2)
                  : fund.fundcode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          fund.name,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '代码: ${fund.fundcode}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        trailing: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '添加',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        onTap: onAdd,
      ),
    );
  }
}
