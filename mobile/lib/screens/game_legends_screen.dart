import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile/models/game_challenge.dart';
import 'package:mobile/models/game_legend.dart';
import 'package:mobile/models/game_live_duel.dart';
import 'package:mobile/models/game_tournament.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/widgets/duel_action_button.dart';
import 'package:mobile/widgets/game_screen_frame.dart';
import 'package:mobile/widgets/trophy_art.dart';

class GameLegendsScreen extends StatefulWidget {
  const GameLegendsScreen({super.key});

  @override
  State<GameLegendsScreen> createState() => _GameLegendsScreenState();
}

class _GameLegendsScreenState extends State<GameLegendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  final TextEditingController _legendSearchController = TextEditingController();
  late Future<List<GameLegend>> _legends;
  late Future<List<GameChallenge>> _challenges;
  late Future<List<GameTournament>> _tournaments;
  late Future<List<GameLiveDuel>> _liveDuels;
  Timer? _liveDuelRefreshTimer;
  Timer? _challengeExpiryTimer;
  String? _username;
  GameLegendTier? _selectedTier;
  String _legendSearch = '';

  @override
  void initState() {
    super.initState();
    _legends = ApiService.fetchGameLegends();
    _challenges = _loadChallenges();
    _tournaments = ApiService.fetchGameTournaments();
    _liveDuels = ApiService.fetchLiveGameDuels();
    _liveDuelRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _liveDuels = ApiService.fetchLiveGameDuels());
    });
    _loadUsername();
  }

  @override
  void dispose() {
    _liveDuelRefreshTimer?.cancel();
    _challengeExpiryTimer?.cancel();
    _tabs.dispose();
    _legendSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final userData = await StorageService.getUserData();
    if (userData == null) return;
    try {
      final decoded = jsonDecode(userData);
      if (decoded is Map<String, dynamic>) {
        final user = User.fromJson(decoded);
        if (mounted) setState(() => _username = user.username);
      }
    } on FormatException catch (error) {
      debugPrint('GameLegendsScreen: profil utilisateur invalide: $error');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _legends = ApiService.fetchGameLegends();
      _challenges = _loadChallenges();
      _tournaments = ApiService.fetchGameTournaments();
      _liveDuels = ApiService.fetchLiveGameDuels();
    });
    await Future.wait([_legends, _challenges, _tournaments, _liveDuels]);
  }

  Future<List<GameChallenge>> _loadChallenges() async {
    final challenges = await ApiService.fetchGameChallenges();
    if (!mounted) return challenges;
    _scheduleChallengeExpiry(challenges);
    return challenges;
  }

  void _scheduleChallengeExpiry(List<GameChallenge> challenges) {
    _challengeExpiryTimer?.cancel();
    final now = DateTime.now();
    final nextExpiry = challenges
        .where(
          (challenge) =>
              challenge.status == 'accepted' &&
              challenge.startedAt == null &&
              challenge.expiresAt != null &&
              challenge.expiresAt!.isAfter(now),
        )
        .map((challenge) => challenge.expiresAt!)
        .fold<DateTime?>(null, (nearest, expiry) {
          if (nearest == null || expiry.isBefore(nearest)) return expiry;
          return nearest;
        });
    if (nextExpiry == null) return;

    _challengeExpiryTimer = Timer(nextExpiry.difference(now), () {
      if (!mounted) return;
      setState(() => _challenges = _loadChallenges());
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.readableGameError(error))),
        );
      }
    }
  }

  Future<void> _challenge(GameLegend legend) => _perform(() async {
    await ApiService.createGameChallenge(legendId: legend.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Défi lancé à ${legend.displayName}.')),
      );
  });

  Future<void> _respond(GameChallenge challenge, bool accept) =>
      _perform(() async {
        await ApiService.respondToGameChallenge(
          challengeId: challenge.id,
          accept: accept,
        );
      });

  Future<void> _cancelChallenge(GameChallenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce défi ?'),
        content: const Text(
          'Ton adversaire sera informé de l’annulation de cette invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder le défi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _perform(
      () => ApiService.cancelGameChallenge(challengeId: challenge.id),
    );
  }

  Future<void> _deleteChallenge(GameChallenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce défi ?'),
        content: const Text(
          'Il sera supprimé définitivement de la liste des deux joueurs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _perform(
      () => ApiService.deleteGameChallenge(challengeId: challenge.id),
    );
  }

  Future<void> _requestRematch(GameChallenge challenge) => _perform(() async {
    await ApiService.requestGameChallengeRematch(challengeId: challenge.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Revanche lancée à '
            '${challenge.opponent?.displayName ?? 'ton adversaire'}.',
          ),
        ),
      );
  });

  Future<void> _playChallenge(GameChallenge challenge) async {
    await Navigator.of(
      context,
    ).pushNamed('/game', arguments: {'challengeId': challenge.id});
    if (mounted) await _refresh();
  }

  Future<void> _createTournament(List<GameLegend> legends) async {
    final selection = await _showTournamentPlayerSelection(
      legends: legends,
      capacity: 6,
      title: 'Créer un championnat',
      chooseCapacity: true,
    );
    if (selection == null || !mounted) return;
    await _perform(() async {
      await ApiService.createGameTournament(
        capacity: selection['capacity'] as int,
        invitedIds: selection['user_ids'] as List<int>,
      );
    });
  }

  Future<void> _inviteTournamentPlayers(
    GameTournament tournament,
    List<GameLegend> legends,
  ) async {
    final selection = await _showTournamentPlayerSelection(
      legends: legends,
      capacity: tournament.capacity,
      title: 'Inviter des Champions League Pro',
      excludedIds: tournament.entries
          .map((entry) => entry['user_id'] as int)
          .toSet(),
      availableSlots: tournament.capacity - tournament.entries.length,
    );
    if (selection == null || selection['user_ids'] is! List<int>) return;
    await _perform(() async {
      await ApiService.inviteGameTournamentPlayers(
        tournamentId: tournament.id,
        userIds: selection['user_ids'] as List<int>,
      );
    });
  }

  Future<Map<String, Object>?> _showTournamentPlayerSelection({
    required List<GameLegend> legends,
    required int capacity,
    required String title,
    Set<int> excludedIds = const {},
    int? availableSlots,
    bool chooseCapacity = false,
  }) async {
    var selectedCapacity = capacity;
    final selectedIds = <int>{};
    int maxInviteCount() => chooseCapacity
        ? selectedCapacity - 1
        : availableSlots ?? selectedCapacity - 1;
    final eligible = legends
        .where(
          (legend) =>
              legend.duelMedal == 'cup_pro' &&
              legend.username != _username &&
              !excludedIds.contains(legend.id),
        )
        .toList(growable: false);
    return showDialog<Map<String, Object>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chooseCapacity)
                  DropdownButtonFormField<int>(
                    initialValue: selectedCapacity,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: const [
                      DropdownMenuItem(value: 6, child: Text('6 joueurs')),
                      DropdownMenuItem(value: 12, child: Text('12 joueurs')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCapacity = value;
                          while (selectedIds.length > selectedCapacity - 1) {
                            selectedIds.remove(selectedIds.last);
                          }
                        });
                      }
                    },
                  ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionne jusqu’à ${maxInviteCount()} participants '
                  'à inviter. Les places libres resteront ouvertes.',
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final legend in eligible)
                        CheckboxListTile(
                          value: selectedIds.contains(legend.id),
                          title: Text(legend.displayName),
                          subtitle: Text('@${legend.username}'),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true &&
                                  selectedIds.length < maxInviteCount()) {
                                selectedIds.add(legend.id);
                              } else {
                                selectedIds.remove(legend.id);
                              }
                            });
                          },
                        ),
                      if (eligible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Aucun autre Champion League Pro à inviter.',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty && !chooseCapacity
                  ? null
                  : () => Navigator.pop(context, {
                      'capacity': selectedCapacity,
                      'user_ids': selectedIds.toList(),
                    }),
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTournamentMatch(
    GameTournament tournament,
    Map<String, dynamic> match,
    bool isParticipant,
  ) async {
    try {
      final challenge = match['status'] == 'playing'
          ? GameChallenge.fromJson({
              'id': match['challenge_id'],
              'status': 'playing',
            })
          : await ApiService.startGameTournamentMatch(
              tournamentId: tournament.id,
              matchId: match['id'] as int,
            );
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        isParticipant ? '/game' : '/game/spectate',
        arguments: {'challengeId': challenge.id},
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.readableGameError(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      appBar: AppBar(
        title: const Text('Légendes FopCam'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.sports_kabaddi), text: 'Duels'),
            Tab(text: '💪 Mes Victoires'),
            Tab(text: '😊 Mes défaites'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Classement'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Championnat'),
          ],
        ),
      ),
      body: FutureBuilder<List<GameLegend>>(
        future: _legends,
        builder: (context, legendSnapshot) {
          if (legendSnapshot.hasError) {
            return _LoadError(error: legendSnapshot.error, onRetry: _refresh);
          }
          if (!legendSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<List<GameChallenge>>(
            future: _challenges,
            builder: (context, challengeSnapshot) {
              if (challengeSnapshot.hasError) {
                return _LoadError(
                  error: challengeSnapshot.error,
                  onRetry: _refresh,
                );
              }
              if (!challengeSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final legends = legendSnapshot.data!;
              final challenges = challengeSnapshot.data!;
              final currentUserLegend = legends
                  .where((legend) => legend.username == _username)
                  .firstOrNull;
              final victories = challenges
                  .where((challenge) => challenge.isMyVictory)
                  .toList(growable: false);
              final defeats = challenges
                  .where((challenge) => challenge.isMyDefeat)
                  .toList(growable: false);
              final activeChallenges = challenges
                  .where(
                    (challenge) =>
                        !challenge.isMyVictory && !challenge.isMyDefeat,
                  )
                  .toList(growable: false);
              return FutureBuilder<List<GameTournament>>(
                future: _tournaments,
                builder: (context, tournamentSnapshot) {
                  if (tournamentSnapshot.hasError) {
                    return _LoadError(
                      error: tournamentSnapshot.error,
                      onRetry: _refresh,
                    );
                  }
                  if (!tournamentSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _buildDuelsTab(activeChallenges),
                          _buildCompletedDuelsTab(
                            challenges: victories,
                            title: 'Mes Victoires',
                            emoji: '💪',
                            emptyTitle: 'Pas encore de victoire',
                            emptyDescription:
                                'Tes duels remportés apparaîtront ici.',
                          ),
                          _buildCompletedDuelsTab(
                            challenges: defeats,
                            title: 'Mes défaites',
                            emoji: '😊',
                            emptyTitle: 'Aucune défaite',
                            emptyDescription:
                                'Tes autres duels restent à jouer. Courage !',
                          ),
                          _buildLeaderboardTab(
                            legends: legends,
                            challenges: challenges,
                            currentUserLegend: currentUserLegend,
                          ),
                          _buildTournamentsTab(
                            tournamentSnapshot.data!,
                            legends,
                            currentUserLegend,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
    final responsiveScreen = kIsWeb
        ? screen
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(
                context,
              ).textScaler.clamp(maxScaleFactor: 1.2),
              boldText: false,
            ),
            child: screen,
          );
    return GameScreenFrame(child: responsiveScreen);
  }

  Widget _buildDuelsTab(List<GameChallenge> challenges) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PageIntroCard(
          icon: Icons.sports_kabaddi,
          title: 'Entre dans l’arène',
          description:
              'Suis un duel en direct ou retrouve tes invitations et tes '
              'demandes de revanche au même endroit.',
        ),
        _LiveDuelsSection(
          future: _liveDuels,
          onRetry: _refresh,
          onWatch: (duel) async {
            await Navigator.of(
              context,
            ).pushNamed('/game/spectate', arguments: {'challengeId': duel.id});
            if (mounted) await _refresh();
          },
        ),
        _SectionHeading(
          title: 'Mes défis',
          subtitle: 'Invitations, parties en cours et revanche',
          count: challenges.length,
          icon: Icons.flag_outlined,
        ),
        if (challenges.isEmpty)
          _EmptySectionCard(
            icon: Icons.sports_kabaddi,
            title: 'Aucun défi pour le moment',
            description:
                'Choisis une légende du même niveau et lance un duel en '
                'un clic.',
            actionLabel: 'Trouver un adversaire',
            onAction: () => _tabs.animateTo(3),
          )
        else
          for (final challenge in challenges)
            _ChallengeTile(
              challenge: challenge,
              pendingRematch: _pendingRematchFor(challenge, challenges),
              onAccept: () => _respond(challenge, true),
              onDecline: () => _respond(challenge, false),
              onPlay: () => _playChallenge(challenge),
              onRematch: () => _requestRematch(challenge),
              onCancel: challenge.canCancel
                  ? () => _cancelChallenge(challenge)
                  : null,
              onDelete: challenge.canDelete
                  ? () => _deleteChallenge(challenge)
                  : null,
            ),
      ],
    ),
  );

  Widget _buildCompletedDuelsTab({
    required List<GameChallenge> challenges,
    required String title,
    required String emoji,
    required String emptyTitle,
    required String emptyDescription,
  }) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PageIntroCard(
          icon: title == 'Mes Victoires'
              ? Icons.emoji_events
              : Icons.sentiment_satisfied_alt,
          title: '$emoji $title',
          description: title == 'Mes Victoires'
              ? 'Retrouve ici les duels que tu as remportés.'
              : 'Retrouve ici les duels terminés que tu as perdus.',
        ),
        _SectionHeading(
          title: title,
          subtitle: title == 'Mes Victoires'
              ? 'Tes duels remportés'
              : 'Tes duels terminés',
          count: challenges.length,
          icon: title == 'Mes Victoires'
              ? Icons.emoji_events
              : Icons.sentiment_satisfied_alt,
        ),
        if (challenges.isEmpty)
          _EmptySectionCard(
            icon: title == 'Mes Victoires'
                ? Icons.emoji_events_outlined
                : Icons.sentiment_satisfied_alt,
            title: emptyTitle,
            description: emptyDescription,
          )
        else
          for (final challenge in challenges)
            _ChallengeTile(
              challenge: challenge,
              pendingRematch: _pendingRematchFor(challenge, challenges),
              onAccept: () => _respond(challenge, true),
              onDecline: () => _respond(challenge, false),
              onPlay: () => _playChallenge(challenge),
              onRematch: () => _requestRematch(challenge),
            ),
      ],
    ),
  );

  Widget _buildLeaderboardTab({
    required List<GameLegend> legends,
    required List<GameChallenge> challenges,
    required GameLegend? currentUserLegend,
  }) {
    final normalizedQuery = _legendSearch.trim().toLowerCase();
    final matchingLegends = legends
        .where((legend) {
          final matchesTier =
              _selectedTier == null || legend.appearsInTier(_selectedTier!);
          final matchesSearch =
              normalizedQuery.isEmpty ||
              legend.displayName.toLowerCase().contains(normalizedQuery) ||
              legend.username.toLowerCase().contains(normalizedQuery);
          return matchesTier && matchesSearch;
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PageIntroCard(
            icon: Icons.emoji_events_outlined,
            title: 'Trouve ton prochain adversaire',
            description:
                'Filtre par titre ou cherche un nom. Le bouton doré '
                '« Défier en duel » envoie directement l’invitation.',
          ),
          TextField(
            controller: _legendSearchController,
            onChanged: (value) => setState(() => _legendSearch = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Rechercher une légende',
              suffixIcon: _legendSearch.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        _legendSearchController.clear();
                        setState(() => _legendSearch = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _TierFilterChip(
                  label: 'Toutes',
                  count: legends.length,
                  selected: _selectedTier == null,
                  onSelected: () => setState(() => _selectedTier = null),
                ),
                for (final tier in GameLegendTier.values)
                  _TierFilterChip(
                    label: _tierLabel(tier),
                    count: legends
                        .where((legend) => legend.appearsInTier(tier))
                        .length,
                    selected: _selectedTier == tier,
                    onSelected: () => setState(() => _selectedTier = tier),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${matchingLegends.length} '
            '${matchingLegends.length == 1 ? 'légende trouvée' : 'légendes trouvées'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (legends.isEmpty)
            const _EmptySectionCard(
              icon: Icons.emoji_events_outlined,
              title: 'Aucune légende pour le moment',
              description:
                  'Sois le premier à valider les 12 niveaux pour rejoindre '
                  'le classement.',
            )
          else if (matchingLegends.isEmpty)
            _EmptySectionCard(
              icon: Icons.search_off,
              title: 'Aucun résultat',
              description: _selectedTier == null
                  ? 'Essaie un autre nom ou pseudonyme.'
                  : 'Aucune légende dans cette catégorie pour le moment.',
              actionLabel: _selectedTier == null ? null : 'Voir toutes',
              onAction: _selectedTier == null
                  ? null
                  : () => setState(() => _selectedTier = null),
            )
          else
            for (final tier in GameLegendTier.values)
              if (_selectedTier == null || _selectedTier == tier)
                _LegendTierSection(
                  tier: tier,
                  legends: matchingLegends
                      .where((legend) => legend.appearsInTier(tier))
                      .toList(growable: false),
                  itemBuilder: (legend) {
                    final medals = legend.medalsForTier(tier);
                    return _LegendTile(
                      legend: legend,
                      tier: tier,
                      medals: medals,
                      isCurrentUser: legend.username == _username,
                      hasOpenChallenge: _hasOpenChallengeWithLegend(
                        legend,
                        challenges,
                      ),
                      canChallenge:
                          currentUserLegend != null &&
                          currentUserLegend.id != legend.id &&
                          currentUserLegend.canChallenge(legend),
                      isLegend: currentUserLegend != null,
                      onChallenge: () => _challenge(legend),
                      onViewChallenges: () => _tabs.animateTo(0),
                    );
                  },
                ),
          if (currentUserLegend == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Valide d’abord le niveau 12 pour pouvoir défier une légende.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab(
    List<GameTournament> tournaments,
    List<GameLegend> legends,
    GameLegend? currentUserLegend,
  ) {
    final canOrganize = currentUserLegend?.duelMedal == 'cup_pro';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PageIntroCard(
            icon: Icons.emoji_events,
            title: 'Championnat FopCam',
            description:
                'Les Champions League Pro organisent et disputent les '
                'tournois. Tous les autres joueurs peuvent suivre les matchs '
                'en direct et soutenir un champion.',
          ),
          if (canOrganize)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => _createTournament(legends),
                icon: const Icon(Icons.add),
                label: const Text('Créer un championnat'),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'L’organisation et la participation sont réservées aux '
                  'Champions League Pro. Le suivi et les votes restent ouverts '
                  'à tous.',
                ),
              ),
            ),
          if (tournaments.isEmpty)
            const _EmptySectionCard(
              icon: Icons.emoji_events_outlined,
              title: 'Aucun championnat disponible',
              description:
                  'Un championnat apparaîtra ici dès qu’un Champion League '
                  'Pro en aura créé un.',
            )
          else
            for (final tournament in tournaments)
              _TournamentCard(
                tournament: tournament,
                onJoin: () => _perform(() async {
                  await ApiService.joinGameTournament(tournament.id);
                }),
                onStart: () => _perform(() async {
                  await ApiService.startGameTournament(tournament.id);
                }),
                onInvite: () => _inviteTournamentPlayers(tournament, legends),
                onSupport: (participantId) => _perform(() async {
                  await ApiService.supportGameTournamentPlayer(
                    tournamentId: tournament.id,
                    participantId: participantId,
                  );
                }),
                onMatch: (match, isParticipant) =>
                    _startTournamentMatch(tournament, match, isParticipant),
              ),
        ],
      ),
    );
  }

  bool _hasOpenChallengeWithLegend(
    GameLegend legend,
    List<GameChallenge> challenges,
  ) => challenges.any(
    (challenge) =>
        challenge.opponent?.id == legend.id &&
        const {'pending', 'accepted', 'playing'}.contains(challenge.status),
  );

  GameChallenge? _pendingRematchFor(
    GameChallenge challenge,
    List<GameChallenge> challenges,
  ) {
    if (challenge.status != 'completed' || challenge.isRematch) return null;
    for (final rematch in challenges) {
      if (rematch.isRematch &&
          rematch.status == 'pending' &&
          rematch.isOutgoingPending &&
          rematch.opponent?.id == challenge.opponent?.id) {
        return rematch;
      }
    }
    return null;
  }
}

class _TournamentCard extends StatefulWidget {
  const _TournamentCard({
    required this.tournament,
    required this.onJoin,
    required this.onStart,
    required this.onInvite,
    required this.onSupport,
    required this.onMatch,
  });

  final GameTournament tournament;
  final Future<void> Function() onJoin;
  final Future<void> Function() onStart;
  final Future<void> Function() onInvite;
  final Future<void> Function(int participantId) onSupport;
  final Future<void> Function(Map<String, dynamic> match, bool isParticipant)
  onMatch;

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  int? _selectedSupportId;

  @override
  Widget build(BuildContext context) {
    final tournament = widget.tournament;
    final entries = tournament.entries;
    final confirmedEntries = entries
        .where((entry) => entry['status'] == 'confirmed')
        .toList(growable: false);
    final isParticipant = entries.any(
      (entry) => entry['is_me'] == true && entry['status'] == 'confirmed',
    );
    final openStatus = tournament.status == 'registration';
    final statusLabel = switch (tournament.status) {
      'registration' => 'Inscriptions',
      'groups' => 'Phase de poules',
      'quarterfinals' => 'Quarts de finale',
      'semifinals' => 'Demi-finales',
      'final' => 'Finale',
      'completed' => 'Terminé',
      _ => tournament.status,
    };
    final eligibleSupportTargets = confirmedEntries
        .where((entry) => entry['user_id'] is int)
        .toList(growable: false);
    final selectedId =
        tournament.mySupportedUserId ??
        _selectedSupportId ??
        (eligibleSupportTargets.isEmpty
            ? null
            : eligibleSupportTargets.first['user_id'] as int);
    final winner = entries
        .where((entry) => entry['user_id'] == tournament.winnerId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFC107),
          child: Icon(Icons.emoji_events, color: Colors.black87),
        ),
        title: Text(
          '${tournament.capacity} joueurs · $statusLabel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Organisé par ${tournament.organizerName}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${confirmedEntries.length}/${tournament.capacity} joueurs inscrits',
            ),
          ),
          if (tournament.trophyTitle.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text(tournament.trophyTitle),
              subtitle: Text(
                winner == null
                    ? 'Trophée du championnat'
                    : 'Vainqueur : ${winner['name']}',
              ),
            ),
          if (tournament.standings.isNotEmpty) ...[
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Classement des poules',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (var group = 1; group <= tournament.capacity ~/ 3; group++) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Poule ${String.fromCharCode(64 + group)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final row in tournament.standings.where(
                (item) => item['group_number'] == group,
              ))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 15,
                    child: Text('${row['position']}'),
                  ),
                  title: Text(row['name'] as String? ?? 'Champion'),
                  subtitle: Text(
                    '${row['points']} pts · ${row['wins']} victoire(s) · '
                    'score ${row['score_for']}–${row['score_against']}',
                  ),
                ),
            ],
          ],
          if (tournament.canJoin)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onJoin,
                child: const Text('Rejoindre le championnat'),
              ),
            ),
          if (tournament.isOrganizer && openStatus) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onInvite,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Inviter'),
                  ),
                ),
                if (tournament.canStart) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onStart,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Démarrer'),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (!openStatus &&
              tournament.status != 'completed' &&
              !isParticipant &&
              eligibleSupportTargets.isNotEmpty) ...[
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisis le champion que tu soutiens',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DropdownButton<int>(
              isExpanded: true,
              value:
                  eligibleSupportTargets.any(
                    (entry) => entry['user_id'] == selectedId,
                  )
                  ? selectedId
                  : eligibleSupportTargets.first['user_id'] as int,
              items: [
                for (final entry in eligibleSupportTargets)
                  DropdownMenuItem<int>(
                    value: entry['user_id'] as int,
                    child: Text(entry['name'] as String? ?? 'Champion'),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedSupportId = value),
            ),
            OutlinedButton.icon(
              onPressed: selectedId == null
                  ? null
                  : () => widget.onSupport(selectedId),
              icon: const Icon(Icons.favorite),
              label: Text(
                tournament.mySupportedUserId == selectedId
                    ? 'Soutien enregistré'
                    : 'Soutenir ce champion',
              ),
            ),
          ],
          if (confirmedEntries.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Participants et supporters',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final entry in confirmedEntries)
              Builder(
                builder: (context) {
                  final id = entry['user_id'] as int;
                  final supporters =
                      tournament.supporters[id.toString()] ?? const [];
                  final group = entry['group_number'];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text((entry['name'] as String? ?? '?')[0]),
                    ),
                    title: Text(entry['name'] as String? ?? 'Champion'),
                    subtitle: Text(
                      [
                        if (group is int)
                          'Poule ${String.fromCharCode(64 + group)}',
                        '${tournament.supportCounts[id.toString()] ?? 0} soutien(s)',
                        if (supporters.isNotEmpty)
                          'Soutenu par : ${supporters.join(', ')}',
                      ].join(' · '),
                    ),
                  );
                },
              ),
          ],
          if (tournament.matches.isNotEmpty) ...[
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Calendrier et suivi en direct',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final match in tournament.matches)
              Builder(
                builder: (context) {
                  final playerA = Map<String, dynamic>.from(
                    match['player_a'] as Map,
                  );
                  final playerB = Map<String, dynamic>.from(
                    match['player_b'] as Map,
                  );
                  final isMyMatch =
                      playerA['id'] == _myEntryId(entries) ||
                      playerB['id'] == _myEntryId(entries);
                  final roundLabel = switch (match['round'] as String?) {
                    'group' =>
                      'Poule ${String.fromCharCode(64 + ((match['group_number'] as int?) ?? 1))}',
                    'quarterfinal' => 'Quart de finale',
                    'semifinal' => 'Demi-finale',
                    'final' => 'Finale',
                    _ => 'Match',
                  };
                  final playing = match['status'] == 'playing';
                  final completed = match['status'] == 'completed';
                  final scores = match['scores'] is Map
                      ? Map<String, dynamic>.from(match['scores'] as Map)
                      : const <String, dynamic>{};
                  final scoreLine =
                      scores.containsKey('${playerA['id']}') &&
                          scores.containsKey('${playerB['id']}') &&
                          scores['${playerA['id']}'] != null &&
                          scores['${playerB['id']}'] != null
                      ? ' · ${scores['${playerA['id']}']}–'
                            '${scores['${playerB['id']}']}'
                      : '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      playing ? Icons.sensors : Icons.sports_esports,
                      color: playing ? Colors.redAccent : null,
                    ),
                    title: Text('${playerA['name']} — ${playerB['name']}'),
                    subtitle: Text(
                      '$roundLabel${completed
                          ? ' · Terminé'
                          : playing
                          ? ' · En direct'
                          : ' · À jouer'}$scoreLine',
                    ),
                    trailing: playing || (!completed && isMyMatch)
                        ? TextButton(
                            onPressed: () => widget.onMatch(match, isMyMatch),
                            child: Text(
                              playing && !isMyMatch
                                  ? 'Suivre'
                                  : playing
                                  ? 'Reprendre'
                                  : 'Jouer',
                            ),
                          )
                        : null,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  int? _myEntryId(List<Map<String, dynamic>> entries) {
    for (final entry in entries) {
      if (entry['is_me'] == true) return entry['user_id'] as int?;
    }
    return null;
  }
}

class _PageIntroCard extends StatelessWidget {
  const _PageIntroCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 18),
    color: const Color(0xFF171D2C),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFFFC107)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFFFC107)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.16),
          foregroundColor: const Color(0xFFFFC107),
          child: Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class _TierFilterChip extends StatelessWidget {
  const _TierFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: selected ? null : CircleAvatar(child: Text('$count')),
      label: Text(label),
      selectedColor: const Color(0xFFFFC107),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF2B1600) : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  );
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFFFFC107)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(description, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LiveDuelsSection extends StatelessWidget {
  const _LiveDuelsSection({
    required this.future,
    required this.onRetry,
    required this.onWatch,
  });

  final Future<List<GameLiveDuel>> future;
  final Future<void> Function() onRetry;
  final ValueChanged<GameLiveDuel> onWatch;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<GameLiveDuel>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Impossible de charger les duels en direct.'),
            trailing: IconButton(
              tooltip: 'Réessayer',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      final duels = snapshot.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duels en direct',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (duels == null)
            const Center(child: CircularProgressIndicator())
          else if (duels.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun duel public en cours pour le moment.'),
              ),
            )
          else
            for (final duel in duels)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.visibility,
                    color: Color(0xFFD4AF37),
                  ),
                  title: Text(
                    '${duel.challengerName} – ${duel.challengedName}',
                  ),
                  subtitle: Text(
                    'Manche ${duel.roundNumber}/3 · '
                    '${duel.challengerScore} – ${duel.challengedScore}'
                    '${duel.hasLiveState ? '' : ' · connexion des joueurs…'}',
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => onWatch(duel),
                ),
              ),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}

class _LegendTierSection extends StatelessWidget {
  const _LegendTierSection({
    required this.tier,
    required this.legends,
    required this.itemBuilder,
  });

  final GameLegendTier tier;
  final List<GameLegend> legends;
  final Widget Function(GameLegend) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      GameLegendTier.legend => const Color(0xFF607D8B),
      GameLegendTier.legendPlus => const Color(0xFFCD7F32),
      GameLegendTier.legendPro => const Color(0xFF90A4AE),
      GameLegendTier.champion => const Color(0xFFFFC107),
      GameLegendTier.championLeague => const Color(0xFFD4AF37),
      GameLegendTier.championLeaguePro => const Color(0xFF9B59B6),
    };
    final icon = switch (tier) {
      GameLegendTier.legend => Icons.stars_outlined,
      GameLegendTier.legendPlus => Icons.workspace_premium_outlined,
      GameLegendTier.legendPro => Icons.military_tech_outlined,
      GameLegendTier.champion => Icons.emoji_events,
      GameLegendTier.championLeague => Icons.emoji_events,
      GameLegendTier.championLeaguePro => Icons.workspace_premium,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.06),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (tier) {
                          GameLegendTier.legend => 'Légende',
                          GameLegendTier.legendPlus => 'Légende+',
                          GameLegendTier.legendPro => 'Légende Pro',
                          GameLegendTier.champion => 'Champion FopCam',
                          GameLegendTier.championLeague =>
                            'Champion 1ère Ligue',
                          GameLegendTier.championLeaguePro =>
                            'Champion League Pro',
                        },
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(switch (tier) {
                        GameLegendTier.legend => 'Niveau 12',
                        GameLegendTier.legendPlus =>
                          'Niveau 12 · Médaille de bronze',
                        GameLegendTier.legendPro =>
                          'Niveau 12 · Médaille d’argent',
                        GameLegendTier.champion => 'Niveau 12 · Médaille d’or',
                        GameLegendTier.championLeague => 'Niveau 12 · Coupe',
                        GameLegendTier.championLeaguePro =>
                          'Niveau 12 · 5 victoires distinctes',
                      }, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Text(
                    '${legends.length}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (legends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aucun joueur dans cette catégorie pour le moment.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...legends.map(itemBuilder),
        ],
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.legend,
    required this.tier,
    required this.medals,
    required this.isCurrentUser,
    required this.hasOpenChallenge,
    required this.canChallenge,
    required this.isLegend,
    required this.onChallenge,
    required this.onViewChallenges,
  });

  final GameLegend legend;
  final GameLegendTier tier;
  final List<String> medals;
  final bool isCurrentUser;
  final bool hasOpenChallenge;
  final bool canChallenge;
  final bool isLegend;
  final VoidCallback onChallenge;
  final VoidCallback onViewChallenges;

  @override
  Widget build(BuildContext context) {
    final avatar = legend.avatarUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFCA28),
              foregroundImage: avatar == null ? null : NetworkImage(avatar),
              child: avatar == null
                  ? Text(
                      '${legend.rank}',
                      style: const TextStyle(color: Colors.black),
                    )
                  : null,
            ),
            title: Text(
              '${legend.rank}. ${legend.displayLabel}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tierLabel(tier)} · ${_tierRequirement(tier)}'
                  '\nMeilleur score : ${legend.score}',
                ),
                if (medals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final medal in medals)
                        ActionChip(
                          avatar: medal == 'cup' || medal == 'cup_pro'
                              ? TrophyCelebration(
                                  medal: medal,
                                  width: 32,
                                  height: 32,
                                )
                              : Icon(
                                  Icons.workspace_premium,
                                  size: 18,
                                  color: _medalColor(medal),
                                ),
                          label: Text(_medalLabel(medal)),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _MedalShowcaseDialog(medal: medal),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: isCurrentUser ? const Text('Toi') : null,
          ),
          if (!isCurrentUser && !canChallenge)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                isLegend ? 'Niveau supérieur requis' : 'Débloque le niveau 12',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (hasOpenChallenge)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: DuelActionButton(
                onPressed: onViewChallenges,
                label: 'VOIR DANS MES DUELS',
                icon: Icons.sports_kabaddi,
              ),
            )
          else if (canChallenge)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: DuelActionButton(
                onPressed: onChallenge,
                label: 'DÉFIER EN DUEL',
              ),
            ),
        ],
      ),
    );
  }
}

String _tierLabel(GameLegendTier tier) => switch (tier) {
  GameLegendTier.legend => 'Légende',
  GameLegendTier.legendPlus => 'Légende+',
  GameLegendTier.legendPro => 'Légende Pro',
  GameLegendTier.champion => 'Champion FopCam',
  GameLegendTier.championLeague => 'Champion 1ère Ligue',
  GameLegendTier.championLeaguePro => 'Champion League Pro',
};

String _tierRequirement(GameLegendTier tier) => switch (tier) {
  GameLegendTier.legend => 'Niveau 12',
  GameLegendTier.legendPlus => 'Niveau 12 · Médaille de bronze',
  GameLegendTier.legendPro => 'Niveau 12 · Médaille d’argent',
  GameLegendTier.champion => 'Niveau 12 · Médailles bronze, argent et or',
  GameLegendTier.championLeague => 'Niveau 12 · 4 victoires distinctes',
  GameLegendTier.championLeaguePro => 'Niveau 12 · 5 victoires distinctes',
};

String _medalLabel(String medal) => switch (medal) {
  'bronze' => 'Bronze',
  'silver' => 'Argent',
  'gold' => 'Or',
  'cup' => 'Coupe',
  'cup_pro' => 'Champion League Pro',
  _ => 'Médaille',
};

Color _medalColor(String medal) => switch (medal) {
  'bronze' => const Color(0xFFCD7F32),
  'silver' => const Color(0xFFC6D0D9),
  'gold' => const Color(0xFFFFD54F),
  'cup' => const Color(0xFFD4AF37),
  'cup_pro' => const Color(0xFF9B59B6),
  _ => const Color(0xFFFFCA28),
};

class _MedalShowcaseDialog extends StatefulWidget {
  const _MedalShowcaseDialog({required this.medal});

  final String medal;

  @override
  State<_MedalShowcaseDialog> createState() => _MedalShowcaseDialogState();
}

class _MedalShowcaseDialogState extends State<_MedalShowcaseDialog> {
  double _rotationX = -0.08;
  double _rotationY = -0.25;

  @override
  Widget build(BuildContext context) {
    final color = _medalColor(widget.medal);
    return Dialog(
      backgroundColor: const Color(0xFF151D32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.medal == 'cup' || widget.medal == 'cup_pro'
                  ? widget.medal == 'cup_pro'
                        ? 'Champion League Pro'
                        : 'Coupe · Champion 1ère Ligue'
                  : 'Médaille ${_medalLabel(widget.medal)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _rotationY += details.delta.dx * 0.012;
                  _rotationX -= details.delta.dy * 0.012;
                });
              },
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateY(_rotationY)
                  ..rotateX(_rotationX),
                child: SizedBox(
                  width: 220,
                  height: 250,
                  child: widget.medal == 'cup' || widget.medal == 'cup_pro'
                      ? TrophyCelebration(
                          medal: widget.medal,
                          width: 190,
                          height: 220,
                        )
                      : CustomPaint(painter: _MedalPainter(color: color)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.medal == 'cup'
                  ? 'Fais glisser la coupe pour la faire tourner et admirer ses reliefs.'
                  : 'Fais glisser la médaille pour la faire tourner et admirer ses reliefs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ribbon = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB71C1C), Color(0xFFE53935), Color(0xFF7F0000)],
      ).createShader(Offset.zero & size);
    final ribbonPath = Path()
      ..moveTo(size.width * 0.32, size.height * 0.02)
      ..lineTo(size.width * 0.68, size.height * 0.02)
      ..lineTo(size.width * 0.62, size.height * 0.48)
      ..lineTo(size.width * 0.5, size.height * 0.4)
      ..lineTo(size.width * 0.38, size.height * 0.48)
      ..close();
    canvas.drawShadow(ribbonPath, Colors.black87, 8, true);
    canvas.drawPath(ribbonPath, ribbon);

    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.38;
    final edgePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.42),
        colors: [
          Color.lerp(color, Colors.white, 0.72)!,
          color,
          Color.lerp(color, Colors.black, 0.5)!,
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(
      center.translate(2, 6),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, radius, edgePaint);
    canvas.drawCircle(
      center,
      radius * 0.9,
      Paint()
        ..color = Color.lerp(color, Colors.white, 0.68)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.26)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pointRadius = radius * (i.isEven ? 0.48 : 0.22);
      final point =
          center +
          Offset(math.cos(angle) * pointRadius, math.sin(angle) * pointRadius);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8D8), Color(0xFFFFD54F), Color(0xFF9C6B00)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      canvas.drawCircle(
        center +
            Offset(
              math.cos(angle) * radius * 0.84,
              math.sin(angle) * radius * 0.84,
            ),
        1.5,
        Paint()..color = Color.lerp(color, Colors.white, 0.7)!,
      );
    }
  }

  @override
  bool shouldRepaint(_MedalPainter oldDelegate) => oldDelegate.color != color;
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.challenge,
    this.pendingRematch,
    required this.onAccept,
    required this.onDecline,
    required this.onPlay,
    required this.onRematch,
    this.onCancel,
    this.onDelete,
  });

  final GameChallenge challenge;
  final GameChallenge? pendingRematch;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onPlay;
  final VoidCallback onRematch;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final opponent = challenge.opponent?.displayName ?? 'Légende';
    final isOutgoingPending = challenge.isOutgoingPending;
    final status = switch (challenge.status) {
      'pending' =>
        challenge.isIncoming
            ? 'Demande reçue de $opponent'
            : 'En attente d’acceptation de $opponent',
      'accepted' when challenge.myScore == null =>
        'Défi accepté · prêt pour le duel contre $opponent',
      'accepted' => 'Score envoyé · en attente de $opponent',
      'playing' when challenge.myRoundComplete =>
        'Manche ${challenge.roundNumber} terminée · tu regardes le tour adverse',
      'playing' when !challenge.isMyTurn =>
        'Tu regardes le tour de ${challenge.turnPlayerName ?? opponent}',
      'playing' => 'À toi de jouer · manche ${challenge.roundNumber}/3',
      'declined' =>
        challenge.isIncoming
            ? 'Tu as refusé le défi de $opponent'
            : 'Défi refusé par $opponent',
      'cancelled' =>
        challenge.isIncoming
            ? '$opponent a annulé son défi'
            : 'Tu as annulé ton défi à $opponent',
      'completed' when challenge.isDraw =>
        'Match Nul · Forces égales contre $opponent',
      'completed' when challenge.winnerByScore && challenge.myWon == true =>
        'Victoire au score cumulé contre $opponent',
      'completed' when challenge.winnerByScore && challenge.myWon == false =>
        'Défaite au score cumulé contre $opponent',
      'completed' when challenge.myWon == true =>
        'Tu as remporté le duel contre $opponent',
      'completed' when challenge.myWon == false =>
        'Tu as été rétrogradé en premier contre $opponent',
      'completed' when challenge.winnerName == null =>
        'Égalité contre $opponent',
      'completed' => 'Victoire de ${challenge.winnerName}',
      _ => 'Défi contre $opponent',
    };
    final resultEmoji = challenge.isMyVictory
        ? '💪 '
        : challenge.isMyDefeat
        ? '😊 '
        : '';
    final secondsUntilExpiry = challenge.secondsUntilExpiry;
    final expiryLabel = secondsUntilExpiry == null
        ? null
        : secondsUntilExpiry >= 3600
        ? '${secondsUntilExpiry ~/ 3600} h '
              '${(secondsUntilExpiry % 3600) ~/ 60} min'
        : '${(secondsUntilExpiry + 59) ~/ 60} min';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$resultEmoji$status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isOutgoingPending)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF6C00).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF6C00).withValues(alpha: 0.65),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      '${challenge.isRematch ? 'Revanche' : 'Défi'} lancé à '
                      '$opponent · en attente d’acceptation',
                      style: const TextStyle(
                        color: Color(0xFFFFAB40),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            if (challenge.status == 'pending' && expiryLabel != null)
              Text(
                'Expire dans $expiryLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (challenge.status == 'completed' &&
                challenge.myScore != null &&
                challenge.opponentScore != null)
              Text(
                'Scores : ${challenge.myScore ?? challenge.challengerScore} - '
                '${challenge.opponentScore ?? challenge.challengedScore}',
              ),
            if (challenge.status == 'completed' && challenge.myTitle != null)
              Text(
                'Ton titre : ${challenge.myTitle}'
                '${challenge.myMedalLabel == null ? '' : ' · Médaille ${challenge.myMedalLabel}'}',
              ),
            if (challenge.status == 'pending' && challenge.isIncoming)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accepter'),
                  ),
                  TextButton(
                    onPressed: onDecline,
                    child: const Text('Refuser'),
                  ),
                ],
              ),
            if (challenge.canCancel && onCancel != null)
              OutlinedButton.icon(
                onPressed: () => onCancel!(),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Annuler la demande'),
              ),
            if (challenge.canDelete && onDelete != null)
              OutlinedButton.icon(
                onPressed: () => onDelete!(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer de ma liste'),
              ),
            if (challenge.canPlay)
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  challenge.status == 'playing'
                      ? 'Rejoindre le duel'
                      : 'Se préparer au duel',
                ),
              ),
            if (pendingRematch != null)
              DuelActionButton(
                onPressed: null,
                icon: Icons.hourglass_top,
                label: 'REVANCHE EN ATTENTE D’ACCEPTATION',
                backgroundColor: const Color(0xFFEF6C00),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFEF6C00),
                disabledForegroundColor: Colors.white,
              )
            else if (challenge.canRequestRematch)
              DuelActionButton(
                onPressed: onRematch,
                icon: Icons.replay_rounded,
                label:
                    'Proposer une revanche · '
                    '${3 - challenge.rematchesUsed} restante(s)',
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impossible de charger les légendes : '
              '${ApiService.readableGameError(error ?? 'Erreur inconnue')}',
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
