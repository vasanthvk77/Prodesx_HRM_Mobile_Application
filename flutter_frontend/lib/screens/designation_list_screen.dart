import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/designation.dart';
import '../repositories/designation_repository.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import 'designation_form_screen.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';

class DesignationListScreen extends ConsumerStatefulWidget {
  const DesignationListScreen({super.key});

  @override
  ConsumerState<DesignationListScreen> createState() => _DesignationListScreenState();
}

class _DesignationListScreenState extends ConsumerState<DesignationListScreen> {
  final DesignationRepository _repository = DesignationRepository();
  final AuthRepository _authRepository = AuthRepository();
  
  List<Designation> _allDesignations = [];
  List<Designation> _filteredDesignations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _parentFilter = 'All';
  
  List<OrgDropdownItem> _organizations = [];
  String? _selectedOrgId;
  String? _selectedOrgName;

  final Set<int> _selectedIds = {};

  bool _isHierarchyView = false;

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 10;
  List<Designation> _paginatedDesignations = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadOrgs();
  }

  Future<void> _checkPermissionsAndLoadOrgs() async {
    final userData = await _authRepository.getCurrentUser();
    if (userData != null) {
      _selectedOrgId = userData['organizationId'].toString();
    }

    try {
      final orgs = await _authRepository.getUserOrganizations();
      setState(() {
        _organizations = orgs.map((o) => OrgDropdownItem(
          id: (o['id'] ?? o['Id'] ?? '').toString(),
          name: o['name'] ?? o['Name'] ?? 'Unknown',
          logoUrl: o['logoUrl'] ?? o['LogoUrl'],
        )).toList();
        
        if (_selectedOrgId == null && _organizations.isNotEmpty) {
          _selectedOrgId = _organizations.first.id;
          _selectedOrgName = _organizations.first.name;
        } else {
          final current = _organizations.firstWhere(
            (o) => o.id == _selectedOrgId, 
            orElse: () => _organizations.isNotEmpty ? _organizations.first : OrgDropdownItem(id: '', name: '')
          );
          _selectedOrgName = current.name;
        }
      });
      _loadDesignations();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading organizations: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadDesignations() async {
    if (_selectedOrgId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getDesignations(int.parse(_selectedOrgId!));
      setState(() {
        _allDesignations = data;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading designations: $e',
          isError: true,
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      final filtered = _allDesignations.where((d) {
        final matchesSearch = d.designationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (d.parentDesignationName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        bool matchesParent = true;
        if (_parentFilter == 'None') {
          matchesParent = d.parentDesignationId == null;
        } else if (_parentFilter != 'All') {
          matchesParent = d.parentDesignationName == _parentFilter;
        }

        return matchesSearch && matchesParent;
      }).toList();
      
      _filteredDesignations = filtered;
      _currentPage = 1; // Reset to page 1 on filter change
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > _filteredDesignations.length 
        ? _filteredDesignations.length 
        : (startIndex + _pageSize);
    
    if (startIndex >= _filteredDesignations.length) {
      _paginatedDesignations = [];
    } else {
      _paginatedDesignations = _filteredDesignations.sublist(startIndex, endIndex);
    }
  }

  List<String> _getParentOptions() {
    final parents = _allDesignations
        .map((d) => d.parentDesignationName)
        .where((p) => p != null)
        .cast<String>()
        .toSet()
        .toList();
    return ['All', 'None', ...parents];
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this designation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteDesignation(id);
        _loadDesignations();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Delete failed: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _handleBulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Delete'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} designations?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.bulkDelete(_selectedIds.toList());
        setState(() => _selectedIds.clear());
        _loadDesignations();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Bulk delete failed: $e',
            isError: true,
          );
        }
      }
    }
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
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                    ),
                    const Expanded(
                      child: Text(
                        'Designation Management',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_isLoading) 
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  ],
                ),
              ),
            ),

            // Top Toolbar (Search, Org, Filter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              onChanged: (val) {
                                _searchQuery = val;
                                _applyFilters();
                              },
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Search designations...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 16),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // View Switcher
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _viewToggleIcon(Icons.list, !_isHierarchyView, () => setState(() => _isHierarchyView = false)),
                              _viewToggleIcon(Icons.account_tree_outlined, _isHierarchyView, () => setState(() => _isHierarchyView = true)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Org Selector
                        if (_organizations.isNotEmpty)
                          Expanded(
                            child: OrgDropdown(
                              value: _selectedOrgId,
                              items: _organizations,
                              onChanged: (id) {
                                setState(() {
                                  _selectedOrgId = id;
                                  _selectedOrgName = _organizations.firstWhere((o) => o.id == id).name;
                                });
                                _loadDesignations();
                              },
                              isCompact: true,
                            ),
                          ),
                        const SizedBox(width: 12),
                        // Parent Filter
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _parentFilter,
                                dropdownColor: const Color(0xFF1E293B),
                                isExpanded: true,
                                icon: const Icon(Icons.filter_list, size: 16, color: Colors.grey),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                items: _getParentOptions().map((opt) {
                                  return DropdownMenuItem(value: opt, child: Text(opt));
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _parentFilter = val!);
                                  _applyFilters();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _navigateToForm(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Designation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedIds.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _handleBulkDelete,
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: Text('Delete (${_selectedIds.length})', style: const TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List / Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : _filteredDesignations.isEmpty 
                  ? const Center(child: Text('No designations found', style: TextStyle(color: Colors.grey)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 900) {
                          return _buildMobileListView();
                        }
                        return _buildDesktopTable(constraints.maxWidth);
                      },
                    ),
              ),
            ),

            // Pagination Footer
            if (!_isLoading && _filteredDesignations.isNotEmpty)
              CustomPagination(
                totalItems: _filteredDesignations.length,
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
    );
  }

  Widget _buildDesktopTable(double availableWidth) {
    final tableWidth = availableWidth < 1000 ? 1000.0 : availableWidth;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, color: Colors.white24, size: 18)),
                  Expanded(flex: 4, child: _buildSortableHeader('NAME')),
                  Expanded(flex: 4, child: _buildSortableHeader('PARENT DESIGNATION')),
                  const SizedBox(width: 120, child: Text('ACTION', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView.builder(
                itemCount: _paginatedDesignations.length,
                itemBuilder: (context, index) {
                  final d = _paginatedDesignations[index];
                  final isSelected = _selectedIds.contains(d.id);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedIds.add(d.id);
                                else _selectedIds.remove(d.id);
                              });
                            },
                            side: const BorderSide(color: Colors.white24),
                            activeColor: Colors.blue,
                          ),
                        ),
                        Expanded(flex: 4, child: Text(d.designationName, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        Expanded(flex: 4, child: Text(d.parentDesignationName ?? '-', style: const TextStyle(color: Colors.white54, fontSize: 13))),
                        SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _navigateToForm(d),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('View', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
                              Theme(
                                data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                                  color: const Color(0xFF1E293B),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                                  offset: const Offset(0, 30),
                                  onSelected: (val) {
                                    if (val == 'edit') _navigateToForm(d);
                                    else if (val == 'delete') _handleDelete(d.id);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [Icon(Icons.edit_outlined, color: Colors.blue, size: 16), SizedBox(width: 10), Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13))]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13))]),
                                    ),
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
      ),
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
      itemCount: _paginatedDesignations.length,
      itemBuilder: (context, index) {
        final d = _paginatedDesignations[index];
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.designationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(d.parentDesignationName != null ? 'Parent: ${d.parentDesignationName}' : 'No Parent', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                        color: const Color(0xFF1E293B),
                        offset: const Offset(0, 40),
                        onSelected: (val) {
                          if (val == 'edit') _navigateToForm(d);
                          else if (val == 'delete') _handleDelete(d.id);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, color: Colors.blue, size: 18), SizedBox(width: 12), Text('Edit', style: TextStyle(color: Colors.white))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.white))])),
                        ],
                      ),
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

  Future<void> _navigateToForm(Designation? editData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DesignationFormScreen(
          organizationId: int.parse(_selectedOrgId!),
          organizationName: _selectedOrgName!,
          allDesignations: _allDesignations,
          editData: editData,
        ),
      ),
    );
    if (result == true) _loadDesignations();
  }

  Widget _viewToggleIcon(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.blue : Colors.grey),
      ),
    );
  }
}

extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    return where(test).toList();
  }
}
