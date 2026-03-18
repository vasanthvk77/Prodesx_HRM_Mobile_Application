import 'package:flutter/material.dart';
import '../widgets/digital_clock.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

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
                  'Tasks & Projects',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
              ),
              const DigitalClock(),
            ],
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Coming Soon',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
