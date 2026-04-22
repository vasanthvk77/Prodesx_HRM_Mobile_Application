import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/basic_pay_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';
import '../models/employee.dart';
import '../widgets/org_dropdown.dart';
import '../widgets/hrm_search_toolbar.dart';
import '../core/api_config.dart';

class BasicPayScreen extends ConsumerStatefulWidget {
  const BasicPayScreen({super.key});

  @override
  ConsumerState<BasicPayScreen> createState() => _BasicPayScreenState();
}

class _BasicPayScreenState extends ConsumerState<BasicPayScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  Map<String, dynamic>? _selectedRecord;
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(basicPayProvider.notifier).init());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _openDrawer(Map<String, dynamic> record) {
    setState(() {
      _selectedRecord = record;
      _amountController.text = (record['basicPay'] as double) > 0 
          ? (record['basicPay'] as double).toStringAsFixed(2) 
          : '';
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _handleSave() async {
    if (_selectedRecord == null || _amountController.text.isEmpty) {
      CustomSnackbar.show(context: context, message: 'Please enter a valid amount');
      return;
    }

    final amountStr = _amountController.text;
    final amount = double.tryParse(amountStr);
    if (amount == null) {
      CustomSnackbar.show(context: context, message: 'Invalid amount format');
      return;
    }

    setState(() => _isSaving = true);

    final Employee emp = _selectedRecord!['employee'];
    final success = await ref.read(basicPayProvider.notifier).saveBasicPay(employeeId: emp.id, amount: amount);

    setState(() => _isSaving = false);

    if (success && mounted) {
      CustomSnackbar.show(context: context, message: _selectedRecord!['isSet'] == true ? 'Basic pay updated' : 'Basic pay set');
      Navigator.of(context).pop(); // close drawer
    } else if (mounted) {
      CustomSnackbar.show(context: context, message: 'Failed to update basic pay');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(basicPayProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setHRManagementContent(null);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        endDrawer: _buildDrawer(state, theme, isDark),
        body: Column(
          children: [
            // ── HEADER ──
            _buildHeader(theme, isDark, state.employees.length),

            // ── FILTER BAR ──
            _buildFilterBar(state, theme, isDark),

            const SizedBox(height: 12),

            // ── TABLE ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: state.isLoading && state.employees.isEmpty
                    ? const Center(child: CircularProgressIndicator())
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

            if (state.filteredAndSorted.isNotEmpty)
              CustomPagination(
                totalItems: state.filteredAndSorted.length,
                pageSize: state.pageSize,
                currentPage: state.currentPage,
                onPageChanged: (p) => ref.read(basicPayProvider.notifier).setPage(p),
                onPageSizeChanged: (s) => ref.read(basicPayProvider.notifier).setPageSize(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (val) => onChanged(val as T),
          icon: const Icon(Icons.filter_list, size: 16),
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          hint: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark, int empCount) {
    final isIOS = theme.platform == TargetPlatform.iOS;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isIOS ? (isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)) : theme.cardColor,
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isIOS) ...[
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.back, size: 22),
                onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
              ),
              const SizedBox(width: 8),
            ] else ...[
              IconButton(
                icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: isDesktop 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Basic Pay',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CLICK ON AN EMPLOYEE ROW TO SET OR UPDATE THEIR BASE SALARY • $empCount MEMBERS',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Text(
                    'Basic Pay',
                    style: isIOS 
                        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                        : theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                  ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BasicPayState state, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: HRMSearchToolbar(
        selectedOrgId: state.selectedOrgId?.toString(),
        orgItems: state.organizations.map((org) => OrgDropdownItem(
          id: (org['id'] ?? org['Id'] ?? '').toString(),
          name: (org['name'] ?? org['Name'] ?? 'Unknown').toString(),
          logoUrl: (org['logoUrl'] ?? org['LogoUrl'])?.toString(),
        )).toList(),
        onOrgChanged: (val) {
          if (val != null) ref.read(basicPayProvider.notifier).setOrgId(val);
        },
        onSearchChanged: (val) {
          ref.read(basicPayProvider.notifier).setSearch(val);
        },
        hintText: 'Search employee name or code...',
        isOrgLoading: false,
        actions: [
          // Year Filter
          _buildCompactFilter(
            label: 'Salary Year',
            value: state.selectedYearId,
            items: state.years.map((y) => DropdownMenuItem(
              value: y.salaryYearId,
              child: Text('Year: ${y.fromYear}-${y.toYear}'),
            )).toList(),
            onChanged: (val) {
              if (val != null) ref.read(basicPayProvider.notifier).setYearId(val);
            },
          ),
          const SizedBox(width: 8),
          // Designation Filter
          _buildCompactFilter(
            label: 'All Designations',
            value: state.designationFilter,
            items: state.availableDesignations.map((d) => DropdownMenuItem(
              value: d,
              child: Text(d == 'All' ? 'All Designations' : d),
            )).toList(),
            onChanged: (val) {
              if (val != null) ref.read(basicPayProvider.notifier).setDesignation(val);
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => ref.read(basicPayProvider.notifier).loadData(),
            icon: const Icon(Icons.sync, size: 14),
            label: const Text('Sync', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: theme.textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BasicPayState state, ThemeData theme, bool isDark) {
    if (state.paginated.isEmpty) return const Center(child: Text('No employees found.'));
    final border = isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
            child: Row(
              children: [
                const SizedBox(width: 40),
                _headerCell('AVATAR', width: 60),
                _headerCell('EMPLOYEE', flex: 3, sortKey: 'name'),
                _headerCell('CODE', flex: 2),
                _headerCell('DESIGNATION', flex: 3),
                _headerCell('BASIC PAY', flex: 2, sortKey: 'basicPay', alignRight: true),
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
                final Employee emp = r['employee'];
                final bool isSet = r['isSet'];
                final double basicPay = r['basicPay'];

                return InkWell(
                  onTap: () => _openDrawer(r),
                  hoverColor: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Icon(Icons.check_box_outline_blank, size: 16, color: theme.dividerColor),
                        ),
                        SizedBox(
                          width: 60,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: isSet ? Colors.blue.withOpacity(0.1) : theme.dividerColor.withOpacity(0.2),
                            backgroundImage: emp.profilePictureUrl != null 
                              ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl)) 
                              : null,
                            child: emp.profilePictureUrl == null
                              ? Text(emp.name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSet ? Colors.blue : theme.textTheme.bodySmall?.color))
                              : null,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.dividerColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(emp.employeeCode ?? '--', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text((emp.designation ?? '').isNotEmpty ? emp.designation! : '--', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            isSet ? '₹${NumberFormat('#,##,##0.00').format(basicPay)}' : 'Not Set',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.w700,
                              color: isSet ? (isDark ? Colors.white : Colors.black) : theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileListView(BasicPayState state, ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.paginated.length,
      itemBuilder: (context, index) {
        final r = state.paginated[index];
        final Employee emp = r['employee'];
        final bool isSet = r['isSet'];
        final double basicPay = r['basicPay'];

        return Card(
          color: theme.cardTheme.color ?? theme.cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.5)),
          ),
          child: InkWell(
            onTap: () => _openDrawer(r),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isSet ? theme.colorScheme.primaryContainer : theme.dividerColor.withOpacity(0.2),
                    backgroundImage: emp.profilePictureUrl != null 
                        ? NetworkImage(ApiConfig.getFullImageUrl(emp.profilePictureUrl!)) 
                        : null,
                    child: emp.profilePictureUrl == null 
                        ? Text(
                            emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E', 
                            style: TextStyle(color: isSet ? theme.colorScheme.onPrimaryContainer : theme.textTheme.bodySmall?.color, fontSize: 16)
                          ) 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.name, 
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), 
                          overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp.employeeCode ?? '--'} • ${(emp.designation == null || emp.designation!.isEmpty) ? 'Staff' : emp.designation!}', 
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)), 
                          overflow: TextOverflow.ellipsis
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'BASIC PAY', 
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.textTheme.labelSmall?.color?.withOpacity(0.5), letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSet ? '₹${NumberFormat('#,##,##0.00').format(basicPay)}' : 'Not Set',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSet ? (isDark ? Colors.white : const Color(0xFF0F172A)) : theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String label, {int? flex, double? width, String? sortKey, bool alignRight = false}) {
    final state = ref.watch(basicPayProvider);
    final theme = Theme.of(context);
    final active = state.sortKey == sortKey;
    final widget = InkWell(
      onTap: sortKey != null ? () => ref.read(basicPayProvider.notifier).setSort(sortKey) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? Colors.blue : theme.textTheme.bodySmall?.color,
            letterSpacing: 1,
          )),
          if (sortKey != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 12, color: active ? Colors.blue : theme.iconTheme.color?.withOpacity(0.3)),
          ],
        ],
      ),
    );

    if (flex != null) return Expanded(flex: flex, child: widget);
    return SizedBox(width: width, child: widget);
  }

  Widget _buildDrawer(BasicPayState state, ThemeData theme, bool isDark) {
    if (_selectedRecord == null) return const SizedBox();
    final Employee emp = _selectedRecord!['employee'];
    final year = state.years.firstWhere((y) => y.salaryYearId == state.selectedYearId);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Set Basic Salary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2), style: BorderStyle.none), // dashed in react but none is cleaner in flutter without extra package
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue,
                      child: Text(emp.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${emp.employeeCode} • ${emp.designation}', style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                enabled: false,
                controller: TextEditingController(text: '${year.fromYear}-${year.toYear}'),
                decoration: InputDecoration(
                  labelText: 'Salary Year',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Basic Pay Amount',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text('SECURE TRANSACTION', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All salary modifications are tracked and audit-logged for financial compliance.',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Update Basic Pay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
