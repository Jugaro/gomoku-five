import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/game/board.dart';
import 'package:gomoku5/profile/nickname_validator.dart';
import 'package:gomoku5/profile/profile_store.dart';
import 'package:gomoku5/services/online_backend.dart';
import 'package:gomoku5/services/profile_cloud.dart';
import 'package:gomoku5/settings/settings_controller.dart';
import 'package:gomoku5/ui/home_screen.dart';
import 'package:gomoku5/ui/online_game_screen.dart';
import 'package:gomoku5/ui/online_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_online_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('валидный ник сохраняется и открывает режимы', (tester) async {
    final store = await _pumpOnline(tester);

    await tester.enterText(
      find.byKey(const Key('own-nickname-field')),
      '  Игрок_5  ',
    );
    await tester.pump();

    await _tap(tester, find.text('Сохранить и продолжить'));
    await tester.pumpAndSettle();

    expect(await store.loadNickname(), 'Игрок_5');
    expect(find.text('Игрок_5'), findsOneWidget);
    expect(find.text('Сменить ник'), findsOneWidget);
    expect(find.text('Случайный соперник'), findsOneWidget);
    expect(find.text('Играть по нику'), findsOneWidget);
  });

  testWidgets('невалидный ник показывает живую ошибку и не сохраняется', (
    tester,
  ) async {
    final store = await _pumpOnline(tester);
    const invalidNickname = 'x';
    final expectedError = NicknameValidator.validate(invalidNickname)!;

    await tester.enterText(
      find.byKey(const Key('own-nickname-field')),
      invalidNickname,
    );
    await tester.pump();

    expect(find.text(expectedError), findsOneWidget);
    await _tap(tester, find.text('Сохранить и продолжить'));
    await tester.pumpAndSettle();

    expect(find.text(expectedError), findsOneWidget);
    expect(await store.loadNickname(), isNull);
    expect(find.text('Случайный соперник'), findsNothing);
    expect(find.text('Играть по нику'), findsNothing);
  });

  testWidgets('повторное открытие показывает сохранённый ник', (tester) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_7');
    await _pumpOnline(tester, store: store);

    expect(find.text('Игрок_7'), findsOneWidget);
    expect(find.text('Сохранить и продолжить'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpOnline(tester, store: store);

    expect(find.text('Игрок_7'), findsOneWidget);
    expect(find.text('Сменить ник'), findsOneWidget);
    expect(find.text('Случайный соперник'), findsOneWidget);
    expect(find.text('Играть по нику'), findsOneWidget);
  });

  testWidgets(
    'случайный поиск запускается, показывает индикатор и отменяется',
    (tester) async {
      final store = ProfileStore();
      await store.saveNickname('Игрок_5');
      final backend = FakeOnlineBackend();
      await _pumpOnline(tester, store: store, backend: backend);

      await _tap(tester, find.text('Найти соперника'));
      await tester.pump();

      expect(backend.startRandomSearchCalls, 1);
      expect(find.text('Поиск соперника…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await _tap(tester, find.text('Отменить поиск'));
      await tester.pump();

      expect(backend.cancelRandomSearchCalls, 1);
      expect(find.text('Поиск соперника…'), findsNothing);
      expect(find.text('Найти соперника'), findsOneWidget);
      expect(find.byType(OnlineScreen), findsOneWidget);
    },
  );

  testWidgets('watchRandomMatch открывает найденную партию', (tester) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_5');
    final backend = FakeOnlineBackend();
    await _pumpOnline(tester, store: store, backend: backend);

    await _tap(tester, find.text('Найти соперника'));
    await tester.pump();
    backend.emitRandomMatch('random-game');
    await tester.pump();
    backend.emitGame(_game('random-game'));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(backend.watchedGameIds, ['random-game']);
    expect(find.text('Онлайн-партия'), findsOneWidget);
    expect(find.text('Поиск соперника…'), findsNothing);
  });

  testWidgets('приглашение по нику отправляется с понятным результатом', (
    tester,
  ) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_5');
    final backend = FakeOnlineBackend();
    await _pumpOnline(tester, store: store, backend: backend);

    await tester.enterText(
      find.byKey(const Key('friend-nickname-field')),
      'Друг_5',
    );
    await _tap(tester, find.text('Пригласить друга'));
    await tester.pump();

    expect(backend.sentInvitations, ['Друг_5']);
    expect(find.text('Приглашение отправлено игроку Друг_5'), findsOneWidget);
    expect(find.byType(OnlineScreen), findsOneWidget);
  });

  testWidgets('входящее приглашение можно принять и открыть gameId', (
    tester,
  ) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_5');
    final backend = FakeOnlineBackend();
    backend.acceptGameIds['invite-1'] = 'invited-game';
    await _pumpOnline(tester, store: store, backend: backend);

    backend.emitInvitations([_invite()]);
    await tester.pumpAndSettle();
    expect(find.text('Входящие приглашения'), findsOneWidget);
    expect(find.text('Друг_5'), findsOneWidget);

    await _tap(tester, find.text('Принять'));
    await tester.pump();
    backend.emitGame(_game('invited-game'));
    await tester.pumpAndSettle();

    expect(backend.acceptedInvitations, ['invite-1']);
    expect(backend.watchedGameIds, ['invited-game']);
    expect(find.byType(OnlineGameScreen), findsOneWidget);
  });

  testWidgets('входящее приглашение можно отклонить без открытия партии', (
    tester,
  ) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_5');
    final backend = FakeOnlineBackend();
    await _pumpOnline(tester, store: store, backend: backend);

    backend.emitInvitations([_invite()]);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Отклонить'));
    await tester.pump();

    expect(backend.declinedInvitations, ['invite-1']);
    expect(backend.acceptedInvitations, isEmpty);
    expect(backend.watchedGameIds, isEmpty);
    expect(find.text('Приглашение отклонено'), findsOneWidget);
    expect(find.text('Друг_5'), findsNothing);
    expect(find.byType(OnlineScreen), findsOneWidget);
  });

  testWidgets('главная кнопка «Онлайн» открывает онлайн-экран', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await _tap(tester, find.text('Онлайн'));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineScreen), findsOneWidget);
    expect(find.text('Онлайн (скоро)'), findsNothing);
  });

  testWidgets('подключённое облако синхронизирует ник перед matchmaking', (
    tester,
  ) async {
    final cloud = _FakeCloud();
    final backend = FakeOnlineBackend();
    await _pumpOnline(tester, cloud: cloud, backend: backend);

    await tester.enterText(
      find.byKey(const Key('own-nickname-field')),
      'Облачный_игрок',
    );
    await tester.pump();
    await _tap(tester, find.text('Сохранить и продолжить'));
    await tester.pumpAndSettle();

    expect(cloud.savedNicknames, ['Облачный_игрок']);
    expect(find.text('Сервер подключён'), findsOneWidget);
    expect(
      find.text('Ник сохранён и синхронизирован с облаком'),
      findsOneWidget,
    );

    await _tap(tester, find.text('Найти соперника'));
    await tester.pump();
    expect(backend.startRandomSearchCalls, 1);
    expect(find.text('Поиск соперника…'), findsOneWidget);
  });

  testWidgets('подписки ждут подключение вместо ошибки авторизации', (
    tester,
  ) async {
    final store = ProfileStore();
    await store.saveNickname('Игрок_5');
    final backend = FakeOnlineBackend();
    final cloud = _FakeCloud(false);
    await _pumpOnline(tester, store: store, backend: backend, cloud: cloud);

    expect(backend.randomMatchWatchCalls, 0);
    expect(backend.invitationsWatchCalls, 0);

    cloud.connect();
    await tester.pump();

    expect(backend.randomMatchWatchCalls, 1);
    expect(backend.invitationsWatchCalls, 1);
  });
}

Future<ProfileStore> _pumpOnline(
  WidgetTester tester, {
  ProfileStore? store,
  ProfileCloud? cloud,
  FakeOnlineBackend? backend,
}) async {
  final profileStore = store ?? ProfileStore();
  final onlineBackend = backend ?? FakeOnlineBackend();
  addTearDown(onlineBackend.close);
  final settings = SettingsController();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    SettingsScope(
      controller: settings,
      child: MaterialApp(
        home: OnlineScreen(
          profileStore: profileStore,
          cloud: cloud ?? _FakeCloud(),
          backend: onlineBackend,
          currentUid: 'me',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return profileStore;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

OnlineGame _game(String id) {
  return OnlineGame(
    id: id,
    players: const ['me', 'opponent'],
    nicknames: const {'me': 'Игрок_5', 'opponent': 'Соперник'},
    currentPlayer: Player.black,
    moves: const [],
    active: true,
  );
}

GameInvite _invite() {
  return const GameInvite(
    id: 'invite-1',
    fromUid: 'opponent',
    toUid: 'me',
    fromNickname: 'Друг_5',
    status: 'pending',
  );
}

class _FakeCloud extends ProfileCloud {
  _FakeCloud([this._connected = true]);

  final List<String> savedNicknames = [];
  bool _connected;

  @override
  bool get isConnected => _connected;

  @override
  String get statusText => _connected ? 'Сервер подключён' : 'Подключение…';

  void connect() {
    _connected = true;
    notifyListeners();
  }

  @override
  Future<void> saveNickname(String nickname) async {
    savedNicknames.add(nickname);
  }
}
