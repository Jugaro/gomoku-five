import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart' show audioService;
import '../game/board.dart';
import '../settings/settings_controller.dart';
import 'board/ai_worker.dart';
import 'board_painter.dart';
import 'settings_screen.dart';

enum GameMode { ai, twoPlayers }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _boardKey = GlobalKey<GameBoardViewState>();
  late GameState _state = GameState();

  bool _aiThinking = false;
  bool _aiError = false;
  int _gameId = 0;

  bool get _vsAi => widget.mode == GameMode.ai;
  bool get _canMove =>
      !_state.isOver &&
      !_aiThinking &&
      (!_vsAi || _state.current == Player.black);

  void _onBoardMove(Pos position) {
    if (_canMove && _state.place(position)) _afterMove();
  }

  void _afterMove() {
    final vibration = SettingsScope.of(context).value.vibrationEnabled;
    if (_state.isOver) {
      audioService.playWin();
      if (vibration) HapticFeedback.mediumImpact();
    } else {
      audioService.playMove();
      if (vibration) HapticFeedback.selectionClick();
    }
    setState(() => _aiError = false);
    if (!_state.isOver && _vsAi && _state.current == Player.white) {
      _startAiTurn();
    }
  }

  Future<void> _startAiTurn() async {
    if (_state.isOver || !_vsAi || _state.current != Player.white) return;
    final id = ++_gameId;
    final request = AiRequest.fromState(
      _state,
      difficulty: SettingsScope.of(context).value.difficulty,
    );
    setState(() {
      _aiThinking = true;
      _aiError = false;
    });

    final Pos move;
    try {
      move = await compute<AiRequest, Pos>(findAiMove, request);
    } catch (_) {
      if (!mounted || id != _gameId) return;
      setState(() {
        _aiThinking = false;
        _aiError = true;
      });
      return;
    }
    if (!mounted || id != _gameId) return;

    if (!_state.place(move)) {
      setState(() {
        _aiThinking = false;
        _aiError = true;
      });
      return;
    }
    final vibration = SettingsScope.of(context).value.vibrationEnabled;
    if (_state.isOver) {
      audioService.playWin();
      if (vibration) HapticFeedback.mediumImpact();
    } else {
      audioService.playMove();
      if (vibration) HapticFeedback.selectionClick();
    }
    setState(() => _aiThinking = false);
    _boardKey.currentState?.revealLastMove();
  }

  void _undo() {
    if (_state.history.isEmpty) return;
    _gameId++;
    setState(() {
      _aiThinking = false;
      _aiError = false;
      _state.undo();
      if (_vsAi &&
          _state.history.isNotEmpty &&
          _state.current != Player.black) {
        _state.undo();
      }
    });
  }

  void _restart() {
    _gameId++;
    setState(() {
      _state = GameState();
      _aiThinking = false;
      _aiError = false;
    });
    _boardKey.currentState?.resetCamera();
  }

  String get _statusText {
    if (_state.isOver) {
      return 'Победа: ${_state.winner == Player.black ? 'чёрные' : 'белые'}!';
    }
    if (_aiError) return 'ИИ не смог сходить. Попробуйте ещё раз.';
    if (_vsAi) {
      return _aiThinking
          ? 'ИИ обдумывает ход…'
          : 'Ваш ход · вы играете чёрными';
    }
    return 'Ход: ${_state.current == Player.black ? 'чёрные' : 'белые'}';
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_vsAi ? 'Против ИИ' : 'Два игрока'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: GameBoardView(
        key: _boardKey,
        state: _state,
        canMove: _canMove,
        onMove: _onBoardMove,
        status: _buildStatus(),
        onUndo: _state.history.isEmpty ? null : _undo,
        onRestart: _restart,
      ),
    );
  }

  Widget _buildStatus() {
    final player = _state.winner ?? _state.current;
    final isBlack = player == Player.black;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (_aiThinking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBlack ? const Color(0xFF202124) : Colors.white,
                border: Border.all(color: const Color(0xFF5D4037)),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (_aiError)
            TextButton(onPressed: _startAiTurn, child: const Text('Ещё раз')),
        ],
      ),
    );
  }
}

class GameBoardView extends StatefulWidget {
  const GameBoardView({
    super.key,
    required this.state,
    required this.canMove,
    required this.onMove,
    required this.status,
    this.onUndo,
    this.onRestart,
  });

  final GameState state;
  final bool canMove;
  final ValueChanged<Pos> onMove;
  final Widget status;
  final VoidCallback? onUndo;
  final VoidCallback? onRestart;

  @override
  State<GameBoardView> createState() => GameBoardViewState();
}

class GameBoardViewState extends State<GameBoardView> {
  static const double _minScale = 28;
  static const double _maxScale = 112;
  static const double _zoomFactor = 1.3;

  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  Size _viewportSize = Size.zero;
  double _scale = 56;
  double _baseScale = 56;
  double? _settingsBoardScale;
  Offset? _doubleTapFocal;
  Pos? _preview;
  bool _cameraReady = false;
  bool _showGestureHint = true;

  Offset get _viewportCenter =>
      Offset(_viewportSize.width / 2, _viewportSize.height / 2);

  double get _defaultScale =>
      (_settingsBoardScale ?? 56).clamp(_minScale, _maxScale);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final boardScale = SettingsScope.of(context).value.boardScale;
    if (boardScale == _settingsBoardScale) return;
    final previousScale = _scale;
    _settingsBoardScale = boardScale;
    _scale = _defaultScale;
    if (_cameraReady && previousScale != _scale) {
      final focal = _viewportCenter;
      _offset = focal - (focal - _offset) * (_scale / previousScale);
    }
  }

  @override
  void didUpdateWidget(GameBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canMove) _preview = null;
  }

  void _updateViewport(Size size) {
    if (size.isEmpty || size == _viewportSize) return;
    if (!_cameraReady) {
      _viewportSize = size;
      _offset = _viewportCenter;
      _cameraReady = true;
      return;
    }
    final worldAtCenter = (_viewportCenter - _offset) / _scale;
    _viewportSize = size;
    _offset = _viewportCenter - worldAtCenter * _scale;
  }

  Pos _positionAt(Offset localPosition) {
    final world = (localPosition - _offset) / _scale;
    return (world.dx.round(), world.dy.round());
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.canMove) return;
    final position = _positionAt(event.localPosition);
    if (_preview == position && !_showGestureHint) return;
    setState(() {
      _preview = position;
      _showGestureHint = false;
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.canMove) return;
    final position = _positionAt(details.localPosition);
    if (widget.state.stones.containsKey(position)) {
      if (_preview != null) setState(() => _preview = null);
      return;
    }
    widget.onMove(position);
    setState(() {
      _preview = null;
      _showGestureHint = false;
    });
  }

  void _onTapCancel() {
    if (_preview == null) return;
    setState(() => _preview = null);
  }

  void _onHover(PointerHoverEvent event) {
    if (!widget.canMove) {
      if (_preview != null) setState(() => _preview = null);
      return;
    }
    final position = _positionAt(event.localPosition);
    if (position == _preview) return;
    setState(() => _preview = position);
  }

  void _onExit(PointerExitEvent event) {
    if (_preview == null) return;
    setState(() => _preview = null);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
    setState(() {
      _preview = null;
      _showGestureHint = false;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newScale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
    final worldAtFocal = (_startFocal - _startOffset) / _baseScale;
    setState(() {
      _scale = newScale;
      _offset = details.localFocalPoint - worldAtFocal * newScale;
    });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapFocal = details.localPosition;
  }

  void _onDoubleTap() {
    final target = _scale < _maxScale - 1
        ? (_scale * 1.6).clamp(_minScale, _maxScale)
        : _defaultScale;
    _zoomTo(target, _doubleTapFocal);
  }

  void _zoomBy(double factor) => _zoomTo(_scale * factor);

  void _zoomTo(double target, [Offset? focal]) {
    if (!_cameraReady) return;
    final focus = focal ?? _viewportCenter;
    final newScale = target.clamp(_minScale, _maxScale);
    setState(() {
      _offset = focus - (focus - _offset) * (newScale / _scale);
      _scale = newScale;
      _preview = null;
      _showGestureHint = false;
    });
  }

  void _centerOnLastMove() {
    if (!_cameraReady || widget.state.history.isEmpty) return;
    final last = widget.state.history.last;
    setState(() {
      _offset = _centeredOffset(last);
      _preview = null;
      _showGestureHint = false;
    });
  }

  Offset _centeredOffset(Pos position) =>
      _viewportCenter -
      Offset(position.$1.toDouble(), position.$2.toDouble()) * _scale;

  void revealLastMove() {
    if (!_cameraReady || widget.state.history.isEmpty) return;
    final last = widget.state.history.last;
    final screenPosition =
        _offset + Offset(last.$1.toDouble(), last.$2.toDouble()) * _scale;
    final safeArea = Rect.fromLTRB(
      36,
      36,
      _viewportSize.width - 36,
      _viewportSize.height - 148,
    );
    if (!safeArea.contains(screenPosition)) {
      setState(() => _offset = _centeredOffset(last));
    }
  }

  void resetCamera() {
    setState(() {
      _preview = null;
      if (_cameraReady) _offset = _viewportCenter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context).value;
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateViewport(constraints.biggest);
        return Stack(
          children: [
            MouseRegion(
              onHover: _onHover,
              onExit: _onExit,
              child: Listener(
                onPointerDown: _onPointerDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onDoubleTapDown: _onDoubleTapDown,
                  onDoubleTap: _onDoubleTap,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: BoardPainter(
                      state: widget.state,
                      offset: _offset,
                      scale: _scale,
                      showCoordinates: settings.showCoordinates,
                      preview: _preview,
                      previewPlayer: widget.canMove
                          ? widget.state.current
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            if (_showGestureHint)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Card(
                      color: const Color(0xFFFFF8E1),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.swipe, color: Color(0xFF6D4C41)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Коснитесь клетки, чтобы сходить. '
                                  'Перетаскивайте доску, масштабируйте щипком '
                                  'или двойным касанием.',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Скрыть подсказку',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _showGestureHint = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SizedBox(
                      width: double.infinity,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              widget.status,
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    tooltip: 'Отменить ход',
                                    icon: const Icon(Icons.undo),
                                    onPressed: widget.onUndo,
                                  ),
                                  IconButton(
                                    tooltip: 'Уменьшить',
                                    icon: const Icon(Icons.zoom_out),
                                    onPressed: _scale <= _minScale
                                        ? null
                                        : () => _zoomBy(1 / _zoomFactor),
                                  ),
                                  IconButton(
                                    tooltip: 'К последнему ходу',
                                    icon: const Icon(Icons.filter_center_focus),
                                    onPressed: widget.state.history.isEmpty
                                        ? null
                                        : _centerOnLastMove,
                                  ),
                                  IconButton(
                                    tooltip: 'Увеличить',
                                    icon: const Icon(Icons.zoom_in),
                                    onPressed: _scale >= _maxScale
                                        ? null
                                        : () => _zoomBy(_zoomFactor),
                                  ),
                                  IconButton(
                                    tooltip: 'Новая игра',
                                    icon: const Icon(Icons.restart_alt),
                                    onPressed: widget.onRestart,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
