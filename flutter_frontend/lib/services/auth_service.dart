import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_frontend/core/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );


      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to login');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> switchOrganization(String token, String organizationId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.switchOrganization}?organizationId=$organizationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to switch organization');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_token');
  }
}

