import 'category_model.dart';

class TournamentModel {
  final String id;
  final String name;
  final String location;
  final DateTime date;
  final DateTime registrationStart;
  final DateTime registrationEnd;
  final String creatorId;
  final bool isApproved;
  final String status;
  final String imagePath;
  final String umpireId;
  final Map<String, String> umpireApplications;
  final List<CategoryModel> categories;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.registrationStart,
    required this.registrationEnd,
    required this.creatorId,
    required this.isApproved,
    this.status = 'pending',
    this.imagePath = '',
    this.umpireId = '',
    this.umpireApplications = const {},
    required this.categories,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'location': location,
    'date': date.millisecondsSinceEpoch,
    'registrationStart': registrationStart.millisecondsSinceEpoch,
    'registrationEnd': registrationEnd.millisecondsSinceEpoch,
    'creatorId': creatorId,
    'isApproved': isApproved,
    'status': status,
    'imagePath': imagePath,
    'umpireId': umpireId,
    'umpireApplications': umpireApplications,
    'categories': categories.map((c) => c.toMap()).toList(),
  };

  factory TournamentModel.fromMap(Map<String, dynamic> map) {
    final categoriesRaw = (map['categories'] as List?) ?? const [];
    final approved = (map['isApproved'] as bool?) ?? false;
    final status =
        (map['status'] as String?) ?? (approved ? 'approved' : 'pending');
    final rawUmpireApplications =
        (map['umpireApplications'] as Map?)?.cast<String, dynamic>() ?? {};
    final umpireApplications = rawUmpireApplications.map((key, value) {
      if (value is Map) {
        return MapEntry(
          key.toString(),
          (value['status'] ?? 'pending').toString(),
        );
      }
      return MapEntry(key.toString(), value.toString());
    });
    final date = DateTime.fromMillisecondsSinceEpoch(
      ((map['date'] as num?) ?? 0).toInt(),
    );

    return TournamentModel(
      id: (map['id'] ?? map['tournamentId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      date: date,
      registrationStart: DateTime.fromMillisecondsSinceEpoch(
        ((map['registrationStart'] as num?) ??
                date.subtract(const Duration(days: 30)).millisecondsSinceEpoch)
            .toInt(),
      ),
      registrationEnd: DateTime.fromMillisecondsSinceEpoch(
        ((map['registrationEnd'] as num?) ??
                date.subtract(const Duration(days: 1)).millisecondsSinceEpoch)
            .toInt(),
      ),
      creatorId: (map['creatorId'] ?? '') as String,
      isApproved: status == 'approved' || approved,
      status: status,
      imagePath: (map['imagePath'] ?? map['imageUrl'] ?? '') as String,
      umpireId: (map['umpireId'] ?? '') as String,
      umpireApplications: umpireApplications,
      categories: categoriesRaw
          .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
