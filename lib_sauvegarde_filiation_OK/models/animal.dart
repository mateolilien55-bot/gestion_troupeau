class Animal {
  final int? id;
  final String identification;
  final String cornes;
  final DateTime dateNaissance;
  final String race;
  final String? sexe;
  final String? premierVelage;
  final String? notes;

  final int? motherId;
  final int? fatherId;

  Animal({
    this.id,
    required this.identification,
    required this.cornes,
    required this.dateNaissance,
    required this.race,
    this.sexe,
    this.premierVelage,
    this.notes,
    this.motherId,
    this.fatherId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identification': identification,
      'cornes': cornes,
      'date_naissance': dateNaissance.toIso8601String(),
      'race': race,
      'sexe': sexe,
      'premier_velage': premierVelage,
      'notes': notes,
      'mother_id': motherId,
      'father_id': fatherId,
    };
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'] as int?,
      identification: map['identification'] as String,
      cornes: map['cornes'] as String,
      dateNaissance: DateTime.parse(
        map['date_naissance'] as String,
      ),
      race: map['race'] as String,
      sexe: map['sexe'] as String?,
      premierVelage: map['premier_velage'] as String?,
      notes: map['notes'] as String?,
      motherId: map['mother_id'] as int?,
      fatherId: map['father_id'] as int?,
    );
  }

  Animal copyWith({
    int? id,
    String? identification,
    String? cornes,
    DateTime? dateNaissance,
    String? race,
    String? sexe,
    String? premierVelage,
    String? notes,
    int? motherId,
    int? fatherId,
  }) {
    return Animal(
      id: id ?? this.id,
      identification: identification ?? this.identification,
      cornes: cornes ?? this.cornes,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      race: race ?? this.race,
      sexe: sexe ?? this.sexe,
      premierVelage: premierVelage ?? this.premierVelage,
      notes: notes ?? this.notes,
      motherId: motherId ?? this.motherId,
      fatherId: fatherId ?? this.fatherId,
    );
  }
}
