import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_config.dart';
import '../models/employee.dart';

final employeeRepositoryProvider = Provider((ref) => EmployeeRepository());

class EmployeeRepository {
  final _storage = FlutterSecureStorage();
  HubConnection? _hubConnection;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- SignalR ---
  Future<void> initSignalR(int organizationId, Function(String action, dynamic data) onUpdate) async {
    if (_hubConnection != null) return;

    final token = await _storage.read(key: 'auth_token');
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(ApiConfig.employeesHub, options: HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
        ))
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on('EmployeeChanged', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        onUpdate(data['action'], data);
      }
    });

    try {
      await _hubConnection!.start();
      print('SignalR: Connected to EmployeesHub');
      // Join the organization group
      await _hubConnection!.invoke('JoinOrganizationGroup', args: [organizationId]);
    } catch (e) {
      print('SignalR Error: $e');
    }
  }

  void disposeSignalR() {
    _hubConnection?.stop();
    _hubConnection = null;
  }

  // --- Employee CRUD ---
  Future<List<Employee>> getEmployees(int? organizationId) async {
    final query = organizationId != null ? '?organizationId=$organizationId' : '';
    final response = await http.get(
      Uri.parse('${ApiConfig.employees}$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load employees: ${response.statusCode}');
    }
  }

  Future<int> createEmployee(Map<String, dynamic> employeeData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.employees),
      headers: await _getHeaders(),
      body: jsonEncode(employeeData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['employeeId'] as int;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create employee');
    }
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> employeeData) async {
    final response = await http.put(
      Uri.parse(ApiConfig.employee(id)),
      headers: await _getHeaders(),
      body: jsonEncode(employeeData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update employee');
    }
  }

  Future<void> deleteEmployee(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.employee(id)),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete employee');
    }
  }

  // --- Dynamic Form Config ---
  Future<List<EmployeeField>> getFormFields(int? organizationId) async {
    final query = organizationId != null ? '?organizationId=$organizationId' : '';
    final response = await http.get(
      Uri.parse('${ApiConfig.employeeFields}$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => EmployeeField.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load form fields');
    }
  }

  Future<void> createMasterField(Map<String, dynamic> fieldData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.createMasterField),
      headers: await _getHeaders(),
      body: jsonEncode(fieldData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create field');
    }
  }

  Future<void> deleteMasterField(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.deleteMasterField(id)),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete field');
    }
  }

  // --- Uploads ---
  Future<String> uploadPhoto(int id, XFile imageFile) async {
    final token = await _storage.read(key: 'auth_token');
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.employeePhoto(id)));
    request.headers['Authorization'] = 'Bearer $token';
    
    final bytes = await imageFile.readAsBytes();
    final mimeType = imageFile.mimeType ?? 'image/jpeg';
    final mimeSplit = mimeType.split('/');
    
    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      bytes, 
      filename: imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg',
      contentType: MediaType(mimeSplit[0], mimeSplit.length > 1 ? mimeSplit[1] : 'jpeg')
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'];
    } else {
      throw Exception('Failed to upload photo');
    }
  }

  Future<String> uploadSignature(int id, XFile signatureFile) async {
    final token = await _storage.read(key: 'auth_token');
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.employeeSignature(id)));
    request.headers['Authorization'] = 'Bearer $token';
    
    final bytes = await signatureFile.readAsBytes();
    final mimeType = signatureFile.mimeType ?? 'image/jpeg';
    final mimeSplit = mimeType.split('/');

    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      bytes, 
      filename: signatureFile.name.isNotEmpty ? signatureFile.name : 'signature.jpg',
      contentType: MediaType(mimeSplit[0], mimeSplit.length > 1 ? mimeSplit[1] : 'jpeg')
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'];
    } else {
      throw Exception('Failed to upload signature');
    }
  }

  // --- Bank Details ---
  Future<EmployeeBankDetails?> getBankDetails(int id) async {
    final response = await http.get(
      Uri.parse(ApiConfig.employeeBankDetails(id)),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') return null;
      return EmployeeBankDetails.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch bank details');
    }
  }

  Future<void> saveBankDetails(int employeeId, Map<String, dynamic> bankData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.employeeBankDetails(employeeId)),
      headers: await _getHeaders(),
      body: jsonEncode(bankData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save bank details');
    }
  }
}
