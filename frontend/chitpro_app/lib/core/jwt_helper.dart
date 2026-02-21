import 'dart:convert';

class JwtHelper {
  static String getAdminId(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception("Invalid JWT");

    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final data = jsonDecode(payload);

    return data['sub'];
  }
}
