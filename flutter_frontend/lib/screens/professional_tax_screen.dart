import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/professional_tax_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/hrm_search_toolbar.dart';
import '../widgets/org_dropdown.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';
import 'create_professional_tax_modal.dart';

class ProfessionalTaxScreen extends ConsumerStatefulWidget {
  const ProfessionalTaxScreen({super.key});

  @override
  ConsumerState<ProfessionalTaxScreen> createState() =>
      _ProfessionalTaxScreenState();
}

class _ProfessionalTaxScreenState extends ConsumerState<ProfessionalTaxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(professionalTaxProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(professionalTaxProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = 'Tax Slabs Configuration';

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
                        title,
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

            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HRMSearchToolbar(
                selectedOrgId: state.selectedOrgId?.toString(),
                orgItems: state.organizations
                    .map((org) => OrgDropdownItem(
                          id: org['id'].toString(),
                          name: org['name'],
                          logoUrl: org['logoUrl'],
                        ))
                    .toList(),
                onOrgChanged: (val) {
                  if (val != null) {
                    ref.read(professionalTaxProvider.notifier).setOrgId(val);
                  }
                },
                onSearchChanged: (v) =>
                    ref.read(professionalTaxProvider.notifier).setSearch(v),
                hintText: 'Search tax entries...',
                isOrgLoading: state.isLoading && state.organizations.isEmpty,
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openModal(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Tax Entry'),
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

            const SizedBox(height: 12),

            // ── MAIN CONTENT ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: state.isLoading && state.paginated.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.filtered.isEmpty
                        ? const Center(child: Text('No tax entries found'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 900) {
                                return _buildMobileListView(state, theme, isDark);
                              }
                              return _buildDesktopTable(state, theme, isDark);
                            },
                          ),
              ),
            ),

            if (state.filtered.isNotEmpty)
              CustomPagination(
                totalItems: state.filtered.length,
                pageSize: state.pageSize,
                currentPage: state.currentPage,
                onPageChanged:
                    (p) =>
                        ref.read(professionalTaxProvider.notifier).setPage(p),
                onPageSizeChanged:
                    (s) => ref
                        .read(professionalTaxProvider.notifier)
                        .setPageSize(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(ProfessionalTaxState state, ThemeData theme, bool isDark) {
    if (state.paginated.isEmpty) return const Center(child: Text('No records found'));
    final border = isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 40),
                _headerCell('Tax Heading', flex: 4, sortKey: 'taxName'),
                _headerCell('Basic Range', flex: 4, sortKey: 'fromAmount'),
                _headerCell('Tax Amount', flex: 2, sortKey: 'taxAmount'),
                _headerCell('Status', width: 100),
                const SizedBox(
                  width: 60,
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
              itemCount: state.paginated.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (context, index) {
                final r = state.paginated[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 4,
                        child: Text(
                          r.taxName,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '₹${NumberFormat('#,##,###').format(r.fromAmount)} — ₹${NumberFormat('#,##,###').format(r.toAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${NumberFormat('#,##,###').format(r.taxAmount)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: r.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            r.isActive ? 'Active' : 'Disabled',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.isActive ? Colors.green : Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: _buildActionMenu(context, r),
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

  Widget _buildMobileListView(ProfessionalTaxState state, ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.paginated.length,
      itemBuilder: (context, i) {
        final r = state.paginated[i];
        return Card(
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.taxName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Basic: ₹${NumberFormat('#,##,###').format(r.fromAmount)} — ₹${NumberFormat('#,##,###').format(r.toAmount)}', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('Tax Amount: ₹${NumberFormat('#,##,###').format(r.taxAmount)}', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                _buildActionMenu(context, r),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String label, {int? flex, double? width, String? sortKey}) {
    final state = ref.watch(professionalTaxProvider);
    final theme = Theme.of(context);
    final active = state.sortKey == sortKey;
    final widget = InkWell(
      onTap: sortKey != null ? () => ref.read(professionalTaxProvider.notifier).setSort(sortKey) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900, // Extra bold
            color: active ? Colors.blue.shade600 : const Color(0xFF475569),
            letterSpacing: 0.8,
          )),
          if (sortKey != null) ...[
            const SizedBox(width: 4),
            Icon(active ? (state.sortDirection == 'asc' ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
              size: 12, color: active ? Colors.blue.shade600 : theme.iconTheme.color?.withOpacity(0.3)),
          ],
        ],
      ),
    );

    if (flex != null) return Expanded(flex: flex, child: widget);
    return SizedBox(width: width, child: widget);
  }

  Widget _buildActionMenu(BuildContext context, dynamic r) {
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
              const Text('Edit Entry'),
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
              const Text('Remove Entry', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  void _openModal(BuildContext context, {dynamic editData}) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: CreateProfessionalTaxModal(editData: editData),
            ),
          ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic record) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: Text(
              'Are you sure you want to delete the tax entry ${record.taxName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success =
                      await ref
                          .read(professionalTaxProvider.notifier)
                          .deleteSlab(record.ptId);
                  if (success && mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Tax slab deleted',
                    );
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
