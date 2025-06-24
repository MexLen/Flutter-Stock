import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fetch.dart';

class FundHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          SizedBox(width: 100, child: Text('名称')),
          SizedBox(width: 100, child: Text('涨跌')),
          SizedBox(width: 100, child: Text('净值')),
          SizedBox(width: 100, child: Text('回撤')),
        ],
      ),
    );
  }
}

class FundDetail extends StatelessWidget {
  final Fund fund;
  const FundDetail({super.key, required this.fund});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FundLineChart(history: fund.history, title: this.fund.name),
        FundInfoHeader(fund: fund),
      ],
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
                    builder: (context) => FundDetail(fund: this.fund),
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
              '-${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
