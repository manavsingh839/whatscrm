import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dynamic Supabase configuration
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: WaCrmApp(),
    ),
  );
}

class WaCrmApp extends StatelessWidget {
  const WaCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'wacrm — WhatsApp CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default dark theme matching modern CRM UI
      routerConfig: appRouter,
    );
  }
}
