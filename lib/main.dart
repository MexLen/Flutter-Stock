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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dbHelper.close();
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

      // 切换到我的基金页面
      _tabController.animateTo(0);

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
    }
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [Tab(text: '我的基金'), Tab(text: '基金搜索')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MyFundList(
            allFunds: const [],
            onRefreshCallbackSet: _setRefreshCallback,
          ), // 我的基金页面
          FundSearchPage(onFundAdded: _addFundAndSwitchTab), // 基金搜索页面
        ],
      ),
    );
  }
}

class FundSearchPage extends StatefulWidget {
  final Function(Fund) onFundAdded;

  const FundSearchPage({super.key, required this.onFundAdded});

  @override
  State<FundSearchPage> createState() => _FundSearchPageState();
}

class _FundSearchPageState extends State<FundSearchPage> {
  final _controller = TextEditingController();
  final _dbHelper = FundDbHelper();
  static final RegExp _fundCodeRegex = RegExp(r'^\d{6}$');
  List<Fund> _results = [];
  bool _loading = false;

  static bool isFundCode(String input) {
    if (input.isEmpty) return false;

    // 移除空格
    final cleanInput = input.trim();

    // 检查是否为6位数字
    return _fundCodeRegex.hasMatch(cleanInput);
  }

  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await _dbHelper.search(keyword);
      if (results.isEmpty && isFundCode(keyword)) {
        var fund = await findFund(keyword);
        setState(() => _results = [fund]);
      } else {
        setState(
          () => _results = results.map((map) => Fund.fromDbMap(map)).toList(),
        );
      }
    } catch (e) {
      print('搜索错误: $e');
      setState(() => _results = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // 搜索框区域
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: '输入基金代码或名称搜索...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.blue[400],
                  size: 24,
                ),
                suffixIcon:
                    _controller.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                            setState(() {});
                          },
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                _search(value);
                setState(() {}); // 更新 suffixIcon 显示状态
              },
            ),
          ),

          // 搜索结果
          Expanded(
            child:
                _loading
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
                    : _results.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _controller.text.isEmpty
                                ? Icons.search
                                : Icons.search_off,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _controller.text.isEmpty ? '请输入关键词搜索基金' : '未找到相关基金',
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
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final fund = _results[index];
                        return FundSearchCard(
                          fund: fund,
                          onAdd: () => widget.onFundAdded(fund),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class FundSearchCard extends StatelessWidget {
  final Fund fund;
  final VoidCallback onAdd;

  const FundSearchCard({super.key, required this.fund, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              fund.fundcode.length >= 2
                  ? fund.fundcode.substring(fund.fundcode.length - 2)
                  : fund.fundcode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          fund.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '代码: ${fund.fundcode}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        trailing: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '添加',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
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
