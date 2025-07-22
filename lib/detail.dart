import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'fetch.dart';

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
          body: ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var holding = snapshot.data![index];
              var name = holding['name'];
              var percent = holding['percent'];
              var marketValue = holding['marketValue'];
              var code = holding['code'];
              return Container(
                padding: EdgeInsets.all(10),
                child: Row(                  
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(name),
                    Text(code),
                    Text(percent),
                    Text(marketValue),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
