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

  /// Creates a new user in the system.
  /// Returns null on success, or an error message on failure.
  Future<String?> createUser({
    required String name,
    required String email,
    required String password,
    required String roleName,
    required int organizationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.users),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'roleName': roleName,
          'organizationId': organizationId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Success
      }

      // Try to parse error message from backend
      try {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Failed to create user';
      } catch (_) {
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      print('Error creating user: $e');
      return 'Network error: could not reach server';
    }
  }

  /// Creates a new organization.
  /// Returns the created organization on success, or throws an exception on failure.
  Future<UserOrganization> createOrganization({
    required String name,
    required String email,
    required String phone,
    required String address,
    dynamic logo, // Can be an XFile or null
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.organizations);
      final request = http.MultipartRequest('POST', uri);
      
      // Add only Authorization header
      request.headers['Authorization'] = 'Bearer $token';

      
      // Add text fields (only if not empty)
      if (name.isNotEmpty) request.fields['name'] = name;
      if (email.isNotEmpty) request.fields['email'] = email;
      if (phone.isNotEmpty) request.fields['phone'] = phone;
      if (address.isNotEmpty) request.fields['address'] = address;

      // Add logo file if provided (Web-safe way)
      if (logo != null) {
        final bytes = await logo.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'logo',
          bytes,
          filename: logo.name,
        );
        request.files.add(multipartFile);
      }



      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return UserOrganization.fromJson(data);
      } else {
        print('Server Error Body: ${response.body}');
        String errorMessage = 'Failed to create organization';
        try {
          final error = jsonDecode(response.body);
          errorMessage = error['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }

    } catch (e) {
      print('Error creating organization: $e');
      if (e is Exception) rethrow;
      throw Exception('Network error or server unavailable');
    }
  }

}
