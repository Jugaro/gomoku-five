import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:gomoku5/profile/nickname_validator.dart';
import 'package:gomoku5/profile/profile_store.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart' show firebaseOnlineBackend, profileCloud;
import '../services/online_backend.dart';
import '../services/profile_cloud.dart';
import 'online/online_mode_card.dart';
import 'online/online_panel.dart';
import 'online_game_screen.dart';
import 'widgets/home_background.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({
    super.key,
    this.profileStore,
    this.cloud,
    this.backend,
    this.currentUid,
  });

  final ProfileStore? profileStore;
  final ProfileCloud? cloud;
  final OnlineBackend? backend;
  final String? currentUid;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final ProfileStore _profileStore;
  late final ProfileCloud _cloud;
  late final OnlineBackend _backend;
  final _nicknameController = TextEditingController();
  final _friendController = TextEditingController();
  final _nicknameFocusNode = FocusNode();

  StreamSubscription<String?>? _randomMatchSubscription;
  StreamSubscription<List<GameInvite>>? _invitationsSubscription;
  StreamSubscription<List<GameInvite>>? _acceptedSubscription;
  final _openedInvitationGameIds = <String>{};
  List<GameInvite> _invitations = const [];
  final _busyInvitations = <String>{};

  String? _savedNickname;
  String? _nicknameError;
  String? _friendError;
  String? _lastRandomMatchId;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _editing = true;
  bool _searching = false;
  bool _searchRequestInFlight = false;
  bool _sendingInvitation = false;
  bool _openingGame = false;

  @override
  void initState() {
    super.initState();
    _profileStore = widget.profileStore ?? ProfileStore();
    _cloud = widget.cloud ?? profileCloud;
    _backend = widget.backend ?? firebaseOnlineBackend;
    _cloud.addListener(_cloudChanged);
    _loadNickname();
  }

  void _cloudChanged() {
    if (!mounted) return;
    setState(() {});
    if (_cloud.isConnected && _savedNickname != null) _startOnlineStreams();
  }

  @override
  void dispose() {
    _cloud.removeListener(_cloudChanged);
    unawaited(_randomMatchSubscription?.cancel());
    unawaited(_invitationsSubscription?.cancel());
    unawaited(_acceptedSubscription?.cancel());
    if (_searching) {
      unawaited(_backend.cancelRandomSearch().catchError((_) {}));
    }
    _nicknameController.dispose();
    _friendController.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNickname() async {
    try {
      final storedNickname = await _profileStore.loadNickname();
      final nickname = NicknameValidator.normalize(storedNickname);
      final error = NicknameValidator.validate(nickname);
      if (!mounted) return;
      setState(() {
        _savedNickname = error == null ? nickname : null;
        _nicknameController.text = nickname;
        _nicknameError = storedNickname == null ? null : error;
        _loading = false;
        _loadFailed = false;
        _editing = error != null;
      });
      if (_savedNickname != null && _cloud.isConnected) _startOnlineStreams();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _startOnlineStreams() {
    if (_randomMatchSubscription == null) {
      try {
        _randomMatchSubscription = _backend.watchRandomMatch().listen(
          _onRandomMatch,
          onError: _onOnlineStreamError,
        );
      } catch (error) {
        _onOnlineStreamError(error);
      }
    }
    if (_invitationsSubscription == null) {
      try {
        _invitationsSubscription = _backend.watchIncomingInvitations().listen(
          _onInvitations,
          onError: _onOnlineStreamError,
        );
      } catch (error) {
        _onOnlineStreamError(error);
      }
    }
    if (_acceptedSubscription == null) {
      try {
        _acceptedSubscription = _backend.watchAcceptedInvitations().listen(
          _onAcceptedInvitations,
          onError: _onOnlineStreamError,
        );
      } catch (error) {
        _onOnlineStreamError(error);
      }
    }
  }

  void _onOnlineStreamError(Object error) {
    debugPrint('Online stream error: $error');
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchRequestInFlight = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Онлайн-сервис временно недоступен. Попробуйте позже.'),
      ),
    );
  }

  void _onRandomMatch(String? gameId) {
    if (!mounted || gameId == null || gameId.isEmpty) return;
    if (gameId == _lastRandomMatchId) return;
    _lastRandomMatchId = gameId;
    if (_searching || _searchRequestInFlight) {
      setState(() {
        _searching = false;
        _searchRequestInFlight = false;
      });
    }
    unawaited(_backend.cancelRandomSearch().catchError((_) {}));
    unawaited(_openGame(gameId));
  }

  void _onInvitations(List<GameInvite> invitations) {
    if (!mounted) return;
    setState(() => _invitations = invitations);
  }

  void _onAcceptedInvitations(List<GameInvite> invitations) {
    for (final invitation in invitations) {
      final gameId = invitation.gameId;
      if (invitation.status != 'accepted' ||
          gameId == null ||
          gameId.isEmpty ||
          !_openedInvitationGameIds.add(gameId)) {
        continue;
      }
      unawaited(_openGame(gameId));
      break;
    }
  }

  Future<void> _startRandomSearch() async {
    if (_searching || _searchRequestInFlight) return;
    setState(() {
      _searching = true;
      _searchRequestInFlight = true;
    });
    try {
      await _backend.startRandomSearch();
      if (!mounted) return;
      setState(() => _searchRequestInFlight = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchRequestInFlight = false;
      });
      _showMessage('Не удалось начать поиск. Проверьте подключение.');
    }
  }

  Future<void> _cancelRandomSearch() async {
    if (!_searching || _searchRequestInFlight) return;
    setState(() => _searchRequestInFlight = true);
    try {
      await _backend.cancelRandomSearch();
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchRequestInFlight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchRequestInFlight = false);
      _showMessage('Не удалось отменить поиск. Попробуйте ещё раз.');
    }
  }

  Future<void> _sendInvitation() async {
    if (_sendingInvitation) return;
    final nickname = NicknameValidator.normalize(_friendController.text);
    final error = NicknameValidator.validate(nickname);
    setState(() => _friendError = error);
    if (error != null) return;

    setState(() => _sendingInvitation = true);
    try {
      await _backend.sendInvitation(nickname);
      if (!mounted) return;
      setState(() {
        _sendingInvitation = false;
        _friendController.clear();
        _friendError = null;
      });
      _showMessage('Приглашение отправлено игроку $nickname');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingInvitation = false);
      _showMessage(
        'Не удалось отправить приглашение. Проверьте ник и подключение.',
      );
    }
  }

  Future<void> _acceptInvitation(GameInvite invitation) async {
    if (_busyInvitations.contains(invitation.id)) return;
    setState(() => _busyInvitations.add(invitation.id));
    try {
      final gameId = await _backend.acceptInvitation(invitation.id);
      if (!mounted) return;
      setState(() => _busyInvitations.remove(invitation.id));
      await _openGame(gameId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyInvitations.remove(invitation.id));
      _showMessage('Не удалось принять приглашение. Попробуйте ещё раз.');
    }
  }

  Future<void> _declineInvitation(GameInvite invitation) async {
    if (_busyInvitations.contains(invitation.id)) return;
    setState(() => _busyInvitations.add(invitation.id));
    try {
      await _backend.declineInvitation(invitation.id);
      if (!mounted) return;
      setState(() {
        _busyInvitations.remove(invitation.id);
        _invitations = _invitations
            .where((item) => item.id != invitation.id)
            .toList();
      });
      _showMessage('Приглашение отклонено');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyInvitations.remove(invitation.id));
      _showMessage('Не удалось отклонить приглашение. Попробуйте ещё раз.');
    }
  }

  String? _authenticatedUid() {
    if (widget.currentUid != null) return widget.currentUid;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openGame(String gameId) async {
    if (_openingGame || !mounted || gameId.isEmpty) return;
    final uid = _authenticatedUid();
    if (uid == null || uid.isEmpty) {
      _showMessage('Не удалось определить игрока. Проверьте подключение.');
      return;
    }
    _openingGame = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineGameScreen(
            gameId: gameId,
            backend: _backend,
            currentUid: uid,
          ),
        ),
      );
    } finally {
      _openingGame = false;
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    _loadNickname();
  }

  void _onNicknameChanged(String raw) {
    setState(() => _nicknameError = NicknameValidator.validate(raw));
  }

  Future<void> _saveNickname() async {
    if (_saving) return;
    final nickname = NicknameValidator.normalize(_nicknameController.text);
    final error = NicknameValidator.validate(nickname);
    if (error != null) {
      setState(() => _nicknameError = error);
      return;
    }

    setState(() {
      _saving = true;
      _nicknameError = null;
    });
    try {
      await _profileStore.saveNickname(nickname);
      var synchronized = false;
      var synchronizationFailed = false;
      if (_cloud.isConnected) {
        try {
          await _cloud.saveNickname(nickname);
          synchronized = true;
        } catch (_) {
          synchronizationFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _savedNickname = nickname;
        _saving = false;
        _editing = false;
        _friendController.clear();
        _friendError = null;
      });
      _startOnlineStreams();
      if (synchronized || synchronizationFailed) {
        _showMessage(
          synchronized
              ? 'Ник сохранён и синхронизирован с облаком'
              : 'Ник сохранён локально; облачная синхронизация не удалась',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Не удалось сохранить ник. Попробуйте ещё раз.');
    }
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _nicknameController.text = _savedNickname ?? '';
      _nicknameError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nicknameFocusNode.requestFocus();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _nicknameController.text = _savedNickname ?? '';
      _nicknameError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingInvitations = _invitations
        .where((invitation) => invitation.status == 'pending')
        .toList();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Онлайн-игра'),
        backgroundColor: Colors.transparent,
      ),
      body: HomeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OnlineIntroduction(
                            statusText: _cloud.statusText,
                            connected: _cloud.isConnected,
                          ),
                          const SizedBox(height: 18),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 56),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_loadFailed)
                            _LoadError(onRetry: _retryLoad)
                          else if (_savedNickname != null && !_editing) ...[
                            _CurrentNickname(
                              nickname: _savedNickname!,
                              onChange: _startEditing,
                            ),
                            if (pendingInvitations.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _InvitationsSection(
                                invitations: pendingInvitations,
                                busyIds: _busyInvitations,
                                onAccept: _acceptInvitation,
                                onDecline: _declineInvitation,
                              ),
                            ],
                            const SizedBox(height: 24),
                            const _SectionTitle('Выберите соперника'),
                            const SizedBox(height: 12),
                            OnlineModeCard(
                              title: 'Случайный соперник',
                              description:
                                  'Мы найдём свободного игрока и откроем новую '
                                  'партию, как только соперник будет готов.',
                              icon: Icons.shuffle_rounded,
                              actionLabel: _searching
                                  ? 'Отменить поиск'
                                  : 'Найти соперника',
                              actionIcon: _searching
                                  ? Icons.close_rounded
                                  : Icons.public_rounded,
                              onPressed: _searchRequestInFlight
                                  ? null
                                  : _searching
                                  ? _cancelRandomSearch
                                  : _startRandomSearch,
                              child: _searching
                                  ? const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        LinearProgressIndicator(),
                                        SizedBox(height: 10),
                                        Text(
                                          'Поиск соперника…',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF60432F),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            OnlineModeCard(
                              title: 'Играть по нику',
                              description:
                                  'Введите ник друга. Он увидит приглашение '
                                  'и сможет принять или отклонить его.',
                              icon: Icons.person_search_rounded,
                              actionLabel: _sendingInvitation
                                  ? 'Отправляем…'
                                  : 'Пригласить друга',
                              actionIcon: Icons.send_rounded,
                              onPressed: _sendingInvitation
                                  ? null
                                  : _sendInvitation,
                              child: TextField(
                                key: const Key('friend-nickname-field'),
                                controller: _friendController,
                                enabled: !_sendingInvitation,
                                autocorrect: false,
                                textInputAction: TextInputAction.done,
                                onChanged: (raw) {
                                  setState(
                                    () => _friendError =
                                        NicknameValidator.validate(raw),
                                  );
                                },
                                onSubmitted: (_) => _sendInvitation(),
                                decoration: _inputDecoration(
                                  label: 'Ник друга',
                                  hint: 'Например, Соперник_5',
                                  icon: Icons.alternate_email_rounded,
                                  error: _friendError,
                                ),
                              ),
                            ),
                          ] else
                            _buildNicknameForm(),
                          const SizedBox(height: 18),
                          const Text(
                            'Ходы и приглашения синхронизируются через Firebase. '
                            'Во время поиска держите приложение открытым.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8B6A4C),
                              fontSize: 12,
                              height: 1.4,
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

  Widget _buildNicknameForm() {
    final changing = _savedNickname != null;
    return OnlinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            changing ? 'Смена ника' : 'Вход по нику',
            style: const TextStyle(
              color: Color(0xFF493024),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Придумайте ник — он будет виден вашему сопернику.',
            style: TextStyle(
              color: Color(0xFF806147),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('own-nickname-field'),
            controller: _nicknameController,
            focusNode: _nicknameFocusNode,
            enabled: !_saving,
            autofocus: !changing,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: _onNicknameChanged,
            onSubmitted: (_) => _saveNickname(),
            decoration: _inputDecoration(
              label: 'Ваш ник',
              hint: 'Например, Игрок_5',
              icon: Icons.person_outline_rounded,
              error: _nicknameError,
              helper: '3–16 символов: буквы, цифры, _ или -',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveNickname,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _saving
                    ? 'Сохраняем…'
                    : changing
                    ? 'Сохранить ник'
                    : 'Сохранить и продолжить',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF603B2C),
                foregroundColor: const Color(0xFFFFF9EF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (changing)
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: const Text('Отмена'),
            ),
          if (!changing) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 16,
                  color: Color(0xFF8B6A4C),
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Ник сохраняется на этом устройстве',
                    style: TextStyle(color: Color(0xFF8B6A4C), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InvitationsSection extends StatelessWidget {
  const _InvitationsSection({
    required this.invitations,
    required this.busyIds,
    required this.onAccept,
    required this.onDecline,
  });

  final List<GameInvite> invitations;
  final Set<String> busyIds;
  final ValueChanged<GameInvite> onAccept;
  final ValueChanged<GameInvite> onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Входящие приглашения'),
        const SizedBox(height: 10),
        for (final invitation in invitations) ...[
          _InvitationCard(
            invitation: invitation,
            busy: busyIds.contains(invitation.id),
            onAccept: () => onAccept(invitation),
            onDecline: () => onDecline(invitation),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final GameInvite invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return OnlinePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF603B2C),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.fromNickname,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF493024),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'приглашает вас в партию',
                      style: TextStyle(color: Color(0xFF806147), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : onDecline,
                child: const Text('Отклонить'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onAccept,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Принять'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? error,
  String? helper,
}) {
  OutlineInputBorder border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: color),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    errorText: error,
    errorMaxLines: 3,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFFFFDF8),
    enabledBorder: border(const Color(0xFFD5BA92)),
    focusedBorder: border(const Color(0xFF8B5A3C)),
    errorBorder: border(const Color(0xFFA34F38)),
    focusedErrorBorder: border(const Color(0xFFA34F38)),
  );
}

class _OnlineIntroduction extends StatelessWidget {
  const _OnlineIntroduction({
    required this.statusText,
    required this.connected,
  });

  final String statusText;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return OnlinePanel(
      highlighted: true,
      child: Column(
        children: [
          const _OnlineEmblem(),
          const SizedBox(height: 14),
          const Text(
            'Живая партия на бесконечной доске',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF493024),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Сыграйте в «Пять в ряд» с другом или новым соперником. '
            'Ходы будут передаваться по сети, а ник поможет узнать друг друга.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF76573F),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: 18,
                color: connected
                    ? const Color(0xFF3E6B3C)
                    : const Color(0xFFA34F38),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: connected
                        ? const Color(0xFF3E6B3C)
                        : const Color(0xFF914A37),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlineEmblem extends StatelessWidget {
  const _OnlineEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFAF0),
              border: Border.all(color: const Color(0xFFC9A878)),
            ),
            child: const Icon(
              Icons.public_rounded,
              size: 38,
              color: Color(0xFF765037),
            ),
          ),
          const Positioned(
            left: 4,
            bottom: 1,
            child: _Stone(color: Color(0xFF302824)),
          ),
          const Positioned(
            right: 4,
            bottom: 1,
            child: _Stone(color: Color(0xFFFFFAF0)),
          ),
        ],
      ),
    );
  }
}

class _Stone extends StatelessWidget {
  const _Stone({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: const Color(0xFF9B7B5B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33503024),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _CurrentNickname extends StatelessWidget {
  const _CurrentNickname({required this.nickname, required this.onChange});

  final String nickname;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return OnlinePanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatar = Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF603B2C),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFFFFF9EF)),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ваш ник',
                style: TextStyle(color: Color(0xFF8B6A4C), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                nickname,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF493024),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final changeButton = TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Сменить ник'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF784A33),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
          final compact =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(12) > 16;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 13),
                    Expanded(child: details),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: changeButton),
              ],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 13),
              Expanded(child: details),
              changeButton,
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF60432F),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OnlinePanel(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 38,
            color: Color(0xFFA34F38),
          ),
          const SizedBox(height: 12),
          const Text(
            'Не удалось открыть профиль',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF493024),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }
}
