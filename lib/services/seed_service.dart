import 'package:crypto/crypto.dart';

import '../models/category_model.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

class SeedService {
  SeedService({LocalDbService? db, AuthService? auth})
    : _db = db ?? LocalDbService.instance,
      _auth = auth ?? AuthService();

  final LocalDbService _db;
  final AuthService _auth;

  Future<void> seedIfNeeded() async {
    await _ensureUser(
      name: 'Admin',
      email: 'admin@seed.local',
      password: 'Admin123!',
      role: 'admin',
    );
    await _ensureUser(
      name: 'User',
      email: 'user@seed.local',
      password: 'User123!',
      role: 'player',
    );
    await _ensureUser(
      name: 'User 2',
      email: 'user2@seed.local',
      password: 'User2123!',
      role: 'player',
    );
    await _ensureUser(
      name: 'Seed Umpire',
      email: 'umpire@seed.local',
      password: 'Umpire123!',
      role: 'umpire',
    );

    await _db.deleteTournamentByName('Spring Pickle Cup');
    await _db.deleteTournamentByName('Summer Doubles Clash');

    final user2Id = _userIdFromEmail('user2@seed.local');
    final umpireId = _userIdFromEmail('umpire@seed.local');

    await _ensureUser2Tournament(
      name: 'User2 City Open',
      location: 'Central Pickleball Courts',
      dateOffsetDays: 10,
      categories: const [
        CategoryModel(
          name: 'Men Singles - Beginners',
          skillLevel: 'Beginners',
          slots: 16,
          players: [],
        ),
        CategoryModel(
          name: 'Mixed Doubles - Intermediate - Upper',
          skillLevel: 'Intermediate - Upper',
          slots: 16,
          players: [],
        ),
      ],
      creatorId: user2Id,
      umpireId: umpireId,
    );

    await _ensureUser2Tournament(
      name: 'User2 Weekend Doubles',
      location: 'Riverside Sports Complex',
      dateOffsetDays: 17,
      categories: const [
        CategoryModel(
          name: 'Women Doubles - Novice - Lower',
          skillLevel: 'Novice - Lower',
          slots: 12,
          players: [],
        ),
      ],
      creatorId: user2Id,
      umpireId: umpireId,
    );

    final fullSlotId = await _ensureUser2Tournament(
      name: 'User2 Full Slot Bracket Lab',
      location: 'Harley Pickleball Courts',
      dateOffsetDays: 7,
      categories: const [
        CategoryModel(
          name: 'Harley Singles - Full Slot',
          skillLevel: 'Open',
          slots: 16,
          players: [],
        ),
        CategoryModel(
          name: 'Harley Doubles - Full Slot',
          skillLevel: 'Open',
          slots: 16,
          players: [],
        ),
      ],
      creatorId: user2Id,
      umpireId: umpireId,
    );

    await _fillCategory(
      tournamentId: fullSlotId,
      categoryName: 'Harley Singles - Full Slot',
      emailPrefix: 'seed.full.singles',
      namePrefix: 'Full Slot Singles Player',
      count: 16,
    );
    await _fillCategory(
      tournamentId: fullSlotId,
      categoryName: 'Harley Doubles - Full Slot',
      emailPrefix: 'seed.full.doubles',
      namePrefix: 'Full Slot Doubles Player',
      count: 16,
    );

    await _db.setCurrentUserId(_userIdFromEmail('user@seed.local'));
  }

  Future<void> _ensureUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final existing = await _db.getUserByEmail(email);
    if (existing != null) return;

    await _auth.signUp(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<String> _ensureUser2Tournament({
    required String name,
    required String location,
    required int dateOffsetDays,
    required List<CategoryModel> categories,
    required String creatorId,
    required String umpireId,
  }) async {
    final existing = await _findApprovedTournamentIdByName(name);
    if (existing != null) {
      await _db.updateTournamentCreator(
        tournamentId: existing,
        creatorId: creatorId,
      );
      await _ensureTournamentCategories(
        tournamentId: existing,
        categories: categories,
      );
      await _db.assignUmpire(tournamentId: existing, umpireId: umpireId);
      return existing;
    }

    final id = await _db.createTournament(
      name: name,
      location: location,
      date: DateTime.now().add(Duration(days: dateOffsetDays)),
      registrationStart: DateTime.now().subtract(const Duration(days: 1)),
      registrationEnd: DateTime.now().add(const Duration(days: 5)),
      creatorId: creatorId,
      isApproved: true,
      categories: categories,
    );
    await _db.applyAsUmpire(tournamentId: id, umpireId: umpireId);
    await _db.assignUmpire(tournamentId: id, umpireId: umpireId);
    return id;
  }

  Future<void> _ensureTournamentCategories({
    required String tournamentId,
    required List<CategoryModel> categories,
  }) async {
    final tournament = await _db.getTournamentById(tournamentId);
    if (tournament == null) return;
    final updated = List<CategoryModel>.from(tournament.categories);
    for (final category in categories) {
      final exists = updated.any((c) => c.name == category.name);
      if (!exists) updated.add(category);
    }
    if (updated.length == tournament.categories.length) return;
    await _db.updateTournamentCategories(
      tournamentId: tournamentId,
      categories: updated,
    );
  }

  Future<String?> _findApprovedTournamentIdByName(String name) async {
    final tournaments = await _db.getApprovedTournaments();
    for (final tournament in tournaments) {
      if (tournament.name == name) return tournament.id;
    }
    return null;
  }

  Future<void> _fillCategory({
    required String tournamentId,
    required String categoryName,
    required String emailPrefix,
    required String namePrefix,
    required int count,
  }) async {
    for (var i = 1; i <= count; i++) {
      final number = i.toString().padLeft(2, '0');
      final email = '$emailPrefix$number@seed.local';
      await _ensureUser(
        name: '$namePrefix $number',
        email: email,
        password: 'Player123!',
        role: 'player',
      );

      final tournament = await _db.getTournamentById(tournamentId);
      final categoryIndex =
          tournament?.categories.indexWhere((c) => c.name == categoryName) ??
          -1;
      if (tournament == null || categoryIndex == -1) return;

      final category = tournament.categories[categoryIndex];
      if (category.players.length >= category.slots) {
        return;
      }

      final playerId = _userIdFromEmail(email);
      if (category.players.contains(playerId)) continue;
      await _db.registerPlayer(
        tournamentId: tournamentId,
        playerId: playerId,
        categoryName: categoryName,
        registrationDetails: {
          'type': categoryName.toLowerCase().contains('double')
              ? 'doubles'
              : 'singles',
          'players': [
            {
              'slot': 1,
              'name': '$namePrefix $number',
              'address': 'Seed Address $number',
              'club': 'Seed Club',
              'age': 25 + (i % 10),
              'idImage': '',
              'contactNumber': '0917000${number.padLeft(4, '0')}',
            },
          ],
        },
      );
    }
  }

  String _userIdFromEmail(String email) {
    return sha256.convert(email.codeUnits).toString();
  }
}
