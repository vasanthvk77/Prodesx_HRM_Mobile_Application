import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/department.dart';
import '../repositories/department_repository.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import 'department_form_screen.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';

class DepartmentListScreen extends ConsumerStatefulWidget {
  const DepartmentListScreen({super.key});

  @override
  ConsumerState<DepartmentListScreen> createState() =>
      _DepartmentListScreenState();
}

class _DepartmentListScreenState extends ConsumerState<DepartmentListScreen> {
  final DepartmentRepository _repository = DepartmentRepository();
  final AuthRepository _authRepository = AuthRepository();

  List<Department> _allDepartments = [];
  List<Department> _filteredDepartments = [];
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
  List<Department> _paginatedDepartments = [];

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
        _organizations = orgs
            .map(
              (o) => OrgDropdownItem(
                id: (o['id'] ?? o['Id'] ?? '').toString(),
                name: o['name'] ?? o['Name'] ?? 'Unknown',
                logoUrl: o['logoUrl'] ?? o['LogoUrl'],
              ),
            )
            .toList();

        if (_selectedOrgId == null && _organizations.isNotEmpty) {
          _selectedOrgId = _organizations.first.id;
          _selectedOrgName = _organizations.first.name;
        } else {
          final current = _organizations.firstWhere(
            (o) => o.id == _selectedOrgId,
            orElse: () => _organizations.isNotEmpty
                ? _organizations.first
                : OrgDropdownItem(id: '', name: ''),
          );
          _selectedOrgName = current.name;
        }
      });
      _loadDepartments();
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

  Future<void> _loadDepartments() async {
    if (_selectedOrgId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _repository.getDepartments(int.parse(_selectedOrgId!));
      setState(() {
        _allDepartments = data;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading departments: $e',
          isError: true,
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      final filtered = _allDepartments.where((d) {
        final matchesSearch =
            d.departmentName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (d.parentDepartmentName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);

        bool matchesParent = true;
        if (_parentFilter == 'None') {
          matchesParent = d.parentDepartmentId == null;
        } else if (_parentFilter != 'All') {
          matchesParent = d.parentDepartmentName == _parentFilter;
        }

        return matchesSearch && matchesParent;
      }).toList();

      _filteredDepartments = filtered;
      _currentPage = 1; // Reset to page 1 on filter change
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > _filteredDepartments.length
        ? _filteredDepartments.length
        : (startIndex + _pageSize);

    if (startIndex >= _filteredDepartments.length) {
      _paginatedDepartments = [];
    } else {
      _paginatedDepartments = _filteredDepartments.sublist(
        startIndex,
        endIndex,
      );
    }
  }

  List<String> _getParentOptions() {
    final parents = _allDepartments
        .map((d) => d.parentDepartmentName)
        .where((p) => p != null)
        .cast<String>()
        .toSet()
        .toList();
    return ['All', 'None', ...parents];
  }

  Future<void> _handleDelete(int id) async {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    final confirmed = await (isIOS
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete this department?',
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete this department?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ));

    if (confirmed == true) {
      try {
        await _repository.deleteDepartment(id);
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Department deleted successfully',
          );
        }
        _loadDepartments();
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
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} departments?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.bulkDelete(_selectedIds.toList());
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: '${_selectedIds.length} departments deleted successfully',
          );
        }
        setState(() => _selectedIds.clear());
        _loadDepartments();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isIOS = theme.platform == TargetPlatform.iOS;

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
              color: isIOS
                  ? (isDark
                        ? Colors.black.withOpacity(0.8)
                        : Colors.white.withOpacity(0.9))
                  : theme.cardColor,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    if (isIOS) ...[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.bars, size: 22),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.back, size: 22),
                        onPressed: () => ref
                            .read(navigationProvider.notifier)
                            .setHRManagementContent(null),
                      ),
                    ] else ...[
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.iconTheme.color,
                          size: 20,
                        ),
                        onPressed: () => ref
                            .read(navigationProvider.notifier)
                            .setHRManagementContent(null),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        'Department Management',
                        style: isIOS
                            ? const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              )
                            : theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    ),
                    if (_isLoading)
                      isIOS
                          ? const CupertinoActivityIndicator()
                          : const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.1),
                              ),
                            ),
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _applyFilters();
                                });
                              },
                              style: theme.textTheme.bodyMedium,
                              decoration: const InputDecoration(
                                hintText: 'Search departments...',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              _viewToggleIcon(
                                Icons.list,
                                !_isHierarchyView,
                                () => setState(() => _isHierarchyView = false),
                              ),
                              _viewToggleIcon(
                                Icons.account_tree_outlined,
                                _isHierarchyView,
                                () => setState(() => _isHierarchyView = true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_organizations.isNotEmpty)
                          Expanded(
                            child: OrgDropdown(
                              value: _selectedOrgId,
                              items: _organizations,
                              onChanged: (id) {
                                setState(() {
                                  _selectedOrgId = id;
                                  _selectedOrgName = _organizations
                                      .firstWhere((o) => o.id == id)
                                      .name;
                                });
                                _loadDepartments();
                              },
                              isCompact: true,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.1),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _parentFilter,
                                dropdownColor: theme.cardColor,
                                isExpanded: true,
                                icon: Icon(
                                  Icons.filter_list,
                                  size: 16,
                                  color: theme.iconTheme.color?.withOpacity(
                                    0.5,
                                  ),
                                ),
                                style: theme.textTheme.bodySmall,
                                items: _getParentOptions().map((opt) {
                                  return DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _parentFilter = val!;
                                    _applyFilters();
                                  });
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    isIOS
                        ? CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minSize: 0,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () => _navigateToForm(null),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.add, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add Department',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _navigateToForm(null),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Department'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                    const SizedBox(width: 8),
                    if (_selectedIds.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _handleBulkDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        label: Text(
                          'Delete (${_selectedIds.length})',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Export logic (placeholder or snackbar)
                        CustomSnackbar.show(
                          context: context,
                          message: 'Exporting departments...',
                        );
                      },
                      icon: const Icon(
                        Icons.download,
                        size: 18,
                        color: Colors.grey,
                      ),
                      label: const Text(
                        'Export',
                        style: TextStyle(color: Colors.grey),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // List / Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      )
                    : _filteredDepartments.isEmpty
                    ? const Center(
                        child: Text(
                          'No departments found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 900) {
                            return _buildMobileListView();
                          }
                          return _buildDesktopTable(
                            constraints.maxWidth,
                            theme,
                          );
                        },
                      ),
              ),
            ),

            // Pagination Footer
            if (!_isLoading && _filteredDepartments.isNotEmpty)
              CustomPagination(
                totalItems: _filteredDepartments.length,
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

  Widget _buildDesktopTable(double availableWidth, ThemeData theme) {
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
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Icon(
                      Icons.check_box_outline_blank,
                      color: theme.iconTheme.color?.withOpacity(0.2),
                      size: 18,
                    ),
                  ),
                  Expanded(flex: 4, child: _buildSortableHeader('NAME', theme)),
                  Expanded(
                    flex: 4,
                    child: _buildSortableHeader('PARENT DEPARTMENT', theme),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'ACTION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView.builder(
                itemCount: _paginatedDepartments.length,
                itemBuilder: (context, index) {
                  final d = _paginatedDepartments[index];
                  final isSelected = _selectedIds.contains(d.id);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true)
                                  _selectedIds.add(d.id);
                                else
                                  _selectedIds.remove(d.id);
                              });
                            },
                            side: BorderSide(color: theme.dividerColor),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            d.departmentName,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            d.parentDepartmentName ?? '-',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _navigateToForm(d),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'View',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                ),
                                child: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: theme.iconTheme.color?.withOpacity(
                                      0.5,
                                    ),
                                    size: 18,
                                  ),
                                  color: theme.cardColor,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: theme.dividerColor),
                                  ),
                                  offset: const Offset(0, 30),
                                  onSelected: (val) {
                                    if (val == 'edit')
                                      _navigateToForm(d);
                                    else if (val == 'delete')
                                      _handleDelete(d.id);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            color: theme.colorScheme.primary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Edit',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Delete',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.redAccent,
                                                ),
                                          ),
                                        ],
                                      ),
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

  Widget _buildSortableHeader(String title, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.unfold_more,
          color: theme.iconTheme.color?.withOpacity(0.3),
          size: 14,
        ),
      ],
    );
  }

  Widget _buildMobileListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _paginatedDepartments.length,
      itemBuilder: (context, index) {
        final d = _paginatedDepartments[index];
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.departmentName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.parentDepartmentName != null
                                ? 'Parent: ${d.parentDepartmentName}'
                                : 'No Parent',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.iconTheme.color?.withOpacity(0.5),
                          size: 20,
                        ),
                        color: theme.cardColor,
                        offset: const Offset(0, 40),
                        onSelected: (val) {
                          if (val == 'edit')
                            _navigateToForm(d);
                          else if (val == 'delete')
                            _handleDelete(d.id);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text('Edit', style: theme.textTheme.bodyLarge),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Future<void> _navigateToForm(Department? editData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartmentFormScreen(
          organizationId: int.parse(_selectedOrgId!),
          organizationName: _selectedOrgName!,
          allDepartments: _allDepartments,
          editData: editData,
        ),
      ),
    );
    if (result == true) _loadDepartments();
  }

  Widget _viewToggleIcon(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).iconTheme.color?.withOpacity(0.4),
        ),
      ),
    );
  }
}
