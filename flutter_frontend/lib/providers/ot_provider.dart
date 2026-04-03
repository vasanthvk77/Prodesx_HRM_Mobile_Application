import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/ot_model.dart';
import './auth_provider.dart';
import 'package:signalr_netcore/signalr_client.dart';

class OTState {
  final List<OvertimeRecord> records;
  final List<dynamic> organizations;
  final String sortKey;
  final String sortDirection;
  final List<dynamic> employees;
  final dynamic selectedOrgId;
  final bool isLoading;
  final String searchQuery;
  final int currentPage;
  final int pageSize;

  OTState({
    this.sortKey = 'overDutyDate',
    this.sortDirection = 'desc',
    this.records = const [],
    this.organizations = const [],
    this.employees = const [],
    this.selectedOrgId,
    this.isLoading = false,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 25,
  });

  List<OvertimeRecord> get filtered {
    // Only search if records exist
    if (searchQuery.isEmpty) return records;
    final q = searchQuery.toLowerCase();
    return records.where((r) {
      return (r.employeeName?.toLowerCase().contains(q) ?? false) ||
          (r.employeeCode?.toLowerCase().contains(q) ?? false) ||
          (r.remarks?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<OvertimeRecord> get paginated {
    final f = filtered;
    final start = (currentPage - 1) * pageSize;
    if (start >= f.length) return [];
    final end = (start + pageSize) > f.length ? f.length : (start + pageSize);
    return f.sublist(start, end);
  }

  OTState copyWith({
    String? sortKey,
    String? sortDirection,
    List<OvertimeRecord>? records,
    List<dynamic>? organizations,
    List<dynamic>? employees,
    dynamic selectedOrgId,
    bool? isLoading,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
  }) =>
      OTState(
        sortKey: sortKey ?? this.sortKey,
        sortDirection: sortDirection ?? this.sortDirection,
        records: records ?? this.records,
        organizations: organizations ?? this.organizations,
        employees: employees ?? this.employees,
        selectedOrgId: selectedOrgId ?? this.selectedOrgId,
        isLoading: isLoading ?? this.isLoading,
        searchQuery: searchQuery ?? this.searchQuery,
        currentPage: currentPage ?? this.currentPage,
        pageSize: pageSize ?? this.pageSize,
      );
}

final otProvider = StateNotifierProvider<OTNotifier, OTState>((ref) {
  return OTNotifier(ref);
});

class OTNotifier extends StateNotifier<OTState> {
  final Ref _ref;
  HubConnection? _hub;

  OTNotifier(this._ref) : super(OTState());

  Map<String, String> get _headers => _ref.read(authProvider).requestHeaders;

  Future<void> init() async {
    final auth = _ref.read(authProvider);
    final user = auth.user;
    if (user == null) return;

    // Load orgs from auth if available
    state = state.copyWith(
      organizations: auth.organizationList,
      selectedOrgId: user.organizationId,
    );

    await fetchRecords();
    _initSignalR();
  }

  Future<void> _initSignalR() async {
    if (_hub != null) return;
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    _hub = HubConnectionBuilder()
        .withUrl(ApiConfig.empOTHub,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => _ref.read(authProvider).token ?? '',
            ))
        .withAutomaticReconnect()
        .build();

    _hub!.on('ReceiveOTUpdate', (args) {
      fetchRecords();
    });

    _hub!.onreconnected(({connectionId}) {
      if (state.selectedOrgId != null) {
        final hubOrgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
        _hub!.invoke('JoinOrganization', args: [hubOrgId]);
      }
    });

    try {
      await _hub!.start();
      print('SignalR: Connected to EmpOT Hub');
      if (state.selectedOrgId != null) {
        final hubOrgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
        await _hub!.invoke('JoinOrganization', args: [hubOrgId]);
      }
    } catch (e) {
      print('SignalR Error: $e');
    }
  }

  void setOrgId(dynamic id) {
    if (state.selectedOrgId == id) return;
    state = state.copyWith(selectedOrgId: id, records: [], currentPage: 1);
    fetchRecords();
    
    // Update SignalR Room
    if (_hub?.state == HubConnectionState.Connected) {
      final newId = int.tryParse(id.toString());
      if (newId != null) {
        _hub!.invoke('JoinOrganization', args: [newId]);
      }
    }
  }

  Future<void> fetchRecords() async {
    final orgId = state.selectedOrgId;
    if (orgId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final headers = _headers;
      final results = await Future.wait<http.Response>([
        http.get(Uri.parse('${ApiConfig.getOTByOrgId}?orgId=$orgId'), headers: headers),
        http.get(Uri.parse('${ApiConfig.employees}?orgId=$orgId'), headers: headers),
      ]);

      final otRes = results[0];
      final empRes = results[1];

      if (otRes.statusCode == 200 && empRes.statusCode == 200) {
        final List otData = json.decode(otRes.body);
        final List empData = json.decode(empRes.body);

        final enriched = otData.map((json) {
          final record = OvertimeRecord.fromJson(json);
          final emp = empData.firstWhere(
            (e) => e['id']?.toString() == record.employeeId?.toString(),
            orElse: () => null,
          );
          if (emp != null) {
            return record.copyWith(
              employeeName: emp['name'],
              employeeCode: emp['organization_Employee_id'] ?? emp['employeeCode'],
              profilePictureUrl: emp['profilePictureUrl'] ?? emp['ProfilePictureUrl'],
            );
          }
          return record;
        }).toList();

        state = state.copyWith(records: enriched, employees: empData, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setSearch(String q) => state = state.copyWith(searchQuery: q, currentPage: 1);
  void setPage(int p) => state = state.copyWith(currentPage: p);
  void setPageSize(int s) => state = state.copyWith(pageSize: s, currentPage: 1);

  void setSort(String key) {
    final direction = (state.sortKey == key && state.sortDirection == 'asc') ? 'desc' : 'asc';
    state = state.copyWith(sortKey: key, sortDirection: direction);
    _applySort();
  }

  void _applySort() {
    final sorted = List<OvertimeRecord>.from(state.records);
    sorted.sort((a, b) {
      dynamic aVal, bVal;
      switch (state.sortKey) {
        case 'employeeName':
          aVal = a.employeeName ?? '';
          bVal = b.employeeName ?? '';
          break;
        case 'overDutyDate':
          aVal = a.overDutyDate;
          bVal = b.overDutyDate;
          break;
        case 'amount':
          aVal = a.amount;
          bVal = b.amount;
          break;
        case 'hours':
          aVal = a.hours;
          bVal = b.hours;
          break;
        default:
          aVal = a.employeeCode ?? '';
          bVal = b.employeeCode ?? '';
      }
      return state.sortDirection == 'asc' ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
    });
    state = state.copyWith(records: sorted);
  }

  Future<bool> saveOT(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.saveEmpOT),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (res.statusCode == 200) {
        await fetchRecords();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateOT(Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse(ApiConfig.updateEmpOT),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (res.statusCode == 200) {
        await fetchRecords();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteOT(int otId) async {
    final orgId = state.selectedOrgId;
    if (orgId == null) return false;

    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.deleteEmpOT}?otId=$otId&orgId=$orgId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        await fetchRecords();
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _hub?.stop();
    super.dispose();
  }
}
