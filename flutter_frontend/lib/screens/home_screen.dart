import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/drawer_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchText = "";

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      /// 🔥 MODERN DRAWER
      drawer: AppDrawer(user: user),

      /// 🔥 APPBAR
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              /// Drawer button
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),

              const SizedBox(width: 10),

              const Text(
                "Dashboard",
                style: TextStyle(fontSize: 20),
              ),

              const SizedBox(width: 15),

              /// Search
             
            ],
          ),
        ),
      ),

      /// 🔥 BODY
      body: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user?.organizationLogo != null)
              Image.network(
                user!.organizationLogo!,
                height: 100,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.business,
                        size: 100, color: Colors.grey),
              )
            else
              const Icon(Icons.account_circle,
                  size: 120, color: Colors.blue),

            const SizedBox(height: 24),

            Text(
              'Welcome Back,',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 8),

            Text(
              user?.name ?? 'User',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
            ),

            const SizedBox(height: 16),

            Chip(
              label: Text(
                user?.role ?? 'Role',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.blue.shade700,
            ),

            const SizedBox(height: 24),

            Text(
              "Search: $searchText",
              style:
                  const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This is your professional HRM dashboard. More features coming soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}