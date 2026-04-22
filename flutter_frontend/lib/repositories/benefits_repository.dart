import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/api_config.dart';
import '../models/benefit_models.dart';

final benefitsRepositoryProvider = Provider((ref) => BenefitsRepository());

class BenefitsRepository {
  final _storage = const FlutterSecureStorage();
  HubConnection? _masterHubConnection;
  HubConnection? _staffHubConnection;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- SignalR ---
  Future<void> initSignalR({
    required int organizationId,
    required BenefitCategory category,
    required Function(String action) onMasterUpdate,
    required Function(String action) onStaffUpdate,
  }) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    final masterHubUrl = category == BenefitCategory.allowance 
        ? ApiConfig.allowancesHub 
        : ApiConfig.deductionsHub;
    
    final staffHubUrl = category == BenefitCategory.allowance 
        ? ApiConfig.staffAllowancesHub 
        : ApiConfig.staffDeductionsHub;

    final masterEvent = category == BenefitCategory.allowance 
        ? 'ReceiveAllowanceUpdate' 
        : 'ReceiveDeductionUpdate';

    final staffEvent = category == BenefitCategory.allowance 
        ? 'ReceiveStaffAllowanceUpdate' 
        : 'ReceiveStaffDeductionUpdate';

    // Master Hub
    _masterHubConnection = HubConnectionBuilder()
        .withUrl(masterHubUrl, options: HttpConnectionOptions(accessTokenFactory: () async => token))
        .withAutomaticReconnect()
        .build();

    _masterHubConnection!.on(masterEvent, (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        onMasterUpdate(arguments[0].toString());
      }
    });

    // Staff Hub
    _staffHubConnection = HubConnectionBuilder()
        .withUrl(staffHubUrl, options: HttpConnectionOptions(accessTokenFactory: () async => token))
        .withAutomaticReconnect()
        .build();

    _staffHubConnection!.on(staffEvent, (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        onStaffUpdate(arguments[0].toString());
      }
    });

    try {
      final master = _masterHubConnection;
      final staff = _staffHubConnection;

      if (master != null && staff != null) {
        await master.start();
        await staff.start();
        
        await master.invoke('JoinOrganizationGroup', args: [organizationId]);
        await staff.invoke('JoinOrganizationGroup', args: [organizationId]);
      }
      
      print('SignalR: Connected to ${category.name} hubs');
    } catch (e) {
      print('SignalR Error (${category.name}): $e');
    }
  }

  void disposeSignalR() {
    _masterHubConnection?.stop();
    _staffHubConnection?.stop();
    _masterHubConnection = null;
    _staffHubConnection = null;
  }

  // --- Master Benefit Types CRUD ---
  Future<List<BenefitType>> getBenefitTypes(int? organizationId, BenefitCategory category) async {
    final url = category == BenefitCategory.allowance 
        ? ApiConfig.getAllowanceByOrgId 
        : ApiConfig.getDeductionsByOrgId;
    
    final query = organizationId != null ? '?orgId=$organizationId' : '';
    
    final response = await http.get(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => BenefitType.fromJson(e, category)).toList();
    } else {
      throw Exception('Failed to load ${category.name} types: ${response.statusCode}');
    }
  }

  Future<void> saveBenefitType(BenefitType benefit) async {
    final url = benefit.category == BenefitCategory.allowance 
        ? ApiConfig.saveAllowance 
        : ApiConfig.saveDeduction;
    
    final query = '?orgId=${benefit.organizationId}';
    
    final response = await http.post(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
      body: jsonEncode(benefit.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save ${benefit.category.name} type');
    }
  }

  Future<void> updateBenefitType(BenefitType benefit) async {
    final url = benefit.category == BenefitCategory.allowance 
        ? ApiConfig.updateAllowance 
        : ApiConfig.updateDeduction;
    
    final query = '?orgId=${benefit.organizationId}';

    final response = await http.put(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
      body: jsonEncode(benefit.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update ${benefit.category.name} type');
    }
  }

  Future<void> deleteBenefitType(int id, int organizationId, BenefitCategory category) async {
    final url = category == BenefitCategory.allowance 
        ? ApiConfig.deleteAllowance 
        : ApiConfig.deleteDeduction;
    
    final idParam = category == BenefitCategory.allowance ? 'allowanceId' : 'deductionId';
    final query = '?$idParam=$id&orgId=$organizationId';

    final response = await http.delete(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete ${category.name} type');
    }
  }

  // --- Staff Benefit Assignments CRUD ---
  Future<List<BenefitAssignment>> getStaffAssignments(int? organizationId, BenefitCategory category) async {
    final url = category == BenefitCategory.allowance 
        ? ApiConfig.getStaffAllowanceByOrgId 
        : ApiConfig.getStaffDeductionsByOrgId;
    
    final query = organizationId != null ? '?orgId=$organizationId' : '';
    
    final response = await http.get(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => BenefitAssignment.fromJson(e, category)).toList();
    } else {
      throw Exception('Failed to load ${category.name} assignments: ${response.statusCode}');
    }
  }

  Future<void> saveStaffAssignment(BenefitAssignment assignment, int organizationId) async {
    final url = assignment.category == BenefitCategory.allowance 
        ? ApiConfig.saveStaffAllowance 
        : ApiConfig.saveStaffDeduction;
    
    final query = '?orgId=$organizationId';

    final response = await http.post(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
      body: jsonEncode(assignment.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save ${assignment.category.name} assignment');
    }
  }

  Future<void> updateStaffAssignment(BenefitAssignment assignment, int organizationId) async {
    final url = assignment.category == BenefitCategory.allowance 
        ? ApiConfig.updateStaffAllowance 
        : ApiConfig.updateStaffDeduction;
    
    final query = '?orgId=$organizationId';

    final response = await http.put(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
      body: jsonEncode(assignment.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update ${assignment.category.name} assignment');
    }
  }

  Future<void> deleteStaffAssignment(int id, int organizationId, BenefitCategory category) async {
    final url = category == BenefitCategory.allowance 
        ? ApiConfig.deleteStaffAllowance 
        : ApiConfig.deleteStaffDeduction;
    
    final idParam = category == BenefitCategory.allowance ? 'staffAllowanceId' : 'staffDeductionId';
    final query = '?$idParam=$id&orgId=$organizationId';

    final response = await http.delete(
      Uri.parse('$url$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete ${category.name} assignment');
    }
  }

  // --- Statutory Settings (PF/ESI) ---
  Future<StatutorySettings> getPayrollSettings() async {
    final response = await http.get(
      Uri.parse(ApiConfig.payrollSettings),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return StatutorySettings.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load statutory settings');
    }
  }

  Future<void> updatePayrollSettings(StatutorySettings settings) async {
    final response = await http.post(
      Uri.parse(ApiConfig.payrollSettings),
      headers: await _getHeaders(),
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update statutory settings');
    }
  }
}
