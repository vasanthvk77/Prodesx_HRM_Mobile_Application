import 'package:flutter/material.dart';
import '../widgets/digital_clock.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Unified Header
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: Theme.of(context).iconTheme.color),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'User Management',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
              ),
              const DigitalClock(),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, 'USER MANAGEMENT'),
                  const SizedBox(height: 10),
                  _buildMenuItem(context, Icons.person_search_outlined, 'Manage Users'),
                  _buildMenuItem(context, Icons.person_add_outlined, 'Create New User'),
                  
                  const SizedBox(height: 30),
                  _sectionHeader(context, 'ORGANIZATION SETTINGS'),
                  const SizedBox(height: 10),
                  _buildMenuItem(context, Icons.calendar_month_outlined, 'Calendar Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]
            : [],
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}
