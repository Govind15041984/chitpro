import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'features/auth/screens/mobile_screen.dart';
import 'features/chit_details/screens/chit_detail_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/chit_create/screens/chit_create_wizard_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ChitProApp()));
}

class ChitProApp extends StatelessWidget {
  const ChitProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChitPro',
      debugShowCheckedModeBanner: false,
      theme: ChitProTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // We use onGenerateRoute or a logic check within the route map
        // to handle arguments safely.
        return null; // Fallback to static routes
      },
      routes: {
        // ---------------- AUTH ----------------
        '/': (_) => const MobileScreen(),

        // ---------------- DASHBOARD ----------------
        '/dashboard': (_) => const DashboardScreen(),

        // ---------------- CREATE CHIT ----------------
        '/create-chit': (_) => const ChitCreateWizardScreen(),

        // ---------------- CHIT DETAIL ----------------
        '/chit-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          String id = "";

          // Check if arguments is a Map (from our updated list)
          // or a String (from older code/direct navigation)
          if (args is Map) {
            id = args['id'] as String;
          } else if (args is String) {
            id = args;
          }

          return ChitDetailScreen(
            chitGroupId: id,
          );
        },
      },
    );
  }
}