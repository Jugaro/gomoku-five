import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract class ProfileCloud extends ChangeNotifier {
  bool get isConnected;
  String get statusText;
  Future<void> saveNickname(String nickname);
}

class FirebaseProfileCloud extends ProfileCloud {
  bool _connected = false;
  String _statusText = 'Подключение к серверу…';
  bool _notificationsRegistered = false;

  @override
  bool get isConnected => _connected;

  @override
  String get statusText => _statusText;

  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) {
      _statusText = 'Сервер доступен в Android-версии';
      notifyListeners();
      return;
    }
    try {
      await Firebase.initializeApp();
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      _connected = true;
      _statusText = 'Сервер подключён';
    } on FirebaseException catch (error) {
      _connected = false;
      _statusText = error.code == 'operation-not-allowed'
          ? 'В Firebase нужно включить Anonymous Authentication'
          : 'Сервер пока не подключён';
    } catch (_) {
      _connected = false;
      _statusText = 'Сервер пока не подключён';
    }
    notifyListeners();
  }

  @override
  Future<void> saveNickname(String nickname) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_connected || user == null) {
      throw StateError('Нет подключения к серверу');
    }
    final normalizedNickname = nickname.trim();
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(firestore.collection('players').doc(user.uid), {
      'nickname': normalizedNickname,
      'nicknameLower': normalizedNickname.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(firestore.collection('publicProfiles').doc(user.uid), {
      'nickname': normalizedNickname,
      'nicknameLower': normalizedNickname.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    unawaited(_registerNotifications(user.uid));
  }

  Future<void> _registerNotifications(String uid) async {
    if (_notificationsRegistered) return;
    _notificationsRegistered = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      messaging.onRegistered.listen((registrationId) async {
        try {
          await _saveRegistration(uid, registrationId);
        } catch (_) {}
      });
      await messaging.register();
    } catch (_) {}
  }

  Future<void> _saveRegistration(String uid, String registrationId) {
    return FirebaseFirestore.instance.collection('players').doc(uid).set({
      'fcmRegistrationIds': FieldValue.arrayUnion([registrationId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
