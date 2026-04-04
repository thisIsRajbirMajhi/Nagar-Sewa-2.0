import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class NagarSewaApp extends ConsumerWidget {
  const NagarSewaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Nagar Sewa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
