import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStore {
  static const _key = 'favorite_animal_ids';

  static Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  static Future<bool> isFavorite(int animalId) async =>
      (await load()).contains(animalId);

  static Future<bool> toggle(int animalId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await load();
    final isNowFavorite = !favorites.contains(animalId);
    if (isNowFavorite) {
      favorites.add(animalId);
    } else {
      favorites.remove(animalId);
    }
    final values = favorites.map((id) => id.toString()).toList()..sort();
    await prefs.setStringList(_key, values);
    return isNowFavorite;
  }
}
