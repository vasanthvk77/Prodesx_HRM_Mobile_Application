import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_frontend/core/api_config.dart';
import 'package:flutter_frontend/providers/auth_provider.dart';
import 'package:flutter_frontend/providers/navigation_provider.dart';
import 'package:flutter_frontend/widgets/org_dropdown.dart';
import 'package:flutter_frontend/widgets/custom_snackbar.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_frontend/utils/download_helper.dart';
import 'package:flutter_frontend/widgets/custom_pagination.dart';

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────
class AttendanceRecord {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? department;
  final String? designation;
  final String? fn;
  final String? an;
  final String? profilePictureUrl;

  const AttendanceRecord({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.department,
    this.designation,
    this.fn,
    this.an,
    this.profilePictureUrl,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    employeeId: j['employeeId'],
    employeeCode: j['employeeCode'] ?? '',
    employeeName: j['employeeName'] ?? '',
    department: j['department'],
    designation: j['designation'],
    fn: j['fn'],
    an: j['an'],
    profilePictureUrl: j['profilePictureUrl'],
  );
}

class LeaveType {
  final int? leaveTypeId;
  final String shortName;
  final String fullName;
  final bool isPaid;
  final bool isShow;

  const LeaveType({
    this.leaveTypeId,
    required this.shortName,
    required this.fullName,
    this.isPaid = true,
    this.isShow = true,
  });

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
    leaveTypeId: j['leaveTypeId'] != null
        ? (j['leaveTypeId'] as num).toInt()
        : null,
    shortName: j['shortName'] ?? '',
    fullName: j['fullName'] ?? '',
    isPaid: j['isPaid'] ?? true,
    isShow: j['isShow'] ?? true,
  );
}

// ─────────────────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────────────────
class _AttState {
  final List<AttendanceRecord> records;
  final List<LeaveType> leaveTypes;
  final List<dynamic> organizations;
  final List<LeaveType> allSettingsLeaveTypes;
  final int? selectedOrgId;
  final DateTime selectedDate;
  final String searchQuery;
  final String deptFilter;
  final String desigFilter;
  final bool isLoading;
  final bool isLoadingSettings;
  final bool isSaving;
  final Set<int> selectedIds;
  final int currentPage;
  final int pageSize;

  const _AttState({
    this.records = const [],
    this.leaveTypes = const [],
    this.organizations = const [],
    this.allSettingsLeaveTypes = const [],
    this.selectedOrgId,
    required this.selectedDate,
    this.searchQuery = '',
    this.deptFilter = '',
    this.desigFilter = '',
    this.isLoading = false,
    this.isLoadingSettings = false,
    this.isSaving = false,
    this.selectedIds = const {},
    this.currentPage = 1,
    this.pageSize = 10,
  });

  List<AttendanceRecord> get paginated {
    final f = filtered;
    final start = (currentPage - 1) * pageSize;
    if (start >= f.length) return [];
    final end = (start + pageSize) > f.length ? f.length : (start + pageSize);
    return f.sublist(start, end);
  }

  List<AttendanceRecord> get filtered => records.where((r) {
    final q = searchQuery.toLowerCase().trim();
    if (q.isEmpty) return true;

    final name = r.employeeName.toLowerCase();
    final code = r.employeeCode.toLowerCase();

    // Exact prefix match or word-start match for more precision
    final matchSearch =
        name.startsWith(q) ||
        name.split(' ').any((word) => word.startsWith(q)) ||
        code.startsWith(q);

    final matchDept = deptFilter.isEmpty || r.department == deptFilter;
    final matchDesig = desigFilter.isEmpty || r.designation == desigFilter;
    return matchSearch && matchDept && matchDesig;
  }).toList();

  Map<String, int> get stats {
    int present = 0, absent = 0, leave = 0, unmarked = 0;
    for (final r in records) {
      if (r.fn == null && r.an == null) {
        unmarked++;
      } else if (r.fn == 'P' && r.an == 'P') {
        present++;
      } else if (r.fn == 'A' && r.an == 'A') {
        absent++;
      } else {
        leave++;
      }
    }
    return {
      'present': present,
      'absent': absent,
      'leave': leave,
      'unmarked': unmarked,
    };
  }

  List<String> get uniqueDepts => records
      .map((r) => r.department)
      .where((d) => d != null)
      .cast<String>()
      .toSet()
      .toList();

  List<String> get uniqueDesigs => records
      .map((r) => r.designation)
      .where((d) => d != null)
      .cast<String>()
      .toSet()
      .toList();

  _AttState copyWith({
    List<AttendanceRecord>? records,
    List<LeaveType>? leaveTypes,
    List<dynamic>? organizations,
    List<LeaveType>? allSettingsLeaveTypes,
    int? selectedOrgId,
    DateTime? selectedDate,
    String? searchQuery,
    String? deptFilter,
    String? desigFilter,
    bool? isLoading,
    bool? isLoadingSettings,
    bool? isSaving,
    Set<int>? selectedIds,
    int? currentPage,
    int? pageSize,
  }) => _AttState(
    records: records ?? this.records,
    leaveTypes: leaveTypes ?? this.leaveTypes,
    organizations: organizations ?? this.organizations,
    allSettingsLeaveTypes: allSettingsLeaveTypes ?? this.allSettingsLeaveTypes,
    selectedOrgId: selectedOrgId ?? this.selectedOrgId,
    selectedDate: selectedDate ?? this.selectedDate,
    searchQuery: searchQuery ?? this.searchQuery,
    deptFilter: deptFilter ?? this.deptFilter,
    desigFilter: desigFilter ?? this.desigFilter,
    isLoading: isLoading ?? this.isLoading,
    isLoadingSettings: isLoadingSettings ?? this.isLoadingSettings,
    isSaving: isSaving ?? this.isSaving,
    selectedIds: selectedIds ?? this.selectedIds,
    currentPage: currentPage ?? this.currentPage,
    pageSize: pageSize ?? this.pageSize,
  );
}

// ─────────────────────────────────────────────────────────────
//  PROVIDER / NOTIFIER
// ─────────────────────────────────────────────────────────────
final attendanceRegisterProvider =
    StateNotifierProvider<_AttNotifier, _AttState>((ref) => _AttNotifier(ref));

class _AttNotifier extends StateNotifier<_AttState> {
  final Ref _ref;
  _AttNotifier(this._ref) : super(_AttState(selectedDate: DateTime.now()));

  Map<String, String> get _headers => _ref.read(authProvider).requestHeaders;

  HubConnection? _hubConnection;

  @override
  void dispose() {
    _hubConnection?.stop();
    super.dispose();
  }

  Future<void> _initSignalR() async {
    if (_hubConnection != null || state.selectedOrgId == null) return;

    final auth = _ref.read(authProvider);
    final token = auth.token;

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          ApiConfig.attendanceHub,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on('LeaveTypeChanged', (_) {
      _loadLeaveTypes();
      loadSettingsData();
    });
    _hubConnection!.on('AttendanceChanged', (_) => _loadRecords());

    try {
      await _hubConnection!.start();
      if (state.selectedOrgId != null) {
        await _hubConnection!.invoke(
          'JoinOrganizationGroup',
          args: [state.selectedOrgId.toString()],
        );
      }
    } catch (e) {
      debugPrint('SignalR Attendance Hub Error: $e');
    }
  }

  Future<void> init() async {
    final auth = _ref.read(authProvider);
    if (auth.user == null) return;

    state = state.copyWith(
      selectedOrgId: auth.user!.organizationId,
      organizations: auth.organizationList,
    );

    // 1. Fire off data loading immediately (don't let SignalR block this)
    _loadRecords();
    _loadLeaveTypes();

    // 2. Initialize SignalR in the background
    _initSignalR();
  }

  Future<void> _loadRecords() async {
    if (state.selectedOrgId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.attendanceMaster}?date=$dateStr&orgId=${state.selectedOrgId}',
        ),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        state = state.copyWith(
          records: data.map((e) => AttendanceRecord.fromJson(e)).toList(),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadLeaveTypes() async {
    if (state.selectedOrgId == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.leaveTypes}?orgId=${state.selectedOrgId}'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        state = state.copyWith(
          leaveTypes: data.map((e) => LeaveType.fromJson(e)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> loadSettingsData() async {
    if (state.selectedOrgId == null) return;
    state = state.copyWith(isLoadingSettings: true);
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.leaveTypes}/settings?orgId=${state.selectedOrgId}',
        ),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        state = state.copyWith(
          allSettingsLeaveTypes: data
              .map((e) => LeaveType.fromJson(e))
              .toList(),
          isLoadingSettings: false,
        );
      } else {
        state = state.copyWith(isLoadingSettings: false);
      }
    } catch (_) {
      state = state.copyWith(isLoadingSettings: false);
    }
  }

  Future<void> toggleLeaveTypeVisibility(
    BuildContext context,
    int leaveTypeId,
    bool isShow,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.leaveTypes}/toggle'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'leaveTypeId': leaveTypeId,
          'organizationId': state.selectedOrgId,
          'isShow': isShow,
        }),
      );
      if (res.statusCode == 200) {
        await loadSettingsData();
        await _loadLeaveTypes();
        if (context.mounted) {
          CustomSnackbar.show(context: context, message: 'Visibility updated');
        }
      }
    } catch (_) {}
  }

  Future<void> saveLeaveType(
    BuildContext context, {
    int? leaveTypeId,
    required String fullName,
    required String shortName,
    required bool isPaid,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.leaveTypes}?orgId=${state.selectedOrgId}'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'leaveTypeId': leaveTypeId,
          'fullName': fullName,
          'shortName': shortName,
          'isPaid': isPaid,
          'organizationId': state.selectedOrgId,
        }),
      );
      if (res.statusCode == 200) {
        await loadSettingsData();
        await _loadLeaveTypes();
        if (context.mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Status saved successfully',
          );
        }
      }
    } catch (_) {}
  }

  Future<void> deleteLeaveType(BuildContext context, int leaveTypeId) async {
    try {
      final res = await http.delete(
        Uri.parse(
          '${ApiConfig.leaveTypes}/$leaveTypeId?orgId=${state.selectedOrgId}',
        ),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        await loadSettingsData();
        await _loadLeaveTypes();
        if (context.mounted) {
          CustomSnackbar.show(context: context, message: 'Status deleted');
        }
      }
    } catch (_) {}
  }

  void setOrgId(int id) {
    if (_hubConnection != null && state.selectedOrgId != null) {
      _hubConnection!.invoke(
        'LeaveOrganizationGroup',
        args: [state.selectedOrgId!.toString()],
      );
    }
    state = state.copyWith(
      selectedOrgId: id,
      selectedIds: {},
      currentPage: 1,
    );
    _loadRecords();
    _loadLeaveTypes();
    if (_hubConnection != null) {
      _hubConnection!.invoke('JoinOrganizationGroup', args: [id.toString()]);
    }
  }

  void setDate(DateTime d) {
    state = state.copyWith(selectedDate: d, selectedIds: {}, currentPage: 1);
    _loadRecords();
  }

  void setSearch(String q) =>
      state = state.copyWith(searchQuery: q, currentPage: 1);
  void setDept(String d) => state = state.copyWith(deptFilter: d, currentPage: 1);
  void setDesig(String d) =>
      state = state.copyWith(desigFilter: d, currentPage: 1);

  void setPage(int p) => state = state.copyWith(currentPage: p);
  void setPageSize(int s) =>
      state = state.copyWith(pageSize: s, currentPage: 1);

  void toggleSelect(int id) {
    final ids = Set<int>.from(state.selectedIds);
    if (ids.contains(id))
      ids.remove(id);
    else
      ids.add(id);
    state = state.copyWith(selectedIds: ids);
  }

  void toggleSelectAll() {
    final all = state.filtered.map((r) => r.employeeId).toSet();
    final ids = state.selectedIds.length == all.length ? <int>{} : all;
    state = state.copyWith(selectedIds: ids);
  }

  void clearSelection() => state = state.copyWith(selectedIds: {});

  Future<void> updateStatus({
    required int employeeId,
    required String field,
    required String code,
    bool isBulk = false,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final targets = isBulk ? state.selectedIds.toList() : [employeeId];
      final bulkRecords = targets.map((id) {
        final rec = state.records.firstWhere(
          (r) => r.employeeId == id,
          orElse: () => AttendanceRecord(
            employeeId: id,
            employeeCode: '',
            employeeName: '',
          ),
        );
        return {
          'employeeId': id,
          'attendanceDate': state.selectedDate.toIso8601String(),
          'fn': field == 'FN' ? code : (rec.fn ?? 'A'),
          'an': field == 'AN' ? code : (rec.an ?? 'A'),
        };
      }).toList();

      await http.post(
        Uri.parse(
          '${ApiConfig.bulkAttendanceMaster}?orgId=${state.selectedOrgId}',
        ),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'attendanceDate': state.selectedDate.toIso8601String(),
          'records': bulkRecords,
        }),
      );
      await _loadRecords();
    } catch (_) {
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> exportData(BuildContext context, String type) async {
    if (state.selectedOrgId == null) return;
    try {
      final dateStr = DateFormat('MMM_yyyy').format(state.selectedDate);
      final fileName =
          'Attendance_Register_$dateStr.${type == 'excel' ? 'xlsx' : 'pdf'}';
      final mimeType = type == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/pdf';

      final params = {
        'month': state.selectedDate.month.toString(),
        'year': state.selectedDate.year.toString(),
        'organizationId': state.selectedOrgId.toString(),
        'type': type,
        if (state.deptFilter.isNotEmpty) 'department': state.deptFilter,
        if (state.desigFilter.isNotEmpty) 'designation': state.desigFilter,
        if (state.searchQuery.isNotEmpty) 'search': state.searchQuery,
      };

      final uri = Uri.parse(
        ApiConfig.exportAttendanceRegister,
      ).replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        await FileDownloadUtils.download(
          bytes: response.bodyBytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        if (context.mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'File downloaded: $fileName',
          );
        }
      } else {
        if (context.mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Export failed: ${response.statusCode}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error: $e',
          isError: true,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────
Color _statusColor(String? code) {
  if (code == null) return const Color(0xFF94A3B8);
  if (code == 'P') return const Color(0xFF10B981);
  if (code == 'A') return const Color(0xFFEF4444);
  return const Color(0xFF3B82F6);
}

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN WIDGET
// ─────────────────────────────────────────────────────────────
class AttendanceRegisterScreen extends ConsumerStatefulWidget {
  const AttendanceRegisterScreen({super.key});
  @override
  ConsumerState<AttendanceRegisterScreen> createState() =>
      _AttendanceRegisterScreenState();
}

class _AttendanceRegisterScreenState
    extends ConsumerState<AttendanceRegisterScreen> {
  final _searchCtrl = TextEditingController();

  // The screen now pulls colors dynamically from Theme.of(context)
  // removed static const _bg, _surface, _border, etc.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceRegisterProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── STATUS BADGE ──────────────────────────────────────────
  Widget _statusBadge({
    required BuildContext context,
    required String? code,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor(code);
    final hasCode = code != null && code.isNotEmpty;

    // Surface/Border colors from theme
    final borderColor =
        isDark ? Colors.white.withOpacity(0.12) : theme.dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: hasCode ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasCode ? color.withOpacity(0.6) : borderColor,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          hasCode ? code : '—',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: hasCode ? color : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  // ── STATUS PICKER MENU ────────────────────────────────────
  void _showStatusMenu(
    BuildContext context,
    Offset position,
    List<LeaveType> leaveTypes, {
    required int employeeId,
    required String field,
    bool isBulk = false,
  }) {
    // Fallback: always show P/A/L/H if API returned nothing
    final effectiveTypes = leaveTypes.isNotEmpty
        ? leaveTypes
        : [
            const LeaveType(shortName: 'P', fullName: 'Present'),
            const LeaveType(shortName: 'A', fullName: 'Absent'),
            const LeaveType(shortName: 'L', fullName: 'Leave'),
            const LeaveType(shortName: 'H', fullName: 'Holiday'),
          ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 200,
        position.dy + 300,
      ),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : theme.dividerColor,
        ),
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'SELECT STATUS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.textTheme.bodySmall?.color,
              letterSpacing: 1,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...effectiveTypes.map(
          (lt) => PopupMenuItem<String>(
            value: lt.shortName,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(lt.shortName),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${lt.fullName} (${lt.shortName})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).then((code) {
      if (code != null) {
        ref
            .read(attendanceRegisterProvider.notifier)
            .updateStatus(
              employeeId: employeeId,
              field: field,
              code: code,
              isBulk: isBulk,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceRegisterProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Map theme colors for screen-wide usage
    final bg = theme.scaffoldBackgroundColor;
    final surface = colorScheme.surface;
    final border = isDark ? Colors.white.withOpacity(0.12) : theme.dividerColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final accent = colorScheme.primary;

    final isAdmin =
        auth.user?.role == 'Admin' || auth.user?.role == 'SuperAdmin';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            _buildHeader(
              state,
              isAdmin,
              isMobile,
              textPrimary,
              textSecondary,
              accent,
              border,
            ),
            // ── STAT CARDS ──
            _buildStatCards(state.stats, isMobile, textPrimary),
            // ── FILTER BAR ──
            _buildFilterBar(
              state,
              isMobile,
              surface,
              border,
              textPrimary,
              textSecondary,
              accent,
            ),
            // ── BULK ACTION BAR ──
            if (state.selectedIds.isNotEmpty) _buildBulkBar(state),
            // ── TABLE ──
            Expanded(
              child: _buildTable(
                state,
                isAdmin,
                screenWidth,
                surface,
                border,
                textPrimary,
                textSecondary,
                accent,
              ),
            ),
            if (state.filtered.isNotEmpty)
              CustomPagination(
                totalItems: state.filtered.length,
                pageSize: state.pageSize,
                currentPage: state.currentPage,
                onPageChanged: (p) =>
                    ref.read(attendanceRegisterProvider.notifier).setPage(p),
                onPageSizeChanged: (s) =>
                    ref.read(attendanceRegisterProvider.notifier).setPageSize(s),
              ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(
    _AttState state,
    bool isAdmin,
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    Color border,
  ) {
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => ref
              .read(navigationProvider.notifier)
              .setHRManagementContent(null),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.arrow_back, color: textSecondary, size: 20),
          ),
        ),
        Icon(Icons.calendar_month, color: accent, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Attendance Register',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${DateFormat('EEE, d MMM yyyy').format(state.selectedDate).toUpperCase()} • ${state.records.length} EMPLOYEES',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Inline buttons on tablet/desktop only
        if (!isMobile) ...[
          if (isAdmin) ...[
            _settingsBtn(textPrimary, border),
            const SizedBox(width: 8),
          ],
          _exportBtn(state, isMobile: false, border: border, textPrimary: textPrimary),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                const SizedBox(height: 10),
                // Buttons row below title on mobile
                Row(
                  children: [
                    if (isAdmin) ...[
                      Expanded(child: _settingsBtn(textPrimary, border)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _exportBtn(
                        state,
                        isMobile: true,
                        border: border,
                        textPrimary: textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : titleRow,
    );
  }

  bool _isSettingsOpen = false;

  void _showSettingsDialog() {
    if (_isSettingsOpen) return;
    _isSettingsOpen = true;

    ref.read(attendanceRegisterProvider.notifier).loadSettingsData();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const _LeaveTypeSettingsDialog(),
    ).then((_) => _isSettingsOpen = false);
  }

  Widget _settingsBtn(Color textPrimary, Color border) => OutlinedButton.icon(
    onPressed: () => _showSettingsDialog(),
    icon: const Icon(Icons.settings_outlined, size: 14),
    label: const Text(
      'Settings',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: textPrimary,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );

  Widget _exportBtn(
    _AttState state, {
    required bool isMobile,
    required Color border,
    required Color textPrimary,
  }) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      offset: const Offset(0, 40),
      onSelected: (type) {
        ref.read(attendanceRegisterProvider.notifier).exportData(context, type);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'excel',
          child: Text(
            'Excel Spreadsheet (.xlsx)',
            style: TextStyle(fontSize: 13, color: textPrimary),
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Text(
            'PDF Document (.pdf)',
            style: TextStyle(fontSize: 13, color: textPrimary),
          ),
        ),
      ],
      child: IgnorePointer(
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.download_outlined, size: 15),
          label: const Text(
            'Export Data',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF3B82F6),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: 8,
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── STAT CARDS ────────────────────────────────────────────
  Widget _buildStatCards(Map<String, int> s, bool isMobile, Color textPrimary) {
    final cards = [
      {
        'label': 'PRESENT',
        'val': s['present']!,
        'color': const Color(0xFF10B981),
        'bg': const Color(0x1410B981),
      },
      {
        'label': 'ABSENT',
        'val': s['absent']!,
        'color': const Color(0xFFEF4444),
        'bg': const Color(0x14EF4444),
      },
      {
        'label': 'ON LEAVE / HALF',
        'val': s['leave']!,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0x143B82F6),
      },
      {
        'label': 'UNMARKED',
        'val': s['unmarked']!,
        'color': const Color(0xFF94A3B8),
        'bg': const Color(0x1494A3B8),
      },
    ];

    Widget buildCard(Map<String, Object> c, {double? fixedWidth}) {
      final color = c['color'] as Color;
      final bg = c['bg'] as Color;
      return Container(
        width: fixedWidth,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c['val']}',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(Icons.people_outline, color: color, size: 14),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      // Horizontally scrollable cards on mobile
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cards.map((c) => buildCard(c, fixedWidth: 160)).toList(),
          ),
        ),
      );
    }

    // Side-by-side equal cards on desktop
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: cards.map((c) => Expanded(child: buildCard(c))).toList(),
      ),
    );
  }

  // ── FILTER BAR ────────────────────────────────────────────
  Widget _buildFilterBar(
    _AttState state,
    bool isMobile,
    Color surface,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Organization
          Icon(Icons.business_outlined, color: textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            'Organization',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: OrgDropdown(
              value: state.selectedOrgId?.toString(),
              items: state.organizations
                  .map(
                    (o) => OrgDropdownItem(
                      id: o['id'].toString(),
                      name: o['name'],
                    ),
                  )
                  .toList(),
              onChanged: (v) => ref
                  .read(attendanceRegisterProvider.notifier)
                  .setOrgId(int.parse(v!)),
              isCompact: true,
              showLabel: false,
            ),
          ),

          Container(
            width: 1,
            height: 28,
            color: border,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // Date picker
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: state.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: accent,
                      brightness: Theme.of(ctx).brightness,
                    ).copyWith(primary: accent),
                  ),
                  child: child!,
                ),
              );
              if (d != null)
                ref.read(attendanceRegisterProvider.notifier).setDate(d);
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF21262D)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: textSecondary,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd-MM-yyyy').format(state.selectedDate),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Search
          Container(
            width: 200,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF21262D)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextField(
              controller: _searchCtrl,
              textAlign: TextAlign.left,
              style: TextStyle(color: textPrimary, fontSize: 13),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: 'Search employee name or code...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: textSecondary, size: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                prefixIconConstraints: const BoxConstraints(minWidth: 28),
              ),
              onChanged: (v) => ref
                  .read(attendanceRegisterProvider.notifier)
                  .setSearch(v.trim()),
            ),
          ),
          const SizedBox(width: 8),

          // Dept filter
          Text(
            'Dept',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 4),
          _miniDropdown(
            value: state.deptFilter,
            items: ['', ...state.uniqueDepts],
            onChanged: (v) =>
                ref.read(attendanceRegisterProvider.notifier).setDept(v ?? ''),
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(width: 8),

          // Desig filter
          Text(
            'Desig',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 4),
          _miniDropdown(
            value: state.desigFilter,
            items: ['', ...state.uniqueDesigs],
            onChanged: (v) =>
                ref.read(attendanceRegisterProvider.notifier).setDesig(v ?? ''),
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        0,
        isMobile ? 16 : 24,
        10,
      ),
      child: isMobile
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar)
          : bar,
    );
  }

  Widget _miniDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF21262D)
          : Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      dropdownColor: surface,
      style: TextStyle(color: textPrimary, fontSize: 13),
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: textSecondary,
        size: 16,
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e.isEmpty ? 'All' : e,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );

  // ── BULK ACTION BAR ───────────────────────────────────────
  Widget _buildBulkBar(_AttState state) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${state.selectedIds.length} Selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.white30,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          _bulkBtn('FN Status', () => _showBulkMenu(context, state, 'FN')),
          const SizedBox(width: 6),
          _bulkBtn('AN Status', () => _showBulkMenu(context, state, 'AN')),
          const Spacer(),
          TextButton(
            onPressed: () =>
                ref.read(attendanceRegisterProvider.notifier).clearSelection(),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulkBtn(String label, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white24,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    child: Text(label),
  );

  void _showBulkMenu(BuildContext context, _AttState state, String field) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(const Offset(60, 140));
    _showStatusMenu(
      context,
      pos,
      state.leaveTypes,
      employeeId: -1,
      field: field,
      isBulk: true,
    );
  }

  // ── TABLE ─────────────────────────────────────────────────
  Widget _buildTable(
    _AttState state,
    bool isAdmin,
    double screenWidth,
    Color surface,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final rows = state.paginated;
    final isMobile = screenWidth < 600;

    Widget tableContent = Column(
      children: [
        // ── TABLE HEADER ──
        Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF21262D)
              : Colors.black.withOpacity(0.04),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _tableRow(
            isMobile: isMobile,
            checkbox: Checkbox(
              value: rows.isNotEmpty && state.selectedIds.length == rows.length,
              tristate:
                  state.selectedIds.isNotEmpty &&
                  state.selectedIds.length < rows.length,
              onChanged: (_) => ref
                  .read(attendanceRegisterProvider.notifier)
                  .toggleSelectAll(),
              side: BorderSide(color: textSecondary),
              fillColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? accent
                    : Colors.transparent,
              ),
            ),
            code: _th('CODE ↕', textSecondary),
            name: _th('NAME', textSecondary),
            fn: isMobile
                ? Center(
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      color: textSecondary,
                      size: 14,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: textSecondary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      _th('FIRST HALF', textSecondary),
                    ],
                  ),
            an: isMobile
                ? Center(
                    child: Icon(
                      Icons.wb_twilight_outlined,
                      color: textSecondary,
                      size: 14,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_twilight_outlined,
                        color: textSecondary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      _th('SECOND HALF', textSecondary),
                    ],
                  ),
            deptDesig: _th('DEPT / DESIGNATION', textSecondary),
            action: _th('ACTION', textSecondary),
          ),
        ),
        Divider(height: 1, color: border),
        // ── TABLE BODY ──
        Expanded(
          child: state.isLoading
              ? Center(child: CircularProgressIndicator(color: accent))
              : rows.isEmpty
                  ? Center(
                      child: Text(
                        'No matching employees found.',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: border.withOpacity(0.5)),
                      itemBuilder: (ctx, i) => _buildRow(
                        ctx,
                        rows[i],
                        state,
                        isAdmin,
                        isMobile,
                        textPrimary,
                        textSecondary,
                        accent,
                      ),
                    ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 24,
        0,
        isMobile ? 12 : 24,
        16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: tableContent,
        ),
      ),
    );
  }

  Widget _th(String text, Color textSecondary) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );

  Widget _buildRow(
    BuildContext ctx,
    AttendanceRecord rec,
    _AttState state,
    bool isAdmin,
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final theme = Theme.of(ctx);
    final isSelected = state.selectedIds.contains(rec.employeeId);
    return InkWell(
      onTap: () => ref
          .read(attendanceRegisterProvider.notifier)
          .toggleSelect(rec.employeeId),
      hoverColor: theme.hoverColor,
      child: Container(
        color: isSelected ? accent.withOpacity(0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: _tableRow(
          isMobile: isMobile,
          checkbox: Checkbox(
            value: isSelected,
            onChanged: (_) => ref
                .read(attendanceRegisterProvider.notifier)
                .toggleSelect(rec.employeeId),
            side: BorderSide(color: textSecondary),
            fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? accent
                  : Colors.transparent,
            ),
          ),
          code: Center(
            child: Text(
              rec.employeeCode,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          name: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isMobile ? 13 : 15,
                backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                backgroundImage: rec.profilePictureUrl != null
                    ? NetworkImage(
                        '${ApiConfig.serverUrl}${rec.profilePictureUrl}',
                      )
                    : null,
                child: rec.profilePictureUrl == null
                    ? Text(
                        rec.employeeName.isNotEmpty
                            ? rec.employeeName[0].toUpperCase()
                            : '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: isMobile ? 6 : 10),
              Flexible(
                child: Text(
                  rec.employeeName,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          fn: Center(
            child: Builder(
              builder: (btnCtx) => _statusBadge(
                context: ctx,
                code: rec.fn,
                onTap: isAdmin
                    ? () {
                        final box = btnCtx.findRenderObject() as RenderBox;
                        final pos = box.localToGlobal(
                          Offset(0, box.size.height),
                        );
                        _showStatusMenu(
                          ctx,
                          pos,
                          state.leaveTypes,
                          employeeId: rec.employeeId,
                          field: 'FN',
                        );
                      }
                    : () {},
              ),
            ),
          ),
          an: Center(
            child: Builder(
              builder: (btnCtx) => _statusBadge(
                context: ctx,
                code: rec.an,
                onTap: isAdmin
                    ? () {
                        final box = btnCtx.findRenderObject() as RenderBox;
                        final pos = box.localToGlobal(
                          Offset(0, box.size.height),
                        );
                        _showStatusMenu(
                          ctx,
                          pos,
                          state.leaveTypes,
                          employeeId: rec.employeeId,
                          field: 'AN',
                        );
                      }
                    : () {},
              ),
            ),
          ),
          // Hidden on mobile to save horizontal space
          deptDesig: isMobile
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rec.department ?? '—',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      rec.designation ?? 'Staff',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
          action: Center(
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }

  // ── SHARED ROW LAYOUT ─────────────────────────────────────
  Widget _tableRow({
    required Widget checkbox,
    required Widget code,
    required Widget name,
    required Widget fn,
    required Widget an,
    required Widget deptDesig,
    required Widget action,
    bool isMobile = false,
  }) {
    // Mobile: no DEPT column, smaller widths to fit ~390px screens
    // Desktop: full columns
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: 30, child: checkbox),
            SizedBox(width: 76, child: code),
            Expanded(child: name),
            SizedBox(width: 40, child: fn),
            SizedBox(width: 40, child: an),
            SizedBox(width: 46, child: action),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(width: 36, child: checkbox),
          SizedBox(width: 100, child: code),
          Expanded(child: name),
          SizedBox(width: 90, child: fn),
          SizedBox(width: 90, child: an),
          SizedBox(width: 140, child: deptDesig),
          SizedBox(width: 54, child: action),
        ],
      ),
    );
  }
}

class _LeaveTypeSettingsDialog extends ConsumerStatefulWidget {
  const _LeaveTypeSettingsDialog();
  @override
  ConsumerState<_LeaveTypeSettingsDialog> createState() =>
      _LeaveTypeSettingsDialogState();
}

class _LeaveTypeSettingsDialogState
    extends ConsumerState<_LeaveTypeSettingsDialog> {
  bool _isForm = false;
  int? _editingId;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isPaid = true;

  void _switchToForm([LeaveType? initial]) {
    setState(() {
      _isForm = true;
      _editingId = initial?.leaveTypeId;
      _nameCtrl.text = initial?.fullName ?? '';
      _codeCtrl.text = initial?.shortName ?? '';
      _isPaid = initial?.isPaid ?? true;
    });
  }

  void _switchToList() {
    setState(() {
      _isForm = false;
      _editingId = null;
      _nameCtrl.clear();
      _codeCtrl.clear();
      _isPaid = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceRegisterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = theme.colorScheme.surface;
    final border = isDark ? Colors.white.withOpacity(0.12) : theme.dividerColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final accent = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                if (_isForm)
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: textSecondary,
                    ),
                    onPressed: _switchToList,
                  ),
                Icon(
                  Icons.settings_outlined,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isForm
                            ? (_editingId == null
                                  ? 'Add New Status'
                                  : 'Edit Status')
                            : 'Status Settings',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'CONFIGURE ATTENDANCE LABELS',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isForm)
                  ElevatedButton.icon(
                    onPressed: () => _switchToForm(),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Flexible(
              child: _isForm
                  ? _buildFormView(theme, textPrimary, textSecondary, accent)
                  : _buildListView(state, surface, textPrimary, textSecondary, accent, border),
            ),

            if (!_isForm) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close Settings',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
    _AttState state,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    Color border,
  ) {
    if (state.isLoadingSettings) {
      return Center(
        child: CircularProgressIndicator(color: accent),
      );
    }

    if (state.allSettingsLeaveTypes.isEmpty) {
      return Center(
        child: Text(
          'No statuses configured.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: state.allSettingsLeaveTypes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final lt = state.allSettingsLeaveTypes[i];
        final color = _statusColor(lt.shortName);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lt.isShow
                ? Colors.transparent
                : textPrimary.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lt.fullName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'CODE: ${lt.shortName} • ${lt.isPaid ? "PAID" : "UNPAID"}',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: textSecondary,
                ),
                onPressed: () => _switchToForm(lt),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: surface,
                      surfaceTintColor: Colors.transparent,
                      title: Text(
                        'Delete status?',
                        style: TextStyle(color: textPrimary),
                      ),
                      content: Text(
                        'This will remove it from your organization settings.',
                        style: TextStyle(color: textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && lt.leaveTypeId != null) {
                    ref
                        .read(attendanceRegisterProvider.notifier)
                        .deleteLeaveType(context, lt.leaveTypeId!);
                  }
                },
              ),
              Transform.scale(
                scale: 0.5,
                child: Switch(
                  value: lt.isShow,
                  activeColor: accent,
                  activeTrackColor: accent.withOpacity(0.4),
                  inactiveThumbColor: textSecondary,
                  inactiveTrackColor: border,
                  onChanged: (val) {
                    if (lt.leaveTypeId != null) {
                      ref
                          .read(attendanceRegisterProvider.notifier)
                          .toggleLeaveTypeVisibility(
                            context,
                            lt.leaveTypeId!,
                            val,
                          );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormView(ThemeData theme, Color textPrimary, Color textSecondary, Color accent) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formLabel('Status Name *', textSecondary),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: _inputDecoration('e.g. Work From Home', theme, accent),
          ),
          const SizedBox(height: 20),
          _formLabel('Short Code (Max 4) *', textSecondary),
          TextField(
            controller: _codeCtrl,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLength: 4,
            decoration: _inputDecoration('WFH', theme, accent),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v ?? true),
                activeColor: accent,
              ),
              Text(
                'This is a Paid Leave / Status',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _switchToList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_nameCtrl.text.isEmpty || _codeCtrl.text.isEmpty)
                      return;
                    await ref
                        .read(attendanceRegisterProvider.notifier)
                        .saveLeaveType(
                          context,
                          leaveTypeId: _editingId,
                          fullName: _nameCtrl.text,
                          shortName: _codeCtrl.text.toUpperCase(),
                          isPaid: _isPaid,
                        );
                    _switchToList();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3B82F6)
                        : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text(
                    'Save Status',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String t, Color textSecondary) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint, ThemeData theme, Color accent) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF484F58)
          : Colors.grey.withOpacity(0.5),
    ),
    filled: true,
    fillColor: Colors.transparent,
    counterStyle: TextStyle(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF8B949E)
          : Colors.grey,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF30363D)
            : theme.dividerColor,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}
