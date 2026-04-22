import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/calendar_settings.dart';
import '../models/salary_year.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/org_dropdown.dart';
import '../core/api_config.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends ConsumerState<CalendarSettingsScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  // Drawer state
  String _drawerMode = 'policy'; // 'policy' or 'year'
  SalaryYear? _editingYear;
  bool _isSaving = false;

  // Policy Form Controllers
  int _acStartMonth = 4;
  final _acStartDay = TextEditingController(text: '1');
  int _acEndMonth = 3;
  final _acEndDay = TextEditingController(text: '31');
  final _salStartDay = TextEditingController(text: '1');
  final _salEndDay = TextEditingController(text: '30');

  // Year Form Controllers
  final _fromYear = TextEditingController();
  final _toYear = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(calendarSettingsProvider.notifier).init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _acStartDay.dispose();
    _acEndDay.dispose();
    _salStartDay.dispose();
    _salEndDay.dispose();
    _fromYear.dispose();
    _toYear.dispose();
    super.dispose();
  }

  String _monthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if (m >= 1 && m <= 12) return months[m - 1];
    return m.toString();
  }

  void _openPolicyDrawer(CalendarSettings? current) {
    setState(() {
      _drawerMode = 'policy';
      _acStartMonth = current?.academicStartMonth ?? 4;
      _acStartDay.text = (current?.academicStartDay ?? 1).toString();
      _acEndMonth = current?.academicEndMonth ?? 3;
      _acEndDay.text = (current?.academicEndDay ?? 31).toString();
      _salStartDay.text = (current?.salaryStartDay ?? 1).toString();
      _salEndDay.text = (current?.salaryEndDay ?? 30).toString();
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openYearDrawer(SalaryYear? year) {
    setState(() {
      _drawerMode = 'year';
      _editingYear = year;
      if (year != null) {
        _fromYear.text = year.fromYear;
        _toYear.text = year.toYear;
        _dateFrom = year.dateFrom;
        _dateTo = year.dateTo;
      } else {
        final currentYear = DateTime.now().year;
        _fromYear.text = currentYear.toString();
        _toYear.text = (currentYear + 1).toString();
        _dateFrom = null;
        _dateTo = null;
      }
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final state = ref.read(calendarSettingsProvider);
    final orgId = int.tryParse(state.selectedOrgId.toString()) ?? 0;

    try {
      if (_drawerMode == 'policy') {
        final policy = CalendarSettings(
          organizationId: orgId,
          academicStartMonth: _acStartMonth,
          academicStartDay: int.tryParse(_acStartDay.text) ?? 1,
          academicEndMonth: _acEndMonth,
          academicEndDay: int.tryParse(_acEndDay.text) ?? 31,
          salaryStartDay: int.tryParse(_salStartDay.text) ?? 1,
          salaryEndDay: int.tryParse(_salEndDay.text) ?? 30,
        );
        final success = await ref.read(calendarSettingsProvider.notifier).savePolicy(policy);
        if (success && mounted) {
          CustomSnackbar.show(context: context, message: 'Calendar policy saved');
          Navigator.of(context).pop();
        }
      } else {
        if (_dateFrom == null || _dateTo == null) {
          CustomSnackbar.show(context: context, message: 'Please select valid dates');
          setState(() => _isSaving = false);
          return;
        }

        final year = SalaryYear(
          salaryYearId: _editingYear?.salaryYearId ?? 0,
          organizationID: orgId,
          fromYear: _fromYear.text,
          toYear: _toYear.text,
          dateFrom: _dateFrom!,
          dateTo: _dateTo!,
          createdBy: 0,
          createdDate: DateTime.now(),
        );

        final success = await ref.read(calendarSettingsProvider.notifier).saveYear(year, isUpdate: _editingYear != null);
        if (success && mounted) {
          CustomSnackbar.show(context: context, message: 'Salary year saved');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) CustomSnackbar.show(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteYear(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Delete this Salary Year record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      final success = await ref.read(calendarSettingsProvider.notifier).deleteYear(id);
      if (success && mounted) {
        CustomSnackbar.show(context: context, message: 'Deleted successfully');
      } else if (mounted) {
        CustomSnackbar.show(context: context, message: 'Failed to delete');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarSettingsProvider);
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
            // Top App Bar like setup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.platform == TargetPlatform.iOS ? (isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)) : theme.cardColor,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    if (theme.platform == TargetPlatform.iOS)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.back, size: 22),
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      )
                    else 
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                        onPressed: () => ref.read(navigationProvider.notifier).setHRManagementContent(null),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.business, color: Color(0xFF6366F1), size: 26),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Organization',
                      style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                     state.organizations.length == 1
                      ? Chip(
                          label: Text(state.organizations[0]['name'], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          visualDensity: VisualDensity.compact,
                        )
                      : OrgDropdown(
                          value: state.selectedOrgId?.toString(),
                          items: state.organizations.map((org) => OrgDropdownItem(
                            id: org['id'].toString(),
                            name: org['name'].toString(),
                            logoUrl: org['logo']?.toString(),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) ref.read(calendarSettingsProvider.notifier).setOrgId(val);
                          },
                        ),
                  ],
                ),
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Calendar Policy'),
                Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Salary Year'),
              ],
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPolicyTab(state, theme, isDark),
                  _buildSalaryYearTab(state, theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTab(CalendarSettingsState state, ThemeData theme, bool isDark) {
    if (state.isLoading && state.policy == null) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payroll & Calendar Policy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 4),
                    Text('Global settings for financial year and payroll cycles', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openPolicyDrawer(state.policy),
                icon: Icon(state.policy == null ? Icons.add : Icons.edit, size: 16),
                label: Text(state.policy == null ? 'Initial Configuration' : 'Configure Policy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: state.policy == null ? Colors.white : Colors.blue,
                  backgroundColor: state.policy == null ? Colors.blue : Colors.transparent,
                  side: BorderSide(color: Colors.blue),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          
          if (state.policy == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Text('No policy configured.', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                
                if (isMobile) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: Colors.red.shade100, radius: 16, child: Icon(Icons.event_available, color: Colors.red.shade700, size: 16)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Standard Calendar Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  Text('Global Organization Default', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Financial Year', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                            Text('${_monthName(state.policy!.academicStartMonth)} ${state.policy!.academicStartDay} - ${_monthName(state.policy!.academicEndMonth)} ${state.policy!.academicEndDay}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payroll Cycle', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                            Chip(
                              label: Text('${state.policy!.salaryStartDay}st - ${state.policy!.salaryEndDay}th Day', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Status', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                            Chip(
                              label: const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                              backgroundColor: Colors.green.withOpacity(0.1),
                              side: const BorderSide(color: Colors.green),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(1)},
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50),
                        children: [
                          _th('CONFIGURATION', theme),
                          _th('FINANCIAL YEAR', theme),
                          _th('PAYROLL CYCLE', theme),
                          _th('STATUS', theme, alignRight: true),
                        ],
                      ),
                      TableRow(
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: Colors.red.shade100, radius: 16, child: Icon(Icons.event_available, color: Colors.red.shade700, size: 16)),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Standard Calendar Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    Text('Global Organization Default', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('${_monthName(state.policy!.academicStartMonth)} ${state.policy!.academicStartDay} - ${_monthName(state.policy!.academicEndMonth)} ${state.policy!.academicEndDay}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                label: Text('${state.policy!.salaryStartDay}st - ${state.policy!.salaryEndDay}th Day', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                                backgroundColor: Colors.blue.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Chip(
                                label: const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                backgroundColor: Colors.green.withOpacity(0.1),
                                side: const BorderSide(color: Colors.green),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryYearTab(CalendarSettingsState state, ThemeData theme, bool isDark) {
    if (state.isLoading && state.salaryYears.isEmpty) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: theme.iconTheme.color?.withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search Salary Year (e.g. 2024)',
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => ref.read(calendarSettingsProvider.notifier).setSearchTerm(v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openYearDrawer(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Salary Year'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;

                if (isMobile) {
                  return state.filteredYears.isEmpty
                      ? const Center(child: Text('No Salary Years found.'))
                      : ListView.separated(
                          itemCount: state.filteredYears.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final y = state.filteredYears[i];
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        radius: 16,
                                        child: Text(
                                          y.fromYear.length >= 2 ? y.fromYear.substring(y.fromYear.length - 2) : y.fromYear,
                                          style: const TextStyle(fontSize: 12, color: Colors.white)
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text('${y.fromYear} - ${y.toYear}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                      Row(
                                        children: [
                                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _openYearDrawer(y), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                          const SizedBox(width: 12),
                                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _handleDeleteYear(y.salaryYearId), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Date From', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                                      Text(DateFormat('dd MMM yyyy').format(y.dateFrom), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Date To', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                                      Text(DateFormat('dd MMM yyyy').format(y.dateTo), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Status', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                                      Chip(
                                        label: const Text('Configured', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                                        backgroundColor: Colors.blue.withOpacity(0.1),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: constraints.maxWidth < 800 ? 800 : constraints.maxWidth,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                          child: Row(
                            children: [
                              _thFlat('YEAR PERIOD', theme, flex: 2),
                              _thFlat('DATE FROM', theme, flex: 2),
                              _thFlat('DATE TO', theme, flex: 2),
                              _thFlat('STATUS', theme, flex: 1),
                              _thFlat('ACTION', theme, flex: 1, alignRight: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: state.filteredYears.isEmpty
                              ? const Center(child: Text('No Salary Years found.'))
                              : ListView.separated(
                                  itemCount: state.filteredYears.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final y = state.filteredYears[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: Colors.blue,
                                                    radius: 16,
                                                    child: Text(y.fromYear.length >= 2 ? y.fromYear.substring(y.fromYear.length - 2) : y.fromYear, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text('${y.fromYear} - ${y.toYear}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(DateFormat('dd MMM yyyy').format(y.dateFrom), style: const TextStyle(fontSize: 13)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(DateFormat('dd MMM yyyy').format(y.dateTo), style: const TextStyle(fontSize: 13)),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Chip(
                                                label: const Text('Configured', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                                                backgroundColor: Colors.blue.withOpacity(0.1),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton(onPressed: () => _openYearDrawer(y), child: const Text('Edit')),
                                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _handleDeleteYear(y.salaryYearId)),
                                                ],
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
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _th(String label, ThemeData theme, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(label, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color)),
    );
  }

  Widget _thFlat(String label, ThemeData theme, {int flex = 1, bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(label, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color)),
      ),
    );
  }

  Widget _buildDrawer(CalendarSettingsState state, ThemeData theme, bool isDark) {
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
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.red, radius: 18, child: Icon(_drawerMode == 'policy' ? Icons.settings : Icons.event_available, color: Colors.white, size: 18)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_drawerMode == 'policy' ? 'Policy Config' : (_editingYear != null ? 'Edit Salary Year' : 'New Salary Year'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Organization', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ],
                      )
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _drawerMode == 'policy' ? _buildPolicyForm(theme, isDark) : _buildYearForm(theme, isDark),
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? 'Saving...' : (_drawerMode == 'policy' && state.policy != null ? 'Save Changes' : 'Create Entry')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyForm(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financial Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _dropdown('Start Month', _acStartMonth, (v) => setState(() => _acStartMonth = v!), List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_monthName(m)))).toList(), isDark),
            ),
            const SizedBox(width: 16),
            Expanded(child: _textField('Start Day', _acStartDay, isDark, type: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _dropdown('End Month', _acEndMonth, (v) => setState(() => _acEndMonth = v!), List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_monthName(m)))).toList(), isDark),
            ),
            const SizedBox(width: 16),
            Expanded(child: _textField('End Day', _acEndDay, isDark, type: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Payroll Cycle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _textField('Cycle Start Day', _salStartDay, isDark, type: TextInputType.number)),
            const SizedBox(width: 16),
            Expanded(child: _textField('Cycle End Day', _salEndDay, isDark, type: TextInputType.number)),
          ],
        ),
      ],
    );
  }

  Widget _buildYearForm(ThemeData theme, bool isDark) {
    void handleStartDate(DateTime? d) {
      if (d == null) return;
      setState(() {
        _dateFrom = d;
        _fromYear.text = d.year.toString();
        // Auto end date
        var end = DateTime(d.year + 1, d.month, d.day).subtract(const Duration(days: 1));
        _dateTo = end;
        _toYear.text = end.year.toString();
      });
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _textField('From Year', _fromYear, isDark)),
            const SizedBox(width: 16),
            Expanded(child: _textField('To Year', _toYear, isDark)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _dateField('Start Date', _dateFrom, (d) => handleStartDate(d), isDark)),
            const SizedBox(width: 16),
            Expanded(child: _dateField('End Date', _dateTo, (d) => setState(() => _dateTo = d), isDark)),
          ],
        ),
      ],
    );
  }

  Widget _textField(String label, TextEditingController controller, bool isDark, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>(String label, T value, void Function(T?) onChanged, List<DropdownMenuItem<T>> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, void Function(DateTime?) onChanged, bool isDark) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) onChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(value), style: TextStyle(color: value == null ? theme.textTheme.bodySmall?.color : null)),
                Icon(Icons.calendar_today, size: 16, color: theme.iconTheme.color?.withOpacity(0.5)),
              ],
            ),
          ),
        )
      ],
    );
  }
}
