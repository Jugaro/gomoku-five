import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../game/board.dart';
import 'online_backend.dart';

class FirebaseOnlineBackend implements OnlineBackend {
  FirebaseOnlineBackend({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Нет подключения к серверу');
    }
    return user;
  }

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');
  CollectionReference<Map<String, dynamic>> get _queue =>
      _firestore.collection('queue');
  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('invitations');
  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  @override
  Stream<String?> watchRandomMatch() {
    final uid = _user.uid;
    return _queue.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null || data['status'] != 'matched') return null;
      final gameId = data['gameId'];
      return gameId is String && gameId.isNotEmpty ? gameId : null;
    });
  }

  @override
  Future<void> startRandomSearch() async {
    final uid = _user.uid;
    final nickname = await _loadOwnNickname(uid);
    final ownQueue = _queue.doc(uid);
    final existingOwn = await ownQueue.get();
    final existingOwnData = existingOwn.data();
    if (existingOwnData?['status'] == 'matched') return;
    if (existingOwnData?['status'] != 'waiting') {
      await ownQueue.set({
        'uid': uid,
        'nickname': nickname,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (existingOwnData?['uid'] != uid ||
        existingOwnData?['nickname'] != nickname ||
        existingOwnData?.containsKey('gameId') == true) {
      await ownQueue.update({
        'uid': uid,
        'nickname': nickname,
        'gameId': FieldValue.delete(),
      });
    }

    final waiting = await _queue
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt')
        .limit(2)
        .get();
    DocumentReference<Map<String, dynamic>>? candidateQueue;
    for (final document in waiting.docs) {
      if (document.id != uid) {
        candidateQueue = document.reference;
        break;
      }
    }

    final game = _games.doc();
    await _firestore.runTransaction<void>((transaction) async {
      final ownSnapshot = await transaction.get(ownQueue);
      final ownData = ownSnapshot.data();
      if (ownData?['status'] == 'matched') return;

      final candidateSnapshot = candidateQueue == null
          ? null
          : await transaction.get(candidateQueue);
      final candidateData = candidateSnapshot?.data();
      final candidateUid = candidateData?['uid'];
      final candidateIsWaiting =
          candidateSnapshot != null &&
          candidateSnapshot.exists &&
          candidateSnapshot.id != uid &&
          candidateUid == candidateSnapshot.id &&
          candidateData?['status'] == 'waiting';

      if (!candidateIsWaiting) {
        _writeWaitingQueueEntry(transaction, ownQueue, ownData, uid, nickname);
        return;
      }

      final ownIsOlder = _ownQueueIsOlder(
        ownData: ownData,
        ownUid: uid,
        candidateData: candidateData!,
        candidateUid: candidateUid as String,
      );
      final blackUid = ownIsOlder ? uid : candidateUid;
      final whiteUid = ownIsOlder ? candidateUid : uid;
      final candidateNickname = _nicknameFromData(candidateData);
      final blackNickname = ownIsOlder ? nickname : candidateNickname;
      final whiteNickname = ownIsOlder ? candidateNickname : nickname;

      transaction.set(
        game,
        _newGameData(
          blackUid: blackUid,
          whiteUid: whiteUid,
          blackNickname: blackNickname,
          whiteNickname: whiteNickname,
        ),
      );
      transaction.update(ownQueue, {'status': 'matched', 'gameId': game.id});
      transaction.update(candidateSnapshot.reference, {
        'status': 'matched',
        'gameId': game.id,
      });
    });
  }

  @override
  Future<void> cancelRandomSearch() {
    return _queue.doc(_user.uid).delete();
  }

  @override
  Stream<List<GameInvite>> watchIncomingInvitations() {
    final uid = _user.uid;
    return _invitations
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => parseGameInvite(document.id, document.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<GameInvite>> watchAcceptedInvitations() {
    final uid = _user.uid;
    return _invitations.where('fromUid', isEqualTo: uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((document) => parseGameInvite(document.id, document.data()))
          .where((invite) => invite.status == 'accepted' && invite.gameId != null)
          .toList(growable: false),
    );
  }

  @override
  Future<void> sendInvitation(String nickname) async {
    final uid = _user.uid;
    final fromNickname = await _loadOwnNickname(uid);
    final nicknameLower = nickname.trim().toLowerCase();
    if (nicknameLower.isEmpty) {
      throw ArgumentError.value(
        nickname,
        'nickname',
        'Никнейм не может быть пустым',
      );
    }

    final profiles = await _publicProfiles
        .where('nicknameLower', isEqualTo: nicknameLower)
        .limit(2)
        .get();
    DocumentSnapshot<Map<String, dynamic>>? recipient;
    var foundOwnProfile = false;
    for (final profile in profiles.docs) {
      if (profile.id == uid) {
        foundOwnProfile = true;
      } else {
        recipient = profile;
        break;
      }
    }
    if (recipient == null) {
      throw StateError(
        foundOwnProfile ? 'Нельзя пригласить самого себя' : 'Игрок не найден',
      );
    }

    final pending = await _invitations
        .where('fromUid', isEqualTo: uid)
        .where('toUid', isEqualTo: recipient.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    final existing = pending.docs.isEmpty ? null : pending.docs.first.reference;
    final invitation = _invitations.doc();

    await _firestore.runTransaction<void>((transaction) async {
      if (existing != null) {
        final snapshot = await transaction.get(existing);
        if (snapshot.data()?['status'] == 'pending') return;
      }
      transaction.set(invitation, {
        'fromUid': uid,
        'toUid': recipient!.id,
        'fromNickname': fromNickname,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String> acceptInvitation(String invitationId) {
    final uid = _user.uid;
    final invitation = _invitations.doc(invitationId);
    final ownProfile = _publicProfiles.doc(uid);
    final game = _games.doc();

    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(invitation);
      final data = snapshot.data();
      if (data == null) throw StateError('Приглашение не найдено');
      if (data['toUid'] != uid) {
        throw StateError('Принять приглашение может только получатель');
      }

      final status = data['status'];
      if (status == 'accepted') {
        final gameId = data['gameId'];
        if (gameId is String && gameId.isNotEmpty) return gameId;
        throw const FormatException(
          'У принятого приглашения отсутствует gameId',
        );
      }
      if (status != 'pending') {
        throw StateError('Приглашение уже обработано');
      }

      final fromUid = data['fromUid'];
      if (fromUid is! String || fromUid.isEmpty || fromUid == uid) {
        throw const FormatException('Некорректный отправитель приглашения');
      }
      final profileSnapshot = await transaction.get(ownProfile);
      final ownNickname = _nicknameFromData(profileSnapshot.data());
      final fromNickname = _nicknameFromData(data, key: 'fromNickname');

      transaction.set(
        game,
        _newGameData(
          blackUid: fromUid,
          whiteUid: uid,
          blackNickname: fromNickname,
          whiteNickname: ownNickname,
        ),
      );
      transaction.update(invitation, {'status': 'accepted', 'gameId': game.id});
      return game.id;
    });
  }

  @override
  Future<void> declineInvitation(String invitationId) {
    final uid = _user.uid;
    final invitation = _invitations.doc(invitationId);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(invitation);
      final data = snapshot.data();
      if (data == null) throw StateError('Приглашение не найдено');
      if (data['toUid'] != uid) {
        throw StateError('Отклонить приглашение может только получатель');
      }
      final status = data['status'];
      if (status == 'declined') return;
      if (status != 'pending') {
        throw StateError('Приглашение уже обработано');
      }
      transaction.update(invitation, {'status': 'declined'});
    });
  }

  @override
  Stream<OnlineGame> watchGame(String gameId) {
    final uid = _user.uid;
    return _games.doc(gameId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) throw StateError('Игра не найдена');
      final game = parseOnlineGame(snapshot.id, data);
      if (!game.players.contains(uid)) {
        throw StateError('Игра доступна только её участникам');
      }
      return game;
    });
  }

  @override
  Future<void> makeMove(String gameId, Pos move) {
    final uid = _user.uid;
    final game = _games.doc(gameId);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(game);
      final data = snapshot.data();
      if (data == null) throw StateError('Игра не найдена');
      final update = buildOnlineMoveUpdate(data: data, uid: uid, move: move);
      transaction.update(game, {
        ...update,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> _loadOwnNickname(String uid) async {
    final snapshot = await _publicProfiles.doc(uid).get();
    return _nicknameFromData(snapshot.data());
  }
}

void _writeWaitingQueueEntry(
  Transaction transaction,
  DocumentReference<Map<String, dynamic>> reference,
  Map<String, dynamic>? currentData,
  String uid,
  String nickname,
) {
  if (currentData?['status'] == 'waiting') {
    transaction.update(reference, {
      'uid': uid,
      'nickname': nickname,
      'gameId': FieldValue.delete(),
    });
    return;
  }
  transaction.set(reference, {
    'uid': uid,
    'nickname': nickname,
    'status': 'waiting',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

bool _ownQueueIsOlder({
  required Map<String, dynamic>? ownData,
  required String ownUid,
  required Map<String, dynamic> candidateData,
  required String candidateUid,
}) {
  if (ownData?['status'] != 'waiting') return false;
  final ownCreatedAt = ownData?['createdAt'];
  final candidateCreatedAt = candidateData['createdAt'];
  if (ownCreatedAt is! Timestamp) return false;
  if (candidateCreatedAt is! Timestamp) return true;
  final comparison = ownCreatedAt.compareTo(candidateCreatedAt);
  if (comparison == 0) return ownUid.compareTo(candidateUid) < 0;
  return comparison < 0;
}

Map<String, Object?> _newGameData({
  required String blackUid,
  required String whiteUid,
  required String blackNickname,
  required String whiteNickname,
}) {
  return {
    'players': [blackUid, whiteUid],
    'nicknames': {blackUid: blackNickname, whiteUid: whiteNickname},
    'currentPlayer': 'black',
    'moves': <Map<String, Object?>>[],
    'active': true,
    'winner': null,
    'version': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

String _nicknameFromData(
  Map<String, dynamic>? data, {
  String key = 'nickname',
}) {
  final nickname = data?[key];
  if (nickname is! String || nickname.trim().isEmpty) {
    throw StateError('Сначала сохраните ник в облачном профиле');
  }
  return nickname.trim();
}

@visibleForTesting
OnlineGame parseOnlineGame(String id, Map<String, Object?> data) {
  return _parseOnlineGame(data, id: id).game;
}

@visibleForTesting
GameInvite parseGameInvite(String id, Map<String, Object?> data) {
  final fromUid = data['fromUid'];
  final toUid = data['toUid'];
  final fromNickname = data['fromNickname'];
  final status = data['status'];
  final gameId = data['gameId'];
  if (fromUid is! String || fromUid.isEmpty) {
    throw const FormatException('Некорректный fromUid приглашения');
  }
  if (toUid is! String || toUid.isEmpty) {
    throw const FormatException('Некорректный toUid приглашения');
  }
  if (fromNickname is! String || fromNickname.trim().isEmpty) {
    throw const FormatException('Некорректный ник отправителя');
  }
  if (status is! String ||
      !const {'pending', 'accepted', 'declined'}.contains(status)) {
    throw const FormatException('Некорректный статус приглашения');
  }
  if (gameId != null && (gameId is! String || gameId.isEmpty)) {
    throw const FormatException('Некорректный gameId приглашения');
  }
  return GameInvite(
    id: id,
    fromUid: fromUid,
    toUid: toUid,
    fromNickname: fromNickname,
    status: status,
    gameId: gameId as String?,
  );
}

@visibleForTesting
Map<String, Object?> buildOnlineMoveUpdate({
  required Map<String, Object?> data,
  required String uid,
  required Pos move,
}) {
  final parsed = _parseOnlineGame(data);
  final game = parsed.game;
  if (!game.active) throw StateError('Игра уже завершена');
  final playerIndex = game.players.indexOf(uid);
  if (playerIndex < 0) throw StateError('Ходить может только участник игры');
  final player = playerIndex == 0 ? Player.black : Player.white;
  if (game.currentPlayer != player) {
    throw StateError('Сейчас ход соперника');
  }

  final state = parsed.state;
  if (state.isOver || state.current != player) {
    throw const FormatException('Состояние игры противоречит списку ходов');
  }
  if (state.stones.containsKey(move)) {
    throw StateError('Эта клетка уже занята');
  }
  if (!state.place(move)) throw StateError('Ход недоступен');

  final version = data['version'];
  if (version is! int || version < 0) {
    throw const FormatException('Некорректная версия игры');
  }
  final winner = state.winner;
  return {
    'moves': [
      for (final previous in parsed.moves) previous.toMap(),
      {'x': move.$1, 'y': move.$2, 'player': player.name},
    ],
    'currentPlayer': player.opponent.name,
    'active': winner == null,
    'winner': winner?.name,
    'version': version + 1,
  };
}

class _ParsedOnlineGame {
  const _ParsedOnlineGame({
    required this.game,
    required this.moves,
    required this.state,
  });

  final OnlineGame game;
  final List<_OnlineMove> moves;
  final GameState state;
}

class _OnlineMove {
  const _OnlineMove(this.position, this.player);

  final Pos position;
  final Player player;

  Map<String, Object?> toMap() => {
    'x': position.$1,
    'y': position.$2,
    'player': player.name,
  };
}

_ParsedOnlineGame _parseOnlineGame(
  Map<String, Object?> data, {
  String id = '',
}) {
  final rawPlayers = data['players'];
  if (rawPlayers is! List ||
      rawPlayers.length != 2 ||
      rawPlayers.any((uid) => uid is! String || uid.isEmpty)) {
    throw const FormatException('В игре должно быть два участника');
  }
  final players = rawPlayers.cast<String>().toList(growable: false);
  if (players[0] == players[1]) {
    throw const FormatException('Участники игры должны быть разными');
  }

  final rawNicknames = data['nicknames'];
  if (rawNicknames is! Map) {
    throw const FormatException('Некорректные ники участников');
  }
  final nicknames = <String, String>{};
  for (final uid in players) {
    final nickname = rawNicknames[uid];
    if (nickname is! String || nickname.isEmpty) {
      throw const FormatException('Некорректные ники участников');
    }
    nicknames[uid] = nickname;
  }

  final currentPlayer = _playerFromName(data['currentPlayer']);
  final active = data['active'];
  if (active is! bool) throw const FormatException('Некорректный статус игры');
  final moves = _parseMoves(data['moves']);
  final state = GameState();
  for (final move in moves) {
    if (state.current != move.player || !state.place(move.position)) {
      throw const FormatException('Некорректный порядок ходов');
    }
  }

  return _ParsedOnlineGame(
    game: OnlineGame(
      id: id,
      players: players,
      nicknames: nicknames,
      currentPlayer: currentPlayer,
      moves: moves.map((move) => move.position).toList(growable: false),
      active: active,
    ),
    moves: moves,
    state: state,
  );
}

List<_OnlineMove> _parseMoves(Object? rawMoves) {
  if (rawMoves is! List) {
    throw const FormatException('Некорректный список ходов');
  }
  final moves = <_OnlineMove>[];
  for (final rawMove in rawMoves) {
    if (rawMove is! Map) throw const FormatException('Некорректный ход');
    final x = rawMove['x'];
    final y = rawMove['y'];
    if (x is! int || y is! int) {
      throw const FormatException('Некорректные координаты хода');
    }
    moves.add(_OnlineMove((x, y), _playerFromName(rawMove['player'])));
  }
  return moves;
}

Player _playerFromName(Object? name) {
  return switch (name) {
    'black' => Player.black,
    'white' => Player.white,
    _ => throw const FormatException('Некорректный цвет игрока'),
  };
}
