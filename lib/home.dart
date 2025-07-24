import 'package:flutter/material.dart';
import 'fund.dart';
import 'fetch.dart';


class FundHome extends StatefulWidget {
  final List<Fund> funds;
  FundHome({super.key,required this.funds});
  @override
  State<FundHome> createState() => _FundHomeState();
}

class _FundHomeState extends State<FundHome> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white70,
      child: MyFundList(allFunds: widget.funds)
      
    );
  }
}


