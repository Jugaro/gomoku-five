import '../game/board.dart';

class OnlineGame {
  const OnlineGame({
    required this.id,
    required this.players,
    required this.nicknames,
    required this.currentPlayer,
    required this.moves,
    required this.active,
  });

  final String id;
  final List<String> players;
  final Map<String, String> nicknames;
  final Player currentPlayer;
  final List<Pos> moves;
  final bool active;

  Player colorFor(String uid) =>
      players.first == uid ? Player.black : Player.white;

  String nicknameFor(String uid) => nicknames[uid] ?? 'Игрок';

  GameState toGameState() {
    final state = GameState();
    for (final move in moves) {
      state.place(move);
    }
    return state;
  }
}

class GameInvite {
  const GameInvite({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromNickname,
    required this.status,
    this.gameId,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromNickname;
  final String status;
  final String? gameId;
}

abstract class OnlineBackend {
  Stream<String?> watchRandomMatch();
  Future<void> startRandomSearch();
  Future<void> cancelRandomSearch();

  Stream<List<GameInvite>> watchIncomingInvitations();
  Stream<List<GameInvite>> watchAcceptedInvitations();
  Future<void> sendInvitation(String nickname);
  Future<String> acceptInvitation(String invitationId);
  Future<void> declineInvitation(String invitationId);

  Stream<OnlineGame> watchGame(String gameId);
  Future<void> makeMove(String gameId, Pos move);
}
