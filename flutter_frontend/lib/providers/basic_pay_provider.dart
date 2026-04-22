import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee.dart';
import '../models/salary_settings.dart';
import '../models/salary_year.dart';
import '../repositories/salary_settings_repository.dart';
import '../repositories/employee_repository.dart';
import '../providers/auth_provider.dart';

class BasicPayState {
  final List<Employee> employees;
  final List<SalarySettings> settings;
  final List<SalaryYear> years;
  final List<dynamic> organizations;
  final dynamic selectedOrgId;
  final int? selectedYearId;
  final String designationFilter;
  final String searchQuery;
  final bool isLoading;
  final String sortKey;
  final String sortDirection;
  final int currentPage;
  final int pageSize;

  BasicPayState({
    this.employees = const [],
    this.settings = const [],
    this.years = const [],
    this.organizations = const [],
    this.selectedOrgId,
    this.selectedYearId,
    this.designationFilter = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.sortKey = 'name',
    this.sortDirection = 'asc',
    this.currentPage = 1,
    this.pageSize = 10,
  });

  BasicPayState copyWith({
    List<Employee>? employees,
    List<SalarySettings>? settings,
    List<SalaryYear>? years,
    List<dynamic>? organizations,
    dynamic selectedOrgId,
    int? selectedYearId,
    String? designationFilter,
    String? searchQuery,
    bool? isLoading,
    String? sortKey,
    String? sortDirection,
    int? currentPage,
    int? pageSize,
  }) {
    return BasicPayState(
      employees: employees ?? this.employees,
      settings: settings ?? this.settings,
      years: years ?? this.years,
      organizations: organizations ?? this.organizations,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      selectedYearId: selectedYearId ?? this.selectedYearId,
      designationFilter: designationFilter ?? this.designationFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      sortKey: sortKey ?? this.sortKey,
      sortDirection: sortDirection ?? this.sortDirection,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  List<Map<String, dynamic>> get mergedData {
    return employees.map((emp) {
      final setting = settings.indexWhere((s) => s.employeeId == emp.id);
      final s = setting >= 0 ? settings[setting] : null;
      return {
        'employee': emp,
        'ssId': s?.ssId,
        'basicPay': s?.basicPay ?? 0.0,
        'isSet': s != null,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get filteredAndSorted {
    var raw = mergedData.where((m) {
      final Employee emp = m['employee'];
      final matchesSearch = searchQuery.isEmpty ||
          emp.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          ((emp.employeeCode ?? '').toLowerCase().contains(searchQuery.toLowerCase()));

      final matchesDesignation = designationFilter == 'All' ||
          emp.designation == designationFilter;

      return matchesSearch && matchesDesignation;
    }).toList();

    raw.sort((a, b) {
      dynamic aVal, bVal;
      if (sortKey == 'name') {
        aVal = (a['employee'] as Employee).name.toLowerCase();
        bVal = (b['employee'] as Employee).name.toLowerCase();
      } else if (sortKey == 'basicPay') {
        aVal = a['basicPay'];
        bVal = b['basicPay'];
      } else {
        aVal = (a['employee'] as Employee).name.toLowerCase();
        bVal = (b['employee'] as Employee).name.toLowerCase();
      }

      int comparison;
      if (aVal is String && bVal is String) {
        comparison = aVal.compareTo(bVal);
      } else {
        comparison = (aVal as double).compareTo(bVal as double);
      }
      return sortDirection == 'asc' ? comparison : -comparison;
    });

    return raw;
  }

  List<Map<String, dynamic>> get paginated {
    final list = filteredAndSorted;
    final start = (currentPage - 1) * pageSize;
    if (start >= list.length) return [];
    final end = (start + pageSize) > list.length ? list.length : (start + pageSize);
    return list.sublist(start, end);
  }

  List<String> get availableDesignations {
    final designations = employees.map((e) => e.designation ?? '').where((d) => d.isNotEmpty).toSet().toList();
    designations.sort();
    return ['All', ...designations];
  }
}

final basicPayProvider = StateNotifierProvider<BasicPayNotifier, BasicPayState>((ref) {
  return BasicPayNotifier(ref);
});

class BasicPayNotifier extends StateNotifier<BasicPayState> {
  final Ref _ref;

  BasicPayNotifier(this._ref) : super(BasicPayState());

  Future<void> init() async {
    final auth = _ref.read(authProvider);
    final user = auth.user;
    if (user == null) return;

    state = state.copyWith(
      organizations: auth.organizationList,
      selectedOrgId: user.organizationId,
    );

    await _loadYears();
  }

  Future<void> _loadYears() async {
    if (state.selectedOrgId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(salarySettingsRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
      final years = await repo.getSalaryYears(orgId);
      
      int? currentYearId = state.selectedYearId;
      bool yearExists = years.any((y) => y.salaryYearId == currentYearId);
      int? defaultYearId = yearExists ? currentYearId : (years.isNotEmpty ? years[0].salaryYearId : null);

      state = state.copyWith(years: years, selectedYearId: defaultYearId);
      if (defaultYearId != null) {
        await loadData(silent: true);
        _initSignalR();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Load years error: $e');
    }
  }

  Future<void> loadData({bool silent = false}) async {
    if (state.selectedOrgId == null || state.selectedYearId == null) return;
    if (!silent) state = state.copyWith(isLoading: true);

    try {
      final repo = _ref.read(salarySettingsRepositoryProvider);
      final empRepo = _ref.read(employeeRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;

      final emps = await empRepo.getEmployees(orgId);
      final sets = await repo.getSalarySettings(orgId, state.selectedYearId!);

      state = state.copyWith(
        employees: emps,
        settings: sets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Load data error: $e');
    }
  }

  void _initSignalR() {
    final repo = _ref.read(salarySettingsRepositoryProvider);
    final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
    repo.initSignalR(orgId, () {
      loadData(silent: true);
    });
  }

  void setOrgId(dynamic id) {
    if (state.selectedOrgId == id) return;
    
    final oldOrgId = int.tryParse(state.selectedOrgId?.toString() ?? '0') ?? 0;
    _ref.read(salarySettingsRepositoryProvider).disposeSignalR(oldOrgId);

    state = state.copyWith(
      selectedOrgId: id,
      selectedYearId: null,
      employees: [],
      settings: [],
      currentPage: 1,
    );
    _loadYears();
  }

  void setYearId(int id) {
    if (state.selectedYearId == id) return;
    state = state.copyWith(selectedYearId: id, currentPage: 1);
    loadData();
  }

  void setSearch(String q) => state = state.copyWith(searchQuery: q, currentPage: 1);
  void setDesignation(String d) => state = state.copyWith(designationFilter: d, currentPage: 1);
  void setPage(int p) => state = state.copyWith(currentPage: p);
  void setPageSize(int s) => state = state.copyWith(pageSize: s, currentPage: 1);

  void setSort(String key) {
    final direction = (state.sortKey == key && state.sortDirection == 'asc') ? 'desc' : 'asc';
    state = state.copyWith(sortKey: key, sortDirection: direction);
  }

  Future<bool> saveBasicPay({required int employeeId, required double amount}) async {
    try {
      final repo = _ref.read(salarySettingsRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;

      final existingIdx = state.settings.indexWhere((s) => s.employeeId == employeeId);
      if (existingIdx >= 0) {
        final existing = state.settings[existingIdx];
        await repo.updateSalarySettings(
          orgId,
          existing.copyWith(basicPay: amount, salaryYearId: state.selectedYearId!),
        );
      } else {
        await repo.saveSalarySettings(
          orgId,
          SalarySettings(
            ssId: 0,
            employeeId: employeeId,
            basicPay: amount,
            salaryYearId: state.selectedYearId!,
          ),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    final orgId = int.tryParse(state.selectedOrgId?.toString() ?? '0') ?? 0;
    _ref.read(salarySettingsRepositoryProvider).disposeSignalR(orgId);
    super.dispose();
  }
}
