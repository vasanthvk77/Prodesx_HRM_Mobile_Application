import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import '../models/calendar_settings.dart';
import '../models/salary_year.dart';
import '../core/api_config.dart';
import '../providers/auth_provider.dart';

final calendarSettingsRepositoryProvider = Provider((ref) => CalendarSettingsRepository(ref));

class CalendarSettingsRepository {
  final Ref _ref;
  final Map<int, HubConnection> _salaryYearHubs = {};

  CalendarSettingsRepository(this._ref);

  Map<String, String> get _headers {
    final auth = _ref.read(authProvider);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${auth.token ?? ''}',
    };
  }

  // CALENDAR SETTINGS
  Future<CalendarSettings?> getSettings(int orgId) async {
    final uri = Uri.parse('${ApiConfig.calendarSettings}?organizationId=$orgId');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return CalendarSettings.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<void> saveSettings(CalendarSettings settings) async {
    final uri = Uri.parse(ApiConfig.calendarSettings);
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(settings.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save calendar policy');
    }
  }

  // SALARY YEAR
  Future<List<SalaryYear>> getSalaryYears(int orgId) async {
    final uri = Uri.parse('${ApiConfig.getSalaryYearsByOrgId}?orgId=$orgId');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => SalaryYear.fromJson(j)).toList();
    }
    return [];
  }

  Future<void> saveSalaryYear(int orgId, SalaryYear year) async {
    final uri = Uri.parse('${ApiConfig.saveSalaryYear}?orgId=$orgId');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(year.toJson()),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to add salary year');
    }
  }

  Future<void> updateSalaryYear(int orgId, SalaryYear year) async {
    final uri = Uri.parse('${ApiConfig.updateSalaryYear}?orgId=$orgId');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode(year.toJson()),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to update salary year');
    }
  }

  Future<void> deleteSalaryYear(int orgId, int salaryYearId) async {
    final uri = Uri.parse('${ApiConfig.deleteSalaryYear}?salaryYearId=$salaryYearId&orgId=$orgId');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete salary year');
    }
  }

  // SIGNAL R
  void initSignalR(int orgId, Function onUpdate) async {
    if (_salaryYearHubs.containsKey(orgId)) return;

    final hub = HubConnectionBuilder()
        .withUrl(
          ApiConfig.salaryYearsHub,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _ref.read(authProvider).token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    hub.on('ReceiveSalaryYearUpdate', (args) => onUpdate());

    hub.onreconnected(({connectionId}) {
      if (hub.state == HubConnectionState.Connected) {
        hub.invoke('JoinOrganizationGroup', args: [orgId.toString()]);
      }
    });

    try {
      await hub.start();
      await hub.invoke('JoinOrganizationGroup', args: [orgId.toString()]);
      _salaryYearHubs[orgId] = hub;
    } catch (e) {
      print('SignalR initialization error: $e');
    }
  }

  void disposeSignalR(int orgId) {
    if (_salaryYearHubs.containsKey(orgId)) {
      _salaryYearHubs[orgId]?.stop();
      _salaryYearHubs.remove(orgId);
    }
  }
}
