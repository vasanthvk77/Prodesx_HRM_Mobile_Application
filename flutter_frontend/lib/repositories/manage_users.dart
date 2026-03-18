import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/manage_users.dart';

class ManageUsersRepository {
  final String token;

  ManageUsersRepository({required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<ManageUser>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.users),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => ManageUser.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<List<UserRole>> getRoles() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.roles),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => UserRole.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching roles: $e');
      return [];
    }
  }

  Future<List<UserOrganization>> getOrganizations() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userOrganizations),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => UserOrganization.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching organizations: $e');
      return [];
    }
  }

  Future<List<dynamic>> getLoginSessions() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.loginSessions),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching login sessions: $e');
      return [];
    }
  }
}
