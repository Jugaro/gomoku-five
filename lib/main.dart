import 'package:material_ui/material_ui.dart';

import 'app_services.dart';
import 'settings/settings_controller.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppServices();
  runApp(const GomokuApp());
}

class GomokuApp extends StatelessWidget {
  const GomokuApp({super.key});

  ThemeData _buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF70452F),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF603B2C),
          onPrimary: const Color(0xFFFFF9EF),
          secondary: const Color(0xFFA34F38),
          surface: const Color(0xFFFFF9EF),
          outline: const Color(0xFFBDA17E),
        );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7EEDC),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7EEDC),
        foregroundColor: colorScheme.primary,
        titleTextStyle: const TextStyle(
          color: Color(0xFF493024),
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF493024),
        contentTextStyle: const TextStyle(color: Color(0xFFFFF9EF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: settingsController,
      child: MaterialApp(
        title: 'Пять в ряд',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
