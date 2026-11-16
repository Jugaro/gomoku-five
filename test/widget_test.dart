import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/main.dart';

void main() {
  testWidgets('главный экран показывает режимы игры', (tester) async {
    await tester.pumpWidget(const GomokuApp());
    expect(find.text('Против ИИ'), findsOneWidget);
    expect(find.text('Два игрока'), findsOneWidget);
    expect(find.text('Онлайн'), findsOneWidget);
  });
}
