import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Cache of `GET /api/aliskanliklar`: the DTO JSON, replaced as a whole.
class AliskanlikOnbellek extends Table {
  TextColumn get id => text()();
  IntColumn get sira => integer()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache of shelf items (`OgeDto` JSON).
class OgeOnbellek extends Table {
  TextColumn get id => text()();
  TextColumn get aliskanlikId => text()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What a queued write does.
enum BekleyenTur {
  /// `PUT /api/aliskanliklar/{hedefId}/kayitlar/{tarih}` with a `GunYaz` body.
  gunYaz,

  /// `POST /api/ogeler/{hedefId}/oturumlar` with an `OturumEkle` body.
  oturumEkle,

  /// `DELETE /api/aliskanliklar/{hedefId}/kayitlar/{tarih}` (day back to zero).
  /// Appended last: the column stores the enum index.
  gunSil,

  /// `POST /api/yakalamalar` with a `YakalamaGovde` body; the queue id is the
  /// capture id, [hedefId] too. Appended last: the column stores the enum index.
  yakalamaEkle,

  /// `PUT /api/yakalamalar/{hedefId}` with a `YakalamaGovde` body.
  yakalamaGuncelle,

  /// `DELETE /api/yakalamalar/{hedefId}`.
  yakalamaSil,

  /// `POST /api/hatirlaticilar` with a `HatirlaticiYaz` body; the queue id is the reminder id, [hedefId] too.
  /// Appended last: the column stores the enum index.
  hatirlaticiEkle,

  /// `PUT /api/hatirlaticilar/{hedefId}` with a `HatirlaticiYaz` body.
  hatirlaticiGuncelle,

  /// `DELETE /api/hatirlaticilar/{hedefId}`.
  hatirlaticiSil,

  /// `POST /api/hatirlaticilar/{hedefId}/yaptim`.
  hatirlaticiYaptim,

  /// `POST /api/hatirlaticilar/{hedefId}/ertele` with `{"sure": "1s" | "yarin"}`.
  hatirlaticiErtele,
}

/// Cache of `GET /api/yakalamalar` (`YakalamaDto` JSON, newest first), replaced as a whole.
class YakalamaOnbellek extends Table {
  TextColumn get id => text()();
  IntColumn get sira => integer()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache of `GET /api/hatirlaticilar` (`HatirlaticiDto` JSON in the server's order), replaced as a whole.
/// The reminders list and the notification plan read it offline, with the queued writes laid on top.
class HatirlaticiOnbellek extends Table {
  TextColumn get id => text()();
  IntColumn get sira => integer()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache of `GET /api/beyin/projeler` (`ProjeOzetDto` JSON, in server order), replaced as a whole.
/// It lets the capture screen's project picker work offline (Kat 1, karar 3).
class ProjeOnbellek extends Table {
  TextColumn get id => text()();
  IntColumn get sira => integer()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The last `GET /api/ben` answer, so the role is known when offline.
class KullaniciOnbellek extends Table {
  IntColumn get id => integer()();
  TextColumn get govde => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A running stopwatch: only the start instant is stored, so the elapsed time
/// is right after the app was in the background or was killed.
class KronometreKayitlari extends Table {
  /// Item id (Raf) or habit id (minute-based Sayac).
  TextColumn get hedefId => text()();
  DateTimeColumn get baslangic => dateTime()();

  @override
  Set<Column> get primaryKey => {hedefId};
}

/// Offline write queue. [id] is a client Guid v7 (K-0013); for
/// [BekleyenTur.oturumEkle] it is also the session id sent to the server.
class BekleyenIslemler extends Table {
  TextColumn get id => text()();
  IntColumn get tur => intEnum<BekleyenTur>()();

  /// Habit id for [BekleyenTur.gunYaz], item id for [BekleyenTur.oturumEkle].
  TextColumn get hedefId => text()();

  /// Habit day ("2026-10-31"); only for [BekleyenTur.gunYaz].
  TextColumn get tarih => text().nullable()();
  TextColumn get govde => text()();
  DateTimeColumn get olusturulma => dateTime()();
  BoolColumn get gonderildi => boolean().withDefault(const Constant(false))();

  /// Set when the server refused the entry for good (4xx); it is skipped later.
  TextColumn get hata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AliskanlikOnbellek,
    OgeOnbellek,
    BekleyenIslemler,
    KullaniciOnbellek,
    KronometreKayitlari,
    YakalamaOnbellek,
    ProjeOnbellek,
    HatirlaticiOnbellek,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'kafamdakiler'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(kullaniciOnbellek);
            await m.createTable(kronometreKayitlari);
          }
          if (from < 3) {
            await m.createTable(yakalamaOnbellek);
          }
          if (from < 4) {
            await m.createTable(projeOnbellek);
          }
          if (from < 5) {
            await m.createTable(hatirlaticiOnbellek);
          }
        },
      );

  /// Sign-out: drops the cache and the offline queue (the user confirmed).
  Future<void> hepsiniTemizle() => transaction(() async {
        await delete(aliskanlikOnbellek).go();
        await delete(ogeOnbellek).go();
        await delete(bekleyenIslemler).go();
        await delete(kullaniciOnbellek).go();
        await delete(kronometreKayitlari).go();
        await delete(yakalamaOnbellek).go();
        await delete(projeOnbellek).go();
        await delete(hatirlaticiOnbellek).go();
      });
}
