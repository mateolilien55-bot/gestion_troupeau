class AnimalEvent {
  final int? id;
  final int animalId;
  final String type;
  final DateTime date;
  final String? description;

  AnimalEvent({
    this.id,
    required this.animalId,
    required this.type,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'type': type,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory AnimalEvent.fromMap(
    Map<String, dynamic> map,
  ) {
    return AnimalEvent(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      type: map['type'] as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      description: map['description'] as String?,
    );
  }
}