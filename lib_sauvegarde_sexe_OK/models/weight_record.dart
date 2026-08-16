class WeightRecord {
  final int? id;
  final int animalId;
  final DateTime date;
  final double weight;
  final String? notes;

  WeightRecord({
    this.id,
    required this.animalId,
    required this.date,
    required this.weight,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'date': date.toIso8601String(),
      'weight': weight,
      'notes': notes,
    };
  }

  factory WeightRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return WeightRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      date: DateTime.parse(
        map['date'] as String,
      ),
      weight:
          (map['weight'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}