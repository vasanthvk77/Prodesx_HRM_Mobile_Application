import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/face_service.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_snackbar.dart';

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
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        elevation: 0,
        backgroundColor: theme.cardColor,
        leading: IconButton(
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: OrgDropdown(
                    value: _selectedOrgId,
                    items: _organizations,
                    onChanged: (id) {
                      setState(() => _selectedOrgId = id);
                      _fetchLogs();
                    },
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ),

          // Header Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOTAL LOGS: ${_logs.length}",
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text("No attendance records found today", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            
                            // Safe parsing
                            final rawTime = log['punchTime'] ?? log['PunchTime'] ?? DateTime.now().toIso8601String();
                            final punchTime = DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
                            final hourStr = DateFormat('HH:mm:ss').format(punchTime);
                            final dateStr = DateFormat('MMM dd, yyyy').format(punchTime);
                            
                            final empName = log['employeeName'] ?? log['EmployeeName'] ?? 'Unknown';
                            final empCode = log['employeeCode'] ?? log['EmployeeCode'] ?? '---';
                            final role = log['role'] ?? log['Role'] ?? 'No Role';
                            final punchType = log['punchType'] ?? log['PunchType'] ?? 'FACE';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                                gradient: isDark ? null : LinearGradient(
                                  colors: [theme.cardColor, theme.cardColor.withOpacity(0.95)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: isDark ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Status Stripe
                                      Container(
                                        width: 4,
                                        color: Colors.blueAccent,
                                      ),
                                      const SizedBox(width: 12),
                                      // Info Section
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.person, color: Colors.blueAccent, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      empName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "$empCode • $role",
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Time Section
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: theme.dividerColor.withOpacity(0.03),
                                          border: Border(left: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              hourStr,
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              dateStr,
                                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                punchType.toString().toUpperCase(),
                                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }
}
