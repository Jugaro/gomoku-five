import '../../game/ai.dart';
import '../../game/board.dart';
import '../../settings/app_settings.dart';

class AiRequest {
  AiRequest.fromState(GameState state, {required this.difficulty})
    : stones = Map<Pos, Player>.of(state.stones),
      history = List<Pos>.of(state.history),
      current = state.current;

  final Map<Pos, Player> stones;
  final List<Pos> history;
  final Player current;
  final AiDifficulty difficulty;
}

Pos findAiMove(AiRequest request) {
  final state = GameState()
    ..stones.addAll(request.stones)
    ..history.addAll(request.history)
    ..current = request.current;
  final ai = switch (request.difficulty) {
    AiDifficulty.easy => GomokuAi(
      maxDepth: 2,
      branching: 6,
      timeBudget: const Duration(milliseconds: 350),
    ),
    AiDifficulty.medium => GomokuAi(),
    AiDifficulty.hard => GomokuAi(
      maxDepth: 5,
      branching: 12,
      timeBudget: const Duration(seconds: 3),
    ),
  };
  return ai.findBestMove(state);
}
