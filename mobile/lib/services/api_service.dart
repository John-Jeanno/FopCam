import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/models/group.dart';
import 'package:mobile/models/game_reward.dart';
import 'package:mobile/models/game_challenge.dart';
import 'package:mobile/models/game_legend.dart';
import 'package:mobile/models/game_live_duel.dart';
import 'package:mobile/models/game_tournament.dart';
import 'package:mobile/models/reel.dart';
import 'package:mobile/models/live_stream.dart';
import 'package:mobile/models/notification.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/models/order.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/story_offline_service.dart';
import 'package:mobile/services/offline_data_service.dart';
import 'package:mobile/utils/message_audio_format.dart';
import 'storage_service.dart';
import 'package:mobile/models/post.dart';

class PostPageResult {
  const PostPageResult({required this.posts, required this.hasNextPage});

  final List<Post> posts;
  final bool hasNextPage;
}

class ApiService {
  static Future<void> requestPasswordReset({
    required String channel,
    required String identifier,
  }) async {
    final response = await http
        .post(
          Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.passwordResetRequest),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channel': channel,
            'identifier': identifier.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return;
    final body = _parseResponseBodyAsMap(response.body);
    throw StateError(
      body?['detail']?.toString() ??
          'La demande de réinitialisation a échoué '
              '(HTTP ${response.statusCode}).',
    );
  }

  static Future<void> confirmPasswordReset({
    required String channel,
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.passwordResetConfirm),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channel': channel,
            'identifier': identifier.trim(),
            'code': code.trim(),
            'new_password': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return;
    final body = _parseResponseBodyAsMap(response.body);
    final detail = body?['detail'] ?? body?['new_password'];
    throw StateError(
      detail?.toString() ??
          'La réinitialisation a échoué (HTTP ${response.statusCode}).',
    );
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _parseResponseBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (e) {
      debugPrint('ApiService._parseResponseBody failed: $e');
      debugPrint('ApiService._parseResponseBody body: $body');
      return body;
    }
  }

  static Map<String, dynamic>? _parseResponseBodyAsMap(String body) {
    final result = _parseResponseBody(body);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  static Future<GameReward> claimLevelTwelveReward({required int score}) async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Connectez-vous pour synchroniser votre récompense.');
    }

    final url = Uri.parse(
      ApiEndpoints.baseUrl + ApiEndpoints.gameLevelTwelveReward,
    );
    Future<http.Response> sendClaim() async => http
        .post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'score': score}),
        )
        .timeout(const Duration(seconds: 20));

    late http.Response response;
    try {
      response = await sendClaim();
      if (await _refreshTokenIfNeeded(
        response,
      ).timeout(const Duration(seconds: 20))) {
        response = await sendClaim();
      }
    } on TimeoutException {
      throw StateError(
        'Le serveur met trop de temps à répondre. Ta progression est gardée ; '
        'réessaie pour synchroniser la récompense.',
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = _parseResponseBodyAsMap(response.body);
      final detail = body?['detail'] ?? body?['score'] ?? body?['error'];
      throw StateError(
        detail?.toString() ??
            'La récompense n’a pas pu être synchronisée '
                '(HTTP ${response.statusCode}).',
      );
    }

    final body = _parseResponseBodyAsMap(response.body);
    if (body == null) {
      throw const FormatException(
        'Réponse de récompense invalide reçue du serveur.',
      );
    }
    return GameReward.fromJson(body);
  }

  static Future<List<GameLegend>> fetchGameLegends() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.gameLegends);
    if (data is! List) {
      throw const FormatException('Le classement des légendes est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => GameLegend.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<GameChallenge>> fetchGameChallenges() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.gameChallenges);
    if (data is! List) {
      throw const FormatException('La liste des défis est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => GameChallenge.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<GameTournament>> fetchGameTournaments() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.gameTournaments);
    if (data is! List) {
      throw const FormatException('La liste des championnats est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => GameTournament.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<GameTournament> createGameTournament({
    required int capacity,
    List<int> invitedIds = const [],
  }) async {
    final data = await _sendGameRequest(
      'POST',
      ApiEndpoints.gameTournaments,
      body: {'capacity': capacity, 'invited_ids': invitedIds},
    );
    return GameTournament.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameTournament> joinGameTournament(int tournamentId) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameTournaments}$tournamentId/join/',
      body: const {},
    );
    return GameTournament.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameTournament> inviteGameTournamentPlayers({
    required int tournamentId,
    required List<int> userIds,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameTournaments}$tournamentId/invite/',
      body: {'user_ids': userIds},
    );
    return GameTournament.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameTournament> startGameTournament(int tournamentId) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameTournaments}$tournamentId/start/',
      body: const {},
    );
    return GameTournament.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameTournament> supportGameTournamentPlayer({
    required int tournamentId,
    required int participantId,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameTournaments}$tournamentId/support/',
      body: {'participant_id': participantId},
    );
    return GameTournament.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> startGameTournamentMatch({
    required int tournamentId,
    required int matchId,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameTournaments}$tournamentId/matches/$matchId/play/',
      body: const {},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<GameLiveDuel>> fetchLiveGameDuels() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.liveGameChallenges);
    if (data is! List) {
      throw const FormatException('La liste des duels en direct est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => GameLiveDuel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<GameLiveDuel> fetchLiveGameDuelState(int challengeId) async {
    final data = await _sendGameRequest(
      'GET',
      '${ApiEndpoints.liveGameChallenges}$challengeId/',
    );
    if (data is! Map) {
      throw const FormatException('L’état du duel en direct est invalide.');
    }
    return GameLiveDuel.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<GameChallenge> fetchGameChallenge(int challengeId) async {
    final data = await _sendGameRequest(
      'GET',
      '${ApiEndpoints.gameChallenges}$challengeId/live-state/',
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<int> fetchIncomingGameChallengeCount() async {
    final challenges = await fetchGameChallenges();
    return challenges
        .where(
          (challenge) => challenge.isIncoming && challenge.status == 'pending',
        )
        .length;
  }

  static Future<GameChallenge> createGameChallenge({
    required int legendId,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      ApiEndpoints.gameChallenges,
      body: {'legend_id': legendId},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> requestGameChallengeRematch({
    required int challengeId,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/rematch/',
      body: const {},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> respondToGameChallenge({
    required int challengeId,
    required bool accept,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/respond/',
      body: {'accept': accept},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> cancelGameChallenge({required int challengeId}) async {
    await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/cancel/',
      body: const {},
    );
  }

  static Future<void> deleteGameChallenge({required int challengeId}) async {
    await _sendGameRequest(
      'DELETE',
      '${ApiEndpoints.gameChallenges}$challengeId/dismiss/',
    );
  }

  static Future<GameChallenge> joinGameChallenge({
    required int challengeId,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/ready/',
      body: const {},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> submitGameChallengeScore({
    required int challengeId,
    required int score,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/score/',
      body: {'score': score},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> reportGameChallengeElimination({
    required int challengeId,
    required int score,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/eliminate/',
      body: {'score': score},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> completeGameChallengeRound({
    required int challengeId,
    required int roundNumber,
    required int score,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/round/',
      body: {'round_number': roundNumber, 'score': score},
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<GameChallenge> updateGameChallengeLiveState({
    required int challengeId,
    required Map<String, dynamic> liveState,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/live-state/',
      body: liveState,
    );
    return GameChallenge.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> shareGameChallengeTrophy(
    int challengeId,
  ) async {
    final data = await _sendGameRequest(
      'POST',
      '${ApiEndpoints.gameChallenges}$challengeId/share-trophy/',
      body: const {},
    );
    if (data is! Map) {
      throw const FormatException(
        'Réponse de publication du trophée invalide.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static String readableGameError(Object error) {
    if (error is StateError) return error.message.toString();
    return error.toString();
  }

  static Future<dynamic> _sendGameRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Connecte-toi pour accéder à cette fonctionnalité.');
    }

    final uri = Uri.parse(ApiEndpoints.baseUrl + endpoint);
    Future<http.Response> send() async {
      final headers = await _getHeaders();
      if (method == 'GET') return OfflineDataService.get(uri, headers: headers);
      if (method == 'DELETE') return http.delete(uri, headers: headers);
      return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    }

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) {
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _parseResponseBodyAsMap(response.body);
      final detail = data?['detail'] ?? data?['error'];
      throw StateError(
        detail?.toString() ??
            'La requête a échoué (HTTP ${response.statusCode}).',
      );
    }
    return _parseResponseBody(response.body);
  }

  static Future<List<Map<String, dynamic>>> fetchGroupEvents() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.groupEvents);
    return _extractResults(data)
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
  }

  static Future<Map<String, dynamic>> createGroupEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      ApiEndpoints.groupEvents,
      body: {
        'title': title,
        'description': description,
        'location': location,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
      },
    );
    if (data is! Map) {
      throw const FormatException('Réponse événement invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> attendGroupEvent(int eventId) async {
    await _sendGameRequest(
      'POST',
      '${ApiEndpoints.groupEvents}$eventId/attend/',
      body: const {'status': 'going'},
    );
  }

  static Future<List<Map<String, dynamic>>> fetchJobPostings() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.jobPostings);
    return _extractResults(
      data,
    ).whereType<Map>().map((job) => Map<String, dynamic>.from(job)).toList();
  }

  static Future<Map<String, dynamic>> createJobPosting({
    required String title,
    required String description,
    required String company,
    required String location,
    required String jobType,
    String? salaryMin,
    String? salaryMax,
  }) async {
    final data = await _sendGameRequest(
      'POST',
      ApiEndpoints.jobPostings,
      body: {
        'title': title,
        'description': description,
        'company': company,
        'location': location,
        'job_type': jobType,
        if (salaryMin != null && salaryMin.isNotEmpty) 'salary_min': salaryMin,
        if (salaryMax != null && salaryMax.isNotEmpty) 'salary_max': salaryMax,
      },
    );
    if (data is! Map) {
      throw const FormatException('Réponse offre d’emploi invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchJobSeekerPosts() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.jobSeekerPosts);
    return _extractResults(
      data,
    ).whereType<Map>().map((post) => Map<String, dynamic>.from(post)).toList();
  }

  static Future<Map<String, dynamic>> createJobSeekerPost({
    required String title,
    required String description,
    required String location,
    required String jobType,
    XFile? resume,
  }) async {
    final fields = {
      'title': title,
      'description': description,
      'location': location,
      'job_type': jobType,
    };
    dynamic data;
    if (resume == null) {
      data = await _sendGameRequest(
        'POST',
        ApiEndpoints.jobSeekerPosts,
        body: fields,
      );
    } else {
      final bytes = await resume.readAsBytes();
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.jobSeekerPosts);
      Future<http.Response> send() async {
        final headers = await _getHeaders();
        headers.remove('Content-Type');
        final request = http.MultipartRequest('POST', url)
          ..headers.addAll(headers)
          ..fields.addAll(fields)
          ..files.add(
            http.MultipartFile.fromBytes(
              'resume',
              bytes,
              filename: resume.name,
            ),
          );
        return http.Response.fromStream(await request.send());
      }

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) {
        response = await send();
      }
      data = _parseResponseBody(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = data is Map
            ? data['detail'] ?? data['resume'] ?? data
            : data;
        throw StateError(
          error?.toString() ??
              'La recherche d’emploi n’a pas pu être publiée '
                  '(HTTP ${response.statusCode}).',
        );
      }
    }
    if (data is! Map) {
      throw const FormatException('Réponse de recherche d’emploi invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchJobApplications() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.jobApplications);
    return _extractResults(data)
        .whereType<Map>()
        .map((application) => Map<String, dynamic>.from(application))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchJobSeekerResumeLinks(
    int postId,
  ) async {
    return _fetchJobResumeLinks(
      '${ApiEndpoints.jobSeekerPosts}$postId/resume-links/',
    );
  }

  static Future<Map<String, dynamic>> fetchJobApplicationResumeLinks(
    int applicationId,
  ) async {
    return _fetchJobResumeLinks(
      '${ApiEndpoints.jobApplications}$applicationId/resume-links/',
    );
  }

  static Future<Map<String, dynamic>> _fetchJobResumeLinks(
    String endpoint,
  ) async {
    final data = await _sendGameRequest('GET', endpoint);
    if (data is! Map ||
        data['view_url'] is! String ||
        data['download_url'] is! String) {
      throw const FormatException('Liens du CV invalides.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> applyToJob({
    required int jobId,
    required String description,
    required XFile resume,
  }) async {
    final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.jobApplications);
    final bytes = await resume.readAsBytes();

    Future<http.Response> send() async {
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..fields['job_id'] = '$jobId'
        ..fields['cover_letter'] = description
        ..files.add(
          http.MultipartFile.fromBytes('resume', bytes, filename: resume.name),
        );
      return http.Response.fromStream(await request.send());
    }

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) {
      response = await send();
    }
    final body = _parseResponseBody(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map) {
      return Map<String, dynamic>.from(body);
    }
    final error = body is Map
        ? body['detail'] ??
              body['job_id'] ??
              body['resume'] ??
              body['cover_letter']
        : body;
    throw StateError(
      error?.toString() ??
          'La candidature n’a pas pu être envoyée '
              '(HTTP ${response.statusCode}).',
    );
  }

  static Future<Map<String, dynamic>> fetchProfileAnalytics() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.profileAnalytics);
    if (data is! Map) {
      throw const FormatException(
        'Les statistiques du profil reçues sont invalides.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> fetchProfileRoleChangeQuota() async {
    final data = await _sendGameRequest('GET', ApiEndpoints.profileRoleChange);
    if (data is! Map) {
      throw const FormatException('Réponse du changement de profil invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> changeProfileRole(String role) async {
    final data = await _sendGameRequest(
      'POST',
      ApiEndpoints.profileRoleChange,
      body: {'role': role},
    );
    if (data is! Map) {
      throw const FormatException('Réponse du changement de profil invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Post>> fetchPosts({
    int pageSize = 10,
    int page = 1,
    bool throwOnError = false,
  }) async {
    final result = await fetchPostPage(
      pageSize: pageSize,
      page: page,
      throwOnError: throwOnError,
    );
    return result.posts;
  }

  static Future<PostPageResult> fetchPostPage({
    int pageSize = 10,
    int page = 1,
    bool throwOnError = false,
  }) async {
    try {
      final params = <String, String>{
        'page_size': '$pageSize',
        'page': '$page',
      };
      final uri = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.posts,
      ).replace(queryParameters: params);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(uri, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          uri,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        final posts = results
            .whereType<Map<String, dynamic>>()
            .map((item) {
              try {
                return Post.fromJson(Map<String, dynamic>.from(item));
              } catch (_) {
                return null;
              }
            })
            .whereType<Post>()
            .toList();
        final hasNextPage = data is Map
            ? data['next'] != null
            : posts.length >= pageSize;
        return PostPageResult(posts: posts, hasNextPage: hasNextPage);
      }
      if (throwOnError) {
        throw http.ClientException(
          'Chargement du fil impossible (HTTP ${response.statusCode}).',
          uri,
        );
      }
      return const PostPageResult(posts: [], hasNextPage: false);
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (throwOnError) rethrow;
      return const PostPageResult(posts: [], hasNextPage: false);
    }
  }

  static Future<bool> likePost(int postId) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.likes);
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'post': postId}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'post': postId}),
        );
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error liking post: $e');
      return false;
    }
  }

  static Future<bool> unlikePost(int postId) async {
    try {
      // Find existing like for this user/post
      final queryUrl = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.likes,
      ).replace(queryParameters: {'post': '$postId'});
      var response = await OfflineDataService.get(
        queryUrl,
        headers: await _getHeaders(),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          queryUrl,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        if (results.isNotEmpty) {
          final likeId = results.first['id'];
          final deleteUrl = Uri.parse(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.likes}$likeId/',
          );
          var delResp = await http.delete(
            deleteUrl,
            headers: await _getHeaders(),
          );
          if (await _refreshTokenIfNeeded(delResp)) {
            delResp = await http.delete(
              deleteUrl,
              headers: await _getHeaders(),
            );
          }
          if (delResp.statusCode == 200 || delResp.statusCode == 204) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error unliking post: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchComments(int postId) async {
    try {
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.comments,
      ).replace(queryParameters: {'post': '$postId'});
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results.map((c) => Map<String, dynamic>.from(c)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  static Future<bool> createComment(int postId, String content) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.comments);
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'post': postId, 'content': content}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'post': postId, 'content': content}),
        );
      }
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating comment: $e');
      return false;
    }
  }

  static Future<bool> updateComment(int commentId, String content) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.comments}$commentId/',
      );
      var response = await http.patch(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'content': content}),
      );
      if (await _refreshTokenIfNeeded(response)) {
        response = await http.patch(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'content': content}),
        );
      }
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (error) {
      debugPrint('Error updating comment: $error');
      return false;
    }
  }

  static Future<bool> deleteComment(int commentId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.comments}$commentId/',
      );
      var response = await http.delete(url, headers: await _getHeaders());
      if (await _refreshTokenIfNeeded(response)) {
        response = await http.delete(url, headers: await _getHeaders());
      }
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (error) {
      debugPrint('Error deleting comment: $error');
      return false;
    }
  }

  static Future<bool> updatePostContent(int postId, String content) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.posts}$postId/',
      );
      var response = await http.patch(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'content': content}),
      );
      if (await _refreshTokenIfNeeded(response)) {
        response = await http.patch(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'content': content}),
        );
      }
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (error) {
      debugPrint('Error updating post: $error');
      return false;
    }
  }

  static Future<bool> deletePost(int postId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.posts}$postId/',
      );
      var response = await http.delete(url, headers: await _getHeaders());
      if (await _refreshTokenIfNeeded(response)) {
        response = await http.delete(url, headers: await _getHeaders());
      }
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (error) {
      debugPrint('Error deleting post: $error');
      return false;
    }
  }

  static Future<Map<String, dynamic>> createPost(
    String content, {
    String privacy = 'public',
    String? location,
    List<String>? hashtags,
    String? backgroundColor,
  }) async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.posts}');
      final headers = await _getHeaders();
      final Map<String, dynamic> body = {
        'content': content,
        'privacy': privacy,
      };
      if (location != null) body['location'] = location;
      if (hashtags != null) body['hashtags'] = hashtags;
      if (backgroundColor != null) body['background_color'] = backgroundColor;

      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating post: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createPostWithImage(
    String content,
    XFile image, {
    String privacy = 'public',
    String? location,
    List<String>? hashtags,
    String? backgroundColor,
  }) async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.posts}');
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      final file = http.MultipartFile(
        'image',
        image.openRead(),
        await image.length(),
        filename: image.name,
      );
      var request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..fields['content'] = content
        ..fields['privacy'] = privacy
        ..fields['post_type'] = 'image'
        ..files.add(file);

      if (location != null) request.fields['location'] = location;
      if (hashtags != null) request.fields['hashtags'] = jsonEncode(hashtags);
      if (backgroundColor != null) {
        request.fields['background_color'] = backgroundColor;
      }

      final streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          return await createPostWithImage(
            content,
            image,
            privacy: privacy,
            location: location,
            hashtags: hashtags,
            backgroundColor: backgroundColor,
          );
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating post with image: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createPostWithImages(
    String content,
    List<XFile> images, {
    String privacy = 'public',
    String? location,
    List<String>? hashtags,
    String? backgroundColor,
  }) async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.posts}');
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      var request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..fields['content'] = content
        ..fields['privacy'] = privacy
        ..fields['post_type'] = 'album';

      for (final image in images) {
        final file = http.MultipartFile(
          'images',
          image.openRead(),
          await image.length(),
          filename: image.name,
        );
        request.files.add(file);
      }

      if (location != null) request.fields['location'] = location;
      if (hashtags != null) request.fields['hashtags'] = jsonEncode(hashtags);
      if (backgroundColor != null) {
        request.fields['background_color'] = backgroundColor;
      }

      final streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          return await createPostWithImages(
            content,
            images,
            privacy: privacy,
            location: location,
            hashtags: hashtags,
            backgroundColor: backgroundColor,
          );
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating post with images: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createPostWithVideo(
    String content,
    XFile video, {
    String privacy = 'public',
    String? location,
    List<String>? hashtags,
    String? backgroundColor,
  }) async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.posts}');
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      final file = http.MultipartFile(
        'video',
        video.openRead(),
        await video.length(),
        filename: video.name,
      );
      var request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..fields['content'] = content
        ..fields['privacy'] = privacy
        ..fields['post_type'] = 'video'
        ..files.add(file);

      if (location != null) request.fields['location'] = location;
      if (hashtags != null) request.fields['hashtags'] = jsonEncode(hashtags);
      if (backgroundColor != null) {
        request.fields['background_color'] = backgroundColor;
      }

      final streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          return await createPostWithVideo(
            content,
            video,
            privacy: privacy,
            location: location,
            hashtags: hashtags,
            backgroundColor: backgroundColor,
          );
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating post with video: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> sharePost(int postId) async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.shares}');
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'post_id': postId}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'post_id': postId}),
        );
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sharing post: $e');
      return false;
    }
  }

  static Future<bool> _refreshTokenIfNeeded(http.Response response) async {
    if (response.statusCode == 401) {
      return await AuthService.refreshToken();
    }
    return false;
  }

  static List<dynamic> _extractResults(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results;
      }
      return [data];
    }
    return [];
  }

  static Future<List<Product>> fetchProducts({
    int pageSize = 20,
    int? shopId,
    String? search,
    int? categoryId,
    String? categoryName,
    String? categoryType,
    Map<String, String>? extraFilters,
  }) async {
    final canUseExampleProducts =
        shopId == null &&
        search == null &&
        categoryId == null &&
        categoryName == null &&
        categoryType == null &&
        extraFilters == null;
    try {
      final params = <String, String>{'page_size': '$pageSize'};
      if (shopId != null) params['shop'] = '$shopId';
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (categoryId != null) params['category'] = '$categoryId';
      if (categoryName != null && categoryName.isNotEmpty) {
        params['category_name'] = categoryName;
      }
      if (categoryType != null && categoryType.isNotEmpty) {
        params['category_type'] = categoryType;
      }
      if (extraFilters != null) params.addAll(extraFilters);

      final uri = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.products,
      ).replace(queryParameters: params);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(uri, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          uri,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        final products = results
            .whereType<Map<String, dynamic>>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        if (products.isNotEmpty) {
          return products;
        }
        return canUseExampleProducts ? Product.mockProducts() : [];
      }
      return canUseExampleProducts ? Product.mockProducts() : [];
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return canUseExampleProducts ? Product.mockProducts() : [];
    }
  }

  static Future<Product?> fetchProduct(int productId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.products}$productId/',
      );
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return Product.fromJson(parsedBody);
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  static Future<List<Group>> fetchGroups({String? search}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.groups,
      ).replace(queryParameters: params.isEmpty ? null : params);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results
            .whereType<Map<String, dynamic>>()
            .map((g) => Group.fromJson(Map<String, dynamic>.from(g)))
            .toList();
      }
      throw StateError(
        'Impossible de charger les groupes (HTTP ${response.statusCode}).',
      );
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      rethrow;
    }
  }

  static Future<bool> joinGroup(int groupId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.groups}$groupId/join/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error joining group: $e');
      return false;
    }
  }

  static Future<bool> leaveGroup(int groupId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.groups}$groupId/leave/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 204;
    } catch (e) {
      debugPrint('Error leaving group: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPendingMembers(
    int groupId,
  ) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.groups}$groupId/pending_members/',
      );
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results.map((m) => Map<String, dynamic>.from(m)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching pending members: $e');
      return [];
    }
  }

  static Future<bool> approveMember(int groupId, int memberId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.groups}$groupId/approve_member/',
      );
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'member_id': memberId}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'member_id': memberId}),
        );
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error approving member: $e');
      return false;
    }
  }

  static Future<bool> rejectMember(int groupId, int memberId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.groups}$groupId/reject_member/',
      );
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'member_id': memberId}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'member_id': memberId}),
        );
      }

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error rejecting member: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> startConversation(
    int recipientId,
  ) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}start_conversation/',
      );
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'recipient_id': recipientId}),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({'recipient_id': recipientId}),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return parsedBody;
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createPayment({
    required int orderId,
    required String provider,
    String? callbackUrl,
  }) async {
    try {
      // Backend exposes a create_payment action at /api/payments/create_payment/
      final endpoint = '${ApiEndpoints.baseUrl}/api/payments/create_payment/';
      final url = Uri.parse(endpoint);
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      final body = {'order': orderId, 'provider': provider};
      if (callbackUrl != null) body['callback_url'] = callbackUrl;

      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return parsedBody;
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating payment: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getOrder(int orderId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}$orderId/',
      );
      var response = await OfflineDataService.get(
        url,
        headers: await _getHeaders(),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return parsedBody;
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching order: $e');
      return null;
    }
  }

  static Future<List<Story>> fetchStories() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.stories);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        final stories = results
            .whereType<Map<String, dynamic>>()
            .map((s) => Story.fromJson(Map<String, dynamic>.from(s)))
            .toList();
        await StoryOfflineService.cacheStories(
          results.whereType<Map<String, dynamic>>().toList(),
        );
        final visibleStories = [
          ...stories,
          ...await StoryOfflineService.pendingStories(),
        ];
        return visibleStories.isNotEmpty
            ? visibleStories
            : Story.exampleStories();
      }
      return await _cachedOrExampleStories();
    } catch (e) {
      debugPrint('Error fetching stories: $e');
      return await _cachedOrExampleStories();
    }
  }

  static Future<List<Story>> _cachedOrExampleStories() async {
    final stories = [
      ...StoryOfflineService.cachedStories(),
      ...await StoryOfflineService.pendingStories(),
    ];
    return stories.isNotEmpty ? stories : Story.exampleStories();
  }

  static Future<List<Reel>> fetchReels() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.reels);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results
            .map((r) => Reel.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }
      throw StateError(
        'Impossible de charger les clips (HTTP ${response.statusCode}).',
      );
    } catch (e) {
      debugPrint('Error fetching reels: $e');
      rethrow;
    }
  }

  static Future<bool> viewReel(int reelId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.reels}$reelId/view/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error recording reel view: $e');
      return false;
    }
  }

  static Future<bool> likeReel(int reelId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.reels}$reelId/like/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error liking reel: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> createReel(
    XFile videoFile, {
    required String title,
    required String description,
    required String theme,
    required String effect,
    required String sticker,
    XFile? beforeVideo,
  }) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.reels);
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      final videoBytes = kIsWeb ? await videoFile.readAsBytes() : null;
      final beforeVideoBytes = beforeVideo != null && kIsWeb
          ? await beforeVideo.readAsBytes()
          : null;

      Future<http.MultipartFile> videoPart(
        String field,
        XFile file,
        List<int>? bytes,
      ) async {
        final fileName = file.name.split('/').last;
        if (bytes != null) {
          return http.MultipartFile.fromBytes(field, bytes, filename: fileName);
        }
        return http.MultipartFile.fromPath(
          field,
          file.path,
          filename: fileName,
        );
      }

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..fields['title'] = title
        ..fields['description'] = description
        ..fields['theme'] = theme
        ..fields['effect'] = effect
        ..fields['sticker'] = effect == 'stickers' ? sticker : '';
      request.files.add(await videoPart('video', videoFile, videoBytes));
      if (beforeVideo != null) {
        request.files.add(
          await videoPart('before_video', beforeVideo, beforeVideoBytes),
        );
      }

      final streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (await _refreshTokenIfNeeded(response)) {
        final refreshedHeaders = await _getHeaders();
        refreshedHeaders.remove('Content-Type');
        final retryRequest = http.MultipartRequest('POST', url)
          ..headers.addAll(refreshedHeaders)
          ..fields['title'] = title
          ..fields['description'] = description
          ..fields['theme'] = theme
          ..fields['effect'] = effect
          ..fields['sticker'] = effect == 'stickers' ? sticker : '';
        retryRequest.files.add(await videoPart('video', videoFile, videoBytes));
        if (beforeVideo != null) {
          retryRequest.files.add(
            await videoPart('before_video', beforeVideo, beforeVideoBytes),
          );
        }
        final retryStream = await retryRequest.send();
        response = await http.Response.fromStream(retryStream);
      }

      final result = _parseResponseBody(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': result};
      }
      return {'success': false, 'error': result};
    } catch (e) {
      debugPrint('Error creating reel: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<LiveStream>> fetchLiveStreams() async {
    final data = await _sendLiveRequest('GET', ApiEndpoints.liveStreams);
    if (data is! List) {
      throw const FormatException('La liste des directs reçue est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => LiveStream.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<Map<String, dynamic>> startLiveStream({
    required String title,
    String category = 'Commerce',
  }) async {
    final data = await _sendLiveRequest(
      'POST',
      ApiEndpoints.liveStreams,
      body: {'title': title, 'category': category},
    );
    if (data is! Map) {
      throw const FormatException('Les informations du direct sont invalides.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> joinLiveStream(String roomName) async {
    final data = await _sendLiveRequest(
      'POST',
      '${ApiEndpoints.liveStreams}$roomName/join/',
    );
    if (data is! Map) {
      throw const FormatException(
        'Le jeton de connexion au direct est invalide.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> endLiveStream(String roomName) async {
    await _sendLiveRequest('DELETE', '${ApiEndpoints.liveStreams}$roomName/');
  }

  static Future<dynamic> _sendLiveRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(ApiEndpoints.baseUrl + endpoint);
    Future<http.Response> send() async {
      final headers = await _getHeaders();
      switch (method) {
        case 'GET':
          return OfflineDataService.get(uri, headers: headers);
        case 'POST':
          return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
          return http.delete(uri, headers: headers);
        default:
          throw ArgumentError.value(
            method,
            'method',
            'Unsupported HTTP method',
          );
      }
    }

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) {
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _parseResponseBodyAsMap(response.body);
      final detail = data?['detail'] ?? data?['title'] ?? data?['category'];
      throw StateError(
        detail?.toString() ??
            'La requête de diffusion a échoué (HTTP ${response.statusCode}).',
      );
    }
    return _parseResponseBody(response.body);
  }

  static Future<List<Shop>> fetchShops({String? search}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.shops,
      ).replace(queryParameters: params.isEmpty ? null : params);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results
            .whereType<Map<String, dynamic>>()
            .map((s) => Shop.fromJson(Map<String, dynamic>.from(s)))
            .where((shop) => shop.active)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shops: $e');
      return [];
    }
  }

  static Future<Shop?> fetchShop(int shopId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.shops}$shopId/',
      );
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return Shop.fromJson(parsedBody);
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching shop: $e');
      return null;
    }
  }

  static Future<List<NotificationItem>> fetchNotifications() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.notifications);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        final notifications = results
            .whereType<Map<String, dynamic>>()
            .map((n) => NotificationItem.fromJson(Map<String, dynamic>.from(n)))
            .toList();
        notifications.sort(
          (first, second) => second.createdAt.compareTo(first.createdAt),
        );
        return notifications;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  static Future<bool> markNotificationRead(int notificationId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notifications}$notificationId/mark_read/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notifications}mark_all_read/',
      );
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
      return false;
    }
  }

  static Future<List<Category>> fetchCategories({
    String? search,
    String? categoryType,
    bool useMockData = true,
  }) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }
      if (categoryType != null && categoryType.isNotEmpty) {
        params['category_type'] = categoryType;
      }
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.categories,
      ).replace(queryParameters: params.isEmpty ? null : params);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        final categories =
            results
                .whereType<Map<String, dynamic>>()
                .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
                .where(
                  (category) =>
                      categoryType == null ||
                      category.categoryType == categoryType,
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        if (categories.isNotEmpty) {
          return categories;
        }
        if (useMockData && (search == null || search.isEmpty)) {
          final mocks =
              Category.mockCategories()
                  .where(
                    (category) =>
                        categoryType == null ||
                        category.categoryType == categoryType,
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          return mocks;
        }
        return [];
      }
      final mocks = useMockData ? Category.mockCategories() : <Category>[];
      return mocks
          .where(
            (category) =>
                categoryType == null || category.categoryType == categoryType,
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      final mocks = useMockData ? Category.mockCategories() : <Category>[];
      return mocks
          .where(
            (category) =>
                categoryType == null || category.categoryType == categoryType,
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  static Future<Map<String, dynamic>> toggleShopInteraction(
    int shopId,
    String interaction,
  ) async {
    if (interaction != 'like' && interaction != 'vote') {
      return {'success': false, 'error': 'Interaction boutique invalide.'};
    }
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.shops}$shopId/$interaction/',
      );
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();

      final data = _parseResponseBody(response.body);
      if (response.statusCode == 200 && data is Map) {
        return {'success': true, ...Map<String, dynamic>.from(data)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': data,
      };
    } catch (e) {
      debugPrint('Error updating shop interaction: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> recordShopShare(int shopId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.shops}$shopId/share/',
      );
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();

      final data = _parseResponseBody(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map) {
        return {'success': true, ...Map<String, dynamic>.from(data)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': data,
      };
    } catch (e) {
      debugPrint('Error recording shop share: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rateShop(int shopId, int rating) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.shops}$shopId/rate/',
      );
      Future<http.Response> send() async => http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'rating': rating}),
      );

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();

      final data = _parseResponseBody(response.body);
      if (response.statusCode == 200 && data is Map) {
        return {'success': true, ...Map<String, dynamic>.from(data)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': data,
      };
    } catch (e) {
      debugPrint('Error rating shop: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Order>> fetchOrders() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.orders);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results
            .whereType<Map<String, dynamic>>()
            .map((o) => Order.fromJson(Map<String, dynamic>.from(o)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.orders);
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(orderData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(orderData),
        );
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating order: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSalesOrders() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.salesOrders);
      Future<http.Response> send() async =>
          OfflineDataService.get(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      if (response.statusCode != 200) {
        throw StateError(
          'Impossible de charger les commandes vendeur '
          '(HTTP ${response.statusCode}).',
        );
      }
      final results = _extractResults(_parseResponseBody(response.body));
      return results
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
    } catch (e) {
      debugPrint('Error fetching seller orders: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateOrderItemFulfillment({
    required int orderId,
    required int itemId,
    required String status,
  }) => _postSellerOrderAction(orderId, 'fulfillment', {
    'item_id': itemId,
    'status': status,
  });

  static Future<Map<String, dynamic>> acceptOrderItemReturn({
    required int orderId,
    required int itemId,
    required int quantity,
    required String note,
  }) => _postSellerOrderAction(orderId, 'accept_return', {
    'item_id': itemId,
    'quantity': quantity,
    'note': note,
  });

  static Future<Map<String, dynamic>> _postSellerOrderAction(
    int orderId,
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}$orderId/$action/',
      );
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders(), body: jsonEncode(body));

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      final data = _parseResponseBody(response.body);
      if (response.statusCode == 200 && data is Map) {
        return {'success': true, 'data': Map<String, dynamic>.from(data)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': data,
      };
    } catch (e) {
      debugPrint('Error updating seller order: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createShop(
    Map<String, dynamic> shopData, {
    XFile? logo,
    XFile? banner,
  }) => _saveShop(shopData, logo: logo, banner: banner);

  static Future<Map<String, dynamic>> updateShop(
    int shopId,
    Map<String, dynamic> shopData, {
    XFile? logo,
    XFile? banner,
  }) => _saveShop(shopData, shopId: shopId, logo: logo, banner: banner);

  static Future<Map<String, dynamic>> _saveShop(
    Map<String, dynamic> shopData, {
    int? shopId,
    XFile? logo,
    XFile? banner,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.shops}'
        '${shopId == null ? '' : '$shopId/'}',
      );
      final method = shopId == null ? 'POST' : 'PATCH';

      Future<http.Response> send() async {
        final headers = await _getHeaders();
        if (logo == null && banner == null) {
          final body = jsonEncode(shopData);
          if (shopId == null) {
            return http.post(url, headers: headers, body: body);
          }
          return OfflineDataService.patch(url, headers: headers, body: body);
        }

        headers.remove('Content-Type');
        final request = http.MultipartRequest(method, url)
          ..headers.addAll(headers)
          ..fields.addAll(
            shopData.map(
              (key, value) =>
                  MapEntry(key, value is String ? value : jsonEncode(value)),
            ),
          );
        if (logo != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'logo',
              await logo.readAsBytes(),
              filename: logo.name,
            ),
          );
        }
        if (banner != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'banner',
              await banner.readAsBytes(),
              filename: banner.name,
            ),
          );
        }
        return http.Response.fromStream(await request.send());
      }

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      if (response.statusCode == 202) {
        return {
          'success': true,
          'pending_sync': true,
          'data': _parseResponseBody(response.body),
        };
      }
      if (response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error saving shop: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> productData, {
    List<XFile>? images,
  }) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.products);
      final headers = await _getHeaders();

      if (images != null && images.isNotEmpty) {
        headers.remove('Content-Type');
        final request = http.MultipartRequest('POST', url)
          ..headers.addAll(headers)
          ..fields.addAll(_productMultipartFields(productData));

        for (final image in images) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              await image.readAsBytes(),
              filename: image.name.split('/').last,
            ),
          );
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (await _refreshTokenIfNeeded(response)) {
          final retryHeaders = await _getHeaders();
          retryHeaders.remove('Content-Type');
          final retryRequest = http.MultipartRequest('POST', url)
            ..headers.addAll(retryHeaders)
            ..fields.addAll(_productMultipartFields(productData));
          for (final image in images) {
            retryRequest.files.add(
              http.MultipartFile.fromBytes(
                'images',
                await image.readAsBytes(),
                filename: image.name.split('/').last,
              ),
            );
          }
          streamedResponse = await retryRequest.send();
          response = await http.Response.fromStream(streamedResponse);
        }

        if (response.statusCode == 201) {
          return {'success': true, 'data': _parseResponseBody(response.body)};
        }
        return {'success': false, 'error': _parseResponseBody(response.body)};
      }

      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(productData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(productData),
        );
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating product: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, String> _productMultipartFields(
    Map<String, dynamic> productData,
  ) {
    return productData.map((key, value) {
      final fieldValue = value is List || value is Map
          ? jsonEncode(value)
          : value?.toString() ?? '';
      return MapEntry(key, fieldValue);
    });
  }

  static Future<Map<String, dynamic>> updateProduct(
    int productId,
    Map<String, dynamic> productData, {
    List<XFile>? images,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.products}$productId/',
      );
      final headers = await _getHeaders();

      if (images != null && images.isNotEmpty) {
        headers.remove('Content-Type');
        final request = http.MultipartRequest('PATCH', url)
          ..headers.addAll(headers)
          ..fields.addAll(_productMultipartFields(productData));

        for (final image in images) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              await image.readAsBytes(),
              filename: image.name.split('/').last,
            ),
          );
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (await _refreshTokenIfNeeded(response)) {
          final retryHeaders = await _getHeaders();
          retryHeaders.remove('Content-Type');
          final retryRequest = http.MultipartRequest('PATCH', url)
            ..headers.addAll(retryHeaders)
            ..fields.addAll(_productMultipartFields(productData));
          for (final image in images) {
            retryRequest.files.add(
              http.MultipartFile.fromBytes(
                'images',
                await image.readAsBytes(),
                filename: image.name.split('/').last,
              ),
            );
          }
          streamedResponse = await retryRequest.send();
          response = await http.Response.fromStream(streamedResponse);
        }

        if (response.statusCode == 200) {
          return {'success': true, 'data': _parseResponseBody(response.body)};
        }
        return {'success': false, 'error': _parseResponseBody(response.body)};
      }

      var response = await OfflineDataService.patch(
        url,
        headers: headers,
        body: jsonEncode(productData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.patch(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(productData),
        );
      }

      if (response.statusCode == 202) {
        return {
          'success': true,
          'pending_sync': true,
          'data': _parseResponseBody(response.body),
        };
      }
      if (response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error updating product: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> deleteProduct(int productId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.products}$productId/',
      );
      final headers = await _getHeaders();
      var response = await http.delete(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.delete(url, headers: await _getHeaders());
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> adjustProductStock({
    required int productId,
    required String movementType,
    required int quantity,
    required String note,
    double? purchasePrice,
    String? direction,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.products}$productId/stock/',
      );
      final body = <String, dynamic>{
        'movement_type': movementType,
        'quantity': quantity,
        'note': note,
        'purchase_price': ?purchasePrice,
        'direction': ?direction,
      };
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders(), body: jsonEncode(body));

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      final data = _parseResponseBody(response.body);
      if (response.statusCode == 201 && data is Map) {
        return {'success': true, 'data': Map<String, dynamic>.from(data)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': data,
      };
    } catch (e) {
      debugPrint('Error adjusting product stock: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchStockMovements() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.stockMovements);
      Future<http.Response> send() async =>
          OfflineDataService.get(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      if (response.statusCode != 200) {
        throw StateError(
          'Impossible de charger les mouvements de stock '
          '(HTTP ${response.statusCode}).',
        );
      }
      final results = _extractResults(_parseResponseBody(response.body));
      return results
          .whereType<Map>()
          .map((movement) => Map<String, dynamic>.from(movement))
          .toList();
    } catch (e) {
      debugPrint('Error fetching stock movements: $e');
      rethrow;
    }
  }

  static Future<List<Product>> fetchMyProducts() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.myProducts);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results
            .whereType<Map<String, dynamic>>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching my products: $e');
      return [];
    }
  }

  static Future<Shop?> fetchMyShop() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.myShop);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          return Shop.fromJson(parsedBody);
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching my shop: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> fetchShopAnalytics(int shopId) async {
    final data = await _sendGameRequest(
      'GET',
      ApiEndpoints.shopAnalytics(shopId),
    );
    if (data is! Map) {
      throw const FormatException(
        'Les statistiques de la boutique reçues sont invalides.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchFriendRequests() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.friends);
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching friend requests: $e');
      return [];
    }
  }

  static Future<int> fetchPendingFriendRequestCount() async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.friends}pending_count/',
      );
      Future<http.Response> send() async =>
          OfflineDataService.get(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      if (response.statusCode != 200) {
        throw StateError(
          'Impossible de charger le nombre de demandes reçues '
          '(HTTP ${response.statusCode}).',
        );
      }
      final body = _parseResponseBodyAsMap(response.body);
      final count = body?['count'];
      if (count is! int || count < 0) {
        throw const FormatException(
          'Le nombre de demandes reçues est invalide.',
        );
      }
      return count;
    } catch (error) {
      debugPrint('Error fetching pending friend request count: $error');
      rethrow;
    }
  }

  static Future<int> fetchUnreadMessageCount() async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}unread_count/',
      );
      Future<http.Response> send() async =>
          OfflineDataService.get(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();

      if (response.statusCode == 200) {
        final body = _parseResponseBodyAsMap(response.body);
        final count = body?['count'];
        if (count is int && count >= 0) return count;
        throw const FormatException(
          'Le compteur de messages non lus est invalide.',
        );
      }
      throw StateError(
        'Impossible de charger les messages non lus '
        '(HTTP ${response.statusCode}).',
      );
    } catch (error) {
      debugPrint('Error fetching unread message count: $error');
      rethrow;
    }
  }

  static Future<void> markRoomMessagesRead(String room) async {
    final url = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}mark_conversation_read/',
    );
    Future<http.Response> send() async => http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'room': room}),
    );

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 200) {
      throw StateError(
        'Impossible de marquer la discussion comme lue '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<List<User>> fetchProfiles({
    String? role,
    String? search,
  }) async {
    final params = <String, String>{'page_size': '100'};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final url = Uri.parse(
      ApiEndpoints.baseUrl + ApiEndpoints.profiles,
    ).replace(queryParameters: params);
    Future<http.Response> send() async =>
        OfflineDataService.get(url, headers: await _getHeaders());

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 200) {
      throw StateError(
        'Impossible de charger les profils (HTTP ${response.statusCode}).',
      );
    }
    final results = _extractResults(_parseResponseBody(response.body));
    final profiles = <int, User>{};
    for (final result in results.whereType<Map<String, dynamic>>()) {
      final user = User.fromJson(Map<String, dynamic>.from(result));
      if (user.id > 0) profiles.putIfAbsent(user.id, () => user);
    }
    return profiles.values.toList();
  }

  static Future<List<User>> fetchUserDirectory({
    bool onlineOnly = false,
    String search = '',
  }) async {
    final usersById = <int, User>{};
    var page = 1;
    var hasNextPage = true;
    while (hasNextPage) {
      final params = <String, String>{
        'page_size': '100',
        'page': '$page',
        if (onlineOnly) 'online': 'true',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      };
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.userDirectory,
      ).replace(queryParameters: params);
      Future<http.Response> send() async =>
          OfflineDataService.get(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      if (response.statusCode != 200) {
        throw StateError(
          'Impossible de charger les utilisateurs '
          '(HTTP ${response.statusCode}).',
        );
      }

      final payload = _parseResponseBodyAsMap(response.body);
      final results = _extractResults(_parseResponseBody(response.body));
      for (final result in results.whereType<Map<String, dynamic>>()) {
        final user = User.fromJson(Map<String, dynamic>.from(result));
        if (user.id > 0) usersById.putIfAbsent(user.id, () => user);
      }
      hasNextPage = payload?['next'] != null && results.isNotEmpty;
      page++;
    }
    return usersById.values.toList();
  }

  static Future<bool> pingUserPresence() async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.userPresence);
      Future<http.Response> send() async =>
          http.post(url, headers: await _getHeaders());

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) response = await send();
      return response.statusCode == 200;
    } catch (error) {
      debugPrint('Error updating user presence: $error');
      return false;
    }
  }

  static Future<User> fetchPublicUser(String username) async {
    final url = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.userPublicProfiles}'
      '${Uri.encodeComponent(username)}/',
    );
    Future<http.Response> send() async =>
        OfflineDataService.get(url, headers: await _getHeaders());

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 200) {
      throw StateError(
        'Impossible de charger le profil utilisateur '
        '(HTTP ${response.statusCode}).',
      );
    }
    final data = _parseResponseBodyAsMap(response.body);
    if (data == null) {
      throw const FormatException('Le profil utilisateur est invalide.');
    }
    return User.fromJson(data);
  }

  static Future<bool> sendFriendRequest(int receiverId) async {
    final result = await sendFriendRequestWithResult(receiverId);
    return result['success'] == true;
  }

  static Future<Map<String, dynamic>> sendFriendRequestWithResult(
    int receiverId,
  ) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.friends);
      Future<http.Response> send() async => http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'receiver_id': receiverId}),
      );

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) {
        response = await send();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }

      final body = _parseResponseBody(response.body);
      final errorText = body is Map
          ? (body['detail'] ?? body['receiver_id'] ?? body['error'])
                    ?.toString() ??
                'La demande n’a pas pu être envoyée (HTTP ${response.statusCode}).'
          : body?.toString() ??
                'La demande n’a pas pu être envoyée (HTTP ${response.statusCode}).';
      final normalizedError = errorText.toLowerCase();
      final alreadyExists =
          response.statusCode == 400 &&
          (normalizedError.contains('existe déjà') ||
              normalizedError.contains('déjà en attente') ||
              normalizedError.contains('déjà amis') ||
              normalizedError.contains('already exists') ||
              normalizedError.contains('déjà connecté'));
      return {
        'success': false,
        'already_exists': alreadyExists,
        'error': errorText,
      };
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProducerReviews(
    int producerId,
  ) async {
    try {
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.producerReviews,
      ).replace(queryParameters: {'producer_id': '$producerId'});
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching producer reviews: $e');
      return [];
    }
  }

  static Future<bool> handleFriendRequestAction(
    int requestId,
    String action,
  ) async {
    if (action != 'accept' && action != 'decline') {
      throw ArgumentError.value(action, 'action', 'Unsupported friend action');
    }
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.friends}$requestId/$action/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error handling friend request action: $e');
      return false;
    }
  }

  static Future<bool> removeFriend(int friendshipId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.friends}$friendshipId/',
      );
      final headers = await _getHeaders();
      var response = await http.delete(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.delete(url, headers: await _getHeaders());
      }

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> seedShopProducts() async {
    try {
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.shopSeedProducts,
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error seeding shop products: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createGroup(
    Map<String, dynamic> groupData,
  ) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.groups);
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(groupData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(groupData),
        );
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating group: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static String _normalizeFilePath(String path) {
    if (path.startsWith('file://')) {
      return Uri.parse(path).toFilePath();
    }
    return path;
  }

  static Future<Map<String, dynamic>> createStory(
    Map<String, dynamic> storyData, {
    XFile? imageFile,
    XFile? videoFile,
    String? imagePath,
    String? videoPath,
  }) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.stories);
      // If there is an image or video, use multipart upload
      if (imageFile != null ||
          videoFile != null ||
          (imagePath != null && imagePath.isNotEmpty) ||
          (videoPath != null && videoPath.isNotEmpty)) {
        final token = await StorageService.getAccessToken();
        if (token == null) return {'success': false, 'error': 'No token'};

        final request = http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $token';

        // Add fields
        storyData.forEach((k, v) {
          if (v != null) request.fields[k] = v.toString();
        });

        if (imageFile != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              await imageFile.readAsBytes(),
              filename: imageFile.name,
            ),
          );
        }

        if (imageFile == null && imagePath != null && imagePath.isNotEmpty) {
          final normalizedImagePath = _normalizeFilePath(imagePath);
          request.files.add(
            await http.MultipartFile.fromPath('image', normalizedImagePath),
          );
        }

        if (videoFile != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'video',
              await videoFile.readAsBytes(),
              filename: videoFile.name,
            ),
          );
        } else if (videoPath != null && videoPath.isNotEmpty) {
          final normalizedVideoPath = _normalizeFilePath(videoPath);
          request.files.add(
            await http.MultipartFile.fromPath('video', normalizedVideoPath),
          );
        }

        final streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 401) {
          final refreshed = await AuthService.refreshToken();
          if (refreshed) {
            return await createStory(
              storyData,
              imageFile: imageFile,
              videoFile: videoFile,
              imagePath: imagePath,
              videoPath: videoPath,
            );
          }
        }

        if (response.statusCode == 201) {
          return {'success': true, 'data': _parseResponseBody(response.body)};
        }

        return {'success': false, 'error': _parseResponseBody(response.body)};
      }

      // Fallback to JSON body when no files
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(storyData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(storyData),
        );
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error creating story: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfileImages({
    XFile? profileImage,
    XFile? coverImage,
    String? profileImagePath,
    String? coverImagePath,
  }) async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        return {'success': false, 'error': 'No token'};
      }

      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.profile);
      final request = http.MultipartRequest('PATCH', url)
        ..headers['Authorization'] = 'Bearer $token';

      if (profileImage != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_image',
            await profileImage.readAsBytes(),
            filename: profileImage.name,
          ),
        );
      } else if (profileImagePath != null && profileImagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', profileImagePath),
        );
      }

      if (coverImage != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'cover_image',
            await coverImage.readAsBytes(),
            filename: coverImage.name,
          ),
        );
      } else if (coverImagePath != null && coverImagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('cover_image', coverImagePath),
        );
      }

      final streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          return await updateProfileImages(
            profileImage: profileImage,
            coverImage: coverImage,
            profileImagePath: profileImagePath,
            coverImagePath: coverImagePath,
          );
        }
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error updating profile images: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        return {'success': false, 'error': 'No token'};
      }

      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.profile);
      final response = await OfflineDataService.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          return await updateProfile(profileData);
        }
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      if (response.statusCode == 202) {
        return {
          'success': true,
          'pending_sync': true,
          'data': _parseResponseBody(response.body),
        };
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMessages([
    String? room,
  ]) async {
    try {
      final url = Uri.parse(
        ApiEndpoints.baseUrl + ApiEndpoints.messages,
      ).replace(queryParameters: room == null ? null : {'room': room});
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      throw StateError(
        'Impossible de charger la discussion (HTTP ${response.statusCode}).',
      );
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      rethrow;
    }
  }

  static Future<http.Response> fetchMessageAudio(String audioUrl) async {
    final uri = Uri.tryParse(audioUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Adresse du message vocal invalide.');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError(
        'Le message vocal est inaccessible (HTTP ${response.statusCode}).',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Le fichier du message vocal est vide.');
    }
    return response;
  }

  static Future<List<Map<String, dynamic>>> fetchConversations() async {
    final url = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}conversations/',
    );
    Future<http.Response> send() async =>
        OfflineDataService.get(url, headers: await _getHeaders());

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 200) {
      throw StateError(
        'Impossible de charger les discussions '
        '(HTTP ${response.statusCode}).',
      );
    }

    final data = _parseResponseBody(response.body);
    if (data is! List) {
      throw const FormatException('La liste des discussions est invalide.');
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> deleteMessage(int messageId) async {
    final url = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}$messageId/',
    );
    Future<http.Response> send() async =>
        http.delete(url, headers: await _getHeaders());

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 204) {
      throw StateError(
        'Impossible de supprimer le message '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<void> deleteConversation(String roomId) async {
    final url = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.messages}delete_conversation/',
    );
    Future<http.Response> send() async => http.delete(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'room': roomId}),
    );

    var response = await send();
    if (await _refreshTokenIfNeeded(response)) response = await send();
    if (response.statusCode != 200) {
      throw StateError(
        'Impossible de supprimer la discussion '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    Map<String, dynamic> messageData,
  ) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.messages);
      final headers = await _getHeaders();
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(messageData),
      );

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode(messageData),
        );
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      }
      return {'success': false, 'error': _parseResponseBody(response.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendMessageAttachment({
    required String room,
    required XFile file,
    required String messageType,
    required String attachmentType,
    String? content,
    int? audioDuration,
    int? replyToId,
  }) async {
    try {
      final url = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.messages);
      final bytes = await file.readAsBytes();
      if (messageType == 'audio' &&
          !MessageAudioFormat.hasAudioPayload(bytes)) {
        return {
          'success': false,
          'error': 'Le fichier vocal est vide ou incomplet. Réessayez.',
        };
      }

      Future<http.Response> send() async {
        final headers = await _getHeaders();
        headers.remove('Content-Type');
        final request = http.MultipartRequest('POST', url)
          ..headers.addAll(headers)
          ..fields['room'] = room
          ..fields['message_type'] = messageType
          ..fields['attachment_type'] = attachmentType
          ..fields['content'] = content ?? file.name
          ..files.add(
            http.MultipartFile.fromBytes(
              'attachment_file',
              bytes,
              filename: file.name,
            ),
          );
        if (replyToId != null) {
          request.fields['reply_to_id'] = '$replyToId';
        }
        if (audioDuration != null) {
          request.fields['audio_duration'] = '$audioDuration';
        }
        return http.Response.fromStream(await request.send());
      }

      var response = await send();
      if (await _refreshTokenIfNeeded(response)) {
        response = await send();
      }

      final body = _parseResponseBody(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body is Map) {
          return {'success': true, 'data': Map<String, dynamic>.from(body)};
        }
        return {'success': false, 'error': 'Réponse du serveur invalide.'};
      }
      return {
        'success': false,
        'error':
            body?.toString() ??
            'Envoi du fichier impossible (HTTP ${response.statusCode}).',
      };
    } catch (error) {
      debugPrint('Error sending chat attachment: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  // Story viewer methods
  static Future<void> markStoryAsViewed(int storyId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.stories}$storyId/view/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      if (response.statusCode != 201 && response.statusCode != 200) {
        debugPrint('Error marking story as viewed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  static Future<bool> likeStory(int storyId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.stories}$storyId/like/',
      );
      final headers = await _getHeaders();
      var response = await http.post(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await http.post(url, headers: await _getHeaders());
      }

      if (response.statusCode == 201 || response.statusCode == 200) return true;
      debugPrint('Error liking story: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Error liking story: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getStoryViewers(int storyId) async {
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.stories}$storyId/viewers/',
      );
      final headers = await _getHeaders();
      var response = await OfflineDataService.get(url, headers: headers);

      if (await _refreshTokenIfNeeded(response)) {
        response = await OfflineDataService.get(
          url,
          headers: await _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        final results = _extractResults(data);
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching story viewers: $e');
      return [];
    }
  }
}
