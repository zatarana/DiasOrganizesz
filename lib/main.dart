import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/theme.dart';
import 'features/dashboard/splash_screen.dart';
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await initializeDateFormatting('pt_BR', null);
  
  runApp(
    const ProviderScope(
      child: DiasOrganizeApp(),
    ),
  );
}

class DiasOrganizeApp extends StatelessWidget {
  const DiasOrganizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiasOrganize',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
