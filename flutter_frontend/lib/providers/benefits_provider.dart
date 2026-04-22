import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/benefit_models.dart';
import '../models/employee.dart';
import '../repositories/benefits_repository.dart';
import '../repositories/employee_repository.dart';
import 'auth_provider.dart';

class BenefitsState {
  final int? organizationId;
  final List<BenefitType> masterTypes;
  final List<BenefitAssignment> assignments;
  final List<Employee> employees;
  final StatutorySettings? statutorySettings;
  final bool isLoading;
  final String? error;

  BenefitsState({
    this.organizationId,
    this.masterTypes = const [],
    this.assignments = const [],
    this.employees = const [],
    this.statutorySettings,
    this.isLoading = false,
    this.error,
  });

  BenefitsState copyWith({
    int? organizationId,
    List<BenefitType>? masterTypes,
    List<BenefitAssignment>? assignments,
    List<Employee>? employees,
    StatutorySettings? statutorySettings,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return BenefitsState(
      organizationId: organizationId ?? this.organizationId,
      masterTypes: masterTypes ?? this.masterTypes,
      assignments: assignments ?? this.assignments,
      employees: employees ?? this.employees,
      statutorySettings: statutorySettings ?? this.statutorySettings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BenefitsNotifier extends StateNotifier<BenefitsState> {
  final BenefitsRepository _repository;
  final EmployeeRepository _employeeRepository;
  final BenefitCategory _category;
  final int? _currentUserId;

  BenefitsNotifier(
    this._repository, 
    this._employeeRepository, 
    this._category, 
    int? initialOrgId, 
    this._currentUserId
  ) : super(BenefitsState(organizationId: initialOrgId)) {
    if (state.organizationId != null) {
      refreshData();
      _initSignalR();
    }
  }

  Future<void> _initSignalR() async {
    if (state.organizationId == null) return;
    
    await _repository.initSignalR(
      organizationId: state.organizationId!,
      category: _category,
      onMasterUpdate: (action) {
        print('SignalR Master Update (${_category.name}): $action');
        fetchMasterTypes(silent: true);
      },
      onStaffUpdate: (action) {
        print('SignalR Staff Update (${_category.name}): $action');
        fetchAssignments(silent: true);
      },
    );
  }

  Future<void> setOrganization(int orgId) async {
    if (state.organizationId == orgId && state.masterTypes.isNotEmpty) return;
    
    // Stop old connections
    _repository.disposeSignalR();
    
    // Update state and re-init, explicitly clearing old data to match React flow
    state = state.copyWith(
      organizationId: orgId, 
      isLoading: true, 
      clearError: true,
      masterTypes: [],
      assignments: [],
      employees: [],
    );
    
    await _initSignalR();
    await refreshData();
  }

  Future<void> refreshData() async {
    if (state.organizationId == null) return;
    
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Parallel fetch matching React's Promise.all logic
      await Future.wait([
        fetchMasterTypes(silent: true),
        fetchAssignments(silent: true),
        fetchEmployees(silent: true),
        if (_category == BenefitCategory.deduction) fetchStatutorySettings(silent: true),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchEmployees({bool silent = false}) async {
    if (state.organizationId == null) return;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    try {
      final emps = await _employeeRepository.getEmployees(state.organizationId!);
      state = state.copyWith(employees: emps, isLoading: silent ? state.isLoading : false);
    } catch (e) {
      if (!silent) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchMasterTypes({bool silent = false}) async {
    if (state.organizationId == null) return;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    try {
      final types = await _repository.getBenefitTypes(state.organizationId, _category);
      state = state.copyWith(masterTypes: types, isLoading: silent ? state.isLoading : false);
    } catch (e) {
      if (!silent) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchAssignments({bool silent = false}) async {
    if (state.organizationId == null) return;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    try {
      final assignments = await _repository.getStaffAssignments(state.organizationId, _category);
      state = state.copyWith(assignments: assignments, isLoading: silent ? state.isLoading : false);
    } catch (e) {
      if (!silent) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  Future<void> fetchStatutorySettings({bool silent = false}) async {
    if (state.organizationId == null || _category != BenefitCategory.deduction) return;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await _repository.getPayrollSettings();
      state = state.copyWith(statutorySettings: settings, isLoading: silent ? state.isLoading : false);
    } catch (e) {
      if (!silent) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // --- Master Type Actions ---
  Future<void> saveMasterType(String fullName, String shortName) async {
    if (state.organizationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newType = BenefitType(
        id: 0,
        organizationId: state.organizationId!,
        fullName: fullName,
        shortName: shortName,
        category: _category,
      );
      await _repository.saveBenefitType(newType);
      await fetchMasterTypes(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateMasterType(BenefitType benefit) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateBenefitType(benefit);
      await fetchMasterTypes(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteMasterType(int id) async {
    if (state.organizationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteBenefitType(id, state.organizationId!, _category);
      await fetchMasterTypes(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // --- Assignment Actions ---
  Future<void> saveAssignment({
    required int benefitId,
    required int employeeId,
    required bool calType,
    required double amount,
  }) async {
    if (state.organizationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final assignment = BenefitAssignment(
        id: 0,
        benefitId: benefitId,
        employeeId: employeeId,
        calType: calType,
        amount: amount,
        createdBy: _currentUserId ?? 0,
        category: _category,
      );
      await _repository.saveStaffAssignment(assignment, state.organizationId!);
      await fetchAssignments(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateAssignment(BenefitAssignment assignment) async {
    if (state.organizationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateStaffAssignment(assignment, state.organizationId!);
      await fetchAssignments(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAssignment(int id) async {
    if (state.organizationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteStaffAssignment(id, state.organizationId!, _category);
      await fetchAssignments(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // --- Statutory Settings Actions ---
  Future<void> updateStatutorySettings(StatutorySettings settings) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updatePayrollSettings(settings);
      await fetchStatutorySettings(silent: true);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    _repository.disposeSignalR();
    super.dispose();
  }
}

// Providers for each category
final allowancesProvider = StateNotifierProvider<BenefitsNotifier, BenefitsState>((ref) {
  final repository = ref.watch(benefitsRepositoryProvider);
  final empRepository = ref.watch(employeeRepositoryProvider);
  final auth = ref.watch(authProvider);
  return BenefitsNotifier(
    repository,
    empRepository,
    BenefitCategory.allowance,
    auth.user?.organizationId,
    auth.user?.id,
  );
});

final deductionsProvider = StateNotifierProvider<BenefitsNotifier, BenefitsState>((ref) {
  final repository = ref.watch(benefitsRepositoryProvider);
  final empRepository = ref.watch(employeeRepositoryProvider);
  final auth = ref.watch(authProvider);
  return BenefitsNotifier(
    repository,
    empRepository,
    BenefitCategory.deduction,
    auth.user?.organizationId,
    auth.user?.id,
  );
});
