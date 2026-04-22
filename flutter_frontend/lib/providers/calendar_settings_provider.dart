import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_settings.dart';
import '../models/salary_year.dart';
import '../repositories/calendar_settings_repository.dart';
import '../providers/auth_provider.dart';

class CalendarSettingsState {
  final CalendarSettings? policy;
  final List<SalaryYear> salaryYears;
  final List<dynamic> organizations;
  final dynamic selectedOrgId;
  final bool isLoading;
  final String searchTerm;

  CalendarSettingsState({
    this.policy,
    this.salaryYears = const [],
    this.organizations = const [],
    this.selectedOrgId,
    this.isLoading = false,
    this.searchTerm = '',
  });

  CalendarSettingsState copyWith({
    CalendarSettings? policy,
    List<SalaryYear>? salaryYears,
    List<dynamic>? organizations,
    dynamic selectedOrgId,
    bool? isLoading,
    String? searchTerm,
  }) {
    return CalendarSettingsState(
      policy: policy ?? this.policy,
      salaryYears: salaryYears ?? this.salaryYears,
      organizations: organizations ?? this.organizations,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      isLoading: isLoading ?? this.isLoading,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  // Allow setting policy to null explicitly during org switch
  CalendarSettingsState cloneWithNullablePolicy({
    CalendarSettings? policy,
    List<SalaryYear>? salaryYears,
    List<dynamic>? organizations,
    dynamic selectedOrgId,
    bool? isLoading,
    String? searchTerm,
  }) {
    return CalendarSettingsState(
      policy: policy,
      salaryYears: salaryYears ?? this.salaryYears,
      organizations: organizations ?? this.organizations,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      isLoading: isLoading ?? this.isLoading,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  List<SalaryYear> get filteredYears {
    if (searchTerm.isEmpty) return salaryYears;
    final term = searchTerm.toLowerCase();
    return salaryYears.where((y) => y.fromYear.contains(term) || y.toYear.contains(term)).toList();
  }
}

final calendarSettingsProvider = StateNotifierProvider<CalendarSettingsNotifier, CalendarSettingsState>((ref) {
  return CalendarSettingsNotifier(ref);
});

class CalendarSettingsNotifier extends StateNotifier<CalendarSettingsState> {
  final Ref _ref;

  CalendarSettingsNotifier(this._ref) : super(CalendarSettingsState());

  Future<void> init() async {
    final auth = _ref.read(authProvider);
    final user = auth.user;
    if (user == null) return;

    state = state.copyWith(
      organizations: auth.organizationList,
      selectedOrgId: user.organizationId,
    );

    await loadData();
    _initSignalR();
  }

  Future<void> loadData({bool silent = false}) async {
    if (state.selectedOrgId == null) return;
    if (!silent) state = state.copyWith(isLoading: true);

    try {
      final repo = _ref.read(calendarSettingsRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;

      final policy = await repo.getSettings(orgId);
      final years = await repo.getSalaryYears(orgId);

      state = state.cloneWithNullablePolicy(
        policy: policy,
        salaryYears: years,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Load data error: $e');
    }
  }

  void _initSignalR() {
    final repo = _ref.read(calendarSettingsRepositoryProvider);
    final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
    repo.initSignalR(orgId, () {
      loadData(silent: true);
    });
  }

  void setOrgId(dynamic id) {
    if (state.selectedOrgId == id) return;
    
    final oldOrgId = int.tryParse(state.selectedOrgId?.toString() ?? '0') ?? 0;
    _ref.read(calendarSettingsRepositoryProvider).disposeSignalR(oldOrgId);

    state = state.cloneWithNullablePolicy(
      selectedOrgId: id,
      policy: null,
      salaryYears: [],
    );
    loadData();
    _initSignalR();
  }

  void setSearchTerm(String term) {
    state = state.copyWith(searchTerm: term);
  }

  Future<bool> savePolicy(CalendarSettings settings) async {
    try {
      final repo = _ref.read(calendarSettingsRepositoryProvider);
      await repo.saveSettings(settings);
      await loadData(silent: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveYear(SalaryYear year, {bool isUpdate = false}) async {
    try {
      final repo = _ref.read(calendarSettingsRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
      if (isUpdate) {
        await repo.updateSalaryYear(orgId, year);
      } else {
        await repo.saveSalaryYear(orgId, year);
      }
      return true;
    } catch (e) {
      throw e;
    }
  }

  Future<bool> deleteYear(int salaryYearId) async {
    try {
      final repo = _ref.read(calendarSettingsRepositoryProvider);
      final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;
      await repo.deleteSalaryYear(orgId, salaryYearId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    final orgId = int.tryParse(state.selectedOrgId?.toString() ?? '0') ?? 0;
    _ref.read(calendarSettingsRepositoryProvider).disposeSignalR(orgId);
    super.dispose();
  }
}
