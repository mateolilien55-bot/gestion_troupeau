class AnimalMovement {
  final int? id;
  final int animalId;
  final String type;
  final DateTime date;

  final String? reason;
  final String? destination;
  final double? price;
  final String? notes;

  AnimalMovement({
    this.id,
    required this.animalId,
    required this.type,
    required this.date,
    this.reason,
    this.destination,
    this.price,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'type': type,
      'date': date.toIso8601String(),
      'reason': reason,
      'destination': destination,
      'price': price,
      'notes': notes,
    };
  }

  factory AnimalMovement.fromMap(
    Map<String, dynamic> map,
  ) {
    return AnimalMovement(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      type: map['type'] as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      reason: map['reason'] as String?,
      destination:
          map['destination'] as String?,
      price:
          map['price'] == null
              ? null
              : (map['price'] as num)
                  .toDouble(),
      notes: map['notes'] as String?,
    );
  }
}