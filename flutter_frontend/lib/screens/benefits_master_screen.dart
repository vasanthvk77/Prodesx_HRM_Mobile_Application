import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'benefits_screen.dart';
import '../models/benefit_models.dart';
import '../providers/benefits_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_pagination.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/hrm_search_toolbar.dart';
import '../repositories/auth_repository.dart';
import '../widgets/org_dropdown.dart';
import '../providers/auth_provider.dart';

class BenefitsMasterScreen extends ConsumerStatefulWidget {
  final BenefitCategory category;

  const BenefitsMasterScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<BenefitsMasterScreen> createState() => _BenefitsMasterScreenState();
}

class _BenefitsMasterScreenState extends ConsumerState<BenefitsMasterScreen> {
  final AuthRepository _authRepository = AuthRepository();
  String _searchQuery = '';
  List<OrgDropdownItem> _organizations = [];
  
  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final orgs = await _authRepository.getUserOrganizations();
      setState(() {
        _organizations = orgs.map((o) => OrgDropdownItem(
          id: (o['id'] ?? o['Id'] ?? '').toString(),
          name: o['name'] ?? o['Name'] ?? 'Unknown',
          logoUrl: o['logoUrl'] ?? o['LogoUrl'],
        )).toList();
      });

      // Synchronize initial organization with Provider if not set
      final provider = widget.category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
      final state = ref.read(provider);
      if (state.organizationId == null) {
        final userData = await _authRepository.getCurrentUser();
        if (userData != null && userData['organizationId'] != null) {
          ref.read(provider.notifier).setOrganization(userData['organizationId']);
        }
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = theme.platform == TargetPlatform.iOS;
    
    final provider = widget.category == BenefitCategory.allowance 
        ? allowancesProvider 
        : deductionsProvider;
    
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    // Filter logic
    final filteredList = state.masterTypes.where((b) {
      return b.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             b.shortName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Pagination logic
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > filteredList.length 
        ? filteredList.length 
        : (startIndex + _pageSize);
    
    final paginatedList = startIndex >= filteredList.length 
        ? <BenefitType>[] 
        : filteredList.sublist(startIndex, endIndex);

    final title = widget.category == BenefitCategory.allowance ? 'Allowance Types' : 'Deduction Types';
    final primaryColor = widget.category == BenefitCategory.allowance ? Colors.blue : Colors.red;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen());
      },
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Header
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
                        onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen()),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 20),
                        onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(const BenefitsScreen()),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: isIOS 
                            ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                            : theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900, // Extra bold
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                      ),
                    ),
                    if (state.isLoading) 
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),

            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HRMSearchToolbar(
                selectedOrgId: state.organizationId?.toString(),
                orgItems: _organizations,
                onOrgChanged: (id) {
                  if (id != null) {
                    notifier.setOrganization(int.parse(id));
                  }
                },
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                hintText: 'Search types...',
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  isIOS 
                      ? CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          minSize: 0,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _showBenefitForm(context, null, widget.category),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.add, size: 18),
                              const SizedBox(width: 8),
                              Text('Add ${widget.category.name.capitalize()}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _showBenefitForm(context, null, widget.category),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Add ${widget.category.name.capitalize()}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600, // Designation Standard Blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                  if (widget.category == BenefitCategory.deduction) ...[
                    const SizedBox(width: 12),
                    isIOS
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            minSize: 0,
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.amber.shade700,
                            onPressed: () => _showStatutorySettingsDrawer(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.settings, size: 18),
                                SizedBox(width: 8),
                                Text('Statutory Settings', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _showStatutorySettingsDrawer(context),
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Statutory Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: state.isLoading && state.masterTypes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredList.isEmpty
                        ? const Center(child: Text('No types found'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                        if (constraints.maxWidth < 900) {
                          return _buildMobileList(paginatedList, theme, primaryColor);
                        }
                        return _buildDesktopTable(paginatedList, theme, primaryColor);
                            },
                          ),
              ),
            ),

            // Pagination
            if (filteredList.isNotEmpty)
              CustomPagination(
                totalItems: filteredList.length,
                pageSize: _pageSize,
                currentPage: _currentPage,
                onPageChanged: (page) => setState(() => _currentPage = page),
                onPageSizeChanged: (size) => setState(() {
                  _pageSize = size;
                  _currentPage = 1;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<BenefitType> list, ThemeData theme, Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isDark = theme.brightness == Brightness.dark;
        return Card(
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Text(item.shortName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Code: ${item.shortName}'),
            trailing: _buildActionMenu(item, theme),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<BenefitType> list, ThemeData theme, Color primaryColor) {
    final isDark = theme.brightness == Brightness.dark;
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
                Expanded(flex: 3, child: _buildSortableHeader('NAME', theme)),
                Expanded(flex: 2, child: _buildSortableHeader('SHORT NAME', theme)),
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
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (context, index) {
                final item = list[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(flex: 3, child: Text(item.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
                      Expanded(flex: 2, child: Text(item.shortName, style: theme.textTheme.bodyMedium)),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionMenu(item, theme),
                          ],
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

  Widget _buildSortableHeader(String title, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900, // Extra bold
          color: const Color(0xFF475569), // Darker text
          letterSpacing: 0.8,
        )),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more, color: theme.iconTheme.color?.withOpacity(0.3), size: 14),
      ],
    );
  }

  Widget _buildActionMenu(BenefitType item, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.iconTheme.color?.withOpacity(0.5), size: 18),
      color: theme.cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      offset: const Offset(0, 40),
      onSelected: (val) {
        if (val == 'edit') _showBenefitForm(context, item, widget.category);
        if (val == 'delete') _handleDelete(item);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 18), const SizedBox(width: 12), const Text('Edit Type')]),
        ),
        PopupMenuItem(
          value: 'delete',
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), const SizedBox(width: 12), const Text('Delete Type')]),
        ),
      ],
    );
  }

  Future<void> _handleDelete(BenefitType item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${item.fullName}? All staff assignments for this ${widget.category.name} will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = widget.category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
        await ref.read(provider.notifier).deleteMasterType(item.id);
        CustomSnackbar.show(context: context, message: 'Deleted successfully');
      } catch (e) {
        CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
      }
    }
  }

  void _showBenefitForm(BuildContext context, BenefitType? editData, BenefitCategory category) {
    final fullNameController = TextEditingController(text: editData?.fullName);
    final shortNameController = TextEditingController(text: editData?.shortName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editData == null ? 'Add ${category.name.capitalize()}' : 'Edit ${category.name.capitalize()}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fullNameController,
                decoration: InputDecoration(
                  labelText: category == BenefitCategory.allowance ? 'Allowance Name *' : 'Deduction Name *',
                  hintText: category == BenefitCategory.allowance ? 'e.g. House Rent Allowance' : 'e.g. Employee Provident Fund',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText: 'Short Code *',
                  hintText: category == BenefitCategory.allowance ? 'e.g. HRA' : 'e.g. EPF',
                  helperText: 'Max 10 characters — appears on payroll slips',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final provider = category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
                  if (editData == null) {
                    await ref.read(provider.notifier).saveMasterType(fullNameController.text, shortNameController.text);
                  } else {
                    final updated = BenefitType(
                      id: editData.id,
                      organizationId: editData.organizationId,
                      fullName: fullNameController.text,
                      shortName: shortNameController.text,
                      category: category,
                    );
                    await ref.read(provider.notifier).updateMasterType(updated);
                  }
                  Navigator.pop(context);
                  CustomSnackbar.show(context: context, message: 'Saved successfully');
                } catch (e) {
                  CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStatutorySettingsDrawer(BuildContext context) {
    final provider = deductionsProvider;
    final state = ref.read(provider);
    final notifier = ref.read(provider.notifier);
    final auth = ref.read(authProvider);
    final isSuperAdmin = auth.user?.role == 'SuperAdmin';
    
    // Default values if settings not loaded yet
    final settings = state.statutorySettings;
    
    final pfActive = ValueNotifier<bool>(settings?.isPFActive ?? false);
    final esiActive = ValueNotifier<bool>(settings?.isESIActive ?? false);
    
    final pfPercentController = TextEditingController(text: (settings?.pfPercentage ?? 12.0).toString());
    final pfCapController = TextEditingController(text: (settings?.pfCapAmount ?? 15000.0).toString());
    final esiPercentController = TextEditingController(text: (settings?.esiPercentage ?? 0.75).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Statutory settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PF Section
                    _buildStatutorySection(
                      context: context,
                      title: 'Provident Fund (PF)',
                      icon: Icons.shield_outlined,
                      color: Colors.blue,
                      isActive: pfActive,
                      isSuperAdmin: isSuperAdmin,
                      percentageController: pfPercentController,
                      capController: pfCapController,
                      showCap: true,
                    ),
                    const SizedBox(height: 24),
                    // ESI Section
                    _buildStatutorySection(
                      context: context,
                      title: 'Employee State Insurance (ESI)',
                      icon: Icons.flash_on_outlined,
                      color: Colors.green,
                      isActive: esiActive,
                      isSuperAdmin: isSuperAdmin,
                      percentageController: esiPercentController,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final updatedSettings = StatutorySettings(
                        organizationId: state.organizationId ?? 0,
                        isPFActive: pfActive.value,
                        isESIActive: esiActive.value,
                        pfPercentage: double.tryParse(pfPercentController.text) ?? 12.0,
                        pfCapAmount: double.tryParse(pfCapController.text) ?? 15000.0,
                        esiPercentage: double.tryParse(esiPercentController.text) ?? 0.75,
                      );
                      await notifier.updateStatutorySettings(updatedSettings);
                      Navigator.pop(context);
                      CustomSnackbar.show(context: context, message: 'Settings updated successfully');
                    } catch (e) {
                      CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutorySection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required ValueNotifier<bool> isActive,
    required bool isSuperAdmin,
    required TextEditingController percentageController,
    TextEditingController? capController,
    bool showCap = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              ValueListenableBuilder<bool>(
                valueListenable: isActive,
                builder: (context, value, _) => Switch.adaptive(
                  value: value,
                  activeColor: color,
                  onChanged: (val) => isActive.value = val,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Percentage (%)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: percentageController,
                      enabled: isSuperAdmin,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        fillColor: isSuperAdmin ? null : Colors.grey.withOpacity(0.1),
                        filled: !isSuperAdmin,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCap) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statutory Cap (₹)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: capController,
                        enabled: isSuperAdmin,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          fillColor: isSuperAdmin ? null : Colors.grey.withOpacity(0.1),
                          filled: !isSuperAdmin,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!isSuperAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Rates can only be modified by SuperAdmin',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
