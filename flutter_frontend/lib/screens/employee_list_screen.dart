import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee.dart';
import '../models/organization.dart';
import '../models/designation.dart';
import '../models/department.dart';
import '../repositories/employee_repository.dart';
import '../repositories/organization_repository.dart';
import '../repositories/designation_repository.dart';
import '../repositories/department_repository.dart';
import '../core/api_config.dart';
import 'employee_form_screen.dart';
import 'manage_fields_screen.dart';
import '../widgets/org_dropdown.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/hrm_search_toolbar.dart';


class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  // State
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  List<Organization> _organizations = [];
  List<Designation> _designations = [];
  List<Department> _departments = [];
  
  int? _selectedOrgId;
  String? _selectedOrgName;
  int? _selectedDesignationId;
  int? _selectedDepartmentId;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isGridView = false;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIds = {};

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 10;
  List<Employee> _paginatedEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final orgRepo = ref.read(organizationRepositoryProvider);
      final desigRepo = ref.read(designationRepositoryProvider);
      final deptRepo = ref.read(departmentRepositoryProvider);
      final empRepo = ref.read(employeeRepositoryProvider);

      final orgs = await orgRepo.getUserOrganizations();
      _organizations = orgs;

      // Default to first org if available
      if (_organizations.isNotEmpty && _selectedOrgId == null) {
        _selectedOrgId = _organizations.first.id;
        _selectedOrgName = _organizations.first.name;
      }

      if (_selectedOrgId != null) {
        final results = await Future.wait([
          desigRepo.getDesignations(_selectedOrgId),
          deptRepo.getDepartments(_selectedOrgId!),
        ]);
        _designations = results[0] as List<Designation>;
        _departments = results[1] as List<Department>;
      }

      await _loadEmployees();
      
      // Init SignalR
      if (_selectedOrgId != null) {
        empRepo.initSignalR(_selectedOrgId!, (action, data) {
          _loadEmployees(); // Reload on change
        });
      }

    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context, 
          message: 'Error loading data: $e', 
          isError: true
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployees() async {
    if (_selectedOrgId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      final desigRepo = ref.read(designationRepositoryProvider);
      final deptRepo = ref.read(departmentRepositoryProvider);

      // Fetch all required data for the organization
      final results = await Future.wait([
        empRepo.getEmployees(_selectedOrgId),
        desigRepo.getDesignations(_selectedOrgId),
        deptRepo.getDepartments(_selectedOrgId!),
      ]);

      _allEmployees = results[0] as List<Employee>;
      _designations = results[1] as List<Designation>;
      _departments = results[2] as List<Department>;
      
      _applyFilters();

      // Re-init SignalR if org changed
      empRepo.initSignalR(_selectedOrgId!, (action, data) {
        _loadEmployees();
      });

    } catch (e) {
      print('Error loading organization data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      final filtered = _allEmployees.where((emp) {
        final matchesSearch = emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (emp.employeeCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            emp.email.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesDesignation = _selectedDesignationId == null;
        if (!matchesDesignation) {
          final selectedDesig = _designations.firstWhere(
            (d) => d.id == _selectedDesignationId,
            orElse: () => Designation(id: -1, organizationId: 0, designationName: ''),
          );
          matchesDesignation = (emp.designationId == _selectedDesignationId) || 
                               (selectedDesig.id != -1 && emp.designation == selectedDesig.designationName);
        }

        bool matchesDepartment = _selectedDepartmentId == null;
        if (!matchesDepartment) {
          final selectedDept = _departments.firstWhere(
            (d) => d.id == _selectedDepartmentId,
            orElse: () => Department(id: -1, organizationId: 0, departmentName: ''),
          );
          matchesDepartment = (emp.departmentId == _selectedDepartmentId) || 
                               (selectedDept.id != -1 && emp.department == selectedDept.departmentName);
        }

        return matchesSearch && matchesDesignation && matchesDepartment;
      }).toList();

      _filteredEmployees = filtered;
      _currentPage = 1; // Reset to page 1 on filter change
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > _filteredEmployees.length 
        ? _filteredEmployees.length 
        : (startIndex + _pageSize);
    
    if (startIndex >= _filteredEmployees.length) {
      _paginatedEmployees = [];
    } else {
      _paginatedEmployees = _filteredEmployees.sublist(startIndex, endIndex);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    ref.read(employeeRepositoryProvider).disposeSignalR();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isIOS = theme.platform == TargetPlatform.iOS;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setHRManagementContent(null);
      },
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Custom Header
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
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        'Employees',
                        style: isIOS 
                            ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                            : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (MediaQuery.of(context).size.width < 900)
                      isIOS 
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: Icon(_isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2, size: 22),
                              onPressed: () => setState(() => _isGridView = !_isGridView),
                            )
                          : IconButton(
                              icon: Icon(_isGridView ? Icons.list : Icons.grid_view, color: theme.colorScheme.primary),
                              onPressed: () => setState(() => _isGridView = !_isGridView),
                            ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildFilterBar(context),
                  _buildActionBar(context),
                  Expanded(
                    child: _isLoading
                        ? Center(child: isIOS ? const CupertinoActivityIndicator() : const CircularProgressIndicator(color: Colors.blue))
                        : _filteredEmployees.isEmpty
                            ? const Center(child: Text('No employees found', style: TextStyle(color: Colors.white70)))
                            : _isGridView 
                                ? _buildGridView() 
                                : MediaQuery.of(context).size.width < 900
                                    ? _buildMobileListView()
                                    : _buildListView(),
                  ),
                  // Pagination Footer
                  if (!_isLoading && _filteredEmployees.isNotEmpty)
                    CustomPagination(
                      totalItems: _filteredEmployees.length,
                      pageSize: _pageSize,
                      currentPage: _currentPage,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                          _updatePagination();
                        });
                      },
                      onPageSizeChanged: (size) {
                        setState(() {
                          _pageSize = size;
                          _currentPage = 1;
                          _updatePagination();
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: HRMSearchToolbar(
        selectedOrgId: _selectedOrgId?.toString(),
        orgItems: _organizations.map((org) => OrgDropdownItem(
          id: org.id.toString(),
          name: org.name,
          logoUrl: org.logoUrl,
        )).toList(),
        onOrgChanged: (val) {
          if (val == null || val == _selectedOrgId?.toString()) return;
          final id = int.parse(val);
          setState(() {
            _selectedOrgId = id;
            _selectedOrgName = _organizations.firstWhere((o) => o.id == id).name;
            _selectedDesignationId = null;
            _selectedDepartmentId = null;
          });
          _loadEmployees();
        },
        onSearchChanged: (val) => setState(() {
          _searchQuery = val;
          _applyFilters();
        }),
        hintText: 'Search Name, ID or Email...',
        isOrgLoading: _isLoading && _organizations.isEmpty,
        actions: [
          // Designation Filter
          _buildCompactFilter(
            label: 'Designation',
            value: _selectedDesignationId,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Designations')),
              ..._designations.map((d) => DropdownMenuItem(value: d.id, child: Text(d.designationName))),
            ],
            onChanged: (val) => setState(() { _selectedDesignationId = val; _applyFilters(); }),
          ),
          const SizedBox(width: 8),
          // Department Filter
          _buildCompactFilter(
            label: 'Department',
            value: _selectedDepartmentId,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Departments')),
              ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.departmentName))),
            ],
            onChanged: (val) => setState(() { _selectedDepartmentId = val; _applyFilters(); }),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (val) => onChanged(val as T),
          icon: const Icon(Icons.filter_list, size: 16),
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          hint: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    
    Widget actions = Row(
      children: [
        isIOS 
            ? CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minSize: 0,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _navigateToForm(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, size: 18),
                    SizedBox(width: 8),
                    Text('Add Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => _navigateToForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Employee', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
        const SizedBox(width: 12),
        isIOS
            ? CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minSize: 0,
                color: CupertinoColors.destructiveRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManageFieldsScreen(organizationId: _selectedOrgId))),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.square_grid_3x2, color: CupertinoColors.destructiveRed, size: 18),
                    SizedBox(width: 8),
                    Text('Fields', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
                  ],
                ),
              )
            : OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManageFieldsScreen(organizationId: _selectedOrgId))),
                icon: const Icon(Icons.storage, size: 18),
                label: const Text('Manage Fields', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
        const SizedBox(width: 12),
        _buildActionButton(icon: Icons.file_upload, label: 'Import', onPressed: () {}),
        const SizedBox(width: 8),
        _buildActionButton(icon: Icons.file_download, label: 'Export', onPressed: () {}),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isDesktop 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              actions,
              Row(
                children: [
                   IconButton(icon: Icon(Icons.list, color: !_isGridView ? Colors.blue : Colors.white54), onPressed: () => setState(() => _isGridView = false)),
                   IconButton(icon: Icon(Icons.grid_view, color: _isGridView ? Colors.blue : Colors.white54), onPressed: () => setState(() => _isGridView = true)),
                ]
              )
            ],
          )
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.textTheme.bodyMedium?.color,
        side: BorderSide(color: theme.dividerColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildListView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth > 900 ? constraints.maxWidth - 32 : 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: _selectedIds.length == _filteredEmployees.length && _filteredEmployees.isNotEmpty,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.addAll(_filteredEmployees.map((e) => e.id));
                                } else {
                                  _selectedIds.clear();
                                }
                              });
                            },
                            side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        Expanded(flex: 2, child: _buildSortableHeader('EMPLOYEE ID', theme)),
                        Expanded(flex: 3, child: _buildSortableHeader('NAME', theme)),
                        Expanded(flex: 4, child: _buildSortableHeader('EMAIL', theme)),
                        Expanded(flex: 2, child: _buildSortableHeader('USER ROLE', theme)),
                        Expanded(flex: 2, child: _buildSortableHeader('STATUS', theme)),
                        SizedBox(width: 60, child: Text('ACTION', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  // Body
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _paginatedEmployees.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                      itemBuilder: (context, index) {
                        final emp = _paginatedEmployees[index];
                        final isSelected = _selectedIds.contains(emp.id);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) _selectedIds.remove(emp.id);
                              else _selectedIds.add(emp.id);
                            });
                          },
                          onDoubleTap: () => _navigateToForm(employee: emp),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) _selectedIds.add(emp.id);
                                        else _selectedIds.remove(emp.id);
                                      });
                                    },
                                    side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                                    activeColor: theme.colorScheme.primary,
                                  ),
                                ),
                                Expanded(flex: 2, child: Text((emp.employeeCode == null || emp.employeeCode!.isEmpty) ? '--' : emp.employeeCode!, style: theme.textTheme.bodyMedium)),
                                Expanded(flex: 3, child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundImage: emp.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) : null,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: emp.profilePictureUrl == null ? Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 11)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(emp.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                  ],
                                )),
                                Expanded(flex: 4, child: Text(emp.email, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                                Expanded(flex: 2, child: Text((emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)))),
                                Expanded(flex: 2, child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: emp.status == 'Active' ? Colors.green : Colors.red, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(emp.status, style: theme.textTheme.bodySmall),
                                  ],
                                )),
                                SizedBox(
                                  width: 60, 
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                      ),
                                      child: PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: theme.iconTheme.color?.withOpacity(0.5), size: 20),
                                        color: theme.cardColor,
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
                                        offset: const Offset(0, 40),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _navigateToForm(employee: emp);
                                          } else if (value == 'delete') {
                                            _confirmDelete(emp);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 18),
                                                const SizedBox(width: 12),
                                                Text('Edit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                                const SizedBox(width: 12),
                                                Text('Delete', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildSortableHeader(String title, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more, color: theme.iconTheme.color?.withOpacity(0.3), size: 14),
      ],
    );
  }

  Widget _buildMobileListView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _paginatedEmployees.length,
      itemBuilder: (context, index) {
        final emp = _paginatedEmployees[index];
        return Card(
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToForm(employee: emp),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: emp.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) : null,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: emp.profilePictureUrl == null ? Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 16)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text((emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildActionMenu(emp, theme),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMobileDetailColumn('ID', (emp.employeeCode == null || emp.employeeCode!.isEmpty) ? '--' : emp.employeeCode!, theme)),
                    Expanded(child: _buildMobileDetailColumn('Email', emp.email, theme)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Status', style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.textTheme.labelSmall?.color?.withOpacity(0.5))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: emp.status == 'Active' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: emp.status == 'Active' ? Colors.green : Colors.red)),
                          child: Text(emp.status, style: TextStyle(color: emp.status == 'Active' ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailColumn(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.textTheme.labelSmall?.color?.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildGridView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _paginatedEmployees.length,
      itemBuilder: (context, index) {
        final emp = _paginatedEmployees[index];
        return Card(
          color: theme.cardTheme.color,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: emp.profilePictureUrl != null 
                      ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) 
                      : null,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: emp.profilePictureUrl == null ? Text(emp.name[0].toUpperCase(), style: TextStyle(fontSize: 24, color: theme.colorScheme.onPrimaryContainer)) : null,
                ),
                const SizedBox(height: 12),
                Text(emp.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  (emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                  child: Text(emp.status, style: TextStyle(color: emp.status == 'Active' ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(Employee emp) {
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete Employee'),
          content: Text('Are you sure you want to delete ${emp.name}?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(employeeRepositoryProvider).deleteEmployee(emp.id);
                  _loadEmployees();
                  if (mounted) CustomSnackbar.show(context: context, message: 'Employee deleted successfully');
                } catch (e) {
                  if (mounted) CustomSnackbar.show(context: context, message: 'Delete failed: $e', isError: true);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
          title: Text('Delete Employee', style: theme.textTheme.titleLarge),
          content: Text('Are you sure you want to delete ${emp.name}?', style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: theme.textTheme.bodySmall?.color))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(employeeRepositoryProvider).deleteEmployee(emp.id);
                  _loadEmployees();
                  if (mounted) CustomSnackbar.show(context: context, message: 'Employee deleted successfully');
                } catch (e) {
                  if (mounted) CustomSnackbar.show(context: context, message: 'Delete failed: $e', isError: true);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }
  void _navigateToForm({Employee? employee}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeFormScreen(
          employee: employee,
          organizationId: _selectedOrgId,
          organizationName: _selectedOrgName,
        ),
      ),
    ).then((_) => _loadEmployees());
  }

  Widget _buildActionMenu(Employee emp, ThemeData theme) {
    final isIOS = theme.platform == TargetPlatform.iOS;
    if (isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        child: Icon(CupertinoIcons.ellipsis_circle, color: theme.iconTheme.color?.withOpacity(0.5), size: 22),
        onPressed: () => _showCupertinoActions(emp),
      );
    }

    return Theme(
      data: theme.copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: theme.iconTheme.color?.withOpacity(0.5), size: 20),
        color: theme.cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
        offset: const Offset(0, 40),
        onSelected: (val) {
          if (val == 'edit') {
            _navigateToForm(employee: emp);
          } else if (val == 'delete') {
            _confirmDelete(emp);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 12),
                Text('Edit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 12),
                Text('Delete', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCupertinoActions(Employee emp) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(emp.name),
        message: Text((emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToForm(employee: emp);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 20),
                SizedBox(width: 10),
                Text('Edit Profile'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(emp);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 20),
                SizedBox(width: 10),
                Text('Delete Employee'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
