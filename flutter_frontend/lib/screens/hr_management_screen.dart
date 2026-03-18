import 'package:flutter/material.dart';
import '../widgets/digital_clock.dart';
import 'designation_list_screen.dart';
import 'department_list_screen.dart';



class HRManagementScreen extends StatelessWidget {
  const HRManagementScreen({super.key});

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
                  'HR Management',
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
                _buildMenuItem(context, Icons.people_outline, 'Employees'),
                _buildMenuItem(context, Icons.event_busy_outlined, 'Leaves'),
                _buildMenuItem(context, Icons.assignment_ind_outlined, 'Shift Assignments'),
                _buildMenuItem(context, Icons.fingerprint, 'Attendance'),
                _buildMenuItem(context, Icons.event_outlined, 'Holiday'),
                _buildMenuItem(context, Icons.badge_outlined, 'Designation'),
                _buildMenuItem(context, Icons.domain_outlined, 'Department'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]
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
        onTap: () {
          if (title == 'Designation') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DesignationListScreen()),
            );
          } else if (title == 'Department') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DepartmentListScreen()),
            );
          }
        },

      ),
    );
  }
}
