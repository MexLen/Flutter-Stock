import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fetch.dart';
import 'dca_buy.dart';

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

class FundDetail extends StatelessWidget {
  final Fund fund;
  const FundDetail({super.key, required this.fund});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            FundLineChart(history: fund.history, title: this.fund.name),
            FundInfoHeader(fund: fund),
          ],
        ),
        // Expanded(child: SimulatedDCAPageWithControl(history: fund.history)),
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
             fund.backdraw_list.last>0?  '-${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%':'${(fund.backdraw_list.last * 100.0).toStringAsFixed(2)}%',
              style: TextStyle(color: fund.backdraw_list.last > 0 ? Colors.green : Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

