import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpHelper {
  String baseUrl;
  String? token;
  String? userId; // 新增userId字段

  HttpHelper(this.baseUrl);

  void setToken(String token, String userId) {
    // 修改方法签名
    this.token = token;
    this.userId = userId;
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, String> data, {
    Map<String, String>? headers, // 支持自定义头
  }) async {
    Uri uri = Uri.parse(
      '$baseUrl${endpoint.startsWith('/') ? '' : '/'}$endpoint',
    );
    final client = http.Client();

    try {
      // 合并请求头
      final mergedHeaders = {
        'x-requested-with': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded',
        if (token != null) 'token_data': token!,
        if (userId != null) ...{
          'token_userId': userId!,
          'tokenUserId': userId!,
        },
        ...?headers,
      };

      var response = await client.post(uri, body: data, headers: mergedHeaders);

      // 处理重定向（保持原有逻辑）
      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        uri = Uri.parse(
          redirectUrl!.startsWith('http')
              ? redirectUrl
              : '$baseUrl$redirectUrl',
        );
        response = await client.post(uri, body: data, headers: mergedHeaders);
      }

      if (response.statusCode != 200) {
        throw Exception('请求失败: ${response.statusCode}');
      }

      return jsonDecode(response.body);
    } finally {
      client.close();
    }
  }
}
