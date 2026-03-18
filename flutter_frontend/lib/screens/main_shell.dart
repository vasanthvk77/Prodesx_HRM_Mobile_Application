import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import 'private_dashboard.dart';
import 'hr_management_screen.dart';
import 'user_management_screen.dart';
import 'manage_users.dart';
import 'tasks_screen.dart';
import '../widgets/drawer_widget.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the navigation and auth providers
    final navState = ref.watch(navigationProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final isAdmin = authState.user?.role == 'SuperAdmin' || authState.user?.role == 'Admin';

    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> navItems = [];

    // Dashboard is always first
    screens.add(navState.dashboardContent ?? const PrivateDashboard());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ));

    if (isAdmin) {
      // HR Management
      screens.add(const HRManagementScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.badge_outlined),
        activeIcon: Icon(Icons.badge),
        label: 'HR Management',
      ));

      // User Management (with sub-page support)
      screens.add(
        navState.manageUsersContent != null 
          ? const ManageUsersScreen(key: ValueKey('ManageUsers')) 
          : const UserManagementScreen(key: ValueKey('UserManagementMenu'))
      );
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'User Management',
      ));
    } else {
      // For regular Users, show attendance-related options instead of management
      screens.add(const Center(child: Text('My Attendance (Coming Soon)')));
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.fingerprint),
        label: 'Attendance',
      ));
    }

    // Tasks is always last
    screens.add(const TasksScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.task_alt_outlined),
      activeIcon: Icon(Icons.task_alt),
      label: 'Tasks',
    ));

    // Safety check for index
    int safeIndex = navState.currentIndex;
    if (safeIndex >= screens.length) {
      safeIndex = 0;
      // We should ideally call notifier.setIndex(0) here, but we can't do it inside build.
      // The IndexedStack will handle it for this frame.
    }

    return Scaffold(
      drawer: AppDrawer(user: user),
      body: IndexedStack(
        index: safeIndex,
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
          currentIndex: safeIndex,
          onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: navItems,
        ),
      ),
    );
  }
}
