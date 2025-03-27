import 'dart:convert';

void main(){
  var string = """{"Time Series (Daily)": {
        "2025-03-26": {
            "1. open": "4.4400",
            "2. high": "4.4400",
            "3. low": "4.3500",
            "4. close": "4.3600",
            "5. volume": "177140798"
        },
        "2025-03-25": {
            "1. open": "4.3700",
            "2. high": "4.4400",
            "3. low": "4.3300",
            "4. close": "4.4300",
            "5. volume": "169368180"
        }}}""";
    Map<String, dynamic> data = json.decode(string);
    data['Time Series (Daily)'].forEach((key,val){
      print(key);
      print(val);
    });
}