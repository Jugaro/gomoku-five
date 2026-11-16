import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'about_screen.dart';
import 'game_screen.dart';
import 'online_screen.dart';
import 'settings_screen.dart';
import 'widgets/brand_logo.dart';
import 'widgets/home_background.dart';
import 'widgets/menu_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openGame(BuildContext context, GameMode mode) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => GameScreen(mode: mode)));
  }

  void _openOnline(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const OnlineScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 690;
              final logoSize = math.min(
                184.0,
                math.max(116.0, constraints.maxHeight * (compact ? 0.2 : 0.24)),
              );
              final verticalPadding = compact ? 16.0 : 26.0;
              final contentHeight = math.max(
                0.0,
                constraints.maxHeight - verticalPadding * 2,
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BrandLogo(size: logoSize),
                          SizedBox(height: compact ? 16 : 22),
                          const Text(
                            'Пять в ряд',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF493024),
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 1,
                                color: const Color(0xFFAD8760),
                              ),
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                color: const Color(0xFFA34F38),
                              ),
                              Container(
                                width: 28,
                                height: 1,
                                color: const Color(0xFFAD8760),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Тишина доски. Искусство победы.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF826348),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.25,
                            ),
                          ),
                          SizedBox(height: compact ? 22 : 30),
                          MenuButton(
                            label: 'Против ИИ',
                            icon: Icons.smart_toy_outlined,
                            primary: true,
                            onPressed: () => _openGame(context, GameMode.ai),
                          ),
                          const SizedBox(height: 12),
                          MenuButton(
                            label: 'Два игрока',
                            icon: Icons.people_alt_outlined,
                            onPressed: () =>
                                _openGame(context, GameMode.twoPlayers),
                          ),
                          const SizedBox(height: 12),
                          MenuButton(
                            label: 'Онлайн',
                            icon: Icons.public_outlined,
                            onPressed: () => _openOnline(context),
                          ),
                          const SizedBox(height: 18),
                          const _SecondaryActions(),
                          SizedBox(height: compact ? 4 : 14),
                          const Text(
                            'БЕСКОНЕЧНАЯ ДОСКА  •  ПЯТЬ В РЯД',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9A7959),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions();

  @override
  Widget build(BuildContext context) {
    final stackButtons = MediaQuery.textScalerOf(context).scale(16) > 20;
    final settings = _SecondaryButton(
      label: 'Настройки',
      icon: Icons.tune_rounded,
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      },
    );
    final rules = _SecondaryButton(
      label: 'Правила',
      icon: Icons.menu_book_outlined,
      onPressed: () {
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
      },
    );

    if (stackButtons) {
      return Column(children: [settings, const SizedBox(height: 10), rules]);
    }
    return Row(
      children: [
        Expanded(child: settings),
        const SizedBox(width: 12),
        Expanded(child: rules),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF624632),
          backgroundColor: const Color(0xFFFFF9EF).withValues(alpha: 0.46),
          side: const BorderSide(color: Color(0xFFD7BE98)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
