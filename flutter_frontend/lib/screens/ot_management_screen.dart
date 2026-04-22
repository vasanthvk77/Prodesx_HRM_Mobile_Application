import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/ot_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_pagination.dart';
import '../core/api_config.dart';
import '../models/ot_model.dart';
import '../widgets/org_dropdown.dart';
import '../widgets/hrm_search_toolbar.dart';
import '../providers/auth_provider.dart';
import 'create_ot_modal.dart';

class OTManagementScreen extends ConsumerStatefulWidget {
  const OTManagementScreen({super.key});

  @override
  ConsumerState<OTManagementScreen> createState() => _OTManagementScreenState();
}

class _OTManagementScreenState extends ConsumerState<OTManagementScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(otProvider.notifier).init());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = theme.platform == TargetPlatform.iOS;

    final user = ref.watch(authProvider).user;
    final isAdminOrAbove = user?.role == 'Admin' || user?.role == 'SuperAdmin';

    // Premium Slate/Navy Theme
    final border = isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1);
    final accent = const Color(0xFF3182ce); // React primary
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
            // ── Premium Custom Header ───────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isIOS
                  ? (isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9))
                  : theme.cardColor,
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
                        'Employee OT Management',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900, // Extra bold
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (state.isLoading)
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

            // ── Desktop/Tablet Action Bar (Optional) ────────────────────
            if (isAdminOrAbove)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openModal(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add OT Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Premium Search Toolbar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HRMSearchToolbar(
                selectedOrgId: state.selectedOrgId?.toString(),
                orgItems: state.organizations.map((org) => OrgDropdownItem(
                  id: org['id'].toString(),
                  name: org['name'],
                  logoUrl: org['logoUrl'],
                )).toList(),
                onOrgChanged: (val) {
                  if (val != null) {
                    ref.read(otProvider.notifier).setOrgId(val);
                  }
                },
                onSearchChanged: (v) => ref.read(otProvider.notifier).setSearch(v),
                hintText: 'Search Name, ID or Remarks...',
                isOrgLoading: state.isLoading && state.organizations.isEmpty,
              ),
            ),

            const SizedBox(height: 8),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: state.isLoading && state.paginated.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                  : isDesktop 
                      ? _buildDesktopTable(state, theme, border, isDark, isAdminOrAbove)
                      : _buildMobileCards(state, theme, border, isDark, isAdminOrAbove),
            ),

            if (state.filtered.isNotEmpty)
              CustomPagination(
                totalItems: state.filtered.length,
                pageSize: state.pageSize,
                currentPage: state.currentPage,
                onPageChanged: (p) => ref.read(otProvider.notifier).setPage(p),
                onPageSizeChanged: (s) => ref.read(otProvider.notifier).setPageSize(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
  Widget _buildMobileCards(OTState state, ThemeData theme, Color border, bool isDark, bool isAdminOrAbove) {
    if (state.paginated.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No OT records found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.paginated.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = state.paginated[i];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: (r.profilePictureUrl != null && r.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(ApiConfig.getFullImageUrl(r.profilePictureUrl))
                        : null,
                    child: (r.profilePictureUrl == null || r.profilePictureUrl!.isEmpty)
                        ? Text(r.employeeName?[0] ?? '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.employeeName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          'ID: ${r.employeeCode ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (isAdminOrAbove) _buildActionMenu(context, r),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoBlock('DATE', DateFormat('dd-MMM-yy').format(r.overDutyDate), isDark),
                  _infoBlock('HOURS', r.hours.toString(), isDark, valueColor: Colors.blue.shade600),
                  _infoBlock('AMOUNT', '₹${NumberFormat('#,##,###').format(r.amount)}', isDark, valueColor: const Color(0xFF0d9488)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(OTState state, ThemeData theme, Color border, bool isDark, bool isAdminOrAbove) {
    if (state.paginated.isEmpty) return const Center(child: Text('No records found'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > 1000 ? constraints.maxWidth : 1000.0;

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Header Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        _headerCell(state, 'EMPLOYEE', 0, expanded: true, sortKey: 'employeeName'),
                        _headerCell(state, 'DATE', 150, sortKey: 'overDutyDate'),
                        _headerCell(state, 'HOURS', 120, align: Alignment.center, sortKey: 'hours'),
                        _headerCell(state, 'AMOUNT', 150, align: Alignment.centerRight, sortKey: 'amount'),
                        if (isAdminOrAbove)
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'ACTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: border),
                  // Body
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: state.paginated.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: border),
                      itemBuilder: (context, i) {
                        final r = state.paginated[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blue.shade50,
                                      backgroundImage: (r.profilePictureUrl != null && r.profilePictureUrl!.isNotEmpty)
                                          ? NetworkImage(ApiConfig.getFullImageUrl(r.profilePictureUrl))
                                          : null,
                                      child: (r.profilePictureUrl == null || r.profilePictureUrl!.isEmpty)
                                          ? Text(r.employeeName?[0] ?? '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.employeeName ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                          Text('ID: ${r.employeeCode ?? 'N/A'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(DateFormat('dd-MMM-yyyy').format(r.overDutyDate), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                              ),
                              Container(
                                width: 120,
                                alignment: Alignment.center,
                                child: Text(r.hours.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.blue.shade600)),
                              ),
                              Container(
                                width: 150,
                                alignment: Alignment.centerRight,
                                child: Text('₹${NumberFormat('#,##,###').format(r.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0d9488))),
                              ),
                              if (isAdminOrAbove)
                                SizedBox(
                                  width: 100,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _buildActionMenu(context, r),
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
          ),
        );
      },
    );
  }
  Widget _headerCell(OTState state, String label, double width, {bool expanded = false, Alignment align = Alignment.centerLeft, String? sortKey}) {
    final active = state.sortKey == sortKey;
    final widget = InkWell(
      onTap: sortKey != null ? () => ref.read(otProvider.notifier).setSort(sortKey) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        width: expanded ? null : width,
        alignment: align,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900, // Extra bold
                color: active ? Colors.blue.shade600 : const Color(0xFF475569),
                letterSpacing: 0.8,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                state.sortDirection == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: Colors.blue.shade600,
              ),
            ],
          ],
        ),
      ),
    );
    return expanded ? Expanded(child: widget) : widget;
  }

  Widget _dataCell(String text, double width, {FontWeight? fontWeight, Color? color}) {
    return Container(
      width: width,
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: fontWeight ?? FontWeight.w500, color: color),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context, OvertimeRecord r) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.iconTheme.color?.withOpacity(0.5), size: 20),
      color: theme.cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      offset: const Offset(0, 40),
      onSelected: (v) {
        if (v == 'edit') _openModal(context, editData: r);
        if (v == 'delete') _confirmDelete(context, r);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'edit',
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 12),
              const Text('Edit Entry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              const SizedBox(width: 12),
              const Text('Delete Entry', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  void _openModal(BuildContext context, {OvertimeRecord? editData}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: CreateOTModal(editData: editData),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, OvertimeRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete the OT entry for ${record.employeeName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(otProvider.notifier).deleteOT(record.overDutyId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
