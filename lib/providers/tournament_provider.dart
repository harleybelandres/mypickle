import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// State management for tournaments and matches.
class TournamentProvider extends ChangeNotifier {
  TournamentProvider({FirestoreService? firestore})
    : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  List<TournamentModel> _tournaments = const [];
  List<TournamentModel> _pendingTournaments = const [];
  List<TournamentModel> _createdTournaments = const [];
  List<TournamentModel> _registeredTournaments = const [];
  List<TournamentModel> _umpiredTournaments = const [];
  List<MatchModel> _matches = const [];
  List<UserModel> _umpires = const [];
  Map<String, Map<String, List<String>>> _brackets = const {};
  final Map<String, Map<String, num>> _playerStats = {};

  List<TournamentModel> get tournaments => _tournaments;
  List<TournamentModel> get pendingTournaments => _pendingTournaments;
  List<TournamentModel> get createdTournaments => _createdTournaments;
  List<TournamentModel> get registeredTournaments => _registeredTournaments;
  List<TournamentModel> get umpiredTournaments => _umpiredTournaments;
  List<MatchModel> get matches => _matches;
  List<UserModel> get umpires => _umpires;
  Map<String, Map<String, List<String>>> get brackets => _brackets;
  Map<String, Map<String, num>> get playerStats =>
      Map.unmodifiable(_playerStats);

  /// Fetch approved tournaments once.
  Future<void> fetchApprovedTournaments() async {
    try {
      // Convert stream into a one-time fetch.
      final first = await _firestore.getApprovedTournaments().first;
      _tournaments = first;
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchApprovedTournaments error: $e\n$st');
    }
  }

  Future<void> fetchPendingTournaments() async {
    try {
      _pendingTournaments = await _firestore.getPendingTournaments();
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchPendingTournaments error: $e\n$st');
    }
  }

  Future<String> createTournament({
    required String name,
    required String location,
    required DateTime date,
    required DateTime registrationStart,
    required DateTime registrationEnd,
    required String creatorId,
    String imagePath = '',
    required List<CategoryModel> categories,
  }) async {
    try {
      // Creator tournaments start unapproved.
      final tournamentId = await _firestore.createTournament(
        name: name,
        location: location,
        date: date,
        registrationStart: registrationStart,
        registrationEnd: registrationEnd,
        creatorId: creatorId,
        isApproved: false,
        imagePath: imagePath,
        categories: categories,
      );

      await Future.wait([
        fetchApprovedTournaments(),
        fetchPendingTournaments(),
        fetchCreatedTournaments(creatorId),
      ]);
      return tournamentId;
    } catch (e, st) {
      // ignore: avoid_print
      print('createTournament error: $e\n$st');
      rethrow;
    }
  }

  Future<void> fetchCreatedTournaments(String creatorId) async {
    try {
      _createdTournaments = await _firestore.getCreatedTournaments(creatorId);
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchCreatedTournaments error: $e\n$st');
    }
  }

  Future<void> fetchRegisteredTournaments(String playerId) async {
    try {
      _registeredTournaments = await _firestore.getRegisteredTournaments(
        playerId,
      );
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchRegisteredTournaments error: $e\n$st');
    }
  }

  Future<void> approveTournament({required String tournamentId}) async {
    try {
      await _firestore.approveTournament(
        tournamentId: tournamentId,
        approved: true,
      );
      await Future.wait([
        fetchApprovedTournaments(),
        fetchPendingTournaments(),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('approveTournament error: $e\n$st');
      rethrow;
    }
  }

  Future<void> rejectTournament({required String tournamentId}) async {
    try {
      await _firestore.rejectTournament(tournamentId: tournamentId);
      await Future.wait([
        fetchApprovedTournaments(),
        fetchPendingTournaments(),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('rejectTournament error: $e\n$st');
      rethrow;
    }
  }

  Future<void> registerPlayer({
    required String tournamentId,
    required String playerId,
    required String categoryName,
    Map<String, dynamic>? registrationDetails,
  }) async {
    try {
      await _firestore.registerPlayer(
        tournamentId: tournamentId,
        playerId: playerId,
        categoryName: categoryName,
        registrationDetails: registrationDetails,
      );
      await Future.wait([
        fetchApprovedTournaments(),
        fetchPendingTournaments(),
        fetchRegisteredTournaments(playerId),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('registerPlayer error: $e\n$st');
      rethrow;
    }
  }

  Future<void> applyAsUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    try {
      await _firestore.applyAsUmpire(
        tournamentId: tournamentId,
        umpireId: umpireId,
      );
      await Future.wait([
        fetchApprovedTournaments(),
        fetchUmpiredTournaments(umpireId),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('applyAsUmpire error: $e\n$st');
      rethrow;
    }
  }

  Future<void> assignUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    try {
      await _firestore.assignUmpire(
        tournamentId: tournamentId,
        umpireId: umpireId,
      );
      await Future.wait([
        fetchApprovedTournaments(),
        fetchMatchesByTournament(tournamentId),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('assignUmpire error: $e\n$st');
      rethrow;
    }
  }

  Future<void> rejectUmpireApplication({
    required String tournamentId,
    required String umpireId,
  }) async {
    try {
      await _firestore.rejectUmpireApplication(
        tournamentId: tournamentId,
        umpireId: umpireId,
      );
      await fetchApprovedTournaments();
    } catch (e, st) {
      // ignore: avoid_print
      print('rejectUmpireApplication error: $e\n$st');
      rethrow;
    }
  }

  Future<void> fetchUmpires() async {
    try {
      _umpires = await _firestore.getUmpires();
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchUmpires error: $e\n$st');
    }
  }

  Future<void> fetchUmpiredTournaments(String umpireId) async {
    try {
      _umpiredTournaments = await _firestore.getUmpiredTournaments(umpireId);
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchUmpiredTournaments error: $e\n$st');
    }
  }

  Future<void> scheduleMatch({
    required String tournamentId,
    required String categoryName,
    required String bracket,
    required String playerA,
    required String playerB,
    required String umpireId,
    required String courtNumber,
  }) async {
    try {
      await _firestore.scheduleMatch(
        tournamentId: tournamentId,
        categoryName: categoryName,
        bracket: bracket,
        playerA: playerA,
        playerB: playerB,
        umpireId: umpireId,
        courtNumber: courtNumber,
      );
      await fetchMatchesByTournament(tournamentId);
    } catch (e, st) {
      // ignore: avoid_print
      print('scheduleMatch error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateMatchAssignment({
    required String tournamentId,
    required String matchId,
    required String umpireId,
    required String courtNumber,
  }) async {
    try {
      await _firestore.updateMatchAssignment(
        matchId: matchId,
        umpireId: umpireId,
        courtNumber: courtNumber,
      );
      await fetchMatchesByTournament(tournamentId);
    } catch (e, st) {
      // ignore: avoid_print
      print('updateMatchAssignment error: $e\n$st');
      rethrow;
    }
  }

  Future<void> generateBrackets({required String tournamentId}) async {
    try {
      await _firestore.generateBrackets(tournamentId: tournamentId);
      await fetchMatchesByTournament(tournamentId);
    } catch (e, st) {
      // ignore: avoid_print
      print('generateBrackets error: $e\n$st');
      rethrow;
    }
  }

  Future<void> fetchBrackets(String tournamentId) async {
    try {
      _brackets = await _firestore.getBrackets(tournamentId);
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchBrackets error: $e\n$st');
    }
  }

  Future<void> saveBrackets({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    try {
      await _firestore.saveBrackets(
        tournamentId: tournamentId,
        bracketsByCategory: bracketsByCategory,
      );
      _brackets = bracketsByCategory;
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('saveBrackets error: $e\n$st');
      rethrow;
    }
  }

  Future<void> generateRoundRobinGames({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    try {
      await _firestore.generateRoundRobinGames(
        tournamentId: tournamentId,
        bracketsByCategory: bracketsByCategory,
      );
      await Future.wait([
        fetchBrackets(tournamentId),
        fetchMatchesByTournament(tournamentId),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('generateRoundRobinGames error: $e\n$st');
      rethrow;
    }
  }

  /// Update a match score and compute winner.
  Future<void> updateScore({
    required String tournamentId,
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String playerAId,
    required String playerBId,
  }) async {
    try {
      if (scoreA == scoreB) {
        throw Exception('Scores cannot be tied');
      }
      final winner = scoreA >= scoreB ? playerAId : playerBId;

      await _firestore.updateScore(
        tournamentId: tournamentId,
        matchId: matchId,
        scoreA: scoreA,
        scoreB: scoreB,
        winner: winner,
      );

      await fetchMatchesByTournament(tournamentId);
      await Future.wait([
        fetchPlayerStats(playerAId),
        fetchPlayerStats(playerBId),
      ]);
    } catch (e, st) {
      // ignore: avoid_print
      print('updateScore error: $e\n$st');
      rethrow;
    }
  }

  Future<void> fetchAssignedMatches(String umpireId) async {
    try {
      _matches = await _firestore.getAssignedMatches(umpireId);
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchAssignedMatches error: $e\n$st');
    }
  }

  Future<Map<String, num>> fetchPlayerStats(String playerId) async {
    try {
      final stats = await _firestore.getPlayerStats(playerId);
      _playerStats[playerId] = stats;
      notifyListeners();
      return stats;
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchPlayerStats error: $e\n$st');
      rethrow;
    }
  }

  Future<void> fetchMatchesByTournament(String tournamentId) async {
    try {
      _matches = await _firestore.getMatchesByTournament(tournamentId);
      notifyListeners();
    } catch (e, st) {
      // ignore: avoid_print
      print('fetchMatchesByTournament error: $e\n$st');
    }
  }
}
