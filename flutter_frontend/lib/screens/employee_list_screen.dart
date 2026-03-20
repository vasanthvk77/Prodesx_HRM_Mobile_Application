import 'dart:async';
import 'package:flutter/material.dart';
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
    const navyBg = Color(0xFF0F172A);
    const slateBg = Color(0xFF1E293B);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setHRManagementContent(null);
      },
      child: Material(
        color: navyBg,
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: slateBg,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        return MediaQuery.of(context).size.width >= 900 ? const SizedBox.shrink() : IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                    const Expanded(
                      child: Text(
                        'Employees',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (MediaQuery.of(context).size.width < 900)
                      IconButton(
                        icon: Icon(_isGridView ? Icons.list : Icons.grid_view, color: Colors.blue),
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
                        ? const Center(child: CircularProgressIndicator(color: Colors.blue))
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
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    
    Widget buildOrgDropdown() => _organizations.isNotEmpty ? OrgDropdown(
      value: _selectedOrgId?.toString(),
      items: _organizations.map((org) => OrgDropdownItem(id: org.id.toString(), name: org.name, logoUrl: org.logoUrl)).toList(),
      onChanged: (val) {
        if (val == null || val == _selectedOrgId?.toString()) return;
        final id = int.parse(val);
        setState(() { _selectedOrgId = id; _selectedOrgName = _organizations.firstWhere((o) => o.id == id).name; _selectedDesignationId = null; _selectedDepartmentId = null; });
        _loadEmployees();
      },
      isCompact: true,
      showLabel: true,
    ) : const SizedBox.shrink();

    Widget buildDesigDrop() => _buildCompactDropdown<int?>(label: 'Designation', value: _selectedDesignationId, items: [const DropdownMenuItem(value: null, child: Text('All')), ..._designations.map((d) => DropdownMenuItem(value: d.id, child: Text(d.designationName)))], onChanged: (val) => setState(() { _selectedDesignationId = val; _applyFilters(); }));
    Widget buildDeptDrop() => _buildCompactDropdown<int?>(label: 'Department', value: _selectedDepartmentId, items: [const DropdownMenuItem(value: null, child: Text('All')), ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.departmentName)))], onChanged: (val) => setState(() { _selectedDepartmentId = val; _applyFilters(); }));
    
    Widget buildSearch() => Container(height: 36, decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchController, onChanged: (val) => setState(() { _searchQuery = val; _applyFilters(); }), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: 'Start typing to search', hintStyle: TextStyle(color: Colors.white38, fontSize: 13), prefixIcon: Icon(Icons.search, color: Colors.white38, size: 16), border: InputBorder.none, contentPadding: EdgeInsets.only(top: 0, bottom: 8))));
    Widget buildFilterBtn() => ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_list, size: 16), label: const Text('Filters', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(0, 36)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), border: Border.all(color: Colors.white10)),
      child: isDesktop ? 
        Row(
          children: [
            SizedBox(width: 200, child: buildOrgDropdown()), const SizedBox(width: 12),
            SizedBox(width: 150, child: buildDesigDrop()), const SizedBox(width: 12),
            SizedBox(width: 150, child: buildDeptDrop()), const SizedBox(width: 24),
            Expanded(child: buildSearch()), const SizedBox(width: 12),
            buildFilterBtn(),
          ],
        ) : 
        Column(
          children: [
            Row(children: [ Expanded(flex: 2, child: buildOrgDropdown()), const SizedBox(width: 8), Expanded(child: buildDesigDrop()), const SizedBox(width: 8), Expanded(child: buildDeptDrop()) ]),
            const SizedBox(height: 12),
            Row(children: [ Expanded(child: buildSearch()), const SizedBox(width: 12), buildFilterBtn() ]),
          ],
        ),
    );
  }

  Widget _buildCompactDropdown<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: (val) => onChanged(val as T),
              dropdownColor: const Color(0xFF1E293B),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    
    Widget actions = Row(
      children: [
        ElevatedButton.icon(
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
        OutlinedButton.icon(
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
        _buildActionButton(Icons.file_upload, 'Import', () {}),
        const SizedBox(width: 8),
        _buildActionButton(Icons.file_download, 'Export', () {}),
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

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildListView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Match React grey
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
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
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12, width: 1.5)),
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
                            side: const BorderSide(color: Colors.white38),
                            activeColor: Colors.blue,
                            fillColor: MaterialStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.blue : null),
                          ),
                        ),
                        Expanded(flex: 2, child: _buildSortableHeader('EMPLOYEE ID')),
                        Expanded(flex: 3, child: _buildSortableHeader('NAME')),
                        Expanded(flex: 4, child: _buildSortableHeader('EMAIL')),
                        Expanded(flex: 2, child: _buildSortableHeader('USER ROLE')),
                        Expanded(flex: 2, child: _buildSortableHeader('STATUS')),
                        const SizedBox(width: 60, child: Text('ACTION', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  // Body
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _paginatedEmployees.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
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
                            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
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
                                    side: const BorderSide(color: Colors.white38),
                                    activeColor: Colors.blue,
                                    fillColor: MaterialStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.blue : null),
                                  ),
                                ),
                                Expanded(flex: 2, child: Text((emp.employeeCode == null || emp.employeeCode!.isEmpty) ? '--' : emp.employeeCode!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                                Expanded(flex: 3, child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundImage: emp.profilePictureUrl != null ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) : null,
                                      backgroundColor: Colors.blueGrey,
                                      child: emp.profilePictureUrl == null ? Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E', style: const TextStyle(color: Colors.white, fontSize: 11)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(emp.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  ],
                                )),
                                Expanded(flex: 4, child: Text(emp.email, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                Expanded(flex: 2, child: Text((emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!, style: const TextStyle(color: Colors.white54, fontSize: 13))),
                                Expanded(flex: 2, child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: emp.status == 'Active' ? Colors.green : Colors.red, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(emp.status, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
                                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                        color: const Color(0xFF1E293B),
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                                        offset: const Offset(0, 40),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _navigateToForm(employee: emp);
                                          } else if (value == 'delete') {
                                            _confirmDelete(emp);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                                SizedBox(width: 12),
                                                Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                                SizedBox(width: 12),
                                                Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildSortableHeader(String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more, color: Colors.white24, size: 14),
      ],
    );
  }

  Widget _buildMobileListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _paginatedEmployees.length,
      itemBuilder: (context, index) {
        final emp = _paginatedEmployees[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
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
                              backgroundColor: Colors.blueGrey,
                              child: emp.profilePictureUrl == null ? Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E', style: const TextStyle(color: Colors.white, fontSize: 16)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text((emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                        color: const Color(0xFF1E293B),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                        offset: const Offset(0, 40),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToForm(employee: emp);
                          } else if (value == 'delete') {
                            _confirmDelete(emp);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                SizedBox(width: 12),
                                Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                SizedBox(width: 12),
                                Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMobileDetailColumn('ID', (emp.employeeCode == null || emp.employeeCode!.isEmpty) ? '--' : emp.employeeCode!)),
                    Expanded(child: _buildMobileDetailColumn('Email', emp.email)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 11)),
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

  Widget _buildMobileDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildGridView() {
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
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _navigateToForm(employee: emp),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: emp.profilePictureUrl != null 
                      ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) 
                      : null,
                  child: emp.profilePictureUrl == null ? Text(emp.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)) : null,
                ),
                const SizedBox(height: 12),
                Text(emp.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  (emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                  child: Text(emp.status, style: TextStyle(color: emp.status == 'Active' ? Colors.green : Colors.red, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(Employee emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Employee', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${emp.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(employeeRepositoryProvider).deleteEmployee(emp.id);
                _loadEmployees();
                CustomSnackbar.show(context: context, message: 'Employee deleted successfully');
              } catch (e) {
                CustomSnackbar.show(context: context, message: 'Delete failed: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
}
