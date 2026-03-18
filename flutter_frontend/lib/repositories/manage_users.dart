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

  Future<String?> grantAccess(int userId, int orgId, int roleId) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.grantAccess(userId)),
        headers: _headers,
        body: jsonEncode({
          'organizationId': orgId,
          'roleId': roleId,
        }),
      );
      if (response.statusCode == 200) {
        return null; // Success
      }
      try {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Grant access failed';
      } catch (_) {
        return 'Grant access failed with status ${response.statusCode}';
      }
    } catch (e) {
      print('Error granting access: $e');
      return 'Network error occurred';
    }
  }

  Future<String?> revokeAccess(int userId, int orgId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.revokeAccess(userId, orgId)),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return null; // Success
      }
      try {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Revoke access failed';
      } catch (_) {
        return 'Revoke access failed with status ${response.statusCode}';
      }
    } catch (e) {
      print('Error revoking access: $e');
      return 'Network error occurred';
    }
  }

  Future<String?> deleteUser(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deleteUser(userId)),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return null; // Success
      }
      try {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Delete user failed';
      } catch (_) {
        return 'Delete user failed with status ${response.statusCode}';
      }
    } catch (e) {
      print('Error deleting user: $e');
      return 'Network error occurred';
    }
  }
}
