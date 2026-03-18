import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/manage_users.dart';
import '../widgets/org_dropdown.dart';
import '../core/api_config.dart';
import '../providers/auth_provider.dart';
import '../repositories/manage_users.dart';

class ManageUsersEditPopup extends ConsumerStatefulWidget {
  final int userId;
  final String userName;
  final String email;
  final List<ManageUser> userAccesses;
  final List<UserOrganization> allOrganizations;
  final List<UserRole> allRoles;

  const ManageUsersEditPopup({
    super.key,
    required this.userId,
    required this.userName,
    required this.email,
    required this.userAccesses,
    required this.allOrganizations,
    required this.allRoles,
  });

  @override
  ConsumerState<ManageUsersEditPopup> createState() => _ManageUsersEditPopupState();
}

class _ManageUsersEditPopupState extends ConsumerState<ManageUsersEditPopup> {
  bool _isAddingAccess = false;
  String? _newAccessOrgId;
  String? _newAccessRoleId;
  
  // Track local edits per row
  final Map<int, String> _pendingRoleChanges = {};

  // Local feedback message state
  String? _feedbackMessage;
  bool _isErrorFeedback = false;
  Timer? _feedbackTimer;
  bool _isLoading = false;

  late List<ManageUser> _currentUserAccesses;

  ManageUsersRepository? get _repository {
    final token = ref.read(authProvider).token;
    if (token == null) return null;
    return ManageUsersRepository(token: token);
  }

  @override
  void initState() {
    super.initState();
    _currentUserAccesses = List.from(widget.userAccesses);
  }

  Future<void> _refreshUserData() async {
    final repo = _repository;
    if (repo == null) return;
    final allUsers = await repo.getUsers();
    if (mounted) {
      setState(() {
        _currentUserAccesses = allUsers.where((u) => u.userID == widget.userId).toList();
      });
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    setState(() {
      _feedbackMessage = message;
      _isErrorFeedback = isError;
    });
    
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Divider(color: Colors.grey.withOpacity(0.2), height: 32),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOrganisationAccessSection(),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.withOpacity(0.2), height: 32),
                      _buildDangerZone(),
                    ],
                  ),
                ),
              ),
              if (_feedbackMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isErrorFeedback ? Colors.redAccent.shade700 : Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_isErrorFeedback ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _feedbackMessage!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(color: Colors.grey.withValues(alpha: 0.2), height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blueAccent,
          child: Text(
            widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                widget.email,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildOrganisationAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ORGANISATION ACCESS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isAddingAccess = !_isAddingAccess);
              },
              icon: Icon(_isAddingAccess ? Icons.remove : Icons.add, size: 16, color: Colors.grey),
              label: Text(
                _isAddingAccess ? 'Cancel' : 'Add Access',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isAddingAccess) _buildAddAccessForm(),
        if (_isAddingAccess) const SizedBox(height: 16),
        ..._currentUserAccesses.map((access) => _buildAccessCard(access)),
      ],
    );
  }

  Widget _buildAddAccessForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrgDropdown(
            value: _newAccessOrgId ?? '',
            items: [
              OrgDropdownItem(id: '', name: 'Organisation'),
              ...widget.allOrganizations.map((e) => OrgDropdownItem(id: e.id.toString(), name: e.name, logoUrl: e.logoUrl)),
            ],
            onChanged: (val) => setState(() => _newAccessOrgId = val),
            isCompact: false,
            showLabel: false,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _newAccessRoleId,
                      hint: const Text('Role', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      items: widget.allRoles.map((role) {
                        return DropdownMenuItem(
                          value: role.roleID.toString(),
                          child: Text(role.roleName, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _newAccessRoleId = val),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      dropdownColor: Theme.of(context).cardTheme.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    if (_newAccessOrgId == null || _newAccessOrgId!.isEmpty || _newAccessRoleId == null || _newAccessRoleId!.isEmpty) {
                      _showFeedback("Please select both Organisation and Role", isError: true);
                      return;
                    }
                    setState(() => _isLoading = true);
                    final repo = _repository;
                    if (repo != null) {
                      final errorMsg = await repo.grantAccess(
                          widget.userId, int.parse(_newAccessOrgId!), int.parse(_newAccessRoleId!));
                      if (errorMsg == null) {
                        await _refreshUserData();
                        _showFeedback("Access successfully granted!");
                        setState(() {
                          _isAddingAccess = false;
                          _newAccessOrgId = null;
                          _newAccessRoleId = null;
                        });
                      } else {
                        _showFeedback(errorMsg, isError: true);
                      }
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Grant', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessCard(ManageUser access) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: access.organizationLogo != null
                      ? Image.network(
                          ApiConfig.getFullImageUrl(access.organizationLogo),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.business, color: Colors.grey, size: 20),
                        )
                      : const Icon(Icons.business, color: Colors.grey, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      access.organizationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Granted ${DateFormat('dd/MM/yyyy').format(access.grantedDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: access.isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  access.isActive ? 'Active' : 'Revoked',
                  style: TextStyle(
                    color: access.isActive ? Colors.green : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (access.isActive)
                TextButton.icon(
                  icon: const Icon(Icons.block, size: 14, color: Colors.grey),
                  label: const Text('Revoke', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    final repo = _repository;
                    if (repo != null) {
                      final errorMsg = await repo.revokeAccess(widget.userId, access.organizationID);
                      if (errorMsg == null) {
                        await _refreshUserData();
                        _showFeedback('Access to ${access.organizationName} revoked.', isError: true);
                      } else {
                        _showFeedback(errorMsg, isError: true);
                      }
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.restore, size: 14, color: Colors.grey),
                  label: const Text('Restore', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    final repo = _repository;
                    if (repo != null) {
                      // Resolve the role ID from the role name to ensure it's never 0
                      final actualRole = widget.allRoles.firstWhere(
                         (r) => r.roleName.toLowerCase() == access.role.toLowerCase(),
                         orElse: () => widget.allRoles.isNotEmpty ? widget.allRoles.first : UserRole(roleID: access.roleID, roleName: access.role),
                      );
                      
                      // Restoring access means granting it again
                      final errorMsg = await repo.grantAccess(widget.userId, access.organizationID, actualRole.roleID);
                      if (errorMsg == null) {
                        await _refreshUserData();
                        _showFeedback('Access to ${access.organizationName} restored.');
                      } else {
                        _showFeedback(errorMsg, isError: true);
                      }
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _pendingRoleChanges[access.accessID] ?? (widget.allRoles.any((r) => r.roleName == access.role) 
                          ? access.role 
                          : (widget.allRoles.isNotEmpty ? widget.allRoles.first.roleName : null)),
                      items: widget.allRoles.map((role) {
                        return DropdownMenuItem(
                          value: role.roleName,
                          child: Text(role.roleName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _pendingRoleChanges[access.accessID] = val;
                          });
                        }
                      },
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                      dropdownColor: Theme.of(context).cardTheme.color,
                    ),
                  ),
                ),
              ),
              if (_pendingRoleChanges[access.accessID] != null && _pendingRoleChanges[access.accessID] != access.role)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        final String updatedRoleName = _pendingRoleChanges[access.accessID] ?? 'Role';
                        final targetRole = widget.allRoles.firstWhere((r) => r.roleName == updatedRoleName);

                        setState(() => _isLoading = true);
                        final repo = _repository;
                        if (repo != null) {
                           final errorMsg = await repo.grantAccess(widget.userId, access.organizationID, targetRole.roleID);
                           if (errorMsg == null) {
                             await _refreshUserData();
                             setState(() { _pendingRoleChanges.remove(access.accessID); });
                             _showFeedback('Role updated to $updatedRoleName!');
                           } else {
                             _showFeedback(errorMsg, isError: true);
                           }
                        }
                        if (mounted) setState(() => _isLoading = false);
                      },
                      icon: _isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DANGER ZONE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.redAccent),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : () async {
            setState(() => _isLoading = true);
            final repo = _repository;
            if (repo != null) {
              final errorMsg = await repo.deleteUser(widget.userId);
              if (errorMsg == null) {
                 _showFeedback('User account ${widget.userName} deleted permanently.', isError: true);
                 Future.delayed(const Duration(milliseconds: 1000), () {
                   if (mounted) Navigator.of(context).pop();
                 });
              } else {
                 _showFeedback(errorMsg, isError: true);
                 if (mounted) setState(() => _isLoading = false);
              }
            }
          },
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          label: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
