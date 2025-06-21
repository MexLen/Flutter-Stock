import 'package:flutter/material.dart';
import 'home.dart';
void main() {
  return runApp(
    MaterialApp(
      title: '基金列表',
      initialRoute: '/',
      routes: {
        // ),
      },
      home: Scaffold(
        appBar: AppBar(title: const Text('基金列表')),
        body: FundHome(),
      ),
    ),
  );
}


