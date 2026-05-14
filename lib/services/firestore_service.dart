import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';
import 'local_db_service.dart';

/// Local persistence implementation exposed through the same API shape
/// as the former FirestoreService.
///
/// This keeps the existing UI/provider code working while removing all
/// Firebase dependencies.
class FirestoreService {
  FirestoreService({LocalDbService? db}) : _db = db ?? LocalDbService.instance;

  final LocalDbService _db;

  Future<String> createTournament({
    required String name,
    required String location,
    required DateTime date,
    required DateTime registrationStart,
    required DateTime registrationEnd,
    required String creatorId,
    required bool isApproved,
    String imagePath = '',
    required List<CategoryModel> categories,
  }) async {
    return _db.createTournament(
      name: name,
      location: location,
      date: date,
      registrationStart: registrationStart,
      registrationEnd: registrationEnd,
      creatorId: creatorId,
      isApproved: isApproved,
      imagePath: imagePath,
      categories: categories,
    );
  }

  Stream<List<TournamentModel>> getApprovedTournaments() {
    return Stream.fromFuture(_db.getApprovedTournaments());
  }

  Future<List<TournamentModel>> getPendingTournaments() {
    return _db.getTournamentsByStatus('pending');
  }

  Future<List<TournamentModel>> getCreatedTournaments(String creatorId) {
    return _db.getCreatedTournaments(creatorId);
  }

  Future<List<TournamentModel>> getRegisteredTournaments(String playerId) {
    return _db.getRegisteredTournaments(playerId);
  }

  Future<TournamentModel?> getTournamentById(String tournamentId) {
    return _db.getTournamentById(tournamentId);
  }

  Future<void> approveTournament({
    required String tournamentId,
    required bool approved,
  }) async {
    await _db.approveTournament(tournamentId: tournamentId, approved: approved);
  }

  Future<void> rejectTournament({required String tournamentId}) async {
    await _db.rejectTournament(tournamentId: tournamentId);
  }

  Future<void> registerPlayer({
    required String tournamentId,
    required String playerId,
    required String categoryName,
    Map<String, dynamic>? registrationDetails,
  }) async {
    await _db.registerPlayer(
      tournamentId: tournamentId,
      playerId: playerId,
      categoryName: categoryName,
      registrationDetails: registrationDetails,
    );
  }

  Future<void> applyAsUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _db.applyAsUmpire(tournamentId: tournamentId, umpireId: umpireId);
  }

  Future<void> assignUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _db.assignUmpire(tournamentId: tournamentId, umpireId: umpireId);
  }

  Future<void> rejectUmpireApplication({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _db.rejectUmpireApplication(
      tournamentId: tournamentId,
      umpireId: umpireId,
    );
  }

  Future<String> createMatch({
    required String tournamentId,
    required String playerA,
    required String playerB,
    required int scoreA,
    required int scoreB,
    required String winner,
    required String umpireId,
  }) async {
    // LocalDbService stores matches without returning an explicit id.
    // The current app only needs match creation to succeed and later fetch.
    await _db.createMatch(
      tournamentId: tournamentId,
      playerA: playerA,
      playerB: playerB,
      scoreA: scoreA,
      scoreB: scoreB,
      winner: winner,
      umpireId: umpireId,
    );

    // Return a best-effort id.
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<void> updateScore({
    required String tournamentId,
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String winner,
  }) async {
    await _db.updateScore(
      matchId: matchId,
      scoreA: scoreA,
      scoreB: scoreB,
      winner: winner,
    );
  }

  Future<List<MatchModel>> getMatchesByTournament(String tournamentId) {
    return _db.getMatchesByTournament(tournamentId);
  }

  Future<List<MatchModel>> getAssignedMatches(String umpireId) {
    return _db.getAssignedMatches(umpireId);
  }

  Future<List<TournamentModel>> getUmpiredTournaments(String umpireId) {
    return _db.getUmpiredTournaments(umpireId);
  }

  Future<List<UserModel>> getUmpires() {
    return _db.getUsersByRole('umpire');
  }

  Future<void> scheduleMatch({
    required String tournamentId,
    required String categoryName,
    required String bracket,
    required String playerA,
    required String playerB,
    required String umpireId,
    required String courtNumber,
  }) {
    return _db.scheduleMatch(
      tournamentId: tournamentId,
      categoryName: categoryName,
      bracket: bracket,
      playerA: playerA,
      playerB: playerB,
      umpireId: umpireId,
      courtNumber: courtNumber,
    );
  }

  Future<void> updateMatchAssignment({
    required String matchId,
    required String umpireId,
    required String courtNumber,
  }) {
    return _db.updateMatchAssignment(
      matchId: matchId,
      umpireId: umpireId,
      courtNumber: courtNumber,
    );
  }

  Future<void> generateBrackets({required String tournamentId}) {
    return _db.generateBrackets(tournamentId: tournamentId);
  }

  Future<Map<String, Map<String, List<String>>>> getBrackets(
    String tournamentId,
  ) {
    return _db.getBrackets(tournamentId);
  }

  Future<void> saveBrackets({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) {
    return _db.saveBrackets(
      tournamentId: tournamentId,
      bracketsByCategory: bracketsByCategory,
    );
  }

  Future<void> generateRoundRobinGames({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) {
    return _db.generateRoundRobinGames(
      tournamentId: tournamentId,
      bracketsByCategory: bracketsByCategory,
    );
  }

  Future<Map<String, num>> getPlayerStats(String playerId) {
    return _db.getPlayerStats(playerId);
  }
}
