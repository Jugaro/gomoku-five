import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Offset, Size;
import 'package:gomoku5/app_services.dart';
import 'package:gomoku5/main.dart';
import 'package:gomoku5/settings/app_settings.dart';
import 'package:gomoku5/ui/game_screen.dart';
import 'package:gomoku5/ui/home_screen.dart';
import 'package:gomoku5/ui/online_screen.dart';
import 'package:gomoku5/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    audioService.applySettings(
      const AppSettings(soundEnabled: false, musicEnabled: false),
    );
  });

  Future<void> prepare(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const GomokuApp());
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('home preview', (tester) async {
    await prepare(tester);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('board preview', (tester) async {
    await prepare(tester);
    await open(tester, 'Два игрока');
    for (final point in [
      const Offset(195, 450),
      const Offset(251, 450),
      const Offset(195, 506),
      const Offset(251, 506),
    ]) {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/board.png'),
    );
  });

  testWidgets('settings preview', (tester) async {
    await prepare(tester);
    await open(tester, 'Настройки');
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings.png'),
    );
  });

  testWidgets('online preview', (tester) async {
    await prepare(tester);
    await open(tester, 'Онлайн');
    await expectLater(
      find.byType(OnlineScreen),
      matchesGoldenFile('goldens/online.png'),
    );
  });
}
