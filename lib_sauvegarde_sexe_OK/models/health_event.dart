class HealthEvent {
  final int? id;
  final int animalId;
  final String type;
  final DateTime date;

  final String? product;
  final String? reason;
  final String? dosage;
  final String? disease;

  final DateTime? recoveryDate;

  final String? notes;

  HealthEvent({
    this.id,
    required this.animalId,
    required this.type,
    required this.date,
    this.product,
    this.reason,
    this.dosage,
    this.disease,
    this.recoveryDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'type': type,
      'date': date.toIso8601String(),
      'product': product,
      'reason': reason,
      'dosage': dosage,
      'disease': disease,
      'recovery_date':
          recoveryDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory HealthEvent.fromMap(
    Map<String, dynamic> map,
  ) {
    return HealthEvent(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      type: map['type'] as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      product: map['product'] as String?,
      reason: map['reason'] as String?,
      dosage: map['dosage'] as String?,
      disease: map['disease'] as String?,
      recoveryDate:
          map['recovery_date'] == null
              ? null
              : DateTime.parse(
                  map['recovery_date'] as String,
                ),
      notes: map['notes'] as String?,
    );
  }
}