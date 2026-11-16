import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/game/board.dart';
import 'package:gomoku5/services/online_backend.dart';
import 'package:gomoku5/settings/settings_controller.dart';
import 'package:gomoku5/ui/board_painter.dart';
import 'package:gomoku5/ui/online_game_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_online_backend.dart';

final _boardFinder = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is BoardPainter,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ход отправляется без оптимистичного камня и ждёт stream', (
    tester,
  ) async {
    final backend = await _pumpOnlineGame(tester);

    expect(find.text('Игрок'), findsOneWidget);
    expect(find.text('Соперник'), findsOneWidget);
    expect(find.text('Чёрные · вы'), findsOneWidget);
    expect(find.text('Ваш ход · вы играете чёрные'), findsOneWidget);

    await _tapCell(tester, (0, 0));

    expect(backend.moves, [('game-1', (0, 0))]);
    expect(_painter(tester).state.stones, isEmpty);
    expect(find.text('Отправляем ход…'), findsOneWidget);

    backend.emitGame(_game(currentPlayer: Player.white, moves: const [(0, 0)]));
    await tester.pump();

    expect(_painter(tester).state.stones, {(0, 0): Player.black});
    expect(find.text('Ход соперника: Соперник'), findsOneWidget);

    await _tapCell(tester, (1, 0));
    expect(backend.moves, hasLength(1));
    expect(_painter(tester).state.stones, hasLength(1));
  });

  testWidgets('белый игрок ходит только своим цветом по currentUid', (
    tester,
  ) async {
    final backend = await _pumpOnlineGame(
      tester,
      currentUid: 'opponent',
      initialGame: _game(currentPlayer: Player.white, moves: const [(0, 0)]),
    );

    expect(find.text('Белые · вы'), findsOneWidget);
    expect(find.text('Ваш ход · вы играете белые'), findsOneWidget);

    await _tapCell(tester, (1, 1));
    expect(backend.moves, [('game-1', (1, 1))]);
    expect(_painter(tester).state.history, [(0, 0)]);

    backend.emitGame(
      _game(currentPlayer: Player.black, moves: const [(0, 0), (1, 1)]),
    );
    await tester.pump();
    await _tapCell(tester, (2, 2));
    expect(backend.moves, hasLength(1));
  });

  testWidgets('победа видна, а ход, undo и restart заблокированы', (
    tester,
  ) async {
    final backend = await _pumpOnlineGame(
      tester,
      initialGame: _game(
        moves: const [
          (-2, 0),
          (5, -4),
          (-1, 0),
          (5, -3),
          (0, 0),
          (5, -2),
          (1, 0),
          (5, -1),
          (2, 0),
        ],
        active: false,
      ),
    );

    expect(find.text('Победа: Игрок (чёрные)!'), findsOneWidget);
    expect(_painter(tester).state.winner, Player.black);
    expect(_painter(tester).state.winningLine, hasLength(5));
    expect(_iconButton(tester, 'Отменить ход').onPressed, isNull);
    expect(_iconButton(tester, 'Новая игра').onPressed, isNull);

    await _tapCell(tester, (3, 0));
    expect(backend.moves, isEmpty);

    await tester.tap(find.byTooltip('Увеличить'));
    await tester.pump();
    expect(_painter(tester).scale, greaterThan(56));
  });

  testWidgets('назад закрывает партию и отменяет watchGame', (tester) async {
    final backend = await _pumpOnlineGame(tester, pushedRoute: true);

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(backend.activeGameListeners('game-1'), 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineGameScreen), findsNothing);
    expect(find.byKey(const Key('open-game')), findsOneWidget);
    expect(backend.activeGameListeners('game-1'), 0);
  });

  testWidgets('ошибка makeMove не меняет доску и разрешает повторить ход', (
    tester,
  ) async {
    final backend = await _pumpOnlineGame(tester);
    backend.makeMoveError = StateError('offline');

    await _tapCell(tester, (0, 0));
    await tester.pump();

    expect(_painter(tester).state.stones, isEmpty);
    expect(
      find.text('Не удалось отправить ход. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Ваш ход · вы играете чёрные'), findsOneWidget);

    backend.makeMoveError = null;
    await _tapCell(tester, (0, 0));
    expect(backend.moves, hasLength(2));
  });
}

Future<FakeOnlineBackend> _pumpOnlineGame(
  WidgetTester tester, {
  String currentUid = 'me',
  OnlineGame? initialGame,
  bool pushedRoute = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final backend = FakeOnlineBackend();
  addTearDown(backend.close);
  final settings = SettingsController();
  addTearDown(settings.dispose);

  final gameScreen = OnlineGameScreen(
    gameId: 'game-1',
    backend: backend,
    currentUid: currentUid,
  );
  await tester.pumpWidget(
    SettingsScope(
      controller: settings,
      child: MaterialApp(
        home: pushedRoute
            ? Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    key: const Key('open-game'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => gameScreen),
                      );
                    },
                    child: const Text('Открыть партию'),
                  ),
                ),
              )
            : gameScreen,
      ),
    ),
  );
  await tester.pump();
  if (pushedRoute) {
    await tester.tap(find.byKey(const Key('open-game')));
    await tester.pump();
  }
  backend.emitGame(initialGame ?? _game());
  await tester.pumpAndSettle();

  final hintClose = find.byTooltip('Скрыть подсказку');
  if (hintClose.evaluate().isNotEmpty) {
    await tester.tap(hintClose);
    await tester.pump();
  }
  return backend;
}

OnlineGame _game({
  Player currentPlayer = Player.black,
  List<Pos> moves = const [],
  bool active = true,
}) {
  return OnlineGame(
    id: 'game-1',
    players: const ['me', 'opponent'],
    nicknames: const {'me': 'Игрок', 'opponent': 'Соперник'},
    currentPlayer: currentPlayer,
    moves: moves,
    active: active,
  );
}

BoardPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(_boardFinder);
  return paint.painter! as BoardPainter;
}

IconButton _iconButton(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    ),
  );
}

Future<void> _tapCell(WidgetTester tester, Pos position) async {
  final board = _painter(tester);
  final world = Offset(position.$1.toDouble(), position.$2.toDouble());
  final point =
      tester.getRect(_boardFinder).topLeft + board.offset + world * board.scale;
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 400));
}
