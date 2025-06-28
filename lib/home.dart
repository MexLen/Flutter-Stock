import 'package:flutter/material.dart';
import 'fund.dart';
import 'fetch.dart';


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
        children: [FundHeader(), Divider(), Expanded(child: FundList(fund_codes: ['019260','016573','017489','015290','018413','016343','007466','004317','018561','017867','014402','011555']))]
      ),
    );
  }
}


class FundList extends StatefulWidget {
  
  final List<String> fund_codes;
  FundList({super.key, required this.fund_codes});

  @override
  State<FundList> createState() => _FundListState();
}

class _FundListState extends State<FundList> {
  List<Fund> funds = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFund();
  }

  Future<void> _loadFund() async {
    // 模拟异步加载基金信息
    List<Fund> cache_funds=[];
    for(var fund_code in this.widget.fund_codes){
      var fund = await findFund(fund_code);
      fund.history = await fetchFundHistory(fund.fundcode,perPage: 30);            
      fund.backdraw_list = calculateMaxDrawdown(fund.history);
      cache_funds.add(fund);   
    }
    setState(() {
      funds = cache_funds;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return Center(child: CircularProgressIndicator());
    }else{    
      return ListView.builder(
        itemBuilder: (context, i) {
          return FundItem(fund:funds[i]);
        },
        itemCount: funds.length,
      );
    }
  }
}




