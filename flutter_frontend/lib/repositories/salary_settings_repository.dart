import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/api_config.dart';
import '../models/salary_settings.dart';
import '../models/salary_year.dart';

final salarySettingsRepositoryProvider = Provider((ref) => SalarySettingsRepository());

class SalarySettingsRepository {
  final _storage = const FlutterSecureStorage();
  HubConnection? _hubConnection;

  // Endpoints map
  String get salaryYearEndpoint => '${ApiConfig.baseUrl}/SalaryYear';
  String get salarySettingsEndpoint => '${ApiConfig.baseUrl}/SalarySettings';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- SignalR ---
  Future<void> initSignalR(int organizationId, Function() onUpdate) async {
    if (_hubConnection != null) return;

    final token = await _storage.read(key: 'auth_token');

    _hubConnection = HubConnectionBuilder()
        .withUrl('${ApiConfig.serverUrl}/hubs/salarysettings', options: HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
        ))
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on('ReceiveSalarySettingsUpdate', (arguments) {
      onUpdate();
    });

    try {
      await _hubConnection!.start();
      print('SignalR: Connected to SalarySettingsHub');
      await _hubConnection!.invoke('JoinOrganizationGroup', args: [organizationId.toString()]);
    } catch (e) {
      print('SignalR Error: $e');
    }
  }

  void disposeSignalR(int organizationId) {
    if (_hubConnection != null && _hubConnection!.state == HubConnectionState.Connected) {
      _hubConnection!.invoke('LeaveOrganizationGroup', args: [organizationId.toString()]);
      _hubConnection!.stop();
    }
    _hubConnection = null;
  }

  // --- API ---

  Future<List<SalaryYear>> getSalaryYears(int orgId) async {
    final response = await http.get(
      Uri.parse('$salaryYearEndpoint/GetSalaryYearsByOrgId?orgId=$orgId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => SalaryYear.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load salary years: ${response.statusCode}');
    }
  }

  Future<List<SalarySettings>> getSalarySettings(int orgId, int salaryYearId) async {
    final response = await http.get(
      Uri.parse('$salarySettingsEndpoint/GetSalarySettings?orgId=$orgId&salaryYearId=$salaryYearId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => SalarySettings.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load salary settings: ${response.statusCode}');
    }
  }

  Future<void> saveSalarySettings(int orgId, SalarySettings settings) async {
    final response = await http.post(
      Uri.parse('$salarySettingsEndpoint/SaveSalarySettings?orgId=$orgId'),
      headers: await _getHeaders(),
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save salary settings: ${response.body}');
    }
  }

  Future<void> updateSalarySettings(int orgId, SalarySettings settings) async {
    final response = await http.put(
      Uri.parse('$salarySettingsEndpoint/UpdateSalarySettings?orgId=$orgId'),
      headers: await _getHeaders(),
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update salary settings: ${response.body}');
    }
  }
}
