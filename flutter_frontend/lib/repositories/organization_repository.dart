import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_config.dart';
import '../models/organization.dart';
import '../services/auth_service.dart';

final organizationRepositoryProvider = Provider((ref) => OrganizationRepository());

class OrganizationRepository {
  final AuthService _authService = AuthService();

  Future<List<Organization>> getUserOrganizations() async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse(ApiConfig.userOrganizations),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Organization.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load user organizations');
    }
  }

  Future<Organization> getOrganizationById(int id) async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/Organizations/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Organization.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load organization details');
    }
  }

  Future<List<Organization>> getOrganizations() async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/Organizations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Organization.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load all organizations');
    }
  }

  Future<void> updateOrganization({
    required int id,
    required String name,
    String? email,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    int? allowedRadius,
  }) async {
    final token = await _authService.getToken();
    
    final uri = Uri.parse('${ApiConfig.baseUrl}/Organizations/$id');
    final request = http.MultipartRequest('PUT', uri);
    
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['Name'] = name;
    if (email != null) request.fields['Email'] = email;
    if (phone != null) request.fields['Phone'] = phone;
    if (address != null) request.fields['Address'] = address;
    if (latitude != null) request.fields['Latitude'] = latitude.toString();
    if (longitude != null) request.fields['Longitude'] = longitude.toString();
    if (allowedRadius != null) request.fields['AllowedRadius'] = allowedRadius.toString();

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update organization: ${response.statusCode}');
    }
  }

  Future<void> deleteOrganization(int id) async {
    final token = await _authService.getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/Organizations/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete organization: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createOrganization({
    required String name,
    String? email,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    int? allowedRadius,
  }) async {
    final token = await _authService.getToken();
    
    final uri = Uri.parse('${ApiConfig.baseUrl}/Organizations');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['Name'] = name;
    if (email != null) request.fields['Email'] = email;
    if (phone != null) request.fields['Phone'] = phone;
    if (address != null) request.fields['Address'] = address;
    if (latitude != null) request.fields['Latitude'] = latitude.toString();
    if (longitude != null) request.fields['Longitude'] = longitude.toString();
    if (allowedRadius != null) request.fields['AllowedRadius'] = allowedRadius.toString();

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create organization');
      } catch (_) {
        throw Exception('Failed to create organization: ${response.statusCode}');
      }
    }
  }
}
