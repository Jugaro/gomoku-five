typedef Pos = (int, int);

enum Player { black, white }

extension PlayerExt on Player {
  Player get opponent => this == Player.black ? Player.white : Player.black;
}

class GameState {
  static const List<(int, int)> dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];

  final Map<Pos, Player> stones = {};
  final List<Pos> history = [];

  Player current = Player.black;
  Player? winner;
  List<Pos> winningLine = const [];

  bool get isOver => winner != null;

  bool place(Pos p) {
    if (isOver || stones.containsKey(p)) return false;
    stones[p] = current;
    history.add(p);
    final line = winningLineFrom(p);
    if (line != null) {
      winner = current;
      winningLine = line;
    } else {
      current = current.opponent;
    }
    return true;
  }

  bool undo() {
    if (history.isEmpty) return false;
    final p = history.removeLast();
    final mover = stones.remove(p);
    winner = null;
    winningLine = const [];
    current = mover ?? current;
    return true;
  }

  List<Pos>? winningLineFrom(Pos p) {
    final me = stones[p];
    if (me == null) return null;
    for (final (dx, dy) in dirs) {
      final line = <Pos>[p];
      var i = 1;
      while (stones[(p.$1 + dx * i, p.$2 + dy * i)] == me) {
        line.add((p.$1 + dx * i, p.$2 + dy * i));
        i++;
      }
      i = 1;
      while (stones[(p.$1 - dx * i, p.$2 - dy * i)] == me) {
        line.add((p.$1 - dx * i, p.$2 - dy * i));
        i++;
      }
      if (line.length >= 5) {
        line.sort(
          (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
        );
        return line;
      }
    }
    return null;
  }
}
