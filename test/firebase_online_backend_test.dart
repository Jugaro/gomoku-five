import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/game/board.dart';
import 'package:gomoku5/services/firebase_online_backend.dart';

void main() {
  group('разбор документов', () {
    test('восстанавливает игру и доску из Firestore-совместимых данных', () {
      final game = parseOnlineGame('game-1', {
        'players': ['black-uid', 'white-uid'],
        'nicknames': {'black-uid': 'Чёрный', 'white-uid': 'Белый'},
        'currentPlayer': 'black',
        'moves': [
          {'x': 2, 'y': -3, 'player': 'black'},
          {'x': 2, 'y': -2, 'player': 'white'},
        ],
        'active': true,
        'winner': null,
        'version': 2,
      });

      expect(game.id, 'game-1');
      expect(game.colorFor('black-uid'), Player.black);
      expect(game.colorFor('white-uid'), Player.white);
      expect(game.nicknameFor('white-uid'), 'Белый');
      expect(game.currentPlayer, Player.black);
      expect(game.active, isTrue);
      expect(game.moves, [(2, -3), (2, -2)]);
      expect(game.toGameState().stones, {
        (2, -3): Player.black,
        (2, -2): Player.white,
      });
    });

    test('восстанавливает приглашение с gameId', () {
      final invite = parseGameInvite('invite-1', {
        'fromUid': 'from',
        'toUid': 'to',
        'fromNickname': 'Отправитель',
        'status': 'accepted',
        'gameId': 'game-1',
      });

      expect(invite.id, 'invite-1');
      expect(invite.fromUid, 'from');
      expect(invite.toUid, 'to');
      expect(invite.fromNickname, 'Отправитель');
      expect(invite.status, 'accepted');
      expect(invite.gameId, 'game-1');
    });

    test('отклоняет повторную клетку и нарушение очерёдности в истории', () {
      final duplicate = _gameData(
        moves: [_move(0, 0, 'black'), _move(0, 0, 'white')],
      );
      final wrongPlayer = _gameData(
        moves: [_move(0, 0, 'black'), _move(1, 0, 'black')],
      );

      expect(() => parseOnlineGame('game', duplicate), throwsFormatException);
      expect(() => parseOnlineGame('game', wrongPlayer), throwsFormatException);
    });
  });

  group('вычисление хода', () {
    test('добавляет ровно один ход и не изменяет исходный документ', () {
      final originalMoves = [_move(0, 0, 'black')];
      final data = _gameData(moves: originalMoves, currentPlayer: 'white');

      final update = buildOnlineMoveUpdate(
        data: data,
        uid: 'white-uid',
        move: (4, -7),
      );

      expect(update['moves'], [
        {'x': 0, 'y': 0, 'player': 'black'},
        {'x': 4, 'y': -7, 'player': 'white'},
      ]);
      expect(update['currentPlayer'], 'black');
      expect(update['active'], isTrue);
      expect(update['winner'], isNull);
      expect(update['version'], 2);
      expect(update.containsKey('updatedAt'), isFalse);
      expect(data['moves'], same(originalMoves));
      expect(originalMoves, hasLength(1));
    });

    test('проверяет участника, активность, очередь и пустую клетку', () {
      final active = _gameData(moves: [_move(0, 0, 'black')]);

      expect(
        () =>
            buildOnlineMoveUpdate(data: active, uid: 'outsider', move: (1, 1)),
        throwsStateError,
      );
      expect(
        () =>
            buildOnlineMoveUpdate(data: active, uid: 'black-uid', move: (1, 1)),
        throwsStateError,
      );
      expect(
        () =>
            buildOnlineMoveUpdate(data: active, uid: 'white-uid', move: (0, 0)),
        throwsStateError,
      );
      expect(
        () => buildOnlineMoveUpdate(
          data: _gameData(active: false, currentPlayer: 'black'),
          uid: 'black-uid',
          move: (1, 1),
        ),
        throwsStateError,
      );
    });

    test('повторная попытка того же игрока не добавляет второй ход', () {
      final initial = _gameData();
      final first = buildOnlineMoveUpdate(
        data: initial,
        uid: 'black-uid',
        move: (0, 0),
      );
      final afterFirst = {...initial, ...first};

      expect(first['moves'], hasLength(1));
      expect(
        () => buildOnlineMoveUpdate(
          data: afterFirst,
          uid: 'black-uid',
          move: (0, 0),
        ),
        throwsStateError,
      );
      expect(afterFirst['moves'], hasLength(1));
    });

    test('завершает игру линией из шести и сохраняет ход победителя', () {
      final data = _gameData(
        moves: [
          _move(0, 0, 'black'),
          _move(10, 0, 'white'),
          _move(1, 0, 'black'),
          _move(10, 2, 'white'),
          _move(2, 0, 'black'),
          _move(10, 4, 'white'),
          _move(4, 0, 'black'),
          _move(10, 6, 'white'),
          _move(5, 0, 'black'),
          _move(10, 8, 'white'),
        ],
        currentPlayer: 'black',
        version: 10,
      );

      final update = buildOnlineMoveUpdate(
        data: data,
        uid: 'black-uid',
        move: (3, 0),
      );

      expect(update['moves'], hasLength(11));
      expect((update['moves']! as List).last, {
        'x': 3,
        'y': 0,
        'player': 'black',
      });
      expect(update['currentPlayer'], 'white');
      expect(update['active'], isFalse);
      expect(update['winner'], 'black');
      expect(update['version'], 11);

      final finished = parseOnlineGame('game', {...data, ...update});
      final state = finished.toGameState();
      expect(state.winner, Player.black);
      expect(state.winningLine, hasLength(6));
      expect(state.history.last, (3, 0));
    });
  });
}

Map<String, Object?> _gameData({
  List<Map<String, Object?>>? moves,
  String? currentPlayer,
  bool active = true,
  int version = 1,
}) {
  return {
    'players': ['black-uid', 'white-uid'],
    'nicknames': {'black-uid': 'Чёрный', 'white-uid': 'Белый'},
    'currentPlayer':
        currentPlayer ?? ((moves?.isEmpty ?? true) ? 'black' : 'white'),
    'moves': moves ?? <Map<String, Object?>>[],
    'active': active,
    'winner': null,
    'version': version,
  };
}

Map<String, Object?> _move(int x, int y, String player) => {
  'x': x,
  'y': y,
  'player': player,
};
