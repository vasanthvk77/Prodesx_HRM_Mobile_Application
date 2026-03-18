import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_frontend/providers/auth_provider.dart';
import 'package:flutter_frontend/providers/theme_provider.dart';
import 'package:flutter_frontend/screens/login_screen.dart';
import 'package:flutter_frontend/screens/main_shell.dart';
import 'package:flutter_frontend/core/theme.dart';

void main() {
  // Wrap the entire app in a ProviderScope to enable Riverpod
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch our new Riverpod providers for changes
    final currentThemeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Prodesx HRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: currentThemeMode,
      home: authState.isAuthenticated ? const MainShell() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainShell(),
      },
    );
  }
}
