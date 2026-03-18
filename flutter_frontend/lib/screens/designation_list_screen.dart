import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/designation.dart';
import '../repositories/designation_repository.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import 'designation_form_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organizations: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading designations: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDesignations = _allDesignations.filter((d) {
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
    });
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk delete failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navyBg = const Color(0xFF0F172A); // Navy background

    return Scaffold(
      backgroundColor: navyBg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header matching HRManagementScreen style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DesignationFormScreen(
                            organizationId: int.parse(_selectedOrgId!),
                            organizationName: _selectedOrgName!,
                            allDesignations: _allDesignations,

                          ),
                        ),
                      );
                      if (result == true) _loadDesignations();
                    },
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

            // List / Table
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDesignations,
                child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredDesignations.isEmpty 
                  ? const Center(child: Text('No designations found', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredDesignations.length,
                      itemBuilder: (context, index) {
                        final d = _filteredDesignations[index];
                        final isSelected = _selectedIds.contains(d.id);
                        return _buildDesignationCard(d, isSelected);
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildDesignationCard(Designation d, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? Colors.blue : Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
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
        title: Text(
          d.designationName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          d.parentDesignationName != null ? 'Parent: ${d.parentDesignationName}' : 'No Parent',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
          color: const Color(0xFF1E293B),
          onSelected: (val) async {
            if (val == 'edit') {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DesignationFormScreen(
                    organizationId: d.organizationId,
                    organizationName: _selectedOrgName!,
                    editData: d,
                    allDesignations: _allDesignations,
                  ),
                ),
              );
              if (result == true) _loadDesignations();
            } else if (val == 'delete') {
              _handleDelete(d.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.blue), SizedBox(width: 8), Text('Edit', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.white))])),
          ],
        ),
      ),
    );
  }
}

extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    return where(test).toList();
  }
}
