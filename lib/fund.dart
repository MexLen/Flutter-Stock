import 'dart:math';

import 'package:Fund/smart_buy.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fetch.dart';
import 'dca_buy.dart';
import 'smart_eva.dart';

class FundHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          SizedBox(width: 100, child: Text('基金名称')),
          SizedBox(width: 100, child: Text('涨跌幅度')),
          SizedBox(width: 100, child: Text('累计净值')),
          SizedBox(width: 100, child: Text('最近回撤')),
        ],
      ),
    );
  }
}

class FundDetailTabView extends StatefulWidget {
  final Fund fund;
  const FundDetailTabView({super.key, required this.fund});

  @override
  _FundDetailTabViewState createState() => _FundDetailTabViewState();
}

class _FundDetailTabViewState extends State<FundDetailTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Future<void> loadHistory() async {
    if (!widget.fund.history90.isEmpty) {
      return;
    }
    var history1 = await fetchFundHistory(
      widget.fund.fundcode,
      page: 1,
      perPage: 30,
    );
    var history2 = await fetchFundHistory(
      widget.fund.fundcode,
      page: 2,
      perPage: 30,
    );
    var history3 = await fetchFundHistory(
      widget.fund.fundcode,
      page: 3,
      perPage: 30,
    );
    setState(() {
      if (widget.fund.history90.isEmpty) {
        widget.fund.history90.addAll(history3);
        widget.fund.history90.addAll(history2);
        widget.fund.history90.addAll(history1);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    loadHistory();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        child: Column(
          children: [
            Container(
              color: Colors.grey[200],
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.black54,
                tabs: [Tab(text: '定投模拟'), Tab(text: '智能买入')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SimulatedDCAPageWithControl(history: widget.fund.history90),
                  SmartBuyPage(history: widget.fund.history90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FundItem extends StatelessWidget {
  final Fund fund;
  FundItem({required this.fund});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FundDetailTabView(fund: this.fund),
                  ),
                );
              },
              child: Text(
                fund.name,
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              fund.gszzl > 0
                  ? '+${fund.gszzl.toStringAsFixed(2)}%'
                  : '${fund.gszzl.toStringAsFixed(2)}%',
              // my_fund.ratio.toString(),
              style: TextStyle(
                color: fund.gszzl < 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 100, child: Text(fund.gsz.toString())),
          SizedBox(
            width: 100,
            child: Text(
              fund.backdraw_list.last > 0
                  ? '-${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%'
                  : '${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%',
              style: TextStyle(
                color: fund.backdraw_list.last > 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
