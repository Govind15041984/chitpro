import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  AuthStorage._internal();
  static final AuthStorage instance = AuthStorage._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _tokenKey = "chitpro_jwt";

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    print("TOKEN SAVED => $token");
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    //print("TOKEN READ => $token");
    return token;
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
  }
}
