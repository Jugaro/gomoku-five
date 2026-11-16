import 'package:material_ui/material_ui.dart';

class OnlinePanel extends StatelessWidget {
  const OnlinePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFF2DFC0).withValues(alpha: 0.94)
            : const Color(0xFFFFFAF0).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFC8A778)
              : const Color(0xFFDDC6A4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3927).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}
