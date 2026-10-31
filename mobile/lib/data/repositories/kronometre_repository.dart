import '../services/database/app_database.dart';

/// Persists the start instant of a running stopwatch (per item or habit).
/// The elapsed time is always `now - start`, so it stays right when the app
/// goes to the background or is killed.
class KronometreRepository {
  KronometreRepository({required this._db});

  final AppDatabase _db;

  Future<DateTime?> baslangic(String hedefId) async {
    final satir =
        await (_db.select(_db.kronometreKayitlari)..where((t) => t.hedefId.equals(hedefId))).getSingleOrNull();
    return satir?.baslangic.toUtc(); // drift hands back local time
  }

  Future<void> baslat(String hedefId, DateTime an) => _db.into(_db.kronometreKayitlari).insertOnConflictUpdate(
        KronometreKayitlariCompanion.insert(hedefId: hedefId, baslangic: an),
      );

  Future<void> temizle(String hedefId) =>
      (_db.delete(_db.kronometreKayitlari)..where((t) => t.hedefId.equals(hedefId))).go();
}
