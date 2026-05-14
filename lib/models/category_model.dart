class CategoryModel {
  final String name;
  final String skillLevel;
  final int slots;
  final List<String> players;

  const CategoryModel({
    required this.name,
    required this.skillLevel,
    required this.slots,
    required this.players,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'skillLevel': skillLevel,
        'slots': slots,
        'players': players,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      name: map['name'] as String,
      skillLevel: map['skillLevel'] as String,
      slots: (map['slots'] as num?)?.toInt() ?? 0,
      players: (map['players'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

