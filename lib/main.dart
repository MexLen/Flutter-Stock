import 'dart:async';
import 'dart:convert';

import 'package:f_b_kline/src/export_k_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
void main() {
  runApp(MaterialApp(
    home: MyWidget(),
  ));
}
const String tushareToken = '1U84RX9XSSXGKUEY'; 




class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final DataAdapter adapter = DataAdapter();
  

  List<KLineEntity> data = [];
  // This widget is the root of your application.
  
  @override
  Widget build(BuildContext context) {
    

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: Colors.grey,
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 100),
              width: double.maxFinite,
              height: 400,
              child: KChartWidget(
                adapter,
                config: KRunConfig(
                  selectedPriceBuilder: (double? value) {
                    return TextSpan(
                      text: value?.toStringAsFixed(2) ?? '--',
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                  dateFormatter: (int? value) {
                    return formatDate(
                        DateTime.fromMillisecondsSinceEpoch(value ?? 0));
                  },
                  mainValueFormatter: (number) {
                    return number?.toStringAsFixed(3) ?? '--';
                  },
                  volValueFormatter: (number) {
                    return number?.toStringAsFixed(3) ?? '--';
                  },
                  infoBuilder: (klineEntry) {
                    return <TextSpan, TextSpan>{
                      const TextSpan(text: 'Date'): TextSpan(
                          text: formatDate2(
                        DateTime.fromMillisecondsSinceEpoch(
                            klineEntry.time ?? 0),
                      )),
                      const TextSpan(text: 'open'):
                          TextSpan(text: klineEntry.open.toStringAsFixed(3)),
                      const TextSpan(text: 'high'):
                          TextSpan(text: klineEntry.high.toStringAsFixed(3)),
                      const TextSpan(text: 'low'):
                          TextSpan(text: klineEntry.low.toStringAsFixed(3)),
                      const TextSpan(text: 'close'):
                          TextSpan(text: klineEntry.close.toStringAsFixed(3)),
                      const TextSpan(text: 'vol'):
                          TextSpan(text: klineEntry.vol.toStringAsFixed(3)),
                    };
                  },
                ),
              ),
            ),
           
          ],
        ),
      ),
    );
  }

  String formatDate(DateTime value) {
    return DateFormat('HH:mm:ss').format(value);
  }

  String formatDate2(DateTime value) {
    return DateFormat('MM/dd HH:mm').format(value);
  }

  Future<void> getData()async{
      final url = Uri.parse('https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=600795.SHH&apikey=$tushareToken');
      final headers = {'Content-Type': 'application/json'};    

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        Map<String, dynamic> res = json.decode(response.body)['Time Series (Daily)'];
        
        setState(() {
          List<KLineEntity> data = [];
          for(var entry in res.entries){
            var key = entry.key;
            var item = entry.value;
            final date = DateFormat('yyyy-MM-dd').parse(key);
            final stamp = date.microsecondsSinceEpoch;
            data.add(KLineEntity()
              ..time = stamp
              ..open = double.parse(item['1. open'])
              ..high = double.parse(item['2. high'])
              ..low = double.parse(item['3. low'])
              ..close = double.parse(item['4. close'])
              ..vol = double.parse(item['5. volume']));
                          
          } 
          data = data.reversed.toList();       
          adapter.resetData(data);
        });
  }
  }
  void initState() {
    super.initState();
    getData();
  }
}