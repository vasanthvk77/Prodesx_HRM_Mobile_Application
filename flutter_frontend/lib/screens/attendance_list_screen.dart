import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/face_service.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/hrm_search_toolbar.dart';

class AttendanceListScreen extends ConsumerStatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  ConsumerState<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends ConsumerState<AttendanceListScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final FaceService _faceService = FaceService();

  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _selectedOrgId;
  List<OrgDropdownItem> _organizations = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    try {
      final userData = await _authRepository.getCurrentUser();
      if (userData != null) {
        _selectedOrgId = userData['organizationId'].toString();
      }

      final orgs = await _authRepository.getUserOrganizations();
      setState(() {
        _organizations = orgs.map((o) => OrgDropdownItem(
          id: (o['id'] ?? o['Id'] ?? '').toString(),
          name: o['name'] ?? o['Name'] ?? 'Unknown',
          logoUrl: o['logoUrl'] ?? o['LogoUrl'],
        )).toList();

        if (_selectedOrgId == null && _organizations.isNotEmpty) {
          _selectedOrgId = _organizations.first.id;
        }
      });
      _fetchLogs();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error loading organizations: $e', isError: true);
      }
    }
  }

  Future<void> _fetchLogs() async {
    if (_selectedOrgId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _faceService.getAttendanceLogs(int.parse(_selectedOrgId!));
      setState(() {
        _logs = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error fetching logs: $e', isError: true);
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
              color: theme.cardColor,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
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
                    Expanded(
                      child: Text(
                        'Attendance Logs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900, // Extra bold
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _fetchLogs,
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Premium Search Toolbar
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: HRMSearchToolbar(
              selectedOrgId: _selectedOrgId,
              orgItems: _organizations,
              onOrgChanged: (id) {
                setState(() {
                  _selectedOrgId = id;
                });
                _fetchLogs();
              },
              onSearchChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              hintText: 'Search Employee Name or ID...',
              isOrgLoading: _isLoading && _organizations.isEmpty,
            ),
          ),

            // Info Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "TOTAL LOGS: ${_logs.length}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMM dd').format(DateTime.now()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading && _logs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text("No records found", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final filtered = _logs.where((log) {
                              final name = (log['employeeName'] ?? log['EmployeeName'] ?? '').toString().toLowerCase();
                              final code = (log['employeeCode'] ?? log['EmployeeCode'] ?? '').toString().toLowerCase();
                              final search = _searchQuery.toLowerCase();
                              return name.contains(search) || code.contains(search);
                            }).toList();

                            if (constraints.maxWidth < 900) {
                              return _buildMobileCards(filtered, theme, isDark);
                            }
                            return _buildDesktopTable(filtered, theme, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<dynamic> filtered, ThemeData theme, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = filtered[index];
        final rawTime = log['punchTime'] ?? log['PunchTime'] ?? DateTime.now().toIso8601String();
        final punchTime = DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
        final hourStr = DateFormat('hh:mm:ss a').format(punchTime);
        final dateStr = DateFormat('MMM dd, yyyy').format(punchTime);
        final empName = log['employeeName'] ?? log['EmployeeName'] ?? 'Unknown';
        final empCode = log['employeeCode'] ?? log['EmployeeCode'] ?? '---';
        final role = log['role'] ?? log['Role'] ?? 'No Role';
        final punchType = log['punchType'] ?? log['PunchType'] ?? 'FACE';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text("$empCode • $role", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(hourStr, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blue.shade600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(punchType.toString().toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> filtered, ThemeData theme, bool isDark) {
    final border = isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
            child: Row(
              children: [
                _headerCell('Employee Details', flex: 4),
                _headerCell('Punch Time', flex: 2),
                _headerCell('Punch Date', flex: 2),
                _headerCell('Verification', flex: 1),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          // Body
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (context, index) {
                final log = filtered[index];
                final rawTime = log['punchTime'] ?? log['PunchTime'] ?? DateTime.now().toIso8601String();
                final punchTime = DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
                final hourStr = DateFormat('hh:mm:ss a').format(punchTime);
                final dateStr = DateFormat('MMM dd, yyyy').format(punchTime);
                final empName = log['employeeName'] ?? log['EmployeeName'] ?? 'Unknown';
                final empCode = log['employeeCode'] ?? log['EmployeeCode'] ?? '---';
                final role = log['role'] ?? log['Role'] ?? 'No Role';
                final punchType = log['punchType'] ?? log['PunchType'] ?? 'FACE';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.shade50,
                              child: Text(empName[0], style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(empName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text("$empCode • $role", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(hourStr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.blue.shade600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            punchType.toString().toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
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

  Widget _headerCell(String label, {int? flex}) {
    return Expanded(
      flex: flex ?? 1,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF475569),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
