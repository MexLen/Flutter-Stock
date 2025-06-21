import 'package:flutter/material.dart';
import 'fund.dart';

class FundHome extends StatefulWidget {
  final List<String> funds = [];
  FundHome({super.key});
  @override
  State<FundHome> createState() => _FundHomeState();
}

class _FundHomeState extends State<FundHome> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white70,
      child: Column(
        children: [
          FundHeader(),
          Divider(),
          Expanded(child: FundList()),
        ],
      ),
    );
  }
}
class FundList extends StatelessWidget {
  const FundList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: (context,i){
      return FundCard(my_fund: mockFunds[i]);
    },itemCount: mockFunds.length,);
  }
}


