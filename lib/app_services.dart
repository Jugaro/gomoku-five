import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'services/accepted_games_coordinator.dart';
import 'services/audio_service.dart';
import 'services/firebase_online_backend.dart';
import 'services/profile_cloud.dart';
import 'settings/settings_controller.dart';
import 'ui/online_game_screen.dart';

final settingsController = SettingsController();
final audioService = AudioService();
final profileCloud = FirebaseProfileCloud();
final firebaseOnlineBackend = FirebaseOnlineBackend();
final navigatorKey = GlobalKey<NavigatorState>();
final acceptedGamesCoordinator = AcceptedGamesCoordinator(
  backend: firebaseOnlineBackend,
  openGame: (gameId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(gameId: gameId)),
    );
  },
);

bool _settingsListenerAttached = false;
bool _acceptedListenerAttached = false;

Future<void> initializeAppServices() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settingsController.load();
  audioService.initialize();
  audioService.applySettings(settingsController.value);
  if (!_acceptedListenerAttached) {
    profileCloud.addListener(_startAcceptedGames);
    _acceptedListenerAttached = true;
  }
  _startAcceptedGames();
  unawaited(profileCloud.initialize());
  if (_settingsListenerAttached) return;
  settingsController.addListener(_applyAudioSettings);
  _settingsListenerAttached = true;
}

void _startAcceptedGames() {
  if (profileCloud.isConnected) acceptedGamesCoordinator.start();
}

void _applyAudioSettings() {
  audioService.applySettings(settingsController.value);
}
