import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/game/board.dart';

void main() {
  GameState play(List<(Player, int, int)> moves) {
    final s = GameState();
    for (final (player, x, y) in moves) {
      expect(s.current, player, reason: 'нарушено чередование ходов');
      expect(s.place((x, y)), isTrue);
    }
    return s;
  }

  test('ходы чередуются, занятую клетку поставить нельзя', () {
    final s = GameState();
    expect(s.current, Player.black);
    expect(s.place((0, 0)), isTrue);
    expect(s.current, Player.white);
    expect(s.place((0, 0)), isFalse);
    expect(s.place((1, 1)), isTrue);
    expect(s.stones, hasLength(2));
  });

  test('пять в ряд по горизонтали — победа', () {
    final s = play([
      (Player.black, 0, 0),
      (Player.white, 10, 0),
      (Player.black, 1, 0),
      (Player.white, 10, 1),
      (Player.black, 2, 0),
      (Player.white, 10, 2),
      (Player.black, 3, 0),
      (Player.white, 10, 3),
      (Player.black, 4, 0),
    ]);
    expect(s.winner, Player.black);
    expect(s.winningLine, hasLength(5));
    expect(s.place((5, 0)), isFalse, reason: 'после победы ходы запрещены');
  });

  test('пять в ряд по диагонали (/) — победа', () {
    final s = play([
      (Player.black, 0, 3),
      (Player.white, 10, 0),
      (Player.black, 1, 2),
      (Player.white, 10, 1),
      (Player.black, 2, 1),
      (Player.white, 10, 2),
      (Player.black, 3, 0),
      (Player.white, 10, 3),
      (Player.black, 4, -1),
    ]);
    expect(s.winner, Player.black);
    expect(s.winningLine, hasLength(5));
  });

  test('пять в ряд по диагонали (\\) — победа', () {
    final s = play([
      (Player.black, 0, 0),
      (Player.white, 10, 0),
      (Player.black, 1, 1),
      (Player.white, 10, 1),
      (Player.black, 2, 2),
      (Player.white, 10, 2),
      (Player.black, 3, 3),
      (Player.white, 10, 3),
      (Player.black, 4, 4),
    ]);
    expect(s.winner, Player.black);
  });

  test('линия длиннее пяти тоже засчитывается, закрытая четвёрка — нет', () {
    final six = GameState();
    for (var x = 0; x < 6; x++) {
      six.stones[(x, 0)] = Player.black;
    }
    expect(six.winningLineFrom((2, 0)), hasLength(6));

    final closedFour = play([
      (Player.black, 0, 0),
      (Player.white, 5, 5),
      (Player.black, 1, 0),
      (Player.white, 5, 6),
      (Player.black, 2, 0),
      (Player.white, 5, 7),
      (Player.black, 3, 0),
      (Player.white, 4, 0),
    ]);
    expect(closedFour.winner, isNull);
    expect(closedFour.winningLine, isEmpty);
  });

  test('вертикальная линия засчитывается', () {
    final s = play([
      (Player.black, 7, -2),
      (Player.white, 10, 0),
      (Player.black, 7, -1),
      (Player.white, 10, 1),
      (Player.black, 7, 0),
      (Player.white, 10, 2),
      (Player.black, 7, 1),
      (Player.white, 10, 3),
      (Player.black, 7, 2),
    ]);
    expect(s.winner, Player.black);
  });

  test('undo откатывает ход и победу', () {
    final s = GameState()
      ..place((0, 0))
      ..place((1, 1));
    expect(s.undo(), isTrue);
    expect(s.stones, hasLength(1));
    expect(s.current, Player.white);

    final winning = play([
      (Player.black, 0, 0),
      (Player.white, 10, 0),
      (Player.black, 1, 0),
      (Player.white, 10, 1),
      (Player.black, 2, 0),
      (Player.white, 10, 2),
      (Player.black, 3, 0),
      (Player.white, 10, 3),
      (Player.black, 4, 0),
    ]);
    expect(winning.undo(), isTrue);
    expect(winning.winner, isNull);
    expect(winning.current, Player.black);
    expect(winning.place((4, 0)), isTrue);
    expect(winning.winner, Player.black);
  });
}
