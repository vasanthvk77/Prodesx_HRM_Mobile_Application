import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/manage_users.dart';
import '../models/manage_users.dart';
import '../widgets/digital_clock.dart';
import '../core/api_config.dart';
import '../widgets/org_dropdown.dart';
import '../popups/manage_users_edit.dart';
import '../popups/create_user_popup.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_pagination.dart';


class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  late ManageUsersRepository _repo;
  List<ManageUser> _users = [];
  List<ManageUser> _filteredUsers = [];
  List<UserOrganization> _organizations = [];
  List<UserRole> _roles = [];

  bool _isLoading = true;
  int _totalUsers = 0;
  int _activeAccess = 0;
  int _revokedAccess = 0;

  String? _selectedOrganizationId;
  String? _selectedRole;
  String? _selectedStatus;

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 10;
  List<ManageUser> _paginatedUsers = [];
  
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authState = ref.read(authProvider);
    _repo = ManageUsersRepository(token: authState.token ?? '');

    final results = await Future.wait([
      _repo.getUsers(),
      _repo.getOrganizations(),
      _repo.getRoles(),
    ]);

    if (mounted) {
      setState(() {
        _users = results[0] as List<ManageUser>;
        _organizations = results[1] as List<UserOrganization>;
        _roles = results[2] as List<UserRole>;
        
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      final filtered = _users.where((user) {
        final matchesOrg = _selectedOrganizationId == null || user.organizationID.toString() == _selectedOrganizationId;
        final matchesRole = _selectedRole == null || user.role == _selectedRole;
        
        bool matchesStatus = true;
        if (_selectedStatus == 'Active') {
          matchesStatus = user.isActive;
        } else if (_selectedStatus == 'Revoked') {
          matchesStatus = !user.isActive;
        }

        return matchesOrg && matchesRole && matchesStatus;
      }).toList();

      _filteredUsers = filtered;
      _totalUsers = _filteredUsers.length;
      _activeAccess = _filteredUsers.where((u) => u.isActive).length;
      _revokedAccess = _filteredUsers.where((u) => !u.isActive).length;
      
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > _filteredUsers.length 
        ? _filteredUsers.length 
        : (startIndex + _pageSize);
    
    if (startIndex >= _filteredUsers.length) {
      _paginatedUsers = [];
    } else {
      _paginatedUsers = _filteredUsers.sublist(startIndex, endIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setManageUsersContent(null);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildKPICards(),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Expanded(child: _buildUserList()),
                              if (!_isLoading && _filteredUsers.isNotEmpty)
                                CustomPagination(
                                  totalItems: _filteredUsers.length,
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

  Widget _buildHeader() {
    final bool isDesktopOrTablet = MediaQuery.of(context).size.width >= 600;
    
    if (isDesktopOrTablet) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22, color: Colors.white),
                onPressed: () => ref.read(navigationProvider.notifier).setManageUsersContent(null),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Manage users and their organisation access rights', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => showDialog(context: context, builder: (context) => CreateUserPopup(onUserCreated: _loadData)),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create New User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), // Match dark theme button
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () {
                ref
                    .read(navigationProvider.notifier)
                    .setManageUsersContent(null);
              },
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const DigitalClock(),
          ],
        ),
        const SizedBox(height: 0),
        Row(
          children: [
           
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => CreateUserPopup(
                      onUserCreated: _loadData,
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New User'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICards() {
    return Row(
      children: [
        Expanded(
          child: _buildKPIItem(
            'TOTAL USERS',
            _totalUsers.toString(),
            Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPIItem(
            'ACTIVE ACCESS',
            _activeAccess.toString(),
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPIItem(
            'REVOKED ACCESS',
            _revokedAccess.toString(),
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildKPIItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Filters',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            OrgDropdown(
              isCompact: true,
              showLabel: true,
              value: _selectedOrganizationId ?? '',
              items: [
                OrgDropdownItem(id: '', name: 'All Organisations'),
                ..._organizations.map((e) => OrgDropdownItem(id: e.id.toString(), name: e.name, logoUrl: e.logoUrl)),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedOrganizationId = (val == '' || val == null) ? null : val;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildDropdownFilter(
              label: 'Role',
              value: _selectedRole,
              items: ['All Roles', ..._roles.map((e) => e.roleName).toSet()],
              onChanged: (val) {
                setState(() {
                  _selectedRole = val == 'All Roles' ? null : val;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildDropdownFilter(
              label: 'Status',
              value: _selectedStatus,
              items: ['All Statuses', 'Active', 'Revoked'],
              onChanged: (val) {
                setState(() {
                  _selectedStatus = val == 'All Statuses' ? null : val;
                  _applyFilters();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final currentValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
               color: value != null ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
              isDense: true,
              dropdownColor: Theme.of(context).cardTheme.color,
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('No users match these filters', style: TextStyle(color: Colors.white70)));
    }

    final bool isDesktopOrTablet = MediaQuery.of(context).size.width >= 600;

    if (isDesktopOrTablet) {
      return _buildDesktopTable();
    }

    return ListView.builder(
      itemCount: _paginatedUsers.length,
      itemBuilder: (context, index) {
        final user = _paginatedUsers[index];
        return _buildUserListItem(user);
      },
    );
  }

  Widget _buildDesktopTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0), // Space for scrollbar
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 16,
                    headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)), // Match dark slate
            dataRowMaxHeight: 65,
            dataRowMinHeight: 65,
            columns: const [
              DataColumn(label: Text('USER', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('EMAIL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('ORGANISATION', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('ROLE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('GRANTED', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('STATUS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('ACTIONS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
            rows: _paginatedUsers.map((user) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          backgroundImage: user.organizationLogo != null && user.organizationLogo!.isNotEmpty ? NetworkImage(ApiConfig.getFullImageUrl(user.organizationLogo)) : null,
                          child: (user.organizationLogo == null || user.organizationLogo!.isEmpty) ? Text(user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(user.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DataCell(Text(user.email, style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(user.organizationName, style: const TextStyle(color: Colors.white))),
                  DataCell(_buildBadge(user.role, _getRoleColor(user.role))),
                  DataCell(Text('${user.grantedDate.day.toString().padLeft(2, '0')}/${user.grantedDate.month.toString().padLeft(2, '0')}/${user.grantedDate.year}', style: const TextStyle(color: Colors.white70))),
                  DataCell(_buildBadge(user.isActive ? 'Active' : 'Revoked', user.isActive ? Colors.green : Colors.red)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white54),
                          onPressed: () => _openEditPopup(user),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: Icon(user.isActive ? Icons.block_flipped : Icons.check_circle_outline, size: 16, color: user.isActive ? Colors.redAccent.withOpacity(0.8) : Colors.green),
                          onPressed: () => _revokeRestoreUserAccess(user),
                          tooltip: user.isActive ? 'Revoke Access' : 'Restore Access',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54),
                          onPressed: () => _deleteUserAccount(user),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildUserListItem(ManageUser user) {
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        backgroundImage: user.organizationLogo != null
                            ? NetworkImage(ApiConfig.getFullImageUrl(user.organizationLogo))
                            : null,
                        child: user.organizationLogo == null
                            ? Text(user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U')
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(user.email, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
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
                        _openEditPopup(user);
                      } else if (value == 'revoke_restore') {
                        _revokeRestoreUserAccess(user);
                      } else if (value == 'delete') {
                        _deleteUserAccount(user);
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
                      PopupMenuItem(
                        value: 'revoke_restore',
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(user.isActive ? Icons.block_flipped : Icons.check_circle_outline, color: user.isActive ? Colors.redAccent.withOpacity(0.8) : Colors.green, size: 18),
                            const SizedBox(width: 12),
                            Text(user.isActive ? 'Revoke Access' : 'Restore Access', style: TextStyle(color: user.isActive ? Colors.redAccent.withOpacity(0.8) : Colors.green, fontSize: 13, fontWeight: FontWeight.w500)),
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
                Expanded(child: _buildMobileDetailColumn('Organization', user.organizationName)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Role', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      _buildBadge(user.role, _getRoleColor(user.role)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: user.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: user.isActive ? Colors.green : Colors.red)),
                      child: Text(user.isActive ? 'Active' : 'Inactive', style: TextStyle(color: user.isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
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

  Future<void> _openEditPopup(ManageUser user) async {
    final userAccesses = _users.where((u) => u.userID == user.userID).toList();

    await showDialog(
      context: context,
      builder: (context) => ManageUsersEditPopup(
        userId: user.userID,
        userName: user.userName,
        email: user.email,
        userAccesses: userAccesses,
        allOrganizations: _organizations,
        allRoles: _roles,
      ),
    );

    // Refresh data after popup closes to catch backend changes
    _loadData();
  }

  Future<void> _revokeRestoreUserAccess(ManageUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(user.isActive ? Icons.block_flipped : Icons.check_circle_outline, color: user.isActive ? Colors.redAccent : Colors.green),
            const SizedBox(width: 12),
            Text(user.isActive ? 'Revoke Access' : 'Restore Access', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to ${user.isActive ? 'revoke' : 'restore'} access to ${user.userName}?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? Colors.redAccent : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(user.isActive ? 'Revoke' : 'Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    String? errorMsg;
    if (user.isActive) {
      errorMsg = await _repo.revokeAccess(user.userID, user.organizationID);
    } else {
      final actualRole = _roles.firstWhere(
        (r) => r.roleName.toLowerCase() == user.role.toLowerCase(),
        orElse: () => _roles.isNotEmpty ? _roles.first : UserRole(roleID: user.roleID, roleName: user.role),
      );
      errorMsg = await _repo.grantAccess(user.userID, user.organizationID, actualRole.roleID);
    }
    
    if (!mounted) return;
    
    if (errorMsg == null) {
      CustomSnackbar.show(
        context: context, 
        message: user.isActive ? 'Access revoked successfully.' : 'Access restored successfully.'
      );
      _loadData();
    } else {
      CustomSnackbar.show(
        context: context, 
        message: errorMsg,
        isError: true,
      );
    }
  }

  Future<void> _deleteUserAccount(ManageUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to permanently delete ${user.userName}?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final errorMsg = await _repo.deleteUser(user.userID);
    if (!mounted) return;
    
    if (errorMsg == null) {
      CustomSnackbar.show(
        context: context, 
        message: 'Account deleted successfully.'
      );
      _loadData();
    } else {
      CustomSnackbar.show(
        context: context, 
        message: errorMsg,
        isError: true,
      );
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'super admin':
        return Colors.amber;
      case 'admin':
        return Colors.blue;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
