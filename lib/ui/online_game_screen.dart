import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart' show firebaseOnlineBackend;
import '../game/board.dart';
import '../services/online_backend.dart';
import 'game_screen.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({
    super.key,
    required this.gameId,
    this.backend,
    this.currentUid,
  });

  final String gameId;
  final OnlineBackend? backend;
  final String? currentUid;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final OnlineBackend _backend;
  late final String? _currentUid;
  StreamSubscription<OnlineGame>? _subscription;
  OnlineGame? _game;
  GameState _state = GameState();
  Object? _streamError;
  bool _sendingMove = false;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? firebaseOnlineBackend;
    _currentUid = widget.currentUid ?? _authenticatedUid();
    _subscribe();
  }

  String? _authenticatedUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  void _subscribe() {
    try {
      _subscription = _backend
          .watchGame(widget.gameId)
          .listen(_onGame, onError: _onStreamError);
    } catch (error) {
      _onStreamError(error);
    }
  }

  void _onGame(OnlineGame game) {
    if (!mounted) return;
    setState(() {
      _game = game;
      _state = game.toGameState();
      _streamError = null;
      _sendingMove = false;
    });
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      _streamError = error;
      _sendingMove = false;
    });
  }

  void _retry() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    setState(() {
      _streamError = null;
      _sendingMove = false;
    });
    _subscribe();
  }

  Player? get _ownColor {
    final game = _game;
    final uid = _currentUid;
    if (game == null ||
        uid == null ||
        game.players.length != 2 ||
        !game.players.contains(uid)) {
      return null;
    }
    return game.colorFor(uid);
  }

  bool get _canMove {
    final game = _game;
    final ownColor = _ownColor;
    return game != null &&
        ownColor != null &&
        game.active &&
        !_state.isOver &&
        _streamError == null &&
        !_sendingMove &&
        game.currentPlayer == ownColor &&
        _state.current == ownColor;
  }

  void _onMove(Pos position) {
    if (!_canMove || _state.stones.containsKey(position)) return;
    setState(() => _sendingMove = true);
    unawaited(_sendMove(position));
  }

  Future<void> _sendMove(Pos position) async {
    try {
      await _backend.makeMove(widget.gameId, position);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingMove = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить ход. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  String _colorName(Player color) => color == Player.black ? 'чёрные' : 'белые';

  String? _uidFor(Player color) {
    final game = _game;
    if (game == null || game.players.length != 2) return null;
    return game.players[color == Player.black ? 0 : 1];
  }

  String _nicknameFor(Player color) {
    final game = _game;
    final uid = _uidFor(color);
    if (game == null || uid == null) return 'Игрок';
    return game.nicknameFor(uid);
  }

  String get _statusText {
    final game = _game;
    if (game == null) return 'Загружаем партию…';
    if (_state.isOver) {
      final winner = _state.winner!;
      return 'Победа: ${_nicknameFor(winner)} (${_colorName(winner)})!';
    }
    if (!game.active) return 'Партия завершена';
    if (_streamError != null) {
      return 'Связь с партией потеряна. Попробуйте обновить экран.';
    }
    if (_currentUid == null) return 'Не удалось определить вашего игрока';
    final ownColor = _ownColor;
    if (ownColor == null) return 'Эта партия доступна только её игрокам';
    if (_sendingMove) return 'Отправляем ход…';
    if (_canMove) return 'Ваш ход · вы играете ${_colorName(ownColor)}';
    return 'Ход соперника: ${_nicknameFor(_state.current)}';
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Онлайн-партия'),
        bottom: game != null && game.players.length == 2
            ? PreferredSize(
                preferredSize: const Size.fromHeight(66),
                child: _PlayersHeader(
                  blackNickname: _nicknameFor(Player.black),
                  whiteNickname: _nicknameFor(Player.white),
                  currentUid: _currentUid,
                  blackUid: game.players[0],
                  whiteUid: game.players[1],
                ),
              )
            : null,
      ),
      body: game == null && _streamError != null
          ? _ConnectionError(onRetry: _retry)
          : game == null
          ? const _GameLoading()
          : GameBoardView(
              state: _state,
              canMove: _canMove,
              onMove: _onMove,
              status: _buildStatus(),
            ),
    );
  }

  Widget _buildStatus() {
    final player = _state.winner ?? _state.current;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (_sendingMove)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            _ColorDot(color: player),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class _PlayersHeader extends StatelessWidget {
  const _PlayersHeader({
    required this.blackNickname,
    required this.whiteNickname,
    required this.currentUid,
    required this.blackUid,
    required this.whiteUid,
  });

  final String blackNickname;
  final String whiteNickname;
  final String? currentUid;
  final String blackUid;
  final String whiteUid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _PlayerBadge(
              nickname: blackNickname,
              color: Player.black,
              isOwn: currentUid == blackUid,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PlayerBadge(
              nickname: whiteNickname,
              color: Player.white,
              isOwn: currentUid == whiteUid,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.nickname,
    required this.color,
    required this.isOwn,
  });

  final String nickname;
  final Player color;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOwn ? const Color(0xFF8B5A3C) : const Color(0xFFD7BE98),
          width: isOwn ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _ColorDot(color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${color == Player.black ? 'Чёрные' : 'Белые'}${isOwn ? ' · вы' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF806147),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Player color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == Player.black ? const Color(0xFF202124) : Colors.white,
        border: Border.all(color: const Color(0xFF5D4037)),
      ),
    );
  }
}

class _GameLoading extends StatelessWidget {
  const _GameLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загружаем партию…'),
        ],
      ),
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Color(0xFFA34F38),
            ),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить партию',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
