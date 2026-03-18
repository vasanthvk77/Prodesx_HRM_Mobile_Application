import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import 'private_dashboard.dart';
import 'hr_management_screen.dart';
import 'user_management_screen.dart';
import '../widgets/drawer_widget.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the navigation and auth providers
    final navState = ref.watch(navigationProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final List<Widget> screens = [
      navState.dashboardContent ?? const PrivateDashboard(),
      const HRManagementScreen(),
      const UserManagementScreen(),
      const Center(child: Text('Tasks & Projects (Coming Soon)')),
    ];

    return Scaffold(
      drawer: AppDrawer(user: user),
      body: IndexedStack(
        index: navState.currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light 
              ? Colors.white 
              : Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: navState.currentIndex,
          onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'HR Management',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'User Management',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_outlined),
              activeIcon: Icon(Icons.task_alt),
              label: 'Tasks',
            ),
          ],
        ),
      ),
    );
  }
}
