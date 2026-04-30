import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/theme.dart';
import 'data/database/db_helper.dart';
import 'features/dashboard/splash_screen.dart';
import 'core/notifications/notification_service.dart';
import 'domain/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.init();
  await initializeDateFormatting('pt_BR', null);
  await notificationService.rescheduleAllActiveNotifications(DatabaseHelper.instance);

  runApp(
    const ProviderScope(
      child: DiasOrganizeApp(),
    ),
  );
}

class DiasOrganizeApp extends ConsumerWidget {
  const DiasOrganizeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'DiasOrganize',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
