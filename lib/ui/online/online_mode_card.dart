import 'package:material_ui/material_ui.dart';

import 'online_panel.dart';

class OnlineModeCard extends StatelessWidget {
  const OnlineModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return OnlinePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEED9B8),
                ),
                child: Icon(icon, color: const Color(0xFF603B2C), size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF493024),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF806147),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (child != null) ...[const SizedBox(height: 16), child!],
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(actionIcon, size: 20),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF603B2C),
                foregroundColor: const Color(0xFFFFF9EF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
