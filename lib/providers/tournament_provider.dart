import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class TournamentProvider extends ChangeNotifier {
  TournamentProvider({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  // Real-time subscription for approved tournaments
  StreamSubscription<List<TournamentModel>>? _tournamentSub;

  List<TournamentModel> _tournaments = const [];
  List<TournamentModel> _pendingTournaments = const [];
  List<TournamentModel> _createdTournaments = const [];
  List<TournamentModel> _registeredTournaments = const [];
  List<TournamentModel> _umpiredTournaments = const [];
  List<MatchModel> _matches = const [];
  List<UserModel> _umpires = const [];
  List<UserModel> _allUsers = [];

  // Added Loading State
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<UserModel> get allUsers => _allUsers;
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
  Map<String, Map<String, num>> get playerStats => Map.unmodifiable(_playerStats);

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Subscribe to live approved tournament updates.
  void subscribeToApprovedTournaments() {
    _tournamentSub?.cancel();
    _tournamentSub = _firestore.getApprovedTournaments().listen((list) {
      _tournaments = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('tournament stream error: $e');
    });
  }

  @override
  void dispose() {
    _tournamentSub?.cancel();
    super.dispose();
  }

  Future<void> fetchApprovedTournaments() async {
    try {
      _tournaments = await _firestore.getApprovedTournaments().first;
      notifyListeners();
    } catch (e) {
      debugPrint('fetchApprovedTournaments: $e');
    }
  }

  Future<void> fetchPendingTournaments() async {
    try {
      _pendingTournaments = await _firestore.getPendingTournaments();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchPendingTournaments: $e');
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
    final id = await _firestore.createTournament(
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
      fetchPendingTournaments(),
      fetchCreatedTournaments(creatorId),
    ]);
    return id;
  }

  Future<void> fetchCreatedTournaments(String creatorId) async {
    try {
      _createdTournaments = await _firestore.getCreatedTournaments(creatorId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchCreatedTournaments: $e');
    }
  }

  Future<void> fetchRegisteredTournaments(String playerId) async {
    try {
      _registeredTournaments = await _firestore.getRegisteredTournaments(playerId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchRegisteredTournaments: $e');
    }
  }

  Future<void> approveTournament({required String tournamentId}) async {
    await _firestore.approveTournament(tournamentId: tournamentId, approved: true);
    await Future.wait([
      fetchApprovedTournaments(),
      fetchPendingTournaments(),
    ]);
  }

  Future<void> rejectTournament({required String tournamentId}) async {
    await _firestore.rejectTournament(tournamentId: tournamentId);
    await Future.wait([
      fetchApprovedTournaments(),
      fetchPendingTournaments(),
    ]);
  }

  Future<void> registerPlayer({
    required String tournamentId,
    required String playerId,
    required String categoryName,
    Map<String, dynamic>? registrationDetails,
  }) async {
    await _firestore.registerPlayer(
      tournamentId: tournamentId,
      playerId: playerId,
      categoryName: categoryName,
      registrationDetails: registrationDetails,
    );
    await Future.wait([
      fetchApprovedTournaments(),
      fetchRegisteredTournaments(playerId),
    ]);
  }

  Future<void> applyAsUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _firestore.applyAsUmpire(tournamentId: tournamentId, umpireId: umpireId);
    await Future.wait([
      fetchApprovedTournaments(),
      fetchUmpiredTournaments(umpireId),
    ]);
  }

  Future<void> assignUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _firestore.assignUmpire(tournamentId: tournamentId, umpireId: umpireId);
    await Future.wait([
      fetchApprovedTournaments(),
      fetchMatchesByTournament(tournamentId),
    ]);
  }

  Future<void> rejectUmpireApplication({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _firestore.rejectUmpireApplication(tournamentId: tournamentId, umpireId: umpireId);
    await fetchApprovedTournaments();
  }

  Future<void> fetchUmpires() async {
    try {
      _umpires = await _firestore.getUmpires();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchUmpires: $e');
    }
  }

  Future<void> fetchUmpiredTournaments(String umpireId) async {
    try {
      _umpiredTournaments = await _firestore.getUmpiredTournaments(umpireId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchUmpiredTournaments: $e');
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
  }

  Future<void> updateMatchAssignment({
    required String tournamentId,
    required String matchId,
    required String umpireId,
    required String courtNumber,
  }) async {
    await _firestore.updateMatchAssignment(
        matchId: matchId, umpireId: umpireId, courtNumber: courtNumber);
    await fetchMatchesByTournament(tournamentId);
  }

  Future<void> fetchBrackets(String tournamentId) async {
    try {
      _brackets = await _firestore.getBrackets(tournamentId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchBrackets: $e');
    }
  }

  Future<void> saveBrackets({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    await _firestore.saveBrackets(
        tournamentId: tournamentId, bracketsByCategory: bracketsByCategory);
    _brackets = bracketsByCategory;
    notifyListeners();
  }

  Future<void> generateRoundRobinGames({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    setLoading(true);
    try {
      await _firestore.generateRoundRobinGames(
          tournamentId: tournamentId, bracketsByCategory: bracketsByCategory);
      await Future.wait([
        fetchBrackets(tournamentId),
        fetchMatchesByTournament(tournamentId),
      ]);
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateScore({
    required String tournamentId,
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String playerAId,
    required String playerBId,
  }) async {
    if (scoreA == scoreB) throw Exception('Scores cannot be tied');

    final winnerId = scoreA > scoreB ? playerAId : playerBId;

    await _firestore.updateScore(
      tournamentId: tournamentId,
      matchId: matchId,
      scoreA: scoreA,
      scoreB: scoreB,
      winner: winnerId,
    );

    await fetchMatchesByTournament(tournamentId);

    try {
      final currentMatch = _matches.firstWhere((m) => m.id == matchId);
      if (currentMatch.round > 0) {
        await _advanceWinner(tournamentId, currentMatch, winnerId);
      }
    } catch (e) {
      debugPrint('Progression check failed: $e');
    }

    notifyListeners();
  }

  Future<void> _advanceWinner(String tournamentId, MatchModel currentMatch, String winnerId) async {
    int nextRound = currentMatch.round + 1;
    int nextMatchIndex = currentMatch.bracketIndex ~/ 2;
    bool isSlotA = currentMatch.bracketIndex % 2 == 0;

    await _firestore.advancePlayerToMatch(
      tournamentId: tournamentId,
      categoryName: currentMatch.categoryName,
      nextRound: nextRound,
      nextMatchIndex: nextMatchIndex,
      playerId: winnerId,
      isSlotA: isSlotA,
    );

    await fetchMatchesByTournament(tournamentId);
  }

  Future<void> fetchAssignedMatches(String umpireId) async {
    try {
      _matches = await _firestore.getAssignedMatches(umpireId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchAssignedMatches: $e');
    }
  }

  Future<Map<String, num>> fetchPlayerStats(String playerId) async {
    final stats = await _firestore.getPlayerStats(playerId);
    _playerStats[playerId] = stats;
    notifyListeners();
    return stats;
  }

  List<MapEntry<String, Map<String, num>>> getSortedStandings() {
    var entries = _playerStats.entries.toList();

    entries.sort((a, b) {
      int winCompare = (b.value['wins'] ?? 0).compareTo(a.value['wins'] ?? 0);
      if (winCompare != 0) return winCompare;

      num diffA = (a.value['pointsFor'] ?? 0) - (a.value['pointsAgainst'] ?? 0);
      num diffB = (b.value['pointsFor'] ?? 0) - (b.value['pointsAgainst'] ?? 0);
      return diffB.compareTo(diffA);
    });

    return entries;
  }

  Future<void> fetchMatchesByTournament(String tournamentId) async {
    try {
      _matches = await _firestore.getMatchesByTournament(tournamentId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchMatchesByTournament: $e');
    }
  }

  Future<void> fetchAllUsers() async {
    try {
      final snapshot = await _firestore.db.collection('users').get();
      _allUsers = snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchAllUsers error: $e');
    }
  }

  Future<void> generateSingleElimination({
    required String tournamentId,
    required String categoryName,
    required List<String> playerIds,
  }) async {
    playerIds.shuffle();
    int count = playerIds.length;
    int bracketSize = 1;
    while (bracketSize < count) {
      bracketSize *= 2;
    }

    List<Map<String, dynamic>> firstRoundMatches = [];

    for (int i = 0; i < bracketSize; i += 2) {
      String pA = (i < count) ? playerIds[i] : "BYE";
      String pB = (i + 1 < count) ? playerIds[i + 1] : "BYE";

      firstRoundMatches.add({
        'playerAId': pA,
        'playerBId': pB,
        'round': 1,
        'bracketIndex': i ~/ 2,
        'tournamentId': tournamentId,
        'categoryName': categoryName,
        'scoreA': 0,
        'scoreB': 0,
        'isFinished': false,
      });
    }

    await _firestore.saveGeneratedMatches(
      tournamentId: tournamentId,
      categoryName: categoryName,
      matches: firstRoundMatches,
    );

    await fetchMatchesByTournament(tournamentId);
  }

  Future<void> manuallyAssignMatch({
    required String matchId,
    required String umpireId,
    required String courtNumber,
  }) async {
    await _firestore.updateMatchAssignment(
      matchId: matchId,
      umpireId: umpireId,
      courtNumber: courtNumber,
    );
    notifyListeners();
  }
}