import 'dart:convert';
import 'package:http/http.dart' as http;

// 示例：获取天天基金网某基金的净值信息
Future<Map<String, dynamic>> fetchFundNetValue(String fundCode) async {
  final url = Uri.parse(
      'https://fundgz.1234567.com.cn/js/$fundCode.js?rt=${DateTime.now().millisecondsSinceEpoch}');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    // 天天基金返回的是js格式，需要处理
    final body = response.body;
    final jsonStr = body.substring(body.indexOf('{'), body.lastIndexOf('}') + 1);
    return json.decode(jsonStr);
  } else {
    throw Exception('Failed to load fund data');
  }
}