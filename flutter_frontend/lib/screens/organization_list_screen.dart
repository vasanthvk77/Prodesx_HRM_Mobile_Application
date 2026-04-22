import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/organization_repository.dart';
import '../models/organization.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_snackbar.dart';
import 'organization_creation_screen.dart';

class OrganizationListScreen extends ConsumerStatefulWidget {
  const OrganizationListScreen({super.key});

  @override
  ConsumerState<OrganizationListScreen> createState() => _OrganizationListScreenState();
}

class _OrganizationListScreenState extends ConsumerState<OrganizationListScreen> {
  bool _isLoading = false;
  List<Organization> _organizations = [];

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final orgs = await ref.read(organizationRepositoryProvider).getOrganizations();
      setState(() => _organizations = orgs);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error fetching organizations: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOrganization(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Organization'),
        content: const Text('Are you sure you want to delete this organization? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(organizationRepositoryProvider).deleteOrganization(id);
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Organization deleted successfully');
        _fetchOrganizations();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error deleting organization: $e', isError: true);
      }
    }
  }

  void _openAddOrganization() {
    ref.read(navigationProvider.notifier).setDashboardContent(
      OrganizationCreationScreen(
        onSuccess: _fetchOrganizations,
      ),
    );
  }

  void _openEditOrganization(Organization org) {
    ref.read(navigationProvider.notifier).setDashboardContent(
      OrganizationCreationScreen(
        organization: org,
        onSuccess: _fetchOrganizations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(null),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organisation Management',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Manage registered organisations',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _openAddOrganization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14),
                          SizedBox(width: 4),
                          Text('Add Organization', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _organizations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_outlined, size: 60, color: Colors.grey.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No organizations found', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 900) {
                                return _buildMobileListView();
                              }
                              return _buildDesktopTable(isDark);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Premium rounding
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.04), // Soft shadow
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? Colors.white.withOpacity(0.01) : Colors.white),
            columnSpacing: 30,
            columns: const [
              DataColumn(label: Text('LOGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
              DataColumn(label: Text('NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
              DataColumn(label: Text('EMAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
              DataColumn(label: Text('PHONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
              DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
              DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.8))),
            ],
            rows: _organizations.map((org) {
              return DataRow(cells: [
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      backgroundImage: org.logoUrl != null ? NetworkImage(org.logoUrl!) : null,
                      child: org.logoUrl == null ? const Icon(Icons.business, size: 18, color: Colors.blueAccent) : null,
                    ),
                  ),
                ),
                DataCell(Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(org.email ?? '-')),
                DataCell(Text(org.phone ?? '-')),
                DataCell(SizedBox(width: 200, child: Text(org.address ?? '-', overflow: TextOverflow.ellipsis))),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                        onPressed: () => _openEditOrganization(org),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () => _deleteOrganization(org.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              backgroundImage: org.logoUrl != null ? NetworkImage(org.logoUrl!) : null,
              child: org.logoUrl == null ? const Icon(Icons.business, size: 24, color: Colors.blueAccent) : null,
            ),
            title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (org.email != null) Text(org.email!, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                if (org.phone != null) Text(org.phone!, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'edit') {
                  _openEditOrganization(org);
                } else if (val == 'delete') {
                  _deleteOrganization(org.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
}
