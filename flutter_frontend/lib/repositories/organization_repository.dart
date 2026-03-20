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
}
