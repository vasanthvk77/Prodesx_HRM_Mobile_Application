import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/staff_salary.dart';
import '../models/salary_year.dart';
import '../models/organization.dart';
import '../repositories/salary_repository.dart';
import '../repositories/salary_settings_repository.dart';
import '../repositories/organization_repository.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/org_dropdown.dart';
import '../core/api_config.dart';
import '../utils/download_helper.dart'; // Add this

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});

  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isExporting = false; // Add this
  String? _error;

  List<Organization> _organizations = [];
  Organization? _selectedOrg;

  List<SalaryYear> _salaryYears = [];
  SalaryYear? _selectedSalaryYear;

  int _selectedMonth = DateTime.now().month;
  int _selectedCalendarYear = DateTime.now().year;

  // Data
  List<StaffSalary> _savedSalaries = [];
  List<PayrollPreviewModel> _previewSalaries = [];
  bool _isPreviewMode = false;
  bool _isFinalizedCurrentMonth = false;

  // Computed columns for dynamic display
  Set<String> _dynamicAllowanceNames = {};
  Set<String> _dynamicDeductionNames = {};
  bool _hasPF = false;
  bool _hasESI = false;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 5;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sort
  String _sortColumn = 'employeeName';
  bool _isAscending = true;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    if (_selectedOrg != null) {
      ref.read(salaryRepositoryProvider).disposeSignalR(_selectedOrg!.id);
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _organizations = await ref.read(organizationRepositoryProvider).getOrganizations();
      if (_organizations.isNotEmpty) {
        _selectedOrg = _organizations.first;
        await _loadSalaryYears();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOrgChange(Organization org) async {
    if (_selectedOrg?.id == org.id) return;

    setState(() => _isProcessing = true);
    try {
      // Switch organization on backend (updates session/token)
      await ref.read(authProvider.notifier).switchOrganization(org.id.toString());
      
      // Dispose SignalR for the previous organization
      if (_selectedOrg != null) {
        ref.read(salaryRepositoryProvider).disposeSignalR(_selectedOrg!.id);
      }

      setState(() {
        _selectedOrg = org;
        _savedSalaries = [];
        _previewSalaries = [];
        _isPreviewMode = false;
        _salaryYears = [];
        _selectedSalaryYear = null;
      });

      // Reload salary years and then data for the new organization
      await _loadSalaryYears();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch organization: $e'))
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _loadSalaryYears() async {
    if (_selectedOrg == null) return;
    try {
      _salaryYears = await ref.read(salarySettingsRepositoryProvider).getSalaryYears(_selectedOrg!.id);
      if (_salaryYears.isNotEmpty) {
        _selectedSalaryYear = _salaryYears.firstWhere((sy) => sy.dateFrom.year <= DateTime.now().year && sy.dateTo.year >= DateTime.now().year, orElse: () => _salaryYears.first);
        await _loadSalaryData();
        
        // SignalR
        ref.read(salaryRepositoryProvider).initSignalR(_selectedOrg!.id, () {
          if (mounted) _loadSalaryData();
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadSalaryData() async {
    if (_selectedSalaryYear == null || _selectedOrg == null) return;

    setState(() {
      _isProcessing = true;
      _isPreviewMode = false;
      _dynamicAllowanceNames.clear();
      _dynamicDeductionNames.clear();
      _hasPF = false;
      _hasESI = false;
    });

    try {
      final salaries = await ref.read(salaryRepositoryProvider).getMonthlySalaries(
        month: _selectedMonth,
        salaryYearId: _selectedSalaryYear!.salaryYearId,
      );

      setState(() {
        _savedSalaries = salaries;
        _isFinalizedCurrentMonth = salaries.isNotEmpty && salaries.first.isFinalized;
        
        // Extract unique column names
        for (var s in salaries) {
          if (s.allowancesDetail != null) {
            for (var d in s.allowancesDetail!) {
              if (d.name.isNotEmpty) _dynamicAllowanceNames.add(d.name);
            }
          }
          if (s.deductionsDetail != null) {
            for (var d in s.deductionsDetail!) {
              if (d.name == 'PF') _hasPF = true;
              else if (d.name == 'ESI') _hasESI = true;
              else if (d.name.isNotEmpty) _dynamicDeductionNames.add(d.name);
            }
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _calculatePayroll() async {
    if (_selectedSalaryYear == null) return;
    
    setState(() => _isProcessing = true);
    try {
      final previews = await ref.read(salaryRepositoryProvider).getPayrollPreview(
        salaryYearId: _selectedSalaryYear!.salaryYearId,
        month: _selectedMonth,
        year: _selectedCalendarYear,
      );

      setState(() {
        _previewSalaries = previews;
        _isPreviewMode = true;
        _dynamicAllowanceNames.clear();
        _dynamicDeductionNames.clear();
        _hasPF = false;
        _hasESI = false;

        for (var p in previews) {
          if (p.allowancesDetail != null) {
            for (var d in p.allowancesDetail!) {
              if (d.name.isNotEmpty) _dynamicAllowanceNames.add(d.name);
            }
          }
          if (p.deductionsDetail != null) {
            for (var d in p.deductionsDetail!) {
              if (d.name == 'PF') _hasPF = true;
              else if (d.name == 'ESI') _hasESI = true;
              else if (d.name.isNotEmpty) _dynamicDeductionNames.add(d.name);
            }
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calculation Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _savePayroll() async {
    if (_previewSalaries.isEmpty || _selectedSalaryYear == null) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      
      for (var preview in _previewSalaries) {
        if (preview.isFinalized) continue;

        await repo.upsertSalary({
          'salaryYearId': _selectedSalaryYear!.salaryYearId,
          'month': _selectedMonth,
          'employeeId': preview.employeeId,
          'baseBasicPay': preview.baseBasicPay,
          'presentDays': preview.presentDays,
          'totalDaysInMonth': preview.totalDaysInMonth,
          'allowancesDetail': preview.allowancesDetail?.map((d) => d.toJson()).toList() ?? [], // Send as JSON array/string equivalent ? Assuming API handles JSON conversion correctly. We might need jsonEncode here if the backend expects string
          'deductionsDetail': preview.deductionsDetail?.map((d) => d.toJson()).toList() ?? [],
          'netSalary': preview.earnedBasicPay, // Earned Basic mapped to netSalary in model
          'totalAllowance': preview.totalAllowance,
          'totalDeduction': preview.totalDeduction,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll saved successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      await _loadSalaryData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _finalizePayroll({bool isUnlocking = false}) async {
    if (_selectedSalaryYear == null || (!isUnlocking && _savedSalaries.isEmpty)) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(isUnlocking ? 'Unlock Payroll' : 'Lock Payroll', style: const TextStyle(color: Colors.white)),
        content: Text(
          isUnlocking 
            ? 'Are you sure you want to unlock this month\'s payroll? This will allow further changes.'
            : 'Are you sure you want to lock this payroll? No further changes will be allowed.', 
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isUnlocking ? const Color(0xFF6366F1) : Colors.red),
            onPressed: () => Navigator.pop(c, true), 
            child: Text(isUnlocking ? 'Yes, Unlock' : 'Yes, Lock', style: const TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(salaryRepositoryProvider).finalizeSalary(
        salaryYearId: _selectedSalaryYear!.salaryYearId,
        month: _selectedMonth,
        employeeId: 0, // All
        isFinalized: !isUnlocking,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUnlocking ? 'Payroll Unlocked' : 'Payroll Locked', style: const TextStyle(color: Colors.white)), 
        backgroundColor: Colors.green
      ));
      await _loadSalaryData();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleExport(String type) async {
    if (_selectedSalaryYear == null || _selectedOrg == null) return;
    
    if (_savedSalaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please calculate and SAVE the payroll before exporting.', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isExporting = true);
    
    try {
      final repo = ref.read(salaryRepositoryProvider);
      dynamic response;
      String fileName = '';
      String mimeType = '';

      final monthName = _months[_selectedMonth - 1];
      final yearStr = _selectedCalendarYear.toString();

      if (type == 'bulk') {
        response = await repo.exportBulkPaySlips(
          salaryYearId: _selectedSalaryYear!.salaryYearId,
          month: _selectedMonth,
          year: _selectedCalendarYear,
        );
        fileName = 'PaySlips_Bulk_${monthName}_$yearStr.zip';
        mimeType = 'application/zip';
      } else {
        response = await repo.exportSalaryRegister(
          salaryYearId: _selectedSalaryYear!.salaryYearId,
          month: _selectedMonth,
          year: _selectedCalendarYear,
          type: type, // 'excel' or 'pdf'
        );
        if (type == 'excel') {
          fileName = 'Salary_Register_${monthName}_$yearStr.xlsx';
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } else {
          fileName = 'Salary_Register_${monthName}_$yearStr.pdf';
          mimeType = 'application/pdf';
        }
      }

      if (response.statusCode == 200) {
        await FileDownloadUtils.download(
          bytes: response.bodyBytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$fileName downloaded successfully!', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: ${response.body}', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export Error: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportIndividualPaySlip(StaffSalary salary) async {
    if (_selectedSalaryYear == null) return;

    setState(() => _isExporting = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final response = await repo.exportIndividualPaySlip(
        employeeId: salary.employeeId,
        salaryYearId: _selectedSalaryYear!.salaryYearId,
        month: _selectedMonth,
        year: _selectedCalendarYear,
      );

      if (response.statusCode == 200) {
        final monthName = _months[_selectedMonth - 1];
        final cleanName = (salary.employeeName ?? 'Employee').replaceAll(' ', '_');
        final fileName = 'PaySlip_${cleanName}_${monthName}_$_selectedCalendarYear.pdf';

        await FileDownloadUtils.download(
          bytes: response.bodyBytes,
          fileName: fileName,
          mimeType: 'application/pdf',
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pay slip downloaded successfully!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: ${response.body}', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export Error: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  PopupMenuItem<String> _buildExportItem(String value, IconData icon, String title, String subtitle) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  double _getMetric(String type) {
    if (_isPreviewMode) {
      if (_previewSalaries.isEmpty) return 0;
      switch (type) {
        case 'Gross': return _previewSalaries.fold(0, (sum, item) => sum + item.grossSalary);
        case 'Allowances': return _previewSalaries.fold(0, (sum, item) => sum + item.totalAllowance);
        case 'Deductions': return _previewSalaries.fold(0, (sum, item) => sum + item.totalDeduction);
        case 'Net': return _previewSalaries.fold(0, (sum, item) => sum + item.grossSalary); // Actually Net is equivalent to Gross here based on the React logic
      }
    } else {
      if (_savedSalaries.isEmpty) return 0;
      switch (type) {
        case 'Gross': return _savedSalaries.fold(0, (sum, item) => sum + item.grossSalary);
        case 'Allowances': return _savedSalaries.fold(0, (sum, item) => sum + item.totalAllowance);
        case 'Deductions': return _savedSalaries.fold(0, (sum, item) => sum + item.totalDeduction);
        case 'Net': return _savedSalaries.fold(0, (sum, item) => sum + item.grossSalary);
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    final theme = Theme.of(context);

    final sortedAllowances = _dynamicAllowanceNames.toList()..sort();
    final sortedDeductions = _dynamicDeductionNames.toList()..sort();

    int totalItems = _isPreviewMode ? _previewSalaries.length : _savedSalaries.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages) _currentPage = 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setHRManagementContent(null);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildFilterBar(),
            const SizedBox(height: 24),
            _buildTopSummaryCards(),
            Expanded(
              child: _buildMainContent(sortedAllowances, sortedDeductions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = theme.platform == TargetPlatform.iOS;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1))),
      ),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isIOS) ...[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(CupertinoIcons.back, color: theme.iconTheme.color, size: 24),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 24),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Salary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  if (_isFinalizedCurrentMonth)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.lock_person_rounded, color: Color(0xFF6366F1), size: 14),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildHeaderActions(),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isIOS) ...[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Salary', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          if (_isFinalizedCurrentMonth) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_person_rounded, color: Color(0xFF6366F1), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Finalized & Locked'.toUpperCase(),
                                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'SNAPSHOT MANAGEMENT · PREVIEW CALCULATIONS OR VIEW HISTORICAL LOCKED DATA',
                        style: TextStyle(
                          color: _isFinalizedCurrentMonth ? Colors.greenAccent : const Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildHeaderActions(),
            ],
          ),
    );
  }

  Widget _buildHeaderActions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isFinalizedCurrentMonth && (_isPreviewMode || _savedSalaries.isNotEmpty)) ...[
          OutlinedButton.icon(
            onPressed: _savePayroll,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save Draft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        ElevatedButton.icon(
          onPressed: () => _finalizePayroll(isUnlocking: _isFinalizedCurrentMonth),
          icon: Icon(_isFinalizedCurrentMonth ? Icons.lock_open_outlined : Icons.lock_person_outlined, size: 16),
          label: Text(_isFinalizedCurrentMonth ? 'Unlock' : 'Lock Payroll', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFinalizedCurrentMonth ? Colors.transparent : const Color(0xFF6366F1),
            foregroundColor: _isFinalizedCurrentMonth ? const Color(0xFF6366F1) : Colors.white,
            side: _isFinalizedCurrentMonth ? const BorderSide(color: Color(0xFF6366F1)) : BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: const Size(0, 36),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        Theme(
          data: Theme.of(context).copyWith(cardColor: isDark ? const Color(0xFF1E293B) : theme.cardColor),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 45),
            onSelected: _handleExport,
            itemBuilder: (context) => [
              _buildExportItem('excel', Icons.table_chart_outlined, 'Export Excel', 'Microsoft Excel Format'),
              _buildExportItem('pdf', Icons.picture_as_pdf_outlined, 'Export PDF', 'Standard PDF Report'),
              const PopupMenuDivider(height: 1),
              _buildExportItem('bulk', Icons.archive_outlined, 'Bulk Pay Slips', 'All Employee Slips (ZIP)'),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.transparent : Colors.white,
                border: Border.all(color: isDark ? const Color(0xFF334155) : theme.primaryColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _isExporting 
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : theme.primaryColor))
                    : Icon(Icons.file_download_outlined, color: isDark ? Colors.white : theme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text('Export', style: TextStyle(color: isDark ? Colors.white : theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : theme.primaryColor, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isFinalizedCurrentMonth ? null : _calculatePayroll,
          icon: const Icon(Icons.calculate_rounded, size: 16),
          label: const Text('Calculate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFinalizedCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFF6366F1),
            foregroundColor: _isFinalizedCurrentMonth ? const Color(0xFF64748B) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: const Size(0, 36),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }


  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    return Container(
      color: theme.cardColor.withOpacity(0.5),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildOrgSelector(),
                const SizedBox(width: 12),
                _buildDropdown<SalaryYear>(
                  label: 'Salary Year',
                  value: _selectedSalaryYear,
                  items: _salaryYears,
                  itemLabel: (sy) => '${sy.fromYear}-${sy.toYear}',
                  onChanged: (sy) {
                    if (sy != null) {
                      setState(() => _selectedSalaryYear = sy);
                      _loadSalaryData();
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildDropdown<int>(
                  label: 'Month',
                  value: _selectedMonth,
                  items: [for (var i = 1; i <= 12; i++) i],
                  itemLabel: (m) => _months[m - 1],
                  onChanged: (m) {
                    if (m != null) {
                      setState(() => _selectedMonth = m);
                      if (!_isPreviewMode) _loadSalaryData();
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildDropdown<int>(
                  label: 'Cal. Year',
                  value: _selectedCalendarYear,
                  items: [for (var i = 2023; i <= 2030; i++) i],
                  itemLabel: (y) => y.toString(),
                  onChanged: (y) {
                    if (y != null) {
                      setState(() => _selectedCalendarYear = y);
                      if (!_isPreviewMode) _loadSalaryData();
                    }
                  },
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 24),
                  _buildResetButton(),
                ],
              ],
            ),
          ),
          if (isMobile) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSearchBox()),
              if (isMobile) ...[
                const SizedBox(width: 8),
                _buildResetButton(),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildOrgSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Organization', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        OrgDropdown(
          value: _selectedOrg?.id.toString(),
          items: _organizations
              .map((org) => OrgDropdownItem(
                    id: org.id.toString(),
                    name: org.name,
                    logoUrl: org.logoUrl,
                  ))
              .toList(),
          onChanged: (idStr) {
            if (idStr != null) {
              final id = int.tryParse(idStr);
              if (id != null) {
                final org = _organizations.firstWhere((o) => o.id == id);
                _handleOrgChange(org);
              }
            }
          },
          isCompact: true,
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('', style: TextStyle(fontSize: 11)), // Empty label for alignment
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.transparent : Colors.grey.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search employee name or code...',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black38, fontSize: 12),
              prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF64748B) : Colors.black45, size: 16),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
                _currentPage = 1;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF94A3B8) : Colors.black54;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _resetFilters,
          icon: Icon(Icons.refresh, size: 16, color: color),
          label: Text('Reset', style: TextStyle(color: color, fontSize: 13)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.transparent : Colors.grey.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              dropdownColor: theme.cardColor,
              value: value,
              icon: Icon(
                Icons.arrow_drop_down,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                size: 16,
              ),
              isDense: true,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedMonth = DateTime.now().month;
      _selectedCalendarYear = DateTime.now().year;
      _isPreviewMode = false;
      _previewSalaries = [];
      _currentPage = 1;
      _sortColumn = 'employeeName';
      _isAscending = true;
    });
    _loadSalaryData();
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
    });
  }

  dynamic _getPropertyValue(dynamic item, String column) {
    if (column == 'employeeName') return (item.employeeName ?? '').toString().toLowerCase();
    if (column == 'baseBasicPay') return item.baseBasicPay ?? 0.0;
    if (column == 'netSalary') return item.netSalary ?? 0.0;
    if (column == 'employeeCode') return (item.employeeCode ?? '').toString().toLowerCase();
    return 0.0;
  }

  Widget _buildTopSummaryCards() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final totalInMonth = _isPreviewMode ? _previewSalaries.length : _savedSalaries.length;
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    // Filtered Count calculation for employees card
    List<dynamic> currentList = _isPreviewMode ? _previewSalaries : _savedSalaries;
    if (_searchQuery.isNotEmpty) {
      currentList = currentList.where((item) {
        final name = (item.employeeName ?? '').toLowerCase();
        final code = (item.employeeCode ?? '').toLowerCase();
        return name.contains(_searchQuery) || code.contains(_searchQuery);
      }).toList();
    }
    final filteredCount = currentList.length;

    final cards = [
      _buildSummaryCard('Total Gross', fmt.format(_getMetric('Gross')), Icons.account_balance_wallet_rounded, const Color(0xFF6366F1)),
      _buildSummaryCard('Allowances', fmt.format(_getMetric('Allowances')), Icons.trending_up, const Color(0xFF22C55E)),
      _buildSummaryCard('Deductions', fmt.format(_getMetric('Deductions')), Icons.trending_down, const Color(0xFFEF4444)),
      _buildSummaryCard('Employees', '$filteredCount / $totalInMonth', Icons. people_alt_rounded, const Color(0xFFF59E0B)),
    ];

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: cards,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList(),
      ),
    );
  }


  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainContent(List<String> sortedAllowances, List<String> sortedDeductions) {
    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    List<dynamic> currentList = _isPreviewMode ? _previewSalaries : _savedSalaries;
    
    // Search Filter
    if (_searchQuery.isNotEmpty) {
      currentList = currentList.where((item) {
        final name = (item.employeeName ?? '').toLowerCase();
        final code = (item.employeeCode ?? '').toLowerCase();
        return name.contains(_searchQuery) || code.contains(_searchQuery);
      }).toList();
    }

    // Sort
    currentList.sort((a, b) {
      var av = _getPropertyValue(a, _sortColumn);
      var bv = _getPropertyValue(b, _sortColumn);
      int res = Comparable.compare(av, bv);
      return _isAscending ? res : -res;
    });

    final totalCount = currentList.length;

    // Slice for Pagination
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage > totalCount) ? totalCount : startIndex + _itemsPerPage;
    final paginatedList = totalCount > 0 ? currentList.sublist(startIndex, endIndex) : [];

    if (totalCount == 0) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _isPreviewMode ? 'No attendance data to calculate.' : 'No saved records found.',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black45, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Combined Header width calculations
    final allowanceCount = sortedAllowances.length;
    final deductionCount = sortedDeductions.length;
    final statCount = (_hasPF ? 1 : 0) + (_hasESI ? 1 : 0);

    final fmt = NumberFormat('#,##0.00');

    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Column(
        children: [
          Expanded(child: _buildMobileListView(paginatedList, sortedAllowances, sortedDeductions, fmt)),
          _buildPaginationControls(totalCount),
        ],
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grouped Header Row
                    _buildGroupHeaderRow(allowanceCount, deductionCount, statCount),
                    // Column Labels Row
                    _buildColumnHeaderRow(sortedAllowances, sortedDeductions),
                    // Data Rows
                    ...paginatedList.map((s) => _buildDataRow(s, sortedAllowances, sortedDeductions, fmt)),
                  ],
                ),
              ),
            ),
          ),
          _buildPaginationControls(totalCount),
        ],
      ),
    );

  }

  SalaryDetail? _getSalaryDetail(List<SalaryDetail>? list, String name) {
    if (list == null) return null;
    try {
      return list.firstWhere((element) => element.name == name);
    } catch (_) {
      return null;
    }
  }

  void _showSalaryDetailsPopup(dynamic s, List<String> sortedAllowances, List<String> sortedDeductions, NumberFormat fmt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.cardColor,
                    backgroundImage: s.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(s.profilePictureUrl)) : null,
                    child: s.profilePictureUrl == null ? Text(s.employeeName?[0] ?? '?', style: TextStyle(color: isDark ? Colors.white : theme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold)) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.employeeName ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(s.employeeCode ?? '--', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
    const Divider(color: Color(0xFF1E293B), height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPopupSectionTitle('CORE FINANCIALS'),
                    _buildPopupRow('Base Basic Pay', fmt.format(s.baseBasicPay)),
                    _buildPopupRow('Attendance', '${s.presentDays}/${s.totalDaysInMonth} Days', valueColor: Colors.greenAccent),
                    _buildPopupRow(_isPreviewMode ? 'Earned Basic' : 'Saved Basic', fmt.format(_isPreviewMode ? s.earnedBasicPay : s.netSalary), isBold: true),
                    
                    if (sortedAllowances.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildPopupSectionTitle('ALLOWANCES BREAKDOWN'),
                      ...sortedAllowances.expand((name) {
                        final detail = _getSalaryDetail(s.allowancesDetail, name);
                        if (detail == null || (detail.amount == 0 && (detail.baseAmount ?? 0) == 0)) return [];
                        return [
                          _buildPopupSubRow(name, full: fmt.format(detail.baseAmount ?? detail.amount), earned: fmt.format(detail.amount), isAllowance: true),
                        ];
                      }),
                    ],

                    const SizedBox(height: 24),
                    _buildPopupSectionTitle('DEDUCTIONS BREAKDOWN'),
                    if (_hasPF && _getSalaryDetail(s.deductionsDetail, 'PF') != null)
                       _buildPopupSubRow('PF', full: '--', earned: fmt.format(_getSalaryDetail(s.deductionsDetail, 'PF')!.amount), isAllowance: false),
                    if (_hasESI && _getSalaryDetail(s.deductionsDetail, 'ESI') != null)
                      _buildPopupSubRow('ESI', full: '--', earned: fmt.format(_getSalaryDetail(s.deductionsDetail, 'ESI')!.amount), isAllowance: false),
                    
                    ...sortedDeductions.expand((name) {
                      final detail = _getSalaryDetail(s.deductionsDetail, name);
                      if (detail == null || (detail.amount == 0 && (detail.baseAmount ?? 0) == 0)) return [];
                      return [
                        _buildPopupSubRow(name, full: fmt.format(detail.baseAmount ?? detail.amount), earned: fmt.format(detail.amount), isAllowance: false),
                      ];
                    }),

                    const SizedBox(height: 24),
                    _buildPopupSectionTitle('SUMMARY'),
                    _buildPopupRow('Total Allowances', '+${fmt.format(s.totalAllowance)}', valueColor: Colors.greenAccent),
                    _buildPopupRow('Total Deductions', '-${fmt.format(s.totalDeduction)}', valueColor: Colors.redAccent),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : theme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET PAYABLE', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          Text('₹${fmt.format(s.grossSalary)}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildPopupRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPopupSubRow(String name, {required String full, required String earned, required bool isAllowance}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Full: $full', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black45, fontSize: 12)),
              Text(isAllowance ? '+$earned' : '-$earned', style: TextStyle(color: isAllowance ? (isDark ? Colors.greenAccent : const Color(0xFF059669)) : (isDark ? Colors.redAccent : const Color(0xFFDC2626)), fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileListView(List<dynamic> list, List<String> allowances, List<String> deductions, NumberFormat fmt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return GestureDetector(
          onTap: () => _showSalaryDetailsPopup(s, allowances, deductions, fmt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1)),
              boxShadow: [
                if (!isDark)
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                if (isDark)
                   BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                // Card Top: Profile and Basic Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isDark ? const Color(0xFF334155) : theme.primaryColor.withOpacity(0.05),
                        backgroundImage: s.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(s.profilePictureUrl)) : null,
                        child: s.profilePictureUrl == null ? Text(s.employeeName?[0] ?? '?', style: TextStyle(color: isDark ? Colors.white : theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.employeeName ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(s.employeeCode ?? '--', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2), size: 14),
                    ],
                  ),
                ),
                Divider(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1), height: 1),
                
                // Card Middle: Quick Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMobileDataRow('Basic Pay', fmt.format(s.baseBasicPay)),
                      _buildMobileDataRow('Attendance', '${s.presentDays}/${s.totalDaysInMonth} Days', valueColor: s.presentDays > 0 ? (isDark ? Colors.greenAccent : const Color(0xFF059669)) : (isDark ? Colors.redAccent : const Color(0xFFDC2626))),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.transparent : theme.dividerColor.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('NET TAKE HOME', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            Text('₹${fmt.format(s.grossSalary)}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDataRow(String label, String value, {Color? valueColor, bool isPrimary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black45, fontSize: 12, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14, fontWeight: isPrimary ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGroupHeaderRow(int allwCount, int dedCount, int statCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.black12, width: 1.5)),
      ),
      child: Row(
        children: [
          _buildGroupCell('CORE DETAILS', width: 570), 
          if (allwCount > 0)
            _buildGroupCell('ALLOWANCES (EARNINGS)', width: allwCount * 200.0, alignment: Alignment.center),
          if (dedCount > 0 || statCount > 0)
            _buildGroupCell('MANUAL DEDUCTIONS', width: (dedCount * 200.0) + (statCount * 100.0), alignment: Alignment.center),
          _buildGroupCell('FINANCIAL SUMMARY', width: 400, alignment: Alignment.center),
        ],
      ),
    );
  }

  Widget _buildGroupCell(String label, {required double width, Alignment alignment = Alignment.centerLeft}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.black12, width: 1.5)),
      ),
      child: Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  Widget _buildColumnHeaderRow(List<String> allowances, List<String> deductions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          _buildHeaderCell('AVATAR', width: 60),
          _buildHeaderCell('EMPLOYEE\nNAME', width: 150, sortKey: 'employeeName'),
          _buildHeaderCell('EMP\nCODE', width: 80, sortKey: 'employeeCode'),
          _buildHeaderCell('BASIC\nPAY', width: 90, sortKey: 'baseBasicPay', align: TextAlign.right),
          _buildHeaderCell('PRESENT/\nTOTAL', width: 90, align: TextAlign.center),
          _buildHeaderCell('EARNED\nBASIC', width: 100, align: TextAlign.right, showRightBorder: true),
          
          ...allowances.expand((a) => [
            _buildHeaderCell('$a\n(FULL)', width: 100, align: TextAlign.right, color: Colors.greenAccent),
            _buildHeaderCell('$a\n(EARN)', width: 100, align: TextAlign.right, color: Colors.greenAccent),
          ]),

          if (_hasPF) _buildHeaderCell('PF', width: 100, align: TextAlign.right, color: Colors.redAccent),
          if (_hasESI) _buildHeaderCell('ESI', width: 100, align: TextAlign.right, color: Colors.redAccent),

          ...deductions.expand((d) => [
            _buildHeaderCell('$d\n(FULL)', width: 100, align: TextAlign.right, color: Colors.redAccent),
            _buildHeaderCell('$d\n(EARN)', width: 100, align: TextAlign.right, color: Colors.redAccent),
          ]),

          _buildHeaderCell('TOTAL\nALLW.', width: 100, align: TextAlign.right),
          _buildHeaderCell('TOTAL\nDED.', width: 100, align: TextAlign.right),
          _buildHeaderCell('NET\nPAY', width: 100, align: TextAlign.right),
          _buildHeaderCell('ACTION', width: 100, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {double width = 100, String? sortKey, TextAlign align = TextAlign.left, Color? color, bool showRightBorder = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: sortKey != null ? () => _onSort(sortKey) : null,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1), width: showRightBorder ? 2 : 1)),
        ),
        child: Row(
          mainAxisAlignment: align == TextAlign.right ? MainAxisAlignment.end : (align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start),
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color ?? (isDark ? const Color(0xFF94A3B8) : Colors.black54), fontSize: 10, fontWeight: FontWeight.bold, height: 1.2),
                textAlign: align,
                maxLines: 2,
              ),
            ),
            if (sortKey != null) ...[
              const SizedBox(width: 2),
              Icon(
                _sortColumn == sortKey ? (_isAscending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                size: 10,
                color: _sortColumn == sortKey ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : Colors.black12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(dynamic s, List<String> allowances, List<String> deductions, NumberFormat fmt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          _buildTableCell(
            CircleAvatar(
              radius: 12,
              backgroundColor: isDark ? const Color(0xFF334155) : theme.primaryColor.withOpacity(0.05),
              backgroundImage: s.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(s.profilePictureUrl)) : null,
              child: s.profilePictureUrl == null ? Text(s.employeeName?[0] ?? '?', style: TextStyle(color: isDark ? Colors.white : theme.primaryColor, fontSize: 10)) : null,
            ),
            width: 60,
            alignment: Alignment.center,
          ),
          _buildTableCell(Text(s.employeeName ?? '', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)), width: 150),
          _buildTableCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(s.employeeCode ?? '', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black54, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            width: 80,
          ),
          _buildTableCell(Text(fmt.format(s.baseBasicPay), style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black45, fontSize: 12)), width: 90, alignment: Alignment.centerRight),
          _buildTableCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: s.presentDays > 0 ? (isDark ? Colors.green.withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.1)) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${s.presentDays}/${s.totalDaysInMonth}', style: TextStyle(color: s.presentDays > 0 ? (isDark ? Colors.greenAccent : const Color(0xFF10B981)) : (isDark ? Colors.redAccent : const Color(0xFFEF4444)), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            width: 90,
            alignment: Alignment.center,
          ),
          _buildTableCell(Text(fmt.format(_isPreviewMode ? s.earnedBasicPay : s.netSalary), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)), width: 100, alignment: Alignment.centerRight, showRightBorder: true),
          
          ...allowances.expand((a) {
            var detail = _getSalaryDetail(s.allowancesDetail, a);
            return [
              _buildTableCell(Text(fmt.format(detail?.baseAmount ?? detail?.amount ?? 0), style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black45, fontSize: 12)), width: 100, alignment: Alignment.centerRight),
              _buildTableCell(Text(fmt.format(detail?.amount ?? 0), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)), width: 100, alignment: Alignment.centerRight),
            ];
          }),

          if (_hasPF)
            _buildTableCell(Text(fmt.format(_getSalaryDetail(s.deductionsDetail, 'PF')?.amount ?? 0), style: TextStyle(color: isDark ? Colors.redAccent : const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)), width: 100, alignment: Alignment.centerRight),
          if (_hasESI)
            _buildTableCell(Text(fmt.format(_getSalaryDetail(s.deductionsDetail, 'ESI')?.amount ?? 0), style: TextStyle(color: isDark ? Colors.redAccent : const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)), width: 100, alignment: Alignment.centerRight),

          ...deductions.expand((d) {
            var detail = _getSalaryDetail(s.deductionsDetail, d);
            return [
              _buildTableCell(Text(fmt.format(detail?.baseAmount ?? detail?.amount ?? 0), style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black45, fontSize: 11)), width: 100, alignment: Alignment.centerRight),
              _buildTableCell(Text(fmt.format(detail?.amount ?? 0), style: TextStyle(color: isDark ? Colors.redAccent : const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)), width: 100, alignment: Alignment.centerRight),
            ];
          }),

          _buildTableCell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+${fmt.format(s.totalAllowance)}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Full: ${fmt.format(s.totalBaseAllowance)}', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black38, fontSize: 9)),
              ],
            ),
            width: 100,
            alignment: Alignment.centerRight,
          ),
          _buildTableCell(Text('-${fmt.format(s.totalDeduction)}', style: TextStyle(color: isDark ? Colors.redAccent : const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)), width: 100, alignment: Alignment.centerRight),
          _buildTableCell(Text(fmt.format(s.grossSalary), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w900)), width: 100, alignment: Alignment.centerRight),
          
          _buildTableCell(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isPreviewMode)
                  IconButton(
                    icon: const Icon(Icons.description_outlined, color: Color(0xFF6366F1), size: 18),
                    onPressed: () => _exportIndividualPaySlip(s),
                  ),
              ],
            ),
            width: 100,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }


  Widget _buildTableCell(Widget child, {required double width, Alignment alignment = Alignment.centerLeft, bool showRightBorder = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1), width: showRightBorder ? 2 : 1),
          bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : theme.dividerColor.withOpacity(0.05), width: 0.5),
        ),
      ),
      child: child,
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : theme.dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${(totalItems > _currentPage * _itemsPerPage) ? _currentPage * _itemsPerPage : totalItems} of $totalItems entries',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black54, fontSize: 12),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black54, size: 20),
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 8),
              Text('Page $_currentPage of $totalPages', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12)),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black54, size: 20),
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
