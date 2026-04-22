import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/api_config.dart';
import '../models/staff_salary.dart';

final salaryRepositoryProvider = Provider((ref) => SalaryRepository());

class SalaryRepository {
  final _storage = const FlutterSecureStorage();
  HubConnection? _hubConnection;

  // Endpoints map
  String get salaryEndpoint => '${ApiConfig.baseUrl}/staff-salary';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- SignalR ---
  Future<void> initSignalR(int organizationId, Function() onUpdate) async {
    if (_hubConnection != null && _hubConnection!.state == HubConnectionState.Connected) {
      await _hubConnection!.invoke('JoinOrganizationGroup', args: [organizationId.toString()]);
      return;
    }

    final token = await _storage.read(key: 'auth_token');

    // Assuming we use the same hub pattern as the React application
    _hubConnection = HubConnectionBuilder()
        .withUrl('${ApiConfig.serverUrl}/hubs/staffsalary', options: HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
        ))
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on('EmployeeChanged', (arguments) {
      onUpdate();
    });
    
    // In Salary.jsx, it listens to AttendanceHub too sometimes, 
    // but the main one for Salary processing is StaffSalaryHub
    _hubConnection!.on('PayrollUpdate', (arguments) {
      onUpdate();
    });

    try {
      await _hubConnection!.start();
      print('SignalR: Connected to StaffSalaryHub');
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

  Future<List<PayrollPreviewModel>> getPayrollPreview({
    required int salaryYearId,
    required int month,
    required int year,
  }) async {
    final response = await http.get(
      Uri.parse('$salaryEndpoint/preview?salaryYearId=$salaryYearId&month=$month&year=$year'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => PayrollPreviewModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load payroll preview: ${response.body}');
    }
  }

  Future<List<StaffSalary>> getMonthlySalaries({
    required int month,
    required int salaryYearId,
  }) async {
    final response = await http.get(
      Uri.parse('$salaryEndpoint/org/$month?salaryYearId=$salaryYearId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => StaffSalary.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load monthly salaries: ${response.body}');
    }
  }

  Future<void> upsertSalary(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(salaryEndpoint),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save salary: ${response.body}');
    }
  }

  Future<void> finalizeSalary({
    required int salaryYearId,
    required int month,
    required int employeeId,
    required bool isFinalized,
  }) async {
    final response = await http.post(
      Uri.parse('$salaryEndpoint/finalize'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'salaryYearId': salaryYearId,
        'month': month,
        'employeeId': employeeId,
        'isFinalized': isFinalized,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to finalize salary: ${response.body}');
    }
  }

  // --- Export Methods ---

  Future<http.Response> exportSalaryRegister({
    required int salaryYearId,
    required int month,
    required int year,
    required String type,
  }) async {
    final url = '${ApiConfig.exportStaffSalary}?salaryYearId=$salaryYearId&month=$month&year=$year&type=$type';
    return await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> exportIndividualPaySlip({
    required int employeeId,
    required int salaryYearId,
    required int month,
    required int year,
  }) async {
    final url = '${ApiConfig.individualPaySlip(employeeId)}?salaryYearId=$salaryYearId&month=$month&year=$year';
    return await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> exportBulkPaySlips({
    required int salaryYearId,
    required int month,
    required int year,
  }) async {
    return await http.post(
      Uri.parse(ApiConfig.exportBulkPaySlips),
      headers: await _getHeaders(),
      body: jsonEncode({
        'salaryYearId': salaryYearId,
        'month': month,
        'year': year,
      }),
    );
  }
}
