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
              color: isIOS ? (isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)) : theme.cardColor,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    if (isIOS) ...[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.back, size: 22),
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Employee OT Management',
                            style: isIOS 
                                ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                                : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Manage employee over duty records',
                            style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (state.isLoading) 
                      isIOS 
                          ? const CupertinoActivityIndicator()
                          : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                  ],
                ),
              ),
            ),

            // ── Desktop/Tablet Action Bar (Optional) ────────────────────
            if (isAdminOrAbove)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    isIOS 
                        ? CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minSize: 0,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () => _openModal(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.add, size: 18),
                                const SizedBox(width: 8),
                                Text('Add OT Entry', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _openModal(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add OT Entry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  : _buildDataTable(state, theme, border, isDark, isAdminOrAbove),
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

Widget _infoBlock(String label, String value, {Color? valueColor}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: valueColor ?? Colors.white,
        ),
      ),
    ],
  );
}
Widget _buildDataTable(OTState state, ThemeData theme, Color border, bool isDark, bool isAdminOrAbove) {
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    itemCount: state.paginated.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (context, i) {
      final r = state.paginated[i];

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // 🔹 Top Row (Profile + Name + Action)
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (r.profilePictureUrl != null && r.profilePictureUrl!.isNotEmpty)
                      ? NetworkImage(ApiConfig.getFullImageUrl(r.profilePictureUrl))
                      : null,
                  child: (r.profilePictureUrl == null || r.profilePictureUrl!.isEmpty)
                      ? Text(r.employeeName?[0] ?? '?', style: const TextStyle(fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.employeeName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${r.employeeCode ?? 'N/A'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                if (isAdminOrAbove)
                  _buildActionMenu(context, r),
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoBlock(
                  'Date',
                  DateFormat('dd-MM-yyyy').format(r.overDutyDate),
                ),
                _infoBlock(
                  'Hours',
                  r.hours.toString(),
                  valueColor: const Color(0xFF3182ce),
                ),
                _infoBlock(
                  'Amount',
                  '₹${NumberFormat('#,##,###').format(r.amount)}',
                  valueColor: const Color(0xFF0d9488),
                ),
              ],
            ),
          ],
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
                fontWeight: FontWeight.w800,
                color: active ? const Color(0xFF3182ce) : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                state.sortDirection == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: const Color(0xFF3182ce),
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
      onSelected: (v) {
        if (v == 'edit') _openModal(context, editData: r);
        if (v == 'delete') _confirmDelete(context, r);
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit Entry', style: TextStyle(fontSize: 13))),
        const PopupMenuItem(value: 'delete', child: Text('Delete Entry', style: TextStyle(fontSize: 13, color: Colors.red))),
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
