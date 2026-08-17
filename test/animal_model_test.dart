import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_troupeau/models/animal.dart';

void main() {
  group('Animal', () {
    test('normalise le sexe, le rôle reproducteur et le statut', () {
      final animal = Animal(
        identification: '1001',
        cornes: 'Cornue',
        dateNaissance: DateTime(2024, 1, 2),
        race: '38',
        sexe: 'Mâle',
        reproductiveRole: 'Reproducteur',
        status: 'Actif',
      );

      expect(animal.normalizedSex, AnimalSex.male);
      expect(animal.normalizedReproductiveRole, ReproductiveRole.breeder);
      expect(animal.normalizedStatus, AnimalStatus.active);
      expect(animal.canReproduce, isTrue);
      expect(animal.isActive, isTrue);
    });

    test('retombe sur Inconnu pour des valeurs non reconnues', () {
      final animal = Animal(
        identification: '1002',
        cornes: 'À définir',
        dateNaissance: DateTime(2024, 1, 2),
        race: '38',
        sexe: 'autre',
        reproductiveRole: 'autre',
      );

      expect(animal.normalizedSex, AnimalSex.unknown);
      expect(animal.normalizedReproductiveRole, ReproductiveRole.unknown);
    });

    test('sérialise et restaure la filiation', () {
      final animal = Animal(
        id: 12,
        identification: '1003',
        cornes: 'Cornue',
        dateNaissance: DateTime(2025, 3, 4),
        race: '38',
        sexe: 'Femelle',
        reproductiveRole: 'Reproducteur',
        motherId: 3,
        fatherId: 7,
      );

      final restored = Animal.fromMap(animal.toMap());

      expect(restored.id, 12);
      expect(restored.motherId, 3);
      expect(restored.fatherId, 7);
      expect(restored.normalizedSex, AnimalSex.female);
      expect(restored.normalizedReproductiveRole, ReproductiveRole.breeder);
    });

    test('copyWith peut retirer explicitement un parent', () {
      final animal = Animal(
        id: 12,
        identification: '1004',
        cornes: 'Cornue',
        dateNaissance: DateTime(2025, 3, 4),
        race: '38',
        motherId: 3,
        fatherId: 7,
      );

      final updated = animal.copyWith(clearMother: true);

      expect(updated.motherId, isNull);
      expect(updated.fatherId, 7);
    });

    test('un non reproducteur ne peut pas être candidat reproducteur', () {
      final animal = Animal(
        identification: '1005',
        cornes: 'Cornue',
        dateNaissance: DateTime(2020, 1, 1),
        race: '38',
        reproductiveRole: 'Non reproducteur',
      );

      expect(animal.canReproduce, isFalse);
    });
  });
}
