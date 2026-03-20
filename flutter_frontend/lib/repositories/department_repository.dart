import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_config.dart';
import '../models/department.dart';
import '../services/auth_service.dart';

final departmentRepositoryProvider = Provider((ref) => DepartmentRepository());

class DepartmentRepository {

  final AuthService _authService = AuthService();

  Future<List<Department>> getDepartments(int organizationId) async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.departments}?organizationId=$organizationId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Department.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load departments');
    }
  }

  Future<void> createDepartment(Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse(ApiConfig.departments),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create department');
    }
  }

  Future<void> updateDepartment(int id, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    final response = await http.put(
      Uri.parse(ApiConfig.department(id)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update department');
    }
  }

  Future<void> deleteDepartment(int id) async {
    final token = await _authService.getToken();
    final response = await http.delete(
      Uri.parse(ApiConfig.department(id)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete department');
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse(ApiConfig.departmentBulkDelete),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(ids),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete departments');
    }
  }
}
