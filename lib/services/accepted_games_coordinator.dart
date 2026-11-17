import 'dart:async';

import 'online_backend.dart';

class AcceptedGamesCoordinator {
  AcceptedGamesCoordinator({
    required this._backend,
    required this._openGame,
  });

  final OnlineBackend _backend;
  final void Function(String gameId) _openGame;
  final _openedGameIds = <String>{};
  StreamSubscription<List<GameInvite>>? _subscription;

  void start() {
    if (_subscription != null) return;
    _subscription = _backend.watchAcceptedInvitations().listen(
      _onAcceptedInvitations,
      onError: (_) {},
    );
  }

  void _onAcceptedInvitations(List<GameInvite> invitations) {
    for (final invitation in invitations) {
      final gameId = invitation.gameId;
      if (invitation.status != 'accepted' ||
          gameId == null ||
          gameId.isEmpty ||
          !_openedGameIds.add(gameId)) {
        continue;
      }
      _openGame(gameId);
      break;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
