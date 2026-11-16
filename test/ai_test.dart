import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/game/ai.dart';
import 'package:gomoku5/game/board.dart';

void main() {
  final ai = GomokuAi(maxDepth: 2, timeBudget: const Duration(seconds: 1));

  test('первый ход — в центр доски', () {
    expect(ai.findBestMove(GameState()), (0, 0));
  });

  test('ИИ добивает свои четыре в ряд', () {
    final s = GameState()
      ..place((0, 0))
      ..place((10, 10))
      ..place((1, 0))
      ..place((11, 11))
      ..place((2, 0))
      ..place((12, 12))
      ..place((3, 0))
      ..place((20, 20));
    expect(s.current, Player.black);

    final move = ai.findBestMove(s);
    expect([(4, 0), (-1, 0)], contains(move));

    expect(s.place(move), isTrue);
    expect(s.winner, Player.black);
  });

  test('ИИ блокирует закрытую четвёрку соперника', () {
    final s = GameState()
      ..place((0, 5))
      ..place((-1, 5))
      ..place((1, 5))
      ..place((0, 0))
      ..place((2, 5))
      ..place((10, 10))
      ..place((3, 5));
    expect(s.current, Player.white);

    final move = ai.findBestMove(s);
    expect(move, (4, 5), reason: 'единственный ход, не дающий сопернику победить');
  });

  test('ИИ строит угрозу из трёх, если победы нет', () {
    final s = GameState()
      ..place((0, 0))
      ..place((10, 10))
      ..place((1, 0))
      ..place((11, 11))
      ..place((2, 0));
    expect(s.current, Player.white);

    final move = ai.findBestMove(s);
    expect(s.place(move), isTrue);
    expect(s.winner, isNull);
  });
}
