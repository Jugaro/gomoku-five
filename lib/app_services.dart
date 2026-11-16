import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'services/audio_service.dart';
import 'services/firebase_online_backend.dart';
import 'services/profile_cloud.dart';
import 'settings/settings_controller.dart';

final settingsController = SettingsController();
final audioService = AudioService();
final profileCloud = FirebaseProfileCloud();
final firebaseOnlineBackend = FirebaseOnlineBackend();

bool _settingsListenerAttached = false;

Future<void> initializeAppServices() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settingsController.load();
  audioService.initialize();
  audioService.applySettings(settingsController.value);
  unawaited(profileCloud.initialize());
  if (_settingsListenerAttached) return;
  settingsController.addListener(_applyAudioSettings);
  _settingsListenerAttached = true;
}

void _applyAudioSettings() {
  audioService.applySettings(settingsController.value);
}
