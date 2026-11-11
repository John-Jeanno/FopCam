import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mobile/game/fopcam_game.dart';
import 'package:mobile/models/game_live_duel.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/game_screen_frame.dart';

class LiveDuelSpectatorScreen extends StatefulWidget {
  const LiveDuelSpectatorScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<LiveDuelSpectatorScreen> createState() =>
      _LiveDuelSpectatorScreenState();
}

class _LiveDuelSpectatorScreenState extends State<LiveDuelSpectatorScreen> {
  GameLiveDuel? _duel;
  FopcamGame? _game;
  Timer? _pollTimer;
  bool _polling = false;
  bool _ended = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 650),
      (_) => unawaited(_poll()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(FopcamGame.pauseGameMusic());
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || _ended) return;
    _polling = true;
    try {
      final duel = await ApiService.fetchLiveGameDuelState(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _duel = duel;
        _error = null;
      });
      final state = duel.state;
      if (state != null) {
        final game = _game;
        if (game == null) {
          setState(() {
            _game = FopcamGame(
              isChallengeMode: true,
              isSpectatorMode: true,
              challengeRoundNumber: duel.roundNumber,
              initialSpectatorState: state,
              initialScore: state['score'] as int? ?? 0,
            );
          });
        } else {
          game.applySpectatorState(state);
        }
      }
    } on StateError catch (error) {
      if (!mounted) return;
      if (error.message == 'Duel terminé.') {
        _pollTimer?.cancel();
        setState(() => _ended = true);
      } else {
        setState(() => _error = error.message.toString());
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur de suivi du duel ${widget.challengeId}: $error\n$stackTrace',
      );
      if (mounted) setState(() => _error = 'Connexion au duel interrompue.');
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duel = _duel;
    return GameScreenFrame(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Duel en direct'),
          backgroundColor: const Color(0xFF111827),
        ),
        backgroundColor: const Color(0xFF101725),
        body: SafeArea(
          child: Column(
            children: [
              if (duel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      Text(
                        '${duel.challengerName}  ${duel.challengerScore}'
                        '  –  ${duel.challengedScore}  ${duel.challengedName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ended
                            ? 'Duel terminé'
                            : 'Manche ${duel.roundNumber}/3'
                                  '${duel.activePlayerName == null ? '' : ' · Tour de ${duel.activePlayerName}'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _ended
                    ? const Center(
                        child: Text(
                          'Ce duel est terminé.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : _game != null
                    ? GameWidget<FopcamGame>(game: _game!)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_error == null)
                              const CircularProgressIndicator(
                                color: Color(0xFFFFCA28),
                              )
                            else
                              const Icon(
                                Icons.wifi_off,
                                color: Colors.orangeAccent,
                                size: 32,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _error ??
                                  'En attente des premières données du duel…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
