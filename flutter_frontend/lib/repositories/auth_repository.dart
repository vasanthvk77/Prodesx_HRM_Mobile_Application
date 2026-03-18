import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class AuthRepository {
  /// Simple login method that calls the API and returns a Map containing
  /// the [User] model and the auth [token].
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
        final data = jsonDecode(response.body);
        return {
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to login');
      }
    } catch (e) {
      // Re-throw the error so the provider can handle it
      rethrow;
    }
  }

  /// Switches the organization for the current user session.
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
        final data = jsonDecode(response.body);
        return {
          'token': data['token'],
          'user': data['user'] != null ? User.fromJson(data['user']) : null,
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to switch organization');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user_data');
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  Future<List<dynamic>> getUserOrganizations() async {
    final token = await AuthService().getToken();
    final response = await http.get(
      Uri.parse(ApiConfig.userOrganizations),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user organizations');
    }
  }
}


