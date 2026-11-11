import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:mobile/game/game_instructions.dart';
import 'package:mobile/game/game_level.dart';
import 'package:mobile/game/fopcam_game.dart';
import 'package:mobile/models/game_challenge.dart';
import 'package:mobile/models/game_reward.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/widgets/duel_action_button.dart';
import 'package:mobile/widgets/game_screen_frame.dart';
import 'package:mobile/widgets/trophy_art.dart';

enum _LevelTwelveAction { exit, replay, challenge }

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key, this.challengeId});

  final int? challengeId;

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with WidgetsBindingObserver {
  FopcamGame? _game;
  String _playerName = 'Joueur';
  bool _loadingIntro = true;
  bool _hasPausedGame = false;
  bool _allowPop = false;
  bool _waitingForOpponent = false;
  bool _challengeJoined = false;
  Timer? _challengePollingTimer;
  bool _challengePollInFlight = false;
  bool _reportingElimination = false;
  bool _sharingTrophy = false;
  bool _trophyShared = false;
  GameChallenge? _challengeResult;
  String? _challengeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      Flame.device.fullScreen();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _loadIntro();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _game?.pauseForLater();
    }
  }

  @override
  void dispose() {
    _challengePollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadIntro() async {
    unawaited(
      FopcamGame.loadAudioSettings().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Game audio settings failed to load: $error\n$stackTrace');
      }),
    );
    var playerName = 'Joueur';
    final userData = await StorageService.getUserData();
    if (userData != null) {
      try {
        final decoded = jsonDecode(userData);
        if (decoded is Map<String, dynamic>) {
          final user = User.fromJson(decoded);
          playerName = user.firstName?.trim().isNotEmpty == true
              ? user.firstName!.trim()
              : user.username;
        }
      } on FormatException catch (error) {
        debugPrint('GamePlayScreen: profil utilisateur invalide: $error');
      }
    }

    final savedGame = widget.challengeId == null
        ? await FopcamGame.loadPausedProgress()
        : null;
    final pendingRewardScore = widget.challengeId == null
        ? await FopcamGame.loadPendingLevelTwelveReward()
        : null;
    try {
      await FopcamGame.prepareAudioForUserGesture(
        level: savedGame?['level'] ?? 1,
        challengeRound: widget.challengeId == null ? null : 1,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Game audio preload failed: $error\n$stackTrace');
    }
    if (!mounted) return;
    setState(() {
      _playerName = playerName;
      _hasPausedGame = savedGame != null && pendingRewardScore == null;
      _loadingIntro = false;
    });
    if (pendingRewardScore != null) {
      unawaited(_grantReward(playerName, pendingRewardScore));
    }
  }

  Future<void> _startGame({bool resumeSavedGame = false}) async {
    unawaited(
      FopcamGame.resumeAudioFromUserGesture().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Game audio activation failed: $error\n$stackTrace');
      }),
    );
    final challengeId = widget.challengeId;
    GameChallenge? challengeState;
    if (challengeId != null) {
      setState(() => _waitingForOpponent = true);
      try {
        var challenge = await ApiService.joinGameChallenge(
          challengeId: challengeId,
        );
        final waitDeadline = DateTime.now().add(const Duration(minutes: 2));
        while (challenge.status == 'accepted' &&
            DateTime.now().isBefore(waitDeadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          challenge = await ApiService.joinGameChallenge(
            challengeId: challengeId,
          );
        }
        if (challenge.status != 'playing' || challenge.startedAt == null) {
          throw StateError(
            'Le duel n’a pas démarré. Vérifie que ton adversaire est prêt.',
          );
        }
        challengeState = challenge;
        if (!mounted) return;
        setState(() {
          _challengeJoined = true;
          _challengeResult = challenge;
        });
        final delay = Duration(
          milliseconds: challenge.startsInMilliseconds ?? 0,
        );
        if (delay > Duration.zero) await Future<void>.delayed(delay);
      } on Object catch (error) {
        if (mounted) {
          setState(() => _waitingForOpponent = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.readableGameError(error))),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _waitingForOpponent = false);
      _startChallengePolling(challengeId);
      if (!challengeState.isMyTurn) {
        setState(
          () => _game = _createChallengeGame(challengeState!, spectator: true),
        );
        return;
      }
    }

    var initialScore = 0;
    var initialLevel = 1;
    int? initialRemainingMilliseconds;
    int? initialPlayerXMillionths;
    int? initialPlayerYMillionths;
    var initialDemotionReplay = false;
    if (resumeSavedGame) {
      final savedGame = await FopcamGame.loadPausedProgress();
      if (savedGame == null) {
        if (mounted) setState(() => _hasPausedGame = false);
        return;
      }
      initialScore = savedGame['score']!;
      initialLevel = savedGame['level']!;
      initialRemainingMilliseconds = savedGame['remainingMilliseconds'];
      initialPlayerXMillionths = savedGame['playerXMillionths'];
      initialPlayerYMillionths = savedGame['playerYMillionths'];
      initialDemotionReplay = savedGame['demotionReplay'] == 1;
    } else if (widget.challengeId == null) {
      await FopcamGame.clearPausedProgress();
      if (mounted) setState(() => _hasPausedGame = false);
    }

    if (!mounted) return;
    _game = FopcamGame(
      playerName: _playerName,
      onRewardEarned: _grantReward,
      onRewardFailed: _showRewardSyncError,
      onChallengeEliminated: _reportChallengeElimination,
      onChallengeRoundCompleted: _reportChallengeRoundCompletion,
      isChallengeMode: widget.challengeId != null,
      challengeRoundNumber: challengeState?.roundNumber ?? 1,
      challengeRoundDurationSeconds: challengeState?.roundDurationSeconds ?? 50,
      challengeRoundStartedAt: challengeState?.startedAt,
      initialChallengeRoundComplete: challengeState?.myRoundComplete ?? false,
      initialScore: initialScore,
      initialLevel: initialLevel,
      initialRemainingMilliseconds: initialRemainingMilliseconds,
      initialPlayerXMillionths: initialPlayerXMillionths,
      initialPlayerYMillionths: initialPlayerYMillionths,
      initialDemotionReplay: initialDemotionReplay,
    );
    if (mounted) {
      setState(() => _challengeResult = challengeState);
    }
  }

  FopcamGame _createChallengeGame(
    GameChallenge challenge, {
    required bool spectator,
  }) => FopcamGame(
    playerName: _playerName,
    onRewardEarned: _grantReward,
    onRewardFailed: _showRewardSyncError,
    onChallengeEliminated: _reportChallengeElimination,
    onChallengeRoundCompleted: _reportChallengeRoundCompletion,
    isChallengeMode: true,
    challengeRoundNumber: challenge.roundNumber,
    challengeRoundDurationSeconds: challenge.roundDurationSeconds,
    challengeRoundStartedAt: challenge.startedAt,
    initialChallengeRoundComplete: !spectator && challenge.myRoundComplete,
    initialScore: 0,
    isSpectatorMode: spectator,
    initialSpectatorState: spectator ? challenge.opponentLiveState : null,
  );

  void _startChallengePolling(int challengeId) {
    _challengePollingTimer?.cancel();
    _challengePollingTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_pollChallenge(challengeId)),
    );
    unawaited(_pollChallenge(challengeId));
  }

  Future<void> _pollChallenge(int challengeId) async {
    if (_challengePollInFlight || _reportingElimination) return;
    _challengePollInFlight = true;
    try {
      final game = _game;
      final challenge = _challengeResult;
      final result =
          game != null &&
              !game.isSpectatorMode &&
              challenge?.isMyTurn == true &&
              game.isChallengeMode
          ? await ApiService.updateGameChallengeLiveState(
              challengeId: challengeId,
              liveState: game.spectatorState(),
            )
          : await ApiService.fetchGameChallenge(challengeId);
      if (!mounted) return;
      _applyChallengeState(result);
    } catch (error, stackTrace) {
      debugPrint('Game challenge status sync failed: $error\n$stackTrace');
      try {
        final latest = await ApiService.fetchGameChallenge(challengeId);
        if (mounted) _applyChallengeState(latest);
      } catch (refreshError, refreshStackTrace) {
        debugPrint(
          'Game challenge status refresh failed: '
          '$refreshError\n$refreshStackTrace',
        );
        if (mounted && _challengeError == null) {
          setState(() {
            _challengeError = ApiService.readableGameError(error);
          });
        }
      }
    } finally {
      _challengePollInFlight = false;
    }
  }

  Future<void> _reportChallengeElimination(int score) async {
    final challengeId = widget.challengeId;
    if (!mounted || challengeId == null || _reportingElimination) return;
    setState(() {
      _reportingElimination = true;
      _challengeError = null;
    });
    try {
      final result = await ApiService.reportGameChallengeElimination(
        challengeId: challengeId,
        score: score,
      );
      if (!mounted) return;
      _applyChallengeState(result);
      if (result.status == 'completed') {
        _challengePollingTimer?.cancel();
      }
    } catch (error, stackTrace) {
      debugPrint('Game challenge elimination sync failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _challengeError = ApiService.readableGameError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _reportingElimination = false);
    }
  }

  Future<void> _reportChallengeRoundCompletion(
    int roundNumber,
    int score,
  ) async {
    final challengeId = widget.challengeId;
    if (!mounted || challengeId == null || _reportingElimination) return;
    setState(() {
      _reportingElimination = true;
      _challengeError = null;
    });
    try {
      final result = await ApiService.completeGameChallengeRound(
        challengeId: challengeId,
        roundNumber: roundNumber,
        score: score,
      );
      if (!mounted) return;
      _applyChallengeState(result);
    } catch (error, stackTrace) {
      debugPrint('Game challenge round sync failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _challengeError = ApiService.readableGameError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _reportingElimination = false);
    }
  }

  void _applyChallengeState(GameChallenge result) {
    if (!mounted) return;
    final currentGame = _game;
    final resetCompletedTurn =
        result.status != 'completed' &&
        currentGame != null &&
        currentGame.overlays.isActive('challengeRoundComplete') &&
        (result.myRoundComplete ||
            result.roundNumber > currentGame.currentChallengeRound);
    if (resetCompletedTurn) {
      currentGame.pauseEngine();
    }
    setState(() {
      _challengeResult = result;
      _challengeError = null;
      if (resetCompletedTurn) _game = null;
    });
    if (result.status == 'completed') {
      _challengePollingTimer?.cancel();
      _game?.completeChallengeFromServer();
    } else if (result.startedAt != null) {
      if (result.isMyTurn) {
        if (_game == null || _game!.isSpectatorMode) {
          setState(
            () => _game = _createChallengeGame(result, spectator: false),
          );
        }
      } else {
        if (_game == null || !_game!.isSpectatorMode) {
          setState(() => _game = _createChallengeGame(result, spectator: true));
        } else if (result.opponentLiveState != null) {
          _game!.applySpectatorState(result.opponentLiveState!);
        }
      }
    }
  }

  void _exitChallenge() {
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _requestChallengeRematch() async {
    final challengeId = widget.challengeId;
    if (!mounted ||
        challengeId == null ||
        _reportingElimination ||
        _challengeResult?.canRequestRematch != true) {
      return;
    }
    setState(() {
      _reportingElimination = true;
      _challengeError = null;
    });
    try {
      await ApiService.requestGameChallengeRematch(challengeId: challengeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation de revanche envoyée.')),
      );
      _exitChallenge();
    } catch (error, stackTrace) {
      debugPrint('Game challenge rematch failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _challengeError = ApiService.readableGameError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _reportingElimination = false);
    }
  }

  Future<void> _shareGameTrophy() async {
    final challenge = _challengeResult;
    if (!mounted ||
        challenge == null ||
        challenge.myWon != true ||
        _sharingTrophy ||
        _trophyShared) {
      return;
    }
    setState(() => _sharingTrophy = true);
    try {
      await ApiService.shareGameChallengeTrophy(challenge.id);
      if (!mounted) return;
      setState(() => _trophyShared = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton trophée est publié dans le fil !')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publication du trophée impossible : '
            '${ApiService.readableGameError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingTrophy = false);
    }
  }

  Future<void> _saveAndExit() async {
    await _game?.savePausedProgress();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _showGameAudioSettings() async {
    try {
      await FopcamGame.resumeAudioFromUserGesture();
    } on Object catch (error, stackTrace) {
      debugPrint('Game audio activation failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’activer le son du jeu.')),
        );
      }
    }
    if (!mounted) return;
    var musicVolume = FopcamGame.gameVolume;
    var effectsVolume = FopcamGame.gameEffectsVolume;
    var muted = FopcamGame.gameMuted;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Son du jeu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Musique'),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: muted ? 'Activer le son' : 'Couper le son',
                    onPressed: () async {
                      final nextMuted = !muted;
                      setDialogState(() => muted = nextMuted);
                      try {
                        await FopcamGame.setGameMuted(nextMuted);
                      } on Object catch (error, stackTrace) {
                        debugPrint(
                          'Game audio mute setting failed: $error\n$stackTrace',
                        );
                        if (mounted && dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Impossible d’enregistrer le réglage audio.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: musicVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(musicVolume * 100).round()} %',
                      onChanged: (value) {
                        setDialogState(() => musicVolume = value);
                        FopcamGame.setGameVolume(value).catchError((
                          Object error,
                          StackTrace stackTrace,
                        ) {
                          debugPrint(
                            'Game audio volume setting failed: $error\n$stackTrace',
                          );
                          if (mounted && dialogContext.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible d’enregistrer le réglage audio.',
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          }
                        });
                      },
                    ),
                  ),
                  Text('${(musicVolume * 100).round()} %'),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Effets sonores'),
              ),
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded),
                  Expanded(
                    child: Slider(
                      value: effectsVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(effectsVolume * 100).round()} %',
                      onChanged: (value) {
                        setDialogState(() => effectsVolume = value);
                        FopcamGame.setGameEffectsVolume(value).catchError((
                          Object error,
                          StackTrace stackTrace,
                        ) {
                          debugPrint(
                            'Game effects volume setting failed: '
                            '$error\n$stackTrace',
                          );
                          if (mounted && dialogContext.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible d’enregistrer le réglage audio.',
                                ),
                              ),
                            );
                            setDialogState(
                              () =>
                                  effectsVolume = FopcamGame.gameEffectsVolume,
                            );
                          }
                        });
                      },
                    ),
                  ),
                  Text('${(effectsVolume * 100).round()} %'),
                ],
              ),
              Text(muted ? 'Son coupé' : 'Réglez séparément chaque volume.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _grantReward(String playerName, int score) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final progressRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Synchronisation de ta récompense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Ta progression est enregistrée. La récompense est vérifiée '
              'avec le serveur.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    unawaited(navigator.push<void>(progressRoute));

    late final GameReward reward;
    try {
      reward = await ApiService.claimLevelTwelveReward(score: score);
    } catch (_) {
      if (navigator.mounted && progressRoute.isActive) {
        navigator.removeRoute(progressRoute);
      }
      rethrow;
    }

    if (navigator.mounted && progressRoute.isActive) {
      navigator.removeRoute(progressRoute);
    }
    if (!mounted) return;

    final action = await showDialog<_LevelTwelveAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(
          Icons.workspace_premium,
          color: Color(0xFFFFCA28),
          size: 56,
        ),
        title: Text('Bravo $playerName !'),
        content: Text(
          reward.alreadyClaimed
              ? 'Ta récompense ${reward.title} est déjà enregistrée sur ton '
                    'compte. Tu as déjà reçu ${reward.points} points bonus.'
              : 'Tu as atteint le niveau 12 et gagné ${reward.title}, '
                    'un badge exclusif ainsi que ${reward.points} points bonus '
                    'synchronisés avec ton compte.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_LevelTwelveAction.replay),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Rejouer'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_LevelTwelveAction.challenge),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Défier une légende'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_LevelTwelveAction.exit),
            icon: const Icon(Icons.exit_to_app_rounded),
            label: const Text('Quitter le jeu'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await FopcamGame.clearPendingLevelTwelveReward();
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to clear the synchronized level 12 reward: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Récompense synchronisée. Elle sera vérifiée à nouveau '
              'à la prochaine ouverture du jeu.',
            ),
          ),
        );
      }
    }
    switch (action) {
      case _LevelTwelveAction.replay:
        await _startGame();
      case _LevelTwelveAction.challenge:
        await _leaveGameAndOpenLegends();
      case _LevelTwelveAction.exit:
      case null:
        await _leaveGame();
    }
  }

  Future<void> _showRewardSyncError(Object error) async {
    if (!mounted) return;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Récompense non synchronisée'),
        content: Text(
          '$error\n\nConnecte-toi à Internet puis réessaie pour enregistrer '
          'ta récompense sur ton compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Quitter, garder ma récompense'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      final game = _game;
      if (game != null) {
        await game.retryLevelTwelveReward();
      } else {
        final score = await FopcamGame.loadPendingLevelTwelveReward();
        if (score != null && mounted) await _grantReward(_playerName, score);
      }
      return;
    }
    await _leaveGame();
  }

  Future<void> _leaveGame() async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _leaveGameAndOpenLegends() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    setState(() => _allowPop = true);
    navigator.pop();
    await Future<void>.delayed(Duration.zero);
    if (navigator.mounted) await navigator.pushNamed('/game/legends');
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return GameScreenFrame(
      child: PopScope(
        canPop: _allowPop || game == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) game?.pauseForLater();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1020),
          body: game == null
              ? _loadingIntro
                    ? const Center(child: CircularProgressIndicator())
                    : _waitingForOpponent
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'En attente de ton adversaire…',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Le duel démarre dès que les deux légendes '
                                'sont prêtes.',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _challengeJoined
                    ? _ChallengeSpectatorView(
                        challenge: _challengeResult,
                        error: _challengeError,
                        isSharingTrophy: _sharingTrophy,
                        trophyShared: _trophyShared,
                        onShareTrophy: _shareGameTrophy,
                        onExit: _exitChallenge,
                      )
                    : _GameIntroScreen(
                        isChallengeMode: widget.challengeId != null,
                        hasPausedGame: _hasPausedGame,
                        onStart: () => _startGame(),
                        onResume: () => _startGame(resumeSavedGame: true),
                      )
              : SafeArea(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: game.isSpectatorMode
                                ? null
                                : (details) {
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    if (box != null && game.size.x > 0) {
                                      final local = details.localPosition;
                                      final x =
                                          local.dx *
                                          (game.size.x / box.size.width);
                                      final y =
                                          local.dy *
                                          (game.size.y / box.size.height);
                                      game.movePlayerTo(x, y);
                                    }
                                  },
                            onPanUpdate: game.isSpectatorMode
                                ? null
                                : (details) {
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    if (box != null && game.size.x > 0) {
                                      final local = details.localPosition;
                                      final x =
                                          local.dx *
                                          (game.size.x / box.size.width);
                                      final y =
                                          local.dy *
                                          (game.size.y / box.size.height);
                                      game.movePlayerTo(x, y);
                                    }
                                  },
                            child: GameWidget<FopcamGame>(
                              game: game,
                              loadingBuilder: (context) => const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFFFFCA28),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Préparation du jeu…',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              overlayBuilderMap: {
                                'levelValidation': (context, game) =>
                                    _LevelValidationOverlay(game: game),
                                'levelDemoted': (context, game) =>
                                    _LevelDemotedOverlay(game: game),
                                'gamePaused': (context, game) => _PauseOverlay(
                                  game: game,
                                  onSaveAndExit: _saveAndExit,
                                ),
                                'levelTimeExpired': (context, game) =>
                                    _LevelTimeExpiredOverlay(
                                      game: game,
                                      onSaveAndExit: _saveAndExit,
                                    ),
                                if (widget.challengeId != null)
                                  'challengeComplete': (context, game) =>
                                      _ChallengeCompleteOverlay(
                                        result: _challengeResult,
                                        score: game.score,
                                        challengeLost: game.challengeLost,
                                        isReporting: _reportingElimination,
                                        error: _challengeError,
                                        onRetry: () =>
                                            _reportChallengeElimination(
                                              game.score,
                                            ),
                                        onRematch: () => unawaited(
                                          _requestChallengeRematch(),
                                        ),
                                        isSharingTrophy: _sharingTrophy,
                                        trophyShared: _trophyShared,
                                        onShareTrophy: _shareGameTrophy,
                                        onExit: _exitChallenge,
                                      ),
                                if (widget.challengeId != null)
                                  'challengeRoundComplete': (context, game) =>
                                      _ChallengeRoundCompleteOverlay(
                                        roundNumber: game.currentChallengeRound,
                                        score: game.score,
                                        isSubmitting: _reportingElimination,
                                        isSubmitted:
                                            _challengeResult?.roundNumber ==
                                                game.currentChallengeRound &&
                                            (_challengeResult
                                                    ?.myRoundComplete ??
                                                false),
                                        opponentSubmitted:
                                            _challengeResult?.roundNumber ==
                                                game.currentChallengeRound &&
                                            (_challengeResult
                                                    ?.opponentRoundComplete ??
                                                false),
                                        error: _challengeError,
                                        onRetry: () =>
                                            _reportChallengeRoundCompletion(
                                              game.currentChallengeRound,
                                              game.score,
                                            ),
                                      ),
                              },
                            ),
                          );
                        },
                      ),
                      if (game.isSpectatorMode && !game.hasSpectatorSnapshot)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 126,
                          child: IgnorePointer(
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xCC0C1622),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFCA28,
                                    ).withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    'Connexion au direct… les obstacles et bonus '
                                    'apparaîtront ici.',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!game.overlays.isActive('gamePaused') &&
                          !game.overlays.isActive('levelValidation') &&
                          !game.overlays.isActive('levelTimeExpired') &&
                          !game.overlays.isActive('challengeComplete') &&
                          !game.overlays.isActive('challengeRoundComplete'))
                        Positioned(
                          top: 112,
                          right: 8,
                          child: IconButton.filledTonal(
                            tooltip: 'Réglages audio',
                            icon: Icon(
                              FopcamGame.gameMuted || FopcamGame.gameVolume == 0
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                            onPressed: _showGameAudioSettings,
                          ),
                        ),
                      if (!game.overlays.isActive('gamePaused') &&
                          !game.overlays.isActive('levelValidation') &&
                          !game.overlays.isActive('levelTimeExpired') &&
                          !game.overlays.isActive('challengeComplete') &&
                          !game.overlays.isActive('challengeRoundComplete'))
                        Positioned(
                          top: 112,
                          left: 8,
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Mettre en pause',
                                icon: const Icon(Icons.pause_rounded),
                                onPressed: game.pauseForLater,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ChallengeSpectatorView extends StatelessWidget {
  const _ChallengeSpectatorView({
    required this.challenge,
    required this.error,
    required this.isSharingTrophy,
    required this.trophyShared,
    required this.onShareTrophy,
    required this.onExit,
  });

  final GameChallenge? challenge;
  final String? error;
  final bool isSharingTrophy;
  final bool trophyShared;
  final VoidCallback onShareTrophy;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final opponentName = challenge?.opponent?.displayName ?? 'Adversaire';
    if (challenge?.status == 'completed') {
      final draw = challenge!.isDraw;
      return SafeArea(
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    draw ? Icons.handshake_rounded : Icons.emoji_events_rounded,
                    color: const Color(0xFFFFCA28),
                    size: 52,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    draw
                        ? 'Match nul · Forces égales'
                        : challenge!.myWon == true
                        ? 'Tu remportes le duel !'
                        : 'Victoire de ${challenge!.winnerName ?? opponentName}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (!draw)
                    Text(
                      challenge!.winnerByScore
                          ? 'Victoire au score cumulé'
                          : 'Victoire après rétrogradation',
                      textAlign: TextAlign.center,
                    ),
                  if (!draw) const SizedBox(height: 8),
                  Text(
                    'Score cumulé : ${challenge!.myScore ?? 0} – '
                    '${challenge!.opponentScore ?? 0}',
                    textAlign: TextAlign.center,
                  ),
                  if (challenge!.myWon == true &&
                      challenge!.myMedalLabel != null) ...[
                    const SizedBox(height: 8),
                    TrophyArtwork(
                      medal: challenge!.myMedal ?? 'cup',
                      width: challenge!.myMedal == 'cup_pro' ? 170 : 130,
                      height: challenge!.myMedal == 'cup_pro' ? 190 : 150,
                    ),
                    Text(
                      '${challenge!.myMedalLabel == 'Coupe' ? 'Trophée' : 'Médaille'} '
                      '${challenge!.myMedalLabel}',
                    ),
                  ],
                  if (challenge!.myWon == true &&
                      challenge!.myMedal != null &&
                      challenge!.myMedal != 'none') ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: isSharingTrophy || trophyShared
                          ? null
                          : onShareTrophy,
                      icon: isSharingTrophy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              trophyShared
                                  ? Icons.check_circle
                                  : Icons.campaign,
                            ),
                      label: Text(
                        trophyShared
                            ? 'Trophée publié'
                            : 'Publier mon trophée dans le fil',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onExit,
                    child: const Text('Retour aux défis'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final state = challenge?.opponentLiveState;
    final objects = state?['objects'];
    final landscape = legendChallengeLandscapeForRound(
      challenge?.roundNumber ?? 1,
    );
    final landscapeColors = switch (landscape.backdrop) {
      GameBackdrop.highlands => const [
        Color(0xFF628BB5),
        Color(0xFF556D70),
        Color(0xFF101725),
      ],
      GameBackdrop.rainySeason => const [
        Color(0xFF526D87),
        Color(0xFF3F654B),
        Color(0xFF101725),
      ],
      GameBackdrop.legend => const [
        Color(0xFF372A70),
        Color(0xFF403151),
        Color(0xFF101725),
      ],
      GameBackdrop.duelCoast => const [
        Color(0xFF2185A5),
        Color(0xFF176B78),
        Color(0xFF101725),
      ],
      GameBackdrop.duelBaobabValley => const [
        Color(0xFFB94838),
        Color(0xFF74442E),
        Color(0xFF101725),
      ],
      GameBackdrop.duelRiverOasis => const [
        Color(0xFF79C8C0),
        Color(0xFF356B4C),
        Color(0xFF101725),
      ],
      _ => throw StateError('Décor de duel des légendes non configuré.'),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    challenge?.isMyTurn == true
                        ? 'Préparation de ton tour'
                        : 'Tour de $opponentName',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitter le duel',
                  onPressed: onExit,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            Text(
              'Manche ${challenge?.roundNumber ?? 1}/3 · '
              '${challenge?.roundDurationSeconds ?? 50} s · '
              'Score : ${challenge?.myScore ?? 0} – '
              '${challenge?.opponentScore ?? 0}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: landscapeColors,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (state == null || objects is! List) {
                        return const Center(
                          child: Text(
                            'En attente du direct de ton adversaire…',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      return Stack(
                        children: [
                          for (final rawObject in objects)
                            if (rawObject is Map)
                              _SpectatorObject(
                                x: (rawObject['x'] as num).toDouble(),
                                y: (rawObject['y'] as num).toDouble(),
                                type: rawObject['type'] as String? ?? '',
                                width: width,
                                height: height,
                              ),
                          Positioned(
                            left: 14,
                            top: 14,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Score ${state['score']} · '
                                  '${(state['remaining_seconds'] as num).ceil()} s',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              challenge?.isMyTurn == true
                  ? 'Ton tour commence bientôt. Les commandes seront activées à son départ.'
                  : 'Tu regardes le tour en direct. Les commandes seront activées quand ce sera à toi.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectatorObject extends StatelessWidget {
  const _SpectatorObject({
    required this.x,
    required this.y,
    required this.type,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final String type;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'shield' => Icons.card_giftcard,
      'bonus' => Icons.bolt,
      _ => Icons.warning_rounded,
    };
    final color = switch (type) {
      'shield' => const Color(0xFFEF476F),
      'bonus' => const Color(0xFFFFCA28),
      _ => const Color(0xFFFF7043),
    };
    return Positioned(
      left: width * x - 14,
      top: height * y - 14,
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _GameIntroScreen extends StatelessWidget {
  const _GameIntroScreen({
    required this.isChallengeMode,
    required this.hasPausedGame,
    required this.onStart,
    required this.onResume,
  });

  final bool isChallengeMode;
  final bool hasPausedGame;
  final VoidCallback onStart;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFFCA28);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Icon(
                Icons.sports_esports,
                color: Color(0xFFFFCA28),
                size: 52,
              ),
              const SizedBox(height: 12),
              Text(
                isChallengeMode ? 'Le duel FopCam' : 'Prêt pour le défi ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isChallengeMode
                    ? 'Joue chacun ton tour, suis ton adversaire en direct '
                          'et cumule des points pendant '
                          '${challengeRoundDurationsSeconds.length} manches.'
                    : '${GameLevel.all.length} niveaux, une difficulté qui monte '
                          'et une place parmi '
                          'les légendes à décrocher. La vitesse augmente '
                          'progressivement à chaque niveau, avec un décor, une '
                          'couleur et une musique propres à chacun.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF151D32),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comment jouer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!isChallengeMode) ...[
                        _buildLevelTargetsGuide(),
                        const SizedBox(height: 14),
                      ],
                      for (final rule
                          in isChallengeMode
                              ? GameInstructions.challengeRules()
                              : GameInstructions.soloRules())
                        _RuleRow(icon: rule.icon, text: rule.text),
                      _RuleRow(
                        icon: Icons.workspace_premium,
                        text: isChallengeMode
                            ? 'Après acceptation, les deux joueurs doivent '
                                  'indiquer qu’ils sont prêts. Une rétrogradation '
                                  'fait perdre le duel.'
                            : 'Au niveau ${GameLevel.all.length}, une récompense '
                                  'personnalisée sera synchronisée avec ton compte.',
                      ),
                    ],
                  ),
                ),
              ),
              if (!isChallengeMode && hasPausedGame) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Reprendre ma partie'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Jouer maintenant'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelTargetsGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Tes niveaux et objectifs',
            style: TextStyle(
              color: Color(0xFFFFCA28),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 440
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in GameLevel.all)
                  SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1224),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: level.color.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: level.color,
                            child: Text(
                              '${level.number}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'À valider : '
                                  '${GameInstructions.requiredScoreFor(level)} pts',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFFCA28), size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.game, required this.onSaveAndExit});

  final FopcamGame game;
  final Future<void> Function() onSaveAndExit;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.78),
    child: Center(
      child: Card(
        color: const Color(0xFF151D32),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle,
                color: Color(0xFFFFCA28),
                size: 58,
              ),
              const SizedBox(height: 10),
              Text(
                'Pause · niveau ${game.level}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game.isChallengeMode
                    ? 'Score actuel : ${game.score}. Reprends quand tu es '
                          'prêt ; un défi n’est pas sauvegardé si tu le quittes.'
                    : 'Score sauvegardé : ${game.score}. Reprends quand tu es '
                          'prêt.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: game.resumeFromPause,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Reprendre'),
                ),
              ),
              const SizedBox(height: 8),
              if (game.isChallengeMode)
                TextButton(
                  onPressed: onSaveAndExit,
                  child: const Text('Quitter le défi'),
                )
              else
                TextButton.icon(
                  onPressed: onSaveAndExit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Sauvegarder et quitter'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LevelTimeExpiredOverlay extends StatelessWidget {
  const _LevelTimeExpiredOverlay({
    required this.game,
    required this.onSaveAndExit,
  });

  final FopcamGame game;
  final Future<void> Function() onSaveAndExit;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.78),
    child: Center(
      child: Card(
        color: const Color(0xFF351111),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_disabled,
                color: Color(0xFFFFCA28),
                size: 54,
              ),
              const SizedBox(height: 10),
              Text(
                'Temps écoulé !',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game.timedOutLevel > 1
                    ? 'Le niveau ${game.timedOutLevel} n’est pas validé. '
                          'Tu perds 3 points et reprends au niveau ${game.level} '
                          'avec ${game.score} points. Cette reprise dure 30 s.'
                    : 'Le niveau 1 n’est pas validé. Tu perds 3 points et '
                          'restes au niveau 1 avec ${game.score} points. '
                          'Cette reprise dure 30 s.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (game.recoverableLevel != null) ...[
                Text(
                  'Récupérer le niveau ${game.recoverableLevel} coûte '
                  '${game.recoveryCost} points. Solde : ${game.score}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: game.canRecoverLostLevel
                        ? game.recoverLostLevel
                        : null,
                    icon: const Icon(Icons.redeem),
                    label: Text(
                      game.canRecoverLostLevel
                          ? 'Récupérer pour ${game.recoveryCost} points'
                          : 'Il te manque ${game.recoveryCost - game.score} points',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: game.retryAfterTimeout,
                  icon: const Icon(Icons.refresh),
                  label: Text('Réessayer le niveau ${game.level}'),
                ),
              ),
              TextButton.icon(
                onPressed: onSaveAndExit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Sauvegarder et quitter'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LevelDemotedOverlay extends StatelessWidget {
  const _LevelDemotedOverlay({required this.game});

  final FopcamGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.78),
    child: Center(
      child: Card(
        color: const Color(0xFF351111),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_down,
                color: Color(0xFFFF8A65),
                size: 54,
              ),
              const SizedBox(height: 10),
              Text(
                'Niveau rétrogradé',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu as ${game.score} points. Récupérer le niveau '
                '${game.recoverableLevel} coûte ${game.recoveryCost} points. '
                'Le niveau à rejouer dure 30 s.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: game.canRecoverLostLevel
                      ? game.recoverLostLevel
                      : null,
                  icon: const Icon(Icons.redeem),
                  label: Text(
                    game.canRecoverLostLevel
                        ? 'Récupérer le niveau (${game.recoveryCost} points)'
                        : 'Il te manque ${game.recoveryCost - game.score} points',
                  ),
                ),
              ),
              TextButton(
                onPressed: game.continueAfterDemotion,
                child: const Text('Continuer au niveau actuel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChallengeCompleteOverlay extends StatelessWidget {
  const _ChallengeCompleteOverlay({
    required this.result,
    required this.score,
    required this.challengeLost,
    required this.isReporting,
    required this.error,
    required this.onRetry,
    required this.onRematch,
    required this.isSharingTrophy,
    required this.trophyShared,
    required this.onShareTrophy,
    required this.onExit,
  });

  final GameChallenge? result;
  final int score;
  final bool challengeLost;
  final bool isReporting;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRematch;
  final bool isSharingTrophy;
  final bool trophyShared;
  final VoidCallback onShareTrophy;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final challengeResult = result;
    final completed = challengeResult?.status == 'completed';
    final won = challengeResult?.myWon;
    final title = completed
        ? challengeResult!.isDraw
              ? 'Match Nul'
              : won == true
              ? 'Tu remportes le duel !'
              : won == false
              ? 'Duel perdu'
              : challengeResult.winnerName == null
              ? 'Résultat du duel'
              : 'Victoire de ${challengeResult.winnerName}'
        : challengeLost
        ? 'Tu as été rétrogradé'
        : 'Duel terminé';
    final message = completed
        ? challengeResult!.isDraw
              ? 'Forces égales après '
                    '${challengeRoundDurationsSeconds.length} manches.'
              : won == true
              ? challengeResult.winnerByScore
                    ? 'Tu as gagné grâce à ton score cumulé après '
                          '${challengeRoundDurationsSeconds.length} manches.'
                    : 'Ton adversaire a été rétrogradé en premier.'
              : won == false
              ? challengeResult.winnerByScore
                    ? 'Ton adversaire a remporté le duel au score cumulé.'
                    : 'Tu as été rétrogradé en premier.'
              : 'Le duel est terminé.'
        : challengeLost
        ? 'La rétrogradation est détectée. Le résultat est en cours de synchronisation. '
              'Ton score au moment de la rétrogradation : $score.'
        : 'Le résultat du duel est synchronisé avec le serveur.';
    final medal = result?.myMedalLabel;

    return ColoredBox(
      color: Colors.black54,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (completed && won == true)
            const IgnorePointer(child: _VictoryConfetti()),
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sports_esports,
                      color: Color(0xFFFFCA28),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    if (completed &&
                        challengeResult!.myScore != null &&
                        challengeResult.opponentScore != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Scores : ${challengeResult.myScore ?? 0} - '
                        '${challengeResult.opponentScore ?? 0}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (completed && won == true && medal != null) ...[
                      const SizedBox(height: 12),
                      TrophyArtwork(
                        medal: result?.myMedal ?? 'cup',
                        width: 112,
                        height: 128,
                      ),
                      Text(
                        '${medal == 'Coupe' ? 'Trophée' : 'Médaille'} $medal'
                        '${result?.myTitle == 'Champion FopCam' || result?.myTitle == 'Champion 1ère Ligue' || result?.myTitle == 'Champion League Pro' ? ' · ${result!.myTitle}' : ''}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (completed &&
                        won == true &&
                        challengeResult!.duelReward != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFD97706),
                              size: 30,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              challengeResult.duelReward!['title']
                                      ?.toString() ??
                                  'Récompense de revanche',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              challengeResult.duelReward!['description']
                                      ?.toString() ??
                                  'Récompense remportée en duel.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (completed &&
                        won == true &&
                        challengeResult!.myMedal != null &&
                        challengeResult.myMedal != 'none') ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isSharingTrophy || trophyShared
                            ? null
                            : onShareTrophy,
                        icon: isSharingTrophy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                trophyShared
                                    ? Icons.check_circle
                                    : Icons.campaign,
                              ),
                        label: Text(
                          trophyShared
                              ? 'Trophée publié dans le fil'
                              : 'Publier mon trophée dans le fil',
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (isReporting) ...[
                      const SizedBox(height: 12),
                      const CircularProgressIndicator(),
                    ],
                    const SizedBox(height: 20),
                    if (challengeLost && !completed)
                      FilledButton(
                        onPressed: isReporting ? null : onRetry,
                        child: Text(
                          isReporting
                              ? 'Synchronisation...'
                              : 'Réessayer la synchronisation',
                        ),
                      ),
                    if (completed && challengeResult!.canRequestRematch)
                      DuelActionButton(
                        onPressed: isReporting ? null : onRematch,
                        icon: Icons.replay_rounded,
                        label:
                            'Proposer une revanche · '
                            '${3 - challengeResult.rematchesUsed} restante(s)',
                      ),
                    if (completed || !isReporting)
                      FilledButton(
                        onPressed: onExit,
                        child: const Text('Retour aux défis'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VictoryConfetti extends StatefulWidget {
  const _VictoryConfetti();

  @override
  State<_VictoryConfetti> createState() => _VictoryConfettiState();
}

class _VictoryConfettiState extends State<_VictoryConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => CustomPaint(
      painter: _VictoryConfettiPainter(_controller.value),
      size: Size.infinite,
    ),
  );
}

class _VictoryConfettiPainter extends CustomPainter {
  const _VictoryConfettiPainter(this.progress);

  final double progress;
  static const colors = [
    Color(0xFFFFD54F),
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFFB388FF),
    Color(0xFFFF8A65),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite || !size.height.isFinite) return;
    for (var index = 0; index < 48; index++) {
      final seed = index * 37;
      final startX = ((seed * 17) % 100) / 100;
      final speed = 0.55 + (seed % 13) / 14;
      final yProgress = (progress * speed + ((seed * 7) % 100) / 100) % 1;
      final sway = math.sin((progress * math.pi * 2) + seed) * 18;
      final x = startX * size.width + sway;
      final y = yProgress * size.height;
      final color = colors[index % colors.length];
      final paint = Paint()..color = color.withValues(alpha: 0.88);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 4 + seed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + seed % 5,
            height: 8 + seed % 5,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VictoryConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ChallengeRoundCompleteOverlay extends StatelessWidget {
  const _ChallengeRoundCompleteOverlay({
    required this.roundNumber,
    required this.score,
    required this.isSubmitting,
    required this.isSubmitted,
    required this.opponentSubmitted,
    required this.error,
    required this.onRetry,
  });

  final int roundNumber;
  final int score;
  final bool isSubmitting;
  final bool isSubmitted;
  final bool opponentSubmitted;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final waitingForOpponent = isSubmitted && !opponentSubmitted;
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFFFCA28),
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  'Fin de la manche $roundNumber/3',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Score : $score', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  waitingForOpponent
                      ? 'Ta manche est validée. En attente de la légende adverse…'
                      : isSubmitted && opponentSubmitted
                      ? 'Passage à la manche suivante…'
                      : 'Synchronise la fin de cette manche pour continuer.',
                  textAlign: TextAlign.center,
                ),
                if (isSubmitting ||
                    waitingForOpponent ||
                    (isSubmitted && opponentSubmitted)) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                if (!isSubmitted || error != null)
                  FilledButton(
                    onPressed: isSubmitting ? null : onRetry,
                    child: Text(
                      isSubmitting
                          ? 'Synchronisation...'
                          : 'Réessayer la synchronisation',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelValidationOverlay extends StatelessWidget {
  const _LevelValidationOverlay({required this.game});

  final FopcamGame game;

  @override
  Widget build(BuildContext context) {
    final isFinalLevel = game.level == GameLevel.all.length;
    final nextLevelName = isFinalLevel ? null : GameLevel.all[game.level].name;

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFinalLevel ? Icons.workspace_premium : Icons.flag,
                  color: game.currentLevel.color,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Niveau ${game.level} réussi !',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isFinalLevel
                      ? 'Valide le dernier niveau pour recevoir ta récompense '
                            'personnalisée.'
                      : 'Valide ce niveau pour débloquer le niveau '
                            '${game.level + 1} : $nextLevelName.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: game.validateCurrentLevel,
                  child: Text(
                    isFinalLevel
                        ? 'Valider et recevoir ma récompense'
                        : 'Valider le niveau',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
