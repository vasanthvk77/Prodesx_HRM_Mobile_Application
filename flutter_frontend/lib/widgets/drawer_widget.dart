import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/login_screen.dart';
import '../screens/employee_registration_screen.dart';
import '../core/api_config.dart';

class AppDrawer extends ConsumerWidget {
  final dynamic user;

  const AppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant providers
    final themeNotifier = ref.watch(themeProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final navNotifier = ref.read(navigationProvider.notifier);
    final navState = ref.watch(navigationProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Theme.of(context).drawerTheme.backgroundColor,
      elevation: Theme.of(context).brightness == Brightness.light ? 0 : 16,
      child: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (user?.organizationLogo != null && user!.organizationLogo.toString().isNotEmpty)
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          NetworkImage(ApiConfig.getFullImageUrl(user.organizationLogo.toString())),
                    )
                  else
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      user?.name ?? "User",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Theme.of(context).dividerColor),

            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: ExpansionTileThemeData(
                    iconColor: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade400 : Theme.of(context).colorScheme.primary,
                    collapsedIconColor: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade400 : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _drawerItem(context, Icons.dashboard_outlined, "Dashboard", isSelected: navState.currentIndex == 0, onTap: () {
                      navNotifier.setIndex(0);
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    if (user?.role == 'SuperAdmin' || user?.role == 'Admin') ...[
                      _drawerItem(context, Icons.badge_outlined, "HR Management", isSelected: navState.currentIndex == 1, onTap: () {
                        navNotifier.setIndex(1);
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      }),
                      _drawerItem(context, Icons.person_outline, "User Management", isSelected: navState.currentIndex == 2, onTap: () {
                        navNotifier.setIndex(2);
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      }),
                      // Add Face Registration for Admins
                      _drawerItem(context, Icons.camera_front, "Face Management", onTap: () {
                        navNotifier.setDashboardContent(const EmployeeRegistrationScreen());
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      }),
                    ] else ...[
                      _drawerItem(context, Icons.fingerprint, "Attendance", isSelected: navState.currentIndex == 1, onTap: () {
                        navNotifier.setIndex(1);
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      }),
                    ],
                    _drawerItem(context, Icons.task_alt_outlined, "Tasks", isSelected: navState.currentIndex == 3, onTap: () {
                      navNotifier.setIndex(3);
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                    ),

                    _drawerItem(context, Icons.handshake_outlined, "Clients", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Clients Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.work_outline, "Work", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Work Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.account_balance_wallet_outlined, "Finance", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Finance Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.shopping_cart_outlined, "Orders", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Orders Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.confirmation_num_outlined, "Tickets", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Tickets Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.event_outlined, "Events", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Events Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.message_outlined, "Messages", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Messages Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.campaign_outlined, "Notice Board", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Notice Board Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),
                    _drawerItem(context, Icons.book_outlined, "Knowledge Base", onTap: () {
                      navNotifier.setDashboardContent(const Center(child: Text("Knowledge Base Screen")));
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                    }),

                    /// Forms
                    _buildExpansionTile(
                      context,
                      icon: Icons.description,
                      title: "Forms",
                      children: [
                        _subItem(context, "Form1", onTap: () {
                          navNotifier.setDashboardContent(const Center(child: Text("Form 1")));
                          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                        }),
                        _subItem(context, "Form2", onTap: () {
                          navNotifier.setDashboardContent(const Center(child: Text("Form 2")));
                          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                        }),
                        _subItem(context, "Form3", onTap: () {
                          navNotifier.setDashboardContent(const Center(child: Text("Form 3")));
                          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                        }),
                      ],
                    ),

                    /// Settings
                    _buildExpansionTile(
                      context,
                      icon: Icons.settings,
                      title: "Settings",
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 10, bottom: 10),
                          child: InkWell(
                            onTap: () => themeNotifier.toggleTheme(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.light 
                                    ? Colors.grey.shade50 
                                    : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                                        color: isDark ? Colors.amber : Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Appearance",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => themeNotifier.toggleTheme(),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 42,
                                      height: 22,
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: isDark ? Colors.blue : Colors.grey.shade400,
                                      ),
                                      child: AnimatedAlign(
                                        duration: const Duration(milliseconds: 150),
                                        alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _subItem(context, "Notifications"),
                        _subItem(context, "Updates"),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// LOGOUT
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Sign Out",
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                authNotifier.logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Expansion tile for nested menus
  Widget _buildExpansionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
    bool isExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isExpanded ? Theme.of(context).colorScheme.surfaceVariant : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isExpanded 
            ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)) 
            : null,
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        leading: Icon(icon, color: isExpanded ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isExpanded ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
            fontWeight: isExpanded ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_more : Icons.chevron_right,
          color: isExpanded 
              ? Theme.of(context).colorScheme.primary 
              : (Theme.of(context).brightness == Brightness.light ? Colors.grey.shade400 : Theme.of(context).textTheme.bodySmall?.color),
          size: 18,
        ),
        children: children,
      ),
    );
  }

  /// Drawer item
  Widget _drawerItem(BuildContext context, IconData icon, String title, {bool isSelected = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: isSelected 
            ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)) 
            : null,
      ),
      child: ListTile(
        visualDensity: const VisualDensity(vertical: -2),
        leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color, size: 20),
        title: Text(
          title,
          style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w400),
        ),
        trailing: Icon(
          Icons.chevron_right, 
          color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade400 : Theme.of(context).dividerColor, 
          size: 14
        ),
        onTap: onTap ?? () {},
      ),
    );
  }

  /// Sub menu
  Widget _subItem(BuildContext context, String title, {bool isSelected = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: isSelected 
              ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)) 
              : null,
        ),
        child: ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap ?? () {},
        ),
      ),
    );
  }
}