import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../widgets/digital_clock.dart';
import 'benefits_master_screen.dart';
import 'benefit_assignment_screen.dart';
import '../models/benefit_models.dart';

class BenefitsScreen extends ConsumerWidget {
  const BenefitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).setDashboardContent(null);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // Unified Header
            Row(
              children: [
                if (MediaQuery.of(context).size.width < 900)
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu,
                          color: Theme.of(context).iconTheme.color),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Benefits',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                ),
                const DigitalClock(),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildMenuItem(
                    context, 
                    ref, 
                    Icons.account_balance_wallet_outlined, 
                    'Allowance Types',
                    () => ref.read(navigationProvider.notifier).setDashboardContent(
                      const BenefitsMasterScreen(category: BenefitCategory.allowance)
                    ),
                  ),
                  _buildMenuItem(
                    context, 
                    ref, 
                    Icons.person_add_alt_1_outlined, 
                    'Staff Allowances',
                    () => ref.read(navigationProvider.notifier).setDashboardContent(
                      const BenefitAssignmentScreen(category: BenefitCategory.allowance)
                    ),
                  ),
                  _buildMenuItem(
                    context, 
                    ref, 
                    Icons.money_off_outlined, 
                    'Deduction Types',
                    () => ref.read(navigationProvider.notifier).setDashboardContent(
                      const BenefitsMasterScreen(category: BenefitCategory.deduction)
                    ),
                  ),
                  _buildMenuItem(
                    context, 
                    ref, 
                    Icons.person_remove_alt_1_outlined, 
                    'Staff Deductions',
                    () => ref.read(navigationProvider.notifier).setDashboardContent(
                      const BenefitAssignmentScreen(category: BenefitCategory.deduction)
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, WidgetRef ref, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        onTap: onTap,
      ),
    );
  }
}
