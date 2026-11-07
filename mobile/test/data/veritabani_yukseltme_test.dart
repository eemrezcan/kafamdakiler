import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

void main() {
  test('schema 3 -> 10:the project, reminder and action cache tables are added; the capture cache and the queue survive', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme3');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski3.sqlite');

    // A database as version 3 left it: a queued capture, a cached capture, user_version 3.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE yakalama_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('y1', 3, 'y1', NULL, '{\"metin\":\"x\"}', 1793000000, 0, NULL)");
      raw.execute("INSERT INTO yakalama_onbellek VALUES ('y2', 0, '{}')");
      raw.execute('PRAGMA user_version = 3');
    }));
    addTearDown(db.close);

    expect(await db.select(db.projeOnbellek).get(), isEmpty, reason: 'the new table exists');
    expect(await db.select(db.hatirlaticiOnbellek).get(), isEmpty, reason: 'the reminder table exists too');
    await db.into(db.projeOnbellek).insert(ProjeOnbellekCompanion.insert(id: 'kitap-kulubu', sira: 0, govde: '{}'));
    expect(await db.select(db.projeOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.bekleyenIslemler).get()).single.id, 'y1');
    expect((await db.select(db.yakalamaOnbellek).get()).single.id, 'y2');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });

  test('schema 2 -> 10:all the new cache tables are added and the queue survives', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski.sqlite');

    // A database exactly as version 2 of the app left it: a queue row and
    // user_version 2. `setup` runs before drift looks at the version.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL
        )
      ''');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('b1', 0, 'a1', '2026-10-31', '{\"miktar\":6}', 1793000000, 0, NULL)");
      raw.execute('PRAGMA user_version = 2');
    }));
    addTearDown(db.close);

    expect(await db.select(db.yakalamaOnbellek).get(), isEmpty, reason: 'the new table exists');
    expect(await db.select(db.projeOnbellek).get(), isEmpty, reason: 'the new table exists');
    final kuyruk = await db.select(db.bekleyenIslemler).get();
    expect(kuyruk.single.id, 'b1');
    expect(kuyruk.single.tur, BekleyenTur.gunYaz);
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });

  test('schema 4 -> 10:the reminder and action cache tables are added and can be written; the queue survives', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme4');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski4.sqlite');

    // A database as version 4 left it: a queued capture and a cached project, user_version 4.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE proje_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('y1', 3, 'y1', NULL, '{\"metin\":\"x\"}', 1793000000, 0, NULL)");
      raw.execute("INSERT INTO proje_onbellek VALUES ('kitap-kulubu', 0, '{}')");
      raw.execute('PRAGMA user_version = 4');
    }));
    addTearDown(db.close);

    expect(await db.select(db.hatirlaticiOnbellek).get(), isEmpty, reason: 'the new table exists');
    await db.into(db.hatirlaticiOnbellek).insert(HatirlaticiOnbellekCompanion.insert(id: 'h1', sira: 0, govde: '{}'));
    expect(await db.select(db.hatirlaticiOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.bekleyenIslemler).get()).single.id, 'y1');
    expect((await db.select(db.projeOnbellek).get()).single.id, 'kitap-kulubu');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });

  test('schema 5 -> 10:the action cache table is added with its "announced" flag; the reminder cache and the queue survive', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme5');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski5.sqlite');

    // A database as version 5 left it: a queued reminder write and a cached reminder, user_version 5.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE hatirlatici_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('h1', 9, 'h1', NULL, '{}', 1793000000, 0, NULL)");
      raw.execute("INSERT INTO hatirlatici_onbellek VALUES ('h2', 0, '{}')");
      raw.execute('PRAGMA user_version = 5');
    }));
    addTearDown(db.close);

    expect(await db.select(db.eylemOnbellek).get(), isEmpty, reason: 'the new table exists');
    await db.into(db.eylemOnbellek).insert(EylemOnbellekCompanion.insert(id: 'e1', sira: 0, govde: '{}'));
    final satir = (await db.select(db.eylemOnbellek).get()).single;
    expect(satir.bildirildi, isFalse, reason: 'not announced until a notification was shown');
    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.hatirlaticiYaptim);
    expect((await db.select(db.hatirlaticiOnbellek).get()).single.id, 'h2');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });

  test('the new queue kinds are appended after the old ones (the column stores the index)', () {
    expect(BekleyenTur.gunYaz.index, 0);
    expect(BekleyenTur.oturumEkle.index, 1);
    expect(BekleyenTur.gunSil.index, 2);
    expect(BekleyenTur.yakalamaEkle.index, 3);
    expect(BekleyenTur.yakalamaGuncelle.index, 4);
    expect(BekleyenTur.yakalamaSil.index, 5);
    expect(BekleyenTur.hatirlaticiEkle.index, 6);
    expect(BekleyenTur.hatirlaticiGuncelle.index, 7);
    expect(BekleyenTur.hatirlaticiSil.index, 8);
    expect(BekleyenTur.hatirlaticiYaptim.index, 9);
    expect(BekleyenTur.hatirlaticiErtele.index, 10);
    expect(BekleyenTur.eylemUygula.index, 11);
    expect(BekleyenTur.eylemReddet.index, 12);
    expect(BekleyenTur.eylemGeriAl.index, 13);
    expect(BekleyenTur.beyinMaddeEkle.index, 14);
    expect(BekleyenTur.beyinMaddeIsaretle.index, 15);
    expect(BekleyenTur.beyinMaddeDevret.index, 16);
    expect(BekleyenTur.beyinMaddeNot.index, 17);
    expect(BekleyenTur.beyinGorevEkle.index, 18);
    expect(BekleyenTur.beyinGorevBitir.index, 19);
    expect(BekleyenTur.beyinGunlereBol.index, 20);
    expect(BekleyenTur.gelenIsle.index, 21);
    expect(BekleyenTur.gelenSil.index, 22);
  });

  test('schema 7 -> 10:the inbox cache table is added and can be written; the queue and the day plan cache survive', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme7');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski7.sqlite');

    // A database as version 7 left it: a queued day plan write (with its "uyari" column), a cached day, user_version 7.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL,
          uyari TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE gun_plani_onbellek (tarih TEXT NOT NULL PRIMARY KEY, govde TEXT NOT NULL, okunma INTEGER NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('m1', 14, 'm1', '2026-11-07', '{}', 1793000000, 0, NULL, NULL)");
      raw.execute("INSERT INTO gun_plani_onbellek VALUES ('2026-11-07', '{}', 1793000000)");
      raw.execute('PRAGMA user_version = 7');
    }));
    addTearDown(db.close);

    expect(await db.select(db.gelenOnbellek).get(), isEmpty, reason: 'the new table exists');
    await db.into(db.gelenOnbellek).insert(GelenOnbellekCompanion.insert(id: '2026-11-03-1840-kitap-onerisi', sira: 0, govde: '{}'));
    expect(await db.select(db.gelenOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.beyinMaddeEkle);
    expect((await db.select(db.gunPlaniOnbellek).get()).single.tarih, '2026-11-07');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);

    // The new queue kinds can be stored and read back.
    await db.into(db.bekleyenIslemler).insert(BekleyenIslemlerCompanion.insert(
          id: 'g1', tur: BekleyenTur.gelenIsle, hedefId: 'kart', govde: '{}', olusturulma: DateTime.utc(2026, 11, 7)));
    final g = await (db.select(db.bekleyenIslemler)..where((t) => t.id.equals('g1'))).getSingle();
    expect(g.tur, BekleyenTur.gelenIsle);
  });

  test('schema 8 -> 10: the briefing cache, settings and timeline cache tables are added and can be written; the inbox cache and the queue survive', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme8');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski8.sqlite');

    // A database as version 8 left it: a queued inbox write, a cached inbox card, user_version 8.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL,
          uyari TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE gelen_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('g1', 21, 'kart', NULL, '{}', 1793000000, 0, NULL, NULL)");
      raw.execute("INSERT INTO gelen_onbellek VALUES ('kart', 0, '{}')");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    expect(await db.select(db.brifingOnbellek).get(), isEmpty, reason: 'the new tables exist');
    expect(await db.select(db.ayarKayitlari).get(), isEmpty);
    expect(await db.select(db.zamanCizelgesiOnbellek).get(), isEmpty);
    await db.into(db.zamanCizelgesiOnbellek).insert(ZamanCizelgesiOnbellekCompanion.insert(gun: '2026-11-08', govde: '{}', okunma: DateTime.utc(2026, 11, 8)));
    expect(await db.select(db.zamanCizelgesiOnbellek).get(), hasLength(1), reason: 'the timeline cache can be written');
    await db.into(db.brifingOnbellek).insert(BrifingOnbellekCompanion.insert(gun: '2026-11-08', govde: '{}', okunma: DateTime.utc(2026, 11, 8)));
    await db.into(db.ayarKayitlari).insert(AyarKayitlariCompanion.insert(anahtar: 'brifing.saat', deger: '07:00'));
    expect(await db.select(db.brifingOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.ayarKayitlari).get()).single.deger, '07:00');
    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.gelenIsle);
    expect((await db.select(db.gelenOnbellek).get()).single.id, 'kart');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });

  test('schema 6 -> 10:the day plan cache, the let-go table and the "uyari" column are added; queued writes and the action cache survive', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme6');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski6.sqlite');

    // A database as version 6 left it: a queued approval decision (no "uyari" column yet), a cached action, user_version 6.
    final db = AppDatabase(NativeDatabase(dosya, setup: (raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE bekleyen_islemler (
          id TEXT NOT NULL PRIMARY KEY,
          tur INTEGER NOT NULL,
          hedef_id TEXT NOT NULL,
          tarih TEXT NULL,
          govde TEXT NOT NULL,
          olusturulma INTEGER NOT NULL,
          gonderildi INTEGER NOT NULL DEFAULT 0 CHECK (gonderildi IN (0, 1)),
          hata TEXT NULL
        )
      ''');
      raw.execute('CREATE TABLE eylem_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL, bildirildi INTEGER NOT NULL DEFAULT 0 CHECK (bildirildi IN (0, 1)))');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('e1', 11, 'e1', NULL, '{}', 1793000000, 0, NULL)");
      raw.execute("INSERT INTO eylem_onbellek VALUES ('e2', 0, '{}', 1)");
      raw.execute('PRAGMA user_version = 6');
    }));
    addTearDown(db.close);

    // The old queue row is read with the new column empty.
    final eski = (await db.select(db.bekleyenIslemler).get()).single;
    expect(eski.tur, BekleyenTur.eylemUygula);
    expect(eski.uyari, isNull);
    expect((await db.select(db.eylemOnbellek).get()).single.bildirildi, isTrue);

    // The new tables exist and can be written; the new column can be set.
    expect(await db.select(db.gunPlaniOnbellek).get(), isEmpty);
    await db.into(db.gunPlaniOnbellek).insert(GunPlaniOnbellekCompanion.insert(tarih: '2026-11-07', govde: '{}', okunma: DateTime.utc(2026, 11, 7)));
    expect((await db.select(db.gunPlaniOnbellek).get()).single.tarih, '2026-11-07');
    await db.into(db.sabahBirakilanlar).insert(SabahBirakilanlarCompanion.insert(id: 'a3f09c', tarih: '2026-11-06'));
    expect(await db.select(db.sabahBirakilanlar).get(), hasLength(1));
    await (db.update(db.bekleyenIslemler)..where((t) => t.id.equals('e1'))).write(const BekleyenIslemlerCompanion(uyari: Value('not')));
    expect((await db.select(db.bekleyenIslemler).get()).single.uyari, 'not');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 10);
  });
}
