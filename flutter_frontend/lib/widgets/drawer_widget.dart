import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/login_screen.dart';
import '../core/api_config.dart';

class AppDrawer extends StatefulWidget {
  final dynamic user;

  const AppDrawer({super.key, required this.user});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = widget.user;

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
                    _drawerItem(Icons.handshake_outlined, "Clients", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Clients Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.work_outline, "Work", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Work Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.account_balance_wallet_outlined, "Finance", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Finance Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.shopping_cart_outlined, "Orders", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Orders Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.confirmation_num_outlined, "Tickets", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Tickets Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.event_outlined, "Events", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Events Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.message_outlined, "Messages", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Messages Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.campaign_outlined, "Notice Board", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Notice Board Screen")));
                      Navigator.pop(context);
                    }),
                    _drawerItem(Icons.book_outlined, "Knowledge Base", onTap: () {
                      Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Knowledge Base Screen")));
                      Navigator.pop(context);
                    }),

                    /// Forms
                    _buildExpansionTile(
                      icon: Icons.description,
                      title: "Forms",
                      children: [
                        _subItem("Form1", onTap: () {
                          Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Form 1")));
                          Navigator.pop(context);
                        }),
                        _subItem("Form2", onTap: () {
                          Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Form 2")));
                          Navigator.pop(context);
                        }),
                        _subItem("Form3", onTap: () {
                          Provider.of<NavigationProvider>(context, listen: false).setDashboardContent(const Center(child: Text("Form 3")));
                          Navigator.pop(context);
                        }),
                      ],
                    ),

                    /// Settings
                    _buildExpansionTile(
                      icon: Icons.settings,
                      title: "Settings",
                      children: [
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 30, right: 10, bottom: 10),
                              child: InkWell(
                                onTap: () => themeProvider.toggleTheme(),
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
                                            themeProvider.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                                            color: themeProvider.isDarkMode ? Colors.amber : Colors.orange,
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
                                        onTap: () => themeProvider.toggleTheme(),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: 42,
                                          height: 22,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            color: themeProvider.isDarkMode ? Colors.blue : Colors.grey.shade400,
                                          ),
                                          child: AnimatedAlign(
                                            duration: const Duration(milliseconds: 150),
                                            alignment: themeProvider.isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
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
                            );
                          },
                        ),
                        _subItem("Notifications"),
                        _subItem("Updates"),
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
                authProvider.logout();
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
  Widget _buildExpansionTile({
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
  Widget _drawerItem(IconData icon, String title, {bool isSelected = false, VoidCallback? onTap}) {
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
  Widget _subItem(String title, {bool isSelected = false, VoidCallback? onTap}) {
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