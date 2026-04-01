import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../widgets/digital_clock.dart';
import 'designation_list_screen.dart';
import 'department_list_screen.dart';
import 'employee_list_screen.dart';
import 'attendance_register_screen.dart';
import 'attendance_list_screen.dart';
import 'face_attendance_screen.dart';

class HRManagementScreen extends ConsumerWidget {
  const HRManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                _buildMenuItem(context, ref, Icons.people_outline, 'Employees'),
                _buildMenuItem(context, ref, Icons.event_busy_outlined, 'Leaves'),
                _buildMenuItem(context, ref, Icons.assignment_ind_outlined, 'Shift Assignments'),
                _buildMenuItem(context, ref, Icons.fact_check_outlined, 'Attendance Register'),
                _buildMenuItem(context, ref, Icons.history_outlined, 'Attendance Logs'),
                _buildMenuItem(context, ref, Icons.location_on_outlined, 'Office Attendance'),
                _buildMenuItem(context, ref, Icons.event_outlined, 'Holiday'),
                _buildMenuItem(context, ref, Icons.badge_outlined, 'Designation'),
                _buildMenuItem(context, ref, Icons.domain_outlined, 'Department'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, WidgetRef ref, IconData icon, String title) {
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
          if (title == 'Employees') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const EmployeeListScreen());
          } else if (title == 'Attendance Register') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const AttendanceRegisterScreen());
          } else if (title == 'Attendance Logs') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const AttendanceListScreen());
          } else if (title == 'Office Attendance') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const FaceAttendanceScreen());
          } else if (title == 'Designation') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const DesignationListScreen());
          } else if (title == 'Department') {
            ref.read(navigationProvider.notifier).setHRManagementContent(const DepartmentListScreen());
          }
        },
      ),
    );
  }
}
