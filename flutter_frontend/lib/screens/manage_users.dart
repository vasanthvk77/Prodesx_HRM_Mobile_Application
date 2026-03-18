import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/manage_users.dart';
import '../models/manage_users.dart';
import '../widgets/digital_clock.dart';
import '../core/api_config.dart';
import '../widgets/org_dropdown.dart';

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
      _filteredUsers = _users.where((user) {
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

      _totalUsers = _filteredUsers.length;
      _activeAccess = _filteredUsers.where((u) => u.isActive).length;
      _revokedAccess = _filteredUsers.where((u) => !u.isActive).length;
    });
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
                  : _buildUserList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
           Expanded(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Manage users and their organisation access rights",
          style: const TextStyle(fontSize: 10, color: Color.fromARGB(255, 255, 255, 255)),
          softWrap: true,
        ),
      ),
    ),

            const SizedBox(width: 3),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {},
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
      return const Center(child: Text('No users match these filters'));
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserListItem(user);
      },
    );
  }

  Widget _buildUserListItem(ManageUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: user.organizationLogo != null
                      ? NetworkImage(
                          ApiConfig.getFullImageUrl(user.organizationLogo),
                        )
                      : null,
                  child: user.organizationLogo == null
                      ? Text(user.userName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBadge(user.role, _getRoleColor(user.role)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    user.organizationName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildBadge(
                      user.isActive ? 'Active' : 'Inactive',
                      user.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.block_outlined, size: 18),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
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
