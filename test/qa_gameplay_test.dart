import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/app_services.dart';
import 'package:gomoku5/game/board.dart';
import 'package:gomoku5/settings/settings_controller.dart';
import 'package:gomoku5/ui/board_painter.dart';
import 'package:gomoku5/ui/game_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _boardFinder = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is BoardPainter,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    audioService.applySettings(
      const AppSettings(soundEnabled: false, musicEnabled: false),
    );
  });

  testWidgets('занятая клетка не меняет камень и не тратит ход', (tester) async {
    await _pumpGame(tester);

    await _tapCell(tester, (0, 0));
    await _tapCell(tester, (0, 0));

    var board = _painter(tester);
    expect(board.state.stones, hasLength(1));
    expect(board.state.stones[(0, 0)], Player.black);
    expect(board.state.history, [(0, 0)]);
    expect(board.state.current, Player.white);
    expect(find.text('Ход: белые'), findsOneWidget);

    await _tapCell(tester, (1, 0));
    board = _painter(tester);
    expect(board.state.stones[(1, 0)], Player.white);
    expect(board.state.history, [(0, 0), (1, 0)]);
    expect(board.state.current, Player.black);
  });

  testWidgets('после pan и zoom тап ставит камень в видимую выбранную клетку', (
    tester,
  ) async {
    await _pumpGame(tester);
    final rect = tester.getRect(_boardFinder);
    final initial = _painter(tester);

    await _pan(tester, rect.center, const Offset(180, 120));
    expect(_painter(tester).state.stones, isEmpty);
    expect(_painter(tester).offset.dx, greaterThan(initial.offset.dx));
    expect(_painter(tester).offset.dy, greaterThan(initial.offset.dy));

    await tester.tap(find.byTooltip('Увеличить'));
    await tester.pump();
    expect(_painter(tester).scale, closeTo(72.8, 0.001));

    final tappedPoint = rect.topLeft + const Offset(200, 200);
    final beforeTap = _painter(tester);
    final local = tappedPoint - rect.topLeft;
    final world = (local - beforeTap.offset) / beforeTap.scale;
    final expected = (world.dx.round(), world.dy.round());
    expect(expected, (-7, -5));

    await tester.tapAt(tappedPoint);
    await tester.pump(const Duration(milliseconds: 400));

    final board = _painter(tester);
    expect(board.state.stones, hasLength(1));
    expect(board.state.stones[expected], Player.black);
    expect(board.state.history, [expected]);
  });

  testWidgets('pinch меняет масштаб и ограничен 28–112', (tester) async {
    await _pumpGame(tester);
    final center = tester.getRect(_boardFinder).center;
    expect(_painter(tester).scale, 56);

    await _pinch(tester, center, 40, 140);
    expect(_painter(tester).scale, greaterThan(56));
    expect(_painter(tester).state.stones, isEmpty);

    await _pinch(tester, center, 40, 140);
    expect(_painter(tester).scale, 112);

    await _pinch(tester, center, 140, 20);
    expect(_painter(tester).scale, 28);
    expect(_painter(tester).state.stones, isEmpty);
  });

  testWidgets('кнопки +/− меняют масштаб и отключаются на 28 и 112', (
    tester,
  ) async {
    await _pumpGame(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Увеличить'));
      await tester.pump();
    }
    expect(_painter(tester).scale, 112);
    final zoomIn = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Увеличить',
    );
    final zoomOut = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Уменьшить',
    );
    expect(tester.widget<IconButton>(zoomIn).onPressed, isNull);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Уменьшить'));
      await tester.pump();
    }
    expect(_painter(tester).scale, 28);
    expect(tester.widget<IconButton>(zoomOut).onPressed, isNull);

    await tester.tap(find.byTooltip('Увеличить'));
    await tester.pump();
    expect(_painter(tester).scale, closeTo(36.4, 0.001));
  });

  testWidgets('double-tap масштабирует, но не ставит лишний камень', (
    tester,
  ) async {
    await _pumpGame(tester);
    final point = _cellCenter(tester, (2, -1));

    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final board = _painter(tester);
    expect(board.scale, closeTo(89.6, 0.001));
    expect(board.state.stones, isEmpty);
    expect(board.state.history, isEmpty);
    expect(board.state.current, Player.black);
  });

  testWidgets('центрирование возвращает последний ход в центр viewport', (
    tester,
  ) async {
    await _pumpGame(tester);
    const last = (3, -2);
    await _tapCell(tester, last);
    await _pan(
      tester,
      tester.getRect(_boardFinder).center,
      const Offset(250, 180),
    );
    expect(_painter(tester).state.history, [last]);

    await tester.tap(find.byTooltip('К последнему ходу'));
    await tester.pump();

    final board = _painter(tester);
    final size = tester.getSize(_boardFinder);
    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final expected =
        viewportCenter -
        Offset(last.$1.toDouble(), last.$2.toDouble()) * board.scale;
    expect(board.offset.dx, closeTo(expected.dx, 0.001));
    expect(board.offset.dy, closeTo(expected.dy, 0.001));
    expect(board.scale, 56);
  });

  testWidgets('restart во время расчёта отклоняет устаревший ответ ИИ', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      mode: GameMode.ai,
      difficulty: AiDifficulty.hard,
    );

    await _tapCell(tester, (0, 0));
    expect(find.text('ИИ обдумывает ход…'), findsOneWidget);
    expect(_painter(tester).state.history, [(0, 0)]);

    await tester.tap(find.byTooltip('Новая игра'));
    await tester.pump();
    expect(_painter(tester).state.stones, isEmpty);
    expect(find.text('Ваш ход · вы играете чёрными'), findsOneWidget);

    await _waitForHardAi(tester);
    expect(_painter(tester).state.stones, isEmpty);
    expect(_painter(tester).state.history, isEmpty);
    expect(_painter(tester).state.current, Player.black);
    expect(find.text('ИИ обдумывает ход…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('undo во время расчёта отклоняет устаревший ответ ИИ', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      mode: GameMode.ai,
      difficulty: AiDifficulty.hard,
    );

    await _tapCell(tester, (0, 0));
    expect(find.text('ИИ обдумывает ход…'), findsOneWidget);

    await tester.tap(find.byTooltip('Отменить ход'));
    await tester.pump();
    expect(_painter(tester).state.stones, isEmpty);

    await _waitForHardAi(tester);
    expect(_painter(tester).state.stones, isEmpty);
    expect(_painter(tester).state.history, isEmpty);
    expect(_painter(tester).state.current, Player.black);
    expect(find.text('Ваш ход · вы играете чёрными'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('пять в ряд блокирует ввод и рисует победную линию и кольца', (
    tester,
  ) async {
    await _pumpGame(tester);
    const moves = [
      (-2, 0),
      (5, -4),
      (-1, 0),
      (5, -3),
      (0, 0),
      (5, -2),
      (1, 0),
      (5, -1),
      (2, 0),
    ];
    for (final move in moves) {
      await _tapCell(tester, move);
    }

    var board = _painter(tester);
    expect(board.state.winner, Player.black);
    expect(board.state.isOver, isTrue);
    expect(board.state.winningLine, [(-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0)]);
    expect(find.text('Победа: чёрные!'), findsOneWidget);
    expect(await _pixelAtWorld(tester, const Offset(0, -0.48)), _isRedHighlight);

    await _tapCell(tester, (3, 0));
    await _tapCell(tester, (6, 6));
    board = _painter(tester);
    expect(board.state.stones, hasLength(9));
    expect(board.state.history, moves);
    expect(board.state.stones[(3, 0)], isNull);
    expect(board.state.stones[(6, 6)], isNull);
    expect(board.state.current, Player.black);
    expect(board.previewPlayer, isNull);
  });
}

Future<void> _pumpGame(
  WidgetTester tester, {
  GameMode mode = GameMode.twoPlayers,
  AiDifficulty difficulty = AiDifficulty.medium,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final controller = SettingsController();
  await controller.setDifficulty(difficulty);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    SettingsScope(
      controller: controller,
      child: MaterialApp(home: GameScreen(mode: mode)),
    ),
  );
  await tester.pump();

  final hintClose = find.byTooltip('Скрыть подсказку');
  if (hintClose.evaluate().isNotEmpty) {
    await tester.tap(hintClose);
    await tester.pump();
  }
}

BoardPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(_boardFinder);
  return paint.painter! as BoardPainter;
}

Offset _cellCenter(WidgetTester tester, Pos position) {
  final board = _painter(tester);
  final world = Offset(position.$1.toDouble(), position.$2.toDouble());
  return tester.getRect(_boardFinder).topLeft +
      board.offset +
      world * board.scale;
}

Future<void> _tapCell(WidgetTester tester, Pos position) async {
  await tester.tapAt(_cellCenter(tester, position));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pan(WidgetTester tester, Offset start, Offset delta) async {
  await tester.dragFrom(start, delta);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pinch(
  WidgetTester tester,
  Offset center,
  double startRadius,
  double endRadius,
) async {
  final first = await tester.startGesture(
    center - Offset(startRadius, 0),
  );
  final second = await tester.startGesture(
    center + Offset(startRadius, 0),
  );
  await tester.pump();
  await first.moveTo(center - Offset(endRadius, 0));
  await second.moveTo(center + Offset(endRadius, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _waitForHardAi(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 4500)),
  );
  await tester.pump();
}

Future<ui.Color> _pixelAtWorld(WidgetTester tester, Offset world) async {
  final board = _painter(tester);
  final size = tester.getSize(_boardFinder);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  board.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(
    () => picture.toImage(size.width.round(), size.height.round()),
  ))!;
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final point = board.offset + world * board.scale;
  final color = _readRgba(bytes!, point.dx.round(), point.dy.round(), image.width);
  picture.dispose();
  image.dispose();
  return color;
}

ui.Color _readRgba(ByteData bytes, int x, int y, int width) {
  final offset = (y * width + x) * 4;
  return ui.Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

final _isRedHighlight = predicate<ui.Color>((color) {
  return color.r > 0.6 && color.g < 0.2 && color.b < 0.2;
}, 'красное кольцо вокруг победного камня');
