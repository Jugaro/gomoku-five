import 'package:material_ui/material_ui.dart';

import '../game/board.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({
    required this.state,
    required this.offset,
    required this.scale,
    this.showCoordinates = false,
    this.preview,
    this.previewPlayer,
  });

  final GameState state;
  final Offset offset;
  final double scale;
  final bool showCoordinates;
  final Pos? preview;
  final Player? previewPlayer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8C37E),
    );

    final left = -offset.dx / scale;
    final top = -offset.dy / scale;
    final right = (size.width - offset.dx) / scale;
    final bottom = (size.height - offset.dy) / scale;
    final x0 = left.floor() - 1;
    final x1 = right.ceil() + 1;
    final y0 = top.floor() - 1;
    final y1 = bottom.ceil() + 1;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final grid = Path();
    final majorGrid = Path();
    for (var x = x0; x <= x1; x++) {
      final path = x % 5 == 0 ? majorGrid : grid;
      path
        ..moveTo(x.toDouble(), y0.toDouble())
        ..lineTo(x.toDouble(), y1.toDouble());
    }
    for (var y = y0; y <= y1; y++) {
      final path = y % 5 == 0 ? majorGrid : grid;
      path
        ..moveTo(x0.toDouble(), y.toDouble())
        ..lineTo(x1.toDouble(), y.toDouble());
    }
    canvas.drawPath(
      grid,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF65471F).withValues(alpha: 0.62)
        ..strokeWidth = 1.1 / scale,
    );
    canvas.drawPath(
      majorGrid,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF513713).withValues(alpha: 0.78)
        ..strokeWidth = 1.6 / scale,
    );

    final selected = preview;
    if (selected != null) {
      final occupied = state.stones.containsKey(selected);
      final center = _center(selected);
      final selection = RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: 0.49),
        const Radius.circular(0.08),
      );
      final color = occupied
          ? const Color(0xFFC62828)
          : const Color(0xFFFFC107);
      canvas.drawRRect(
        selection,
        Paint()..color = color.withValues(alpha: occupied ? 0.14 : 0.24),
      );
      canvas.drawRRect(
        selection,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale
          ..color = color.withValues(alpha: 0.9),
      );
    }

    for (final entry in state.stones.entries) {
      _paintStone(canvas, _center(entry.key), entry.value);
    }

    if (selected != null &&
        previewPlayer != null &&
        !state.stones.containsKey(selected)) {
      _paintStone(canvas, _center(selected), previewPlayer!, opacity: 0.48);
    }

    if (state.isOver && state.winningLine.isNotEmpty) {
      final a = _center(state.winningLine.first);
      final b = _center(state.winningLine.last);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFB71C1C).withValues(alpha: 0.88)
          ..strokeWidth = 7 / scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFFFE082)
          ..strokeWidth = 2.4 / scale
          ..strokeCap = StrokeCap.round,
      );
      for (final position in state.winningLine) {
        canvas.drawCircle(
          _center(position),
          0.48,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / scale
            ..color = const Color(0xFFB71C1C),
        );
      }
    }

    final last = state.history.isEmpty ? null : state.history.last;
    if (last != null) {
      final center = _center(last);
      canvas.drawCircle(
        center,
        0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5 / scale
          ..color = Colors.black.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        center,
        0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / scale
          ..color = const Color(0xFFFFC107),
      );
      canvas.drawCircle(
        center,
        0.065,
        Paint()..color = const Color(0xFFFFC107),
      );
    }

    canvas.restore();

    if (showCoordinates) {
      _paintCoordinates(canvas, size, x0, x1, y0, y1);
    }
  }

  Offset _center(Pos position) =>
      Offset(position.$1.toDouble(), position.$2.toDouble());

  void _paintStone(
    Canvas canvas,
    Offset center,
    Player player, {
    double opacity = 1,
  }) {
    const radius = 0.445;
    final isBlack = player == Player.black;
    if (opacity == 1) {
      canvas.drawCircle(
        center + Offset(1.5 / scale, 2.5 / scale),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 / scale),
      );
    }

    final colors = isBlack
        ? const [Color(0xFF65676B), Color(0xFF25262A), Color(0xFF090A0C)]
        : const [Color(0xFFFFFFFF), Color(0xFFF2F0E9), Color(0xFFB9B8B2)];
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 0.95,
          colors: [
            for (final color in colors) color.withValues(alpha: opacity),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / scale
        ..color = (isBlack ? Colors.black : const Color(0xFF686862)).withValues(
          alpha: 0.8 * opacity,
        ),
    );
    canvas.drawCircle(
      center + const Offset(-0.14, -0.16),
      0.105,
      Paint()
        ..color = Colors.white.withValues(
          alpha: (isBlack ? 0.22 : 0.72) * opacity,
        ),
    );
  }

  void _paintCoordinates(
    Canvas canvas,
    Size size,
    int x0,
    int x1,
    int y0,
    int y1,
  ) {
    final step = (52 / scale).ceil();
    for (var x = x0; x <= x1; x++) {
      if (x % step != 0) continue;
      final screenX = offset.dx + x * scale;
      if (screenX < 30 || screenX > size.width - 30) continue;
      _paintCoordinateLabel(canvas, '$x', Offset(screenX + 3, 4));
    }
    for (var y = y0; y <= y1; y++) {
      if (y % step != 0) continue;
      final screenY = offset.dy + y * scale;
      if (screenY < 28 || screenY > size.height - 22) continue;
      _paintCoordinateLabel(canvas, '$y', Offset(4, screenY + 3));
    }
  }

  void _paintCoordinateLabel(Canvas canvas, String text, Offset position) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF3E2A14),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final background = RRect.fromRectAndRadius(
      (position & label.size).inflate(2),
      const Radius.circular(3),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xE6F5DEA8));
    label.paint(canvas, position);
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
