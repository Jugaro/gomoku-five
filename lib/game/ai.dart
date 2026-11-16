import 'board.dart';

class GomokuAi {
  GomokuAi({
    this.maxDepth = 4,
    this.branching = 10,
    this.timeBudget = const Duration(seconds: 2),
  });

  final int maxDepth;
  final int branching;
  final Duration timeBudget;

  static const int _win = 1 << 24;
  static const int _inf = 1 << 30;

  Pos findBestMove(GameState state) {
    if (state.stones.isEmpty) return (0, 0);
    final stopwatch = Stopwatch()..start();
    var candidates = _candidates(state, limit: branching);
    Pos? best;
    for (var depth = 1; depth <= maxDepth && stopwatch.elapsed < timeBudget; depth++) {
      final move = _rootSearch(state, candidates, depth, stopwatch);
      if (move == null) break;
      best = move;
      candidates = [best, ...candidates.where((c) => c != best)];
    }
    return best ?? candidates.first;
  }

  Pos? _rootSearch(GameState state, List<Pos> candidates, int depth, Stopwatch sw) {
    try {
      var bestVal = -_inf;
      Pos? bestMove;
      for (final move in candidates) {
        state.place(move);
        final val = -_negamax(state, depth - 1, -_inf, _inf, sw);
        state.undo();
        if (val > bestVal) {
          bestVal = val;
          bestMove = move;
        }
      }
      return bestMove;
    } on _TimeUp {
      return null;
    }
  }

  int _negamax(GameState state, int depth, int alpha, int beta, Stopwatch sw) {
    if (state.isOver) return -_win - depth;
    if (depth == 0) return _evaluate(state);
    if (sw.elapsed > timeBudget) throw const _TimeUp();
    final moves = _candidates(state, limit: branching);
    if (moves.isEmpty) return _evaluate(state);
    var best = -_inf;
    for (final move in moves) {
      state.place(move);
      final val = -_negamax(state, depth - 1, -beta, -alpha, sw);
      state.undo();
      if (val > best) best = val;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _evaluate(GameState state) {
    final me = state.current;
    return _boardScore(state, me) - _boardScore(state, me.opponent) * 11 ~/ 10;
  }

  int _boardScore(GameState state, Player player) {
    var total = 0;
    for (final entry in state.stones.entries) {
      if (entry.value != player) continue;
      final p = entry.key;
      for (final (dx, dy) in GameState.dirs) {
        if (state.stones[(p.$1 - dx, p.$2 - dy)] == player) continue;
        var len = 1;
        var nx = p.$1 + dx;
        var ny = p.$2 + dy;
        while (state.stones[(nx, ny)] == player) {
          len++;
          nx += dx;
          ny += dy;
        }
        final open = (state.stones[(p.$1 - dx, p.$2 - dy)] == null ? 1 : 0) +
            (state.stones[(nx, ny)] == null ? 1 : 0);
        total += _patternScore(len, open);
      }
    }
    return total;
  }

  List<Pos> _candidates(GameState state, {required int limit}) {
    final empty = <Pos>{};
    for (final p in state.stones.keys) {
      for (var dx = -2; dx <= 2; dx++) {
        for (var dy = -2; dy <= 2; dy++) {
          final q = (p.$1 + dx, p.$2 + dy);
          if (!state.stones.containsKey(q)) empty.add(q);
        }
      }
    }
    final me = state.current;
    final scored = [
      for (final q in empty)
        (
          q,
          _moveScore(state, q, me) + _moveScore(state, q, me.opponent) * 9 ~/ 10,
        ),
    ];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  int _moveScore(GameState state, Pos pos, Player player) {
    var total = 0;
    for (final (dx, dy) in GameState.dirs) {
      var forward = 0;
      var nx = pos.$1 + dx;
      var ny = pos.$2 + dy;
      while (state.stones[(nx, ny)] == player) {
        forward++;
        nx += dx;
        ny += dy;
      }
      var backward = 0;
      var bx = pos.$1 - dx;
      var by = pos.$2 - dy;
      while (state.stones[(bx, by)] == player) {
        backward++;
        bx -= dx;
        by -= dy;
      }
      final open = (state.stones[(nx, ny)] == null ? 1 : 0) +
          (state.stones[(bx, by)] == null ? 1 : 0);
      total += _patternScore(1 + forward + backward, open);
    }
    return total;
  }

  int _patternScore(int len, int open) {
    if (len >= 5) return _win;
    if (open == 0) return 0;
    return switch (len) {
      4 => open == 2 ? 100000 : 10000,
      3 => open == 2 ? 5000 : 800,
      2 => open == 2 ? 500 : 80,
      1 => 10,
      _ => 0,
    };
  }
}

class _TimeUp implements Exception {
  const _TimeUp();
}
