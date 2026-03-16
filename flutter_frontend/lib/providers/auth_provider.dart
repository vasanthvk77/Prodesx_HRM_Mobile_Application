import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'HRM_Storage',
      publicKey: 'HRM_KEY',
    ),
  );
  final _authService = AuthService();

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    _token = await _storage.read(key: 'auth_token');
    String? userJson = await _storage.read(key: 'user_data');
    if (userJson != null) {
      _user = User.fromJson(jsonDecode(userJson));
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _authService.login(email, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);

      await _storage.write(key: 'auth_token', value: _token);
      await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));


      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    notifyListeners();
  }
}
