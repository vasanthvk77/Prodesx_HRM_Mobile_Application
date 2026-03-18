import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/designation.dart';
import '../services/auth_service.dart';

class DesignationRepository {
  final AuthService _authService = AuthService();

  Future<List<Designation>> getDesignations(int? organizationId) async {
    final token = await _authService.getToken();
    final orgId = organizationId ?? 0;
    
    final response = await http.get(
      Uri.parse('${ApiConfig.designations}?organizationId=$orgId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Designation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load designations: ${response.body}');
    }
  }

  Future<void> createDesignation(Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse(ApiConfig.designations),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create designation: ${response.body}');
    }
  }

  Future<void> updateDesignation(int id, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.designations}/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update designation: ${response.body}');
    }
  }

  Future<void> deleteDesignation(int id) async {
    final token = await _authService.getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.designations}/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete designation: ${response.body}');
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.designationBulkDelete}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(ids),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to bulk delete designations: ${response.body}');
    }
  }
}
