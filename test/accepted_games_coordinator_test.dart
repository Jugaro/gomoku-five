import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/services/accepted_games_coordinator.dart';
import 'package:gomoku5/services/online_backend.dart';

import 'fake_online_backend.dart';

void main() {
  test('принятое приглашение открывает игру отправителя один раз', () async {
    final backend = FakeOnlineBackend();
    final opened = <String>[];
    final coordinator = AcceptedGamesCoordinator(
      backend: backend,
      openGame: opened.add,
    );
    coordinator.start();

    const invite = GameInvite(
      id: 'outgoing-1',
      fromUid: 'me',
      toUid: 'opponent',
      fromNickname: 'Игрок_5',
      status: 'accepted',
      gameId: 'game-1',
    );
    backend.emitAcceptedInvitations([invite]);
    await Future<void>.delayed(Duration.zero);
    backend.emitAcceptedInvitations([invite]);
    await Future<void>.delayed(Duration.zero);

    expect(opened, ['game-1']);
    await coordinator.dispose();
    await backend.close();
  });

  test('pending и приглашения без gameId не открывают игру', () async {
    final backend = FakeOnlineBackend();
    final opened = <String>[];
    final coordinator = AcceptedGamesCoordinator(
      backend: backend,
      openGame: opened.add,
    );
    coordinator.start();

    backend.emitAcceptedInvitations([
      const GameInvite(
        id: 'outgoing-1',
        fromUid: 'me',
        toUid: 'opponent',
        fromNickname: 'Игрок_5',
        status: 'pending',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(opened, isEmpty);
    await coordinator.dispose();
    await backend.close();
  });
}
