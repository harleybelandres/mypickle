class MatchModel {
  final String id;
  final String tournamentId;
  final String categoryName;
  final String bracket;
  final int round;
  final String playerA;
  final String playerB;
  final int scoreA;
  final int scoreB;
  final String winner;
  final String umpireId;
  final String courtNumber;
  final String status;

  const MatchModel({
    required this.id,
    this.tournamentId = '',
    this.categoryName = '',
    this.bracket = '',
    this.round = 1,
    required this.playerA,
    required this.playerB,
    required this.scoreA,
    required this.scoreB,
    required this.winner,
    required this.umpireId,
    this.courtNumber = '',
    this.status = 'scheduled',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tournamentId': tournamentId,
    'categoryName': categoryName,
    'bracket': bracket,
    'round': round,
    'playerA': playerA,
    'playerB': playerB,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'winner': winner,
    'umpireId': umpireId,
    'courtNumber': courtNumber,
    'status': status,
  };

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: (map['id'] ?? map['matchId'] ?? '') as String,
      tournamentId: (map['tournamentId'] ?? '') as String,
      categoryName: (map['categoryName'] ?? '') as String,
      bracket: (map['bracket'] ?? '') as String,
      round: ((map['round'] as num?) ?? 1).toInt(),
      playerA: (map['playerA'] ?? map['player1'] ?? '') as String,
      playerB: (map['playerB'] ?? map['player2'] ?? '') as String,
      scoreA: ((map['scoreA'] ?? map['score1']) as num?)?.toInt() ?? 0,
      scoreB: ((map['scoreB'] ?? map['score2']) as num?)?.toInt() ?? 0,
      winner: (map['winner'] as String?) ?? '',
      umpireId: (map['umpireId'] as String?) ?? '',
      courtNumber: (map['courtNumber'] as String?) ?? '',
      status:
          (map['status'] as String?) ??
          (((map['winner'] as String?) ?? '').isEmpty
              ? 'scheduled'
              : 'completed'),
    );
  }
}
