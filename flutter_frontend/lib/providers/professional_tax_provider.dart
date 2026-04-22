import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/professional_tax.dart';
import './auth_provider.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ProfessionalTaxState {
  final List<ProfessionalTax> records;
  final List<dynamic> organizations;
  final String sortKey;
  final String sortDirection;
  final dynamic selectedOrgId;
  final bool isLoading;
  final String searchQuery;
  final int currentPage;
  final int pageSize;

  ProfessionalTaxState({
    this.sortKey = 'fromAmount',
    this.sortDirection = 'asc',
    this.records = const [],
    this.organizations = const [],
    this.selectedOrgId,
    this.isLoading = false,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 10,
  });

  List<ProfessionalTax> get filtered {
    if (searchQuery.isEmpty) return records;
    final q = searchQuery.toLowerCase();
    return records.where((r) {
      return r.taxName.toLowerCase().contains(q);
    }).toList();
  }

  List<ProfessionalTax> get paginated {
    final f = filtered;
    final start = (currentPage - 1) * pageSize;
    if (start >= f.length) return [];
    final end = (start + pageSize) > f.length ? f.length : (start + pageSize);
    return f.sublist(start, end);
  }

  ProfessionalTaxState copyWith({
    String? sortKey,
    String? sortDirection,
    List<ProfessionalTax>? records,
    List<dynamic>? organizations,
    dynamic selectedOrgId,
    bool? isLoading,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
  }) =>
      ProfessionalTaxState(
        sortKey: sortKey ?? this.sortKey,
        sortDirection: sortDirection ?? this.sortDirection,
        records: records ?? this.records,
        organizations: organizations ?? this.organizations,
        selectedOrgId: selectedOrgId ?? this.selectedOrgId,
        isLoading: isLoading ?? this.isLoading,
        searchQuery: searchQuery ?? this.searchQuery,
        currentPage: currentPage ?? this.currentPage,
        pageSize: pageSize ?? this.pageSize,
      );
}

final professionalTaxProvider =
    StateNotifierProvider<ProfessionalTaxNotifier, ProfessionalTaxState>((ref) {
  return ProfessionalTaxNotifier(ref);
});

class ProfessionalTaxNotifier extends StateNotifier<ProfessionalTaxState> {
  final Ref _ref;
  HubConnection? _hub;

  ProfessionalTaxNotifier(this._ref) : super(ProfessionalTaxState());

  Map<String, String> get _headers => _ref.read(authProvider).requestHeaders;

  Future<void> init() async {
    final auth = _ref.read(authProvider);
    final user = auth.user;
    if (user == null) return;

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
        .withUrl(
          ApiConfig.professionalTaxHub,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _ref.read(authProvider).token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hub!.on('ProfessionalTaxChanged', (args) {
      fetchRecords();
    });

    _hub!.onreconnected(({connectionId}) {
      if (state.selectedOrgId != null) {
        _hub!.invoke(
          'JoinOrganizationGroup',
          args: [int.tryParse(state.selectedOrgId.toString()) ?? 0],
        );
      }
    });

    try {
      await _hub!.start();
      if (state.selectedOrgId != null) {
        await _hub!.invoke(
          'JoinOrganizationGroup',
          args: [int.tryParse(state.selectedOrgId.toString()) ?? 0],
        );
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
        _hub!.invoke('JoinOrganizationGroup', args: [newId]);
      }
    }
  }

  Future<void> fetchRecords() async {
    final orgId = state.selectedOrgId;
    if (orgId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.getProfessionalTax}'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        final list = data.map((j) => ProfessionalTax.fromJson(j)).toList();
        state = state.copyWith(records: list, isLoading: false);
        _applySort();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setSearch(String q) =>
      state = state.copyWith(searchQuery: q, currentPage: 1);
  void setPage(int p) => state = state.copyWith(currentPage: p);
  void setPageSize(int s) =>
      state = state.copyWith(pageSize: s, currentPage: 1);

  void setSort(String key) {
    final direction =
        (state.sortKey == key && state.sortDirection == 'asc') ? 'desc' : 'asc';
    state = state.copyWith(sortKey: key, sortDirection: direction);
    _applySort();
  }

  void _applySort() {
    final sorted = List<ProfessionalTax>.from(state.records);
    sorted.sort((a, b) {
      dynamic aVal, bVal;
      switch (state.sortKey) {
        case 'taxName':
          aVal = a.taxName;
          bVal = b.taxName;
          break;
        case 'taxAmount':
          aVal = a.taxAmount;
          bVal = b.taxAmount;
          break;
        default:
          aVal = a.fromAmount;
          bVal = b.fromAmount;
      }
      return state.sortDirection == 'asc'
          ? aVal.compareTo(bVal)
          : bVal.compareTo(aVal);
    });
    state = state.copyWith(records: sorted);
  }

  Future<bool> saveSlab(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.saveProfessionalTax),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> updateSlab(Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse(ApiConfig.updateProfessionalTax),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> deleteSlab(int ptId) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.deleteProfessionalTax}?ptId=$ptId'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _hub?.stop();
    super.dispose();
  }
}
