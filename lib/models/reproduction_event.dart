class ReproductionEvent {
  final int? id;
  final int animalId;
  final String type;
  final DateTime date;

  final int? relatedAnimalId;

  final String? bull;
  final bool? pregnancyConfirmed;

  final int? calfId;
  final String? calfSex;

  final String? calvingEase;
  final double? calfWeight;

  final String? notes;

  ReproductionEvent({
    this.id,
    required this.animalId,
    required this.type,
    required this.date,
    this.relatedAnimalId,
    this.bull,
    this.pregnancyConfirmed,
    this.calfId,
    this.calfSex,
    this.calvingEase,
    this.calfWeight,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'type': type,
      'date': date.toIso8601String(),
      'related_animal_id': relatedAnimalId,
      'bull': bull,
      'pregnancy_confirmed':
          pregnancyConfirmed == null
              ? null
              : pregnancyConfirmed!
                  ? 1
                  : 0,
      'calf_id': calfId,
      'calf_sex': calfSex,
      'calving_ease': calvingEase,
      'calf_weight': calfWeight,
      'notes': notes,
    };
  }

  factory ReproductionEvent.fromMap(
    Map<String, dynamic> map,
  ) {
    return ReproductionEvent(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      type: map['type'] as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      relatedAnimalId:
          map['related_animal_id'] as int?,
      bull: map['bull'] as String?,
      pregnancyConfirmed:
          map['pregnancy_confirmed'] == null
              ? null
              : map['pregnancy_confirmed'] == 1,
      calfId: map['calf_id'] as int?,
      calfSex: map['calf_sex'] as String?,
      calvingEase:
          map['calving_ease'] as String?,
      calfWeight:
          map['calf_weight'] == null
              ? null
              : (map['calf_weight'] as num)
                  .toDouble(),
      notes: map['notes'] as String?,
    );
  }
}