class FeedingRecord {
  final int? id;
  final int animalId;
  final DateTime date;
  final String feed;
  final String? quantity;
  final String? notes;

  FeedingRecord({
    this.id,
    required this.animalId,
    required this.date,
    required this.feed,
    this.quantity,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'date': date.toIso8601String(),
      'feed': feed,
      'quantity': quantity,
      'notes': notes,
    };
  }

  factory FeedingRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return FeedingRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      date: DateTime.parse(
        map['date'] as String,
      ),
      feed: map['feed'] as String,
      quantity: map['quantity'] as String?,
      notes: map['notes'] as String?,
    );
  }
}