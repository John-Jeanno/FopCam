import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/services/api_service.dart';

class ProfileAnalyticsSection extends StatefulWidget {
  const ProfileAnalyticsSection({super.key});

  @override
  State<ProfileAnalyticsSection> createState() =>
      _ProfileAnalyticsSectionState();
}

class _ProfileAnalyticsSectionState extends State<ProfileAnalyticsSection> {
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = ApiService.fetchProfileAnalytics();
  }

  int _analyticsInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  Widget _metric({
    required String title,
    required int value,
    required Object? change,
    required int comparisonValue,
    String? detail,
  }) {
    final percent = change is num ? change.toInt() : null;
    final trendColor = percent == null
        ? Colors.blueGrey.shade200
        : percent < 0
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF86EFAC);
    final trendText = percent == null
        ? (comparisonValue == 0
              ? 'Pas encore de comparaison'
              : 'Nouveau sur la période')
        : '${percent > 0 ? '+' : ''}$percent % par rapport aux 7 jours précédents';
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            trendText,
            style: TextStyle(
              color: trendColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weeklyChart(List<Map<String, dynamic>> days) {
    if (days.isEmpty) {
      return const Text(
        'Les données hebdomadaires ne sont pas encore disponibles.',
        style: TextStyle(color: Colors.white70),
      );
    }
    final maximum = days.fold<int>(
      0,
      (max, day) => max > _analyticsInt(day['impressions'])
          ? max
          : _analyticsInt(day['impressions']),
    );
    const weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_analyticsInt(day['impressions'])}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maximum == 0
                          ? 4
                          : 44 * _analyticsInt(day['impressions']) / maximum,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekdayLabel(day['date'], weekdayLabels),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayLabel(Object? value, List<String> labels) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '—' : labels[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            color: Color(0xFF172033),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            color: const Color(0xFF172033),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistiques indisponibles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () =>
                          _analyticsFuture = ApiService.fetchProfileAnalytics(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final analytics = snapshot.data!;
        final weeklyProgress = (analytics['weekly_progress'] as List? ?? [])
            .whereType<Map>()
            .map((day) => Map<String, dynamic>.from(day))
            .toList();
        return Card(
          color: const Color(0xFF172033),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vue d’ensemble',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Suivez les performances de votre profil.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _metric(
                            title: 'Impressions des publications · 7 jours',
                            value: _analyticsInt(
                              analytics['post_impressions_7d'],
                            ),
                            change:
                                analytics['post_impressions_change_percent'],
                            comparisonValue: _analyticsInt(
                              analytics['post_impressions_7d'],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metric(
                            title: 'Total d’abonnés',
                            value: _analyticsInt(analytics['followers_total']),
                            change: analytics['followers_change_percent'],
                            comparisonValue: _analyticsInt(
                              analytics['new_followers_7d'],
                            ),
                            detail:
                                '${_analyticsInt(analytics['new_followers_7d'])} nouveau(x) cette semaine',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metric(
                            title: 'Vues du profil · 90 jours',
                            value: _analyticsInt(
                              analytics['profile_views_90d'],
                            ),
                            change: analytics['profile_views_change_percent'],
                            comparisonValue: _analyticsInt(
                              analytics['profile_views_7d'],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metric(
                            title: 'Apparitions dans les recherches · 7 jours',
                            value: _analyticsInt(
                              analytics['search_appearances_7d'],
                            ),
                            change:
                                analytics['search_appearances_change_percent'],
                            comparisonValue: _analyticsInt(
                              analytics['search_appearances_7d'],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Progression hebdomadaire',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_analyticsInt(analytics['posts_published_7d']) == 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Aucune publication cette semaine. Publiez pour commencer à suivre vos impressions.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                _weeklyChart(weeklyProgress),
              ],
            ),
          ),
        );
      },
    );
  }
}
