import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'benefits_screen.dart';
import 'benefit_assignment_form_screen.dart';
import '../models/benefit_models.dart';
import '../models/employee.dart';
import '../providers/benefits_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/employee_repository.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/hrm_search_toolbar.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';

class BenefitAssignmentScreen extends ConsumerStatefulWidget {
  final BenefitCategory category;

  const BenefitAssignmentScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<BenefitAssignmentScreen> createState() => _BenefitAssignmentScreenState();
}

class _BenefitAssignmentScreenState extends ConsumerState<BenefitAssignmentScreen> {
  final AuthRepository _authRepository = AuthRepository();
  
  String _searchQuery = '';
  List<OrgDropdownItem> _organizations = [];
  
  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final orgs = await _authRepository.getUserOrganizations();
      setState(() {
        _organizations = orgs.map((o) => OrgDropdownItem(
          id: (o['id'] ?? o['Id'] ?? '').toString(),
          name: o['name'] ?? o['Name'] ?? 'Unknown',
          logoUrl: o['logoUrl'] ?? o['LogoUrl'],
        )).toList();
      });

      // Synchronize initial organization with Provider if not set
      final provider = widget.category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
      final state = ref.read(provider);
      if (state.organizationId == null) {
        final userData = await _authRepository.getCurrentUser();
        if (userData != null && userData['organizationId'] != null) {
          ref.read(provider.notifier).setOrganization(userData['organizationId']);
        }
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = theme.platform == TargetPlatform.iOS;
    
    final provider = widget.category == BenefitCategory.allowance 
        ? allowancesProvider 
        : deductionsProvider;
    
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    // Frontend Enrichment Logic
    final enrichedList = state.assignments.map((a) {
      Employee? emp;
      try {
        emp = state.employees.firstWhere((e) => e.id == a.employeeId);
      } catch (_) {}
      
      if (emp != null) {
        return a.copyWith(
          employeeName: emp.name,
          employeeCode: emp.employeeCode ?? emp.employeeCode,
          profilePictureUrl: emp.profilePictureUrl,
        );
      }
      return a;
    }).toList();

    // Filter logic
    final filteredList = enrichedList.where((a) {
      final query = _searchQuery.toLowerCase();
      final name = a.employeeName?.toLowerCase() ?? '';
      final code = a.employeeCode?.toLowerCase() ?? '';
      final benefit = a.benefitName?.toLowerCase() ?? '';
      
      return name.contains(query) || 
             code.contains(query) || 
             benefit.contains(query);
    }).toList();

    // Grouped logic for Staff-Centric view
    final Map<int, List<BenefitAssignment>> groupedMap = {};
    final List<Employee> uniqueStaffInActiveList = [];
    final Set<int> seenIds = {};

    for (var a in filteredList) {
      if (!groupedMap.containsKey(a.employeeId)) {
        groupedMap[a.employeeId] = [];
        if (!seenIds.contains(a.employeeId)) {
          uniqueStaffInActiveList.add(Employee(
            id: a.employeeId,
            name: a.employeeName ?? 'Unknown',
            email: '',
            employeeCode: a.employeeCode,
            profilePictureUrl: a.profilePictureUrl,
            organizationId: state.organizationId ?? 0,
            status: 'Active',
          ));
          seenIds.add(a.employeeId);
        }
      }
      groupedMap[a.employeeId]!.add(a);
    }

    // Pagination logic
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > uniqueStaffInActiveList.length 
        ? uniqueStaffInActiveList.length 
        : (startIndex + _pageSize);
    
    final paginatedStaff = startIndex >= uniqueStaffInActiveList.length 
        ? <Employee>[] 
        : uniqueStaffInActiveList.sublist(startIndex, endIndex);

    final title = widget.category == BenefitCategory.allowance ? 'Staff Allowances' : 'Staff Deductions';
    final primaryColor = widget.category == BenefitCategory.allowance ? Colors.blue : Colors.red;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen());
      },
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isIOS ? (isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)) : theme.cardColor,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    if (isIOS) ...[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.back, size: 22),
                        onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen()),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                        onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen()),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: isIOS 
                            ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                            : theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                      ),
                    ),
                    if (state.isLoading) 
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),

            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HRMSearchToolbar(
                selectedOrgId: state.organizationId?.toString(),
                orgItems: _organizations,
                onOrgChanged: (id) {
                  if (id != null) {
                    notifier.setOrganization(int.parse(id));
                  }
                },
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                hintText: 'Search staff assignments...',
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  isIOS 
                      ? CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          minSize: 0,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _navigateToForm(null),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.add, size: 18),
                              const SizedBox(width: 8),
                              const Text('Assign Staff', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        )
                        : ElevatedButton.icon(
                          onPressed: () => _navigateToForm(null),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Assign Staff'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Staff List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: state.isLoading && state.assignments.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : uniqueStaffInActiveList.isEmpty
                        ? const Center(child: Text('No staff and benefits found'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 900) {
                                return _buildMobileList(paginatedStaff, groupedMap, theme, primaryColor);
                              }
                              return _buildDesktopTable(paginatedStaff, groupedMap, theme, primaryColor, state);
                            },
                          ),
              ),
            ),

            // Pagination
            if (uniqueStaffInActiveList.isNotEmpty)
              CustomPagination(
                totalItems: uniqueStaffInActiveList.length,
                pageSize: _pageSize,
                currentPage: _currentPage,
                onPageChanged: (page) => setState(() => _currentPage = page),
                onPageSizeChanged: (size) => setState(() {
                  _pageSize = size;
                  _currentPage = 1;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<Employee> staffList, Map<int, List<BenefitAssignment>> groupedMap, ThemeData theme, Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];
        final benefits = groupedMap[staff.id] ?? [];
        final total = benefits.fold(0.0, (sum, b) => sum + b.amount);
        final isDark = theme.brightness == Brightness.dark;
        
        return Card(
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.15),
              backgroundImage: (staff.profilePictureUrl != null && staff.profilePictureUrl!.isNotEmpty)
                  ? NetworkImage(staff.profilePictureUrl!)
                  : null,
              child: (staff.profilePictureUrl == null || staff.profilePictureUrl!.isEmpty)
                  ? Text(
                      staff.name.isNotEmpty ? staff.name.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  : null,
            ),
            title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('ID: ${staff.employeeCode ?? "-"} • Total: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _navigateToForm(null, preselectedEmployeeId: staff.id),
            ),
            children: benefits.map((b) => ListTile(
              dense: true,
              title: Text(b.benefitName ?? 'Unknown', style: const TextStyle(fontSize: 12)),
              subtitle: Text(b.calType ? '₹${b.amount}' : '${b.amount}%', style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _navigateToForm(b),
              ),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Employee> staffList, Map<int, List<BenefitAssignment>> groupedMap, ThemeData theme, Color primaryColor, BenefitsState state) {
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(flex: 3, child: _buildSortableHeader('EMPLOYEE', theme)),
                Expanded(flex: 4, child: _buildSortableHeader('ASSIGNED ${widget.category == BenefitCategory.allowance ? 'ALLOWANCES' : 'DEDUCTIONS'}', theme)),
                Expanded(flex: 2, child: _buildSortableHeader('TOTAL (₹)', theme)),
                const SizedBox(
                  width: 120,
                  child: Text(
                    'ACTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569),
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          // Body
          Expanded(
            child: ListView.separated(
              itemCount: staffList.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (context, index) {
                final staff = staffList[index];
                final benefits = groupedMap[staff.id] ?? [];
                final total = benefits.fold(0.0, (sum, b) => sum + b.amount);
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                             CircleAvatar(
                                radius: 16,
                                backgroundColor: primaryColor.withOpacity(0.15),
                                child: Text(
                                  staff.name.isNotEmpty ? staff.name.substring(0, 1).toUpperCase() : '?', 
                                  style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w900)
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(staff.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text('ID: ${staff.employeeCode ?? ""}', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontSize: 10)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: benefits.isEmpty 
                            ? <Widget>[Text('None Assigned', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, fontSize: 11))]
                            : benefits.map((b) => InputChip(
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                label: Text('${b.benefitShortName ?? b.benefitName}: ${b.calType ? '₹' : ''}${b.amount}${b.calType ? '' : '%'}'),
                                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: border)),
                                onPressed: () => _navigateToForm(b),
                                onDeleted: () => _handleDelete(b),
                                deleteIcon: const Icon(Icons.cancel, size: 14, color: Colors.red),
                              )).toList(),
                        ),
                      ),
                      Expanded(
                        flex: 2, 
                        child: Text(
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total), 
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))
                        )
                      ),
                      SizedBox(
                        width: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => _navigateToForm(null, preselectedEmployeeId: staff.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: primaryColor,
                                elevation: 0,
                                side: BorderSide(color: primaryColor.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 14),
                                  SizedBox(width: 4),
                                  Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: const Color(0xFF475569),
          letterSpacing: 0.8,
        )),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more, color: theme.iconTheme.color?.withOpacity(0.3), size: 14),
      ],
    );
  }

  Future<void> _handleDelete(BenefitAssignment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Remove'),
        content: Text('Are you sure you want to remove ${item.benefitName} for ${item.employeeName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = widget.category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
        await ref.read(provider.notifier).deleteAssignment(item.id);
        CustomSnackbar.show(context: context, message: 'Removed successfully');
      } catch (e) {
        CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _navigateToForm(BenefitAssignment? editData, {int? preselectedEmployeeId}) async {
    final provider = widget.category == BenefitCategory.allowance 
        ? allowancesProvider 
        : deductionsProvider;
    
    final state = ref.read(provider);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BenefitAssignmentFormScreen(
          category: widget.category,
          organizationId: state.organizationId,
          editData: editData,
          benefitTypes: state.masterTypes,
          employees: state.employees,
          preselectedEmployeeId: preselectedEmployeeId,
        ),
      ),
    );

    if (result == true) {
      // Refresh logic is handled by providers
    }
  }
}

extension BenefitStringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
