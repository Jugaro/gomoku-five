import 'package:material_ui/material_ui.dart';

import '../app_services.dart' as app_services;
import '../services/audio_service.dart';
import '../settings/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.audioService});

  final AudioService? audioService;

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final settings = controller.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                const _SectionTitle('Доска и игра'),
                const SizedBox(height: 8),
                Text('Размер клетки: ${settings.boardScale.round()} px'),
                Slider(
                  value: settings.boardScale,
                  min: SettingsController.minBoardScale,
                  max: SettingsController.maxBoardScale,
                  divisions: 84,
                  label: '${settings.boardScale.round()} px',
                  onChanged: controller.setBoardScale,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AiDifficulty>(
                  initialValue: settings.difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Сложность ИИ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AiDifficulty.easy,
                      child: Text('Лёгкий'),
                    ),
                    DropdownMenuItem(
                      value: AiDifficulty.medium,
                      child: Text('Средний'),
                    ),
                    DropdownMenuItem(
                      value: AiDifficulty.hard,
                      child: Text('Сложный'),
                    ),
                  ],
                  onChanged: (difficulty) {
                    if (difficulty != null) {
                      controller.setDifficulty(difficulty);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Координаты на доске'),
                  value: settings.showCoordinates,
                  onChanged: controller.setShowCoordinates,
                ),
                const Divider(height: 28),
                const _SectionTitle('Музыка и звук'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.music_note),
                  title: const Text('Музыка'),
                  value: settings.musicEnabled,
                  onChanged: controller.setMusicEnabled,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text('Громкость'),
                      Expanded(
                        child: Slider(
                          value: settings.musicVolume,
                          divisions: 20,
                          label: '${(settings.musicVolume * 100).round()}%',
                          onChanged: settings.musicEnabled
                              ? controller.setMusicVolume
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(settings.musicVolume * 100).round()}%',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_up),
                  title: const Text('Звуки'),
                  subtitle: const Text('Ходы и победа'),
                  value: settings.soundEnabled,
                  onChanged: controller.setSoundEnabled,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: settings.soundEnabled
                        ? () => (audioService ?? app_services.audioService)
                              .playMove()
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Прослушать звук хода'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Вибрация'),
                  value: settings.vibrationEnabled,
                  onChanged: controller.setVibrationEnabled,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _confirmReset(context, controller),
                  icon: const Icon(Icons.restore),
                  label: const Text('Сбросить настройки'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text('Все параметры вернутся к значениям по умолчанию.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Настройки сброшены')));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
