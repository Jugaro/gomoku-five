import 'dart:async';

import 'package:gomoku5/game/board.dart';
import 'package:gomoku5/services/online_backend.dart';

class FakeOnlineBackend implements OnlineBackend {
  final _randomMatchController = StreamController<String?>.broadcast();
  final _invitationsController = StreamController<List<GameInvite>>.broadcast();
  final _acceptedController = StreamController<List<GameInvite>>.broadcast();
  final _gameControllers = <String, StreamController<OnlineGame>>{};
  final _activeGameListeners = <String, int>{};

  int startRandomSearchCalls = 0;
  int cancelRandomSearchCalls = 0;
  int randomMatchWatchCalls = 0;
  int invitationsWatchCalls = 0;
  int gameSubscriptionCancelCalls = 0;

  final sentInvitations = <String>[];
  final acceptedInvitations = <String>[];
  final declinedInvitations = <String>[];
  final watchedGameIds = <String>[];
  final moves = <(String, Pos)>[];
  final acceptGameIds = <String, String>{};

  Object? startRandomSearchError;
  Object? cancelRandomSearchError;
  Object? sendInvitationError;
  Object? acceptInvitationError;
  Object? declineInvitationError;
  Object? makeMoveError;

  @override
  Stream<String?> watchRandomMatch() {
    randomMatchWatchCalls++;
    return _randomMatchController.stream;
  }

  @override
  Future<void> startRandomSearch() async {
    startRandomSearchCalls++;
    final error = startRandomSearchError;
    if (error != null) throw error;
  }

  @override
  Future<void> cancelRandomSearch() async {
    cancelRandomSearchCalls++;
    final error = cancelRandomSearchError;
    if (error != null) throw error;
  }

  @override
  Stream<List<GameInvite>> watchIncomingInvitations() {
    invitationsWatchCalls++;
    return _invitationsController.stream;
  }

  @override
  Stream<List<GameInvite>> watchAcceptedInvitations() {
    return _acceptedController.stream;
  }

  @override
  Future<void> sendInvitation(String nickname) async {
    sentInvitations.add(nickname);
    final error = sendInvitationError;
    if (error != null) throw error;
  }

  @override
  Future<String> acceptInvitation(String invitationId) async {
    acceptedInvitations.add(invitationId);
    final error = acceptInvitationError;
    if (error != null) throw error;
    return acceptGameIds[invitationId] ?? 'game-$invitationId';
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    declinedInvitations.add(invitationId);
    final error = declineInvitationError;
    if (error != null) throw error;
  }

  @override
  Stream<OnlineGame> watchGame(String gameId) {
    watchedGameIds.add(gameId);
    return _gameController(gameId).stream;
  }

  @override
  Future<void> makeMove(String gameId, Pos move) async {
    moves.add((gameId, move));
    final error = makeMoveError;
    if (error != null) throw error;
  }

  void emitRandomMatch(String? gameId) {
    _randomMatchController.add(gameId);
  }

  void emitInvitations(List<GameInvite> invitations) {
    _invitationsController.add(invitations);
  }

  void emitAcceptedInvitations(List<GameInvite> invitations) {
    _acceptedController.add(invitations);
  }

  void emitGame(OnlineGame game) {
    _gameController(game.id).add(game);
  }

  int activeGameListeners(String gameId) => _activeGameListeners[gameId] ?? 0;

  StreamController<OnlineGame> _gameController(String gameId) {
    return _gameControllers.putIfAbsent(gameId, () {
      late final StreamController<OnlineGame> controller;
      controller = StreamController<OnlineGame>.broadcast(
        onListen: () {
          _activeGameListeners[gameId] = activeGameListeners(gameId) + 1;
        },
        onCancel: () {
          _activeGameListeners[gameId] = activeGameListeners(gameId) - 1;
          gameSubscriptionCancelCalls++;
        },
      );
      return controller;
    });
  }

  Future<void> close() async {
    await _randomMatchController.close();
    await _invitationsController.close();
    await _acceptedController.close();
    for (final controller in _gameControllers.values) {
      await controller.close();
    }
  }
}
