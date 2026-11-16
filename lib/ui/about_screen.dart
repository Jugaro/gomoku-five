import 'package:material_ui/material_ui.dart';

import 'widgets/home_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Правила')),
      body: HomeBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9EF).withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFD7BE98)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.join_inner_rounded,
                          size: 42,
                          color: Color(0xFFA34F38),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Пять в ряд',
                          style: TextStyle(
                            color: Color(0xFF493024),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Древняя игра на внимание и стратегию. Побеждает не случайность, а точный расчёт.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF826348),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _RuleCard(
                    number: '01',
                    title: 'Ходите по очереди',
                    text: 'Чёрные камни — крестики — ходят первыми. Каждый ход ставит один камень на свободное пересечение линий.',
                  ),
                  const _RuleCard(
                    number: '02',
                    title: 'Соберите пять',
                    text: 'Постройте непрерывный ряд из пяти или более своих камней по горизонтали, вертикали или диагонали.',
                  ),
                  const _RuleCard(
                    number: '03',
                    title: 'Исследуйте доску',
                    text: 'Доска бесконечна: проведите пальцем, чтобы переместить её, и используйте щипок для изменения масштаба.',
                  ),
                  const _RuleCard(
                    number: '04',
                    title: 'Управляйте партией',
                    text: 'На верхней панели можно отменить последний ход или начать новую партию.',
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF603B2C).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          color: Color(0xFF603B2C),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'В игре против ИИ вы ходите первыми чёрными камнями. В режиме для двоих камни передаются по очереди.',
                            style: TextStyle(
                              color: Color(0xFF624632),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9EF).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2CEAB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF603B2C),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFFFFF9EF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF493024),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF765B45),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
