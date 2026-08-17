enum AnimalSex {
  female('Femelle'),
  male('Mâle'),
  unknown('Inconnu');

  const AnimalSex(this.label);
  final String label;

  static AnimalSex fromStorage(String? value) {
    return AnimalSex.values.firstWhere(
      (sex) => sex.label == value,
      orElse: () => AnimalSex.unknown,
    );
  }
}

enum ReproductiveRole {
  breeder('Reproducteur'),
  nonBreeder('Non reproducteur'),
  unknown('Inconnu');

  const ReproductiveRole(this.label);
  final String label;

  static ReproductiveRole fromStorage(String? value) {
    return ReproductiveRole.values.firstWhere(
      (role) => role.label == value,
      orElse: () => ReproductiveRole.unknown,
    );
  }
}

enum AnimalStatus {
  active('Actif'),
  sold('Vendu'),
  dead('Mort'),
  transferred('Sorti');

  const AnimalStatus(this.label);
  final String label;

  static AnimalStatus fromStorage(String? value) {
    return AnimalStatus.values.firstWhere(
      (status) => status.label == value,
      orElse: () => AnimalStatus.active,
    );
  }
}

class Animal {
  final int? id;
  final String identification;
  final String cornes;
  final DateTime dateNaissance;
  final String race;
  final String? sexe;
  final String reproductiveRole;
  final String? premierVelage;
  final String? notes;
  final int? motherId;
  final int? fatherId;
  final String status;
  final DateTime? exitDate;

  Animal({
    this.id,
    required this.identification,
    required this.cornes,
    required this.dateNaissance,
    required this.race,
    this.sexe,
    this.reproductiveRole = 'Inconnu',
    this.premierVelage,
    this.notes,
    this.motherId,
    this.fatherId,
    this.status = 'Actif',
    this.exitDate,
  });

  AnimalSex get normalizedSex => AnimalSex.fromStorage(sexe);
  ReproductiveRole get normalizedReproductiveRole =>
      ReproductiveRole.fromStorage(reproductiveRole);
  AnimalStatus get normalizedStatus => AnimalStatus.fromStorage(status);
  bool get isActive => normalizedStatus == AnimalStatus.active;
  bool get canReproduce =>
      normalizedReproductiveRole != ReproductiveRole.nonBreeder;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identification': identification,
      'cornes': cornes,
      'date_naissance': dateNaissance.toIso8601String(),
      'race': race,
      'sexe': normalizedSex.label,
      'reproductive_role': normalizedReproductiveRole.label,
      'premier_velage': premierVelage,
      'notes': notes,
      'mother_id': motherId,
      'father_id': fatherId,
      'status': normalizedStatus.label,
      'exit_date': exitDate?.toIso8601String(),
    };
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'] as int?,
      identification: map['identification'] as String,
      cornes: map['cornes'] as String,
      dateNaissance: DateTime.parse(map['date_naissance'] as String),
      race: map['race'] as String,
      sexe: AnimalSex.fromStorage(map['sexe'] as String?).label,
      reproductiveRole:
          ReproductiveRole.fromStorage(map['reproductive_role'] as String?).label,
      premierVelage: map['premier_velage'] as String?,
      notes: map['notes'] as String?,
      motherId: map['mother_id'] as int?,
      fatherId: map['father_id'] as int?,
      status: AnimalStatus.fromStorage(map['status'] as String?).label,
      exitDate: map['exit_date'] == null
          ? null
          : DateTime.tryParse(map['exit_date'] as String),
    );
  }

  Animal copyWith({
    int? id,
    String? identification,
    String? cornes,
    DateTime? dateNaissance,
    String? race,
    String? sexe,
    String? reproductiveRole,
    String? premierVelage,
    String? notes,
    int? motherId,
    int? fatherId,
    String? status,
    DateTime? exitDate,
    bool clearMother = false,
    bool clearFather = false,
    bool clearExitDate = false,
  }) {
    return Animal(
      id: id ?? this.id,
      identification: identification ?? this.identification,
      cornes: cornes ?? this.cornes,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      race: race ?? this.race,
      sexe: sexe ?? this.sexe,
      reproductiveRole: reproductiveRole ?? this.reproductiveRole,
      premierVelage: premierVelage ?? this.premierVelage,
      notes: notes ?? this.notes,
      motherId: clearMother ? null : (motherId ?? this.motherId),
      fatherId: clearFather ? null : (fatherId ?? this.fatherId),
      status: status ?? this.status,
      exitDate: clearExitDate ? null : (exitDate ?? this.exitDate),
    );
  }
}
