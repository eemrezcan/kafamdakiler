import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

void main() {
  test('schema 3 -> 13: the project, reminder, action and day view cache tables are added; the capture cache and the queue survive', () async {
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
    expect(surum.data.values.first, 13);
  });

  test('schema 2 -> 13: all the new cache tables are added and the queue survives', () async {
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
    expect(surum.data.values.first, 13);
  });

  test('schema 4 -> 13:the reminder and action cache tables are added and can be written; the queue survives', () async {
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
    expect(surum.data.values.first, 13);
  });

  test('schema 5 -> 13:the action cache table is added with its "announced" flag; the reminder cache and the queue survive', () async {
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
    expect(surum.data.values.first, 13);
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
    expect(BekleyenTur.gunYaptim.index, 23);
    expect(BekleyenTur.gunOgeEkle.index, 24);
    expect(BekleyenTur.ogeHatirlaticiYaz.index, 25);
    expect(BekleyenTur.ogeHatirlaticiSil.index, 26);
    expect(BekleyenTur.dundenBirak.index, 27);
    expect(BekleyenTur.ayarGunYaz.index, 28);
    expect(BekleyenTur.gunDevret.index, 29);
    expect(BekleyenTur.asistanGirdi.index, 30);
    expect(BekleyenTur.asistanCevap.index, 31);
    expect(BekleyenTur.bildirimOkundu.index, 32);
    expect(BekleyenTur.bildirimHepsiOkundu.index, 33);
    expect(BekleyenTur.values, hasLength(34));
  });

  test('schema 7 -> 13: the inbox cache table is added and can be written; the queue survives; the day plan cache is dropped', () async {
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
    final eskiTablo = await db.customSelect("SELECT name FROM sqlite_master WHERE name IN ('gun_plani_onbellek', 'sabah_birakilanlar')").get();
    expect(eskiTablo, isEmpty, reason: 'the day plan cache of the old plan card is gone: the day view replaced it');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 13);

    // The new queue kinds can be stored and read back.
    await db.into(db.bekleyenIslemler).insert(BekleyenIslemlerCompanion.insert(
          id: 'g1', tur: BekleyenTur.gelenIsle, hedefId: 'kart', govde: '{}', olusturulma: DateTime.utc(2026, 11, 7)));
    final g = await (db.select(db.bekleyenIslemler)..where((t) => t.id.equals('g1'))).getSingle();
    expect(g.tur, BekleyenTur.gelenIsle);
  });

  test('schema 8 -> 13: the briefing cache and settings tables are added and can be written; the inbox cache and the queue survive', () async {
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
    await db.into(db.brifingOnbellek).insert(BrifingOnbellekCompanion.insert(gun: '2026-11-08', govde: '{}', okunma: DateTime.utc(2026, 11, 8)));
    await db.into(db.ayarKayitlari).insert(AyarKayitlariCompanion.insert(anahtar: 'brifing.saat', deger: '07:00'));
    expect(await db.select(db.brifingOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.ayarKayitlari).get()).single.deger, '07:00');
    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.gelenIsle);
    expect((await db.select(db.gelenOnbellek).get()).single.id, 'kart');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 13);
  });

  test('schema 6 -> 13: the "uyari" column is added; queued writes and the action cache survive', () async {
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

    // The new column can be set; the day plan tables of version 7 are not made for a database that never had them.
    expect(await db.customSelect("SELECT name FROM sqlite_master WHERE name IN ('gun_plani_onbellek', 'sabah_birakilanlar')").get(), isEmpty);
    await (db.update(db.bekleyenIslemler)..where((t) => t.id.equals('e1'))).write(const BekleyenIslemlerCompanion(uyari: Value('not')));
    expect((await db.select(db.bekleyenIslemler).get()).single.uyari, 'not');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 13);
  });

  test('schema 10 -> 13: the day view, calendar, feed and notification caches are added and can be written; the timeline cache is dropped; the queue survives', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme10');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski10.sqlite');

    // A database as version 10 left it: a queued tick of a plan item, a cached timeline, user_version 10.
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
      raw.execute('CREATE TABLE zaman_cizelgesi_onbellek (gun TEXT NOT NULL PRIMARY KEY, govde TEXT NOT NULL, okunma INTEGER NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('b1', 15, 'a1b2c3', '2026-11-10', '{}', 1793000000, 0, NULL, NULL)");
      raw.execute("INSERT INTO zaman_cizelgesi_onbellek VALUES ('2026-11-09', '{}', 1793000000)");
      raw.execute('PRAGMA user_version = 10');
    }));
    addTearDown(db.close);

    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.beyinMaddeIsaretle);
    // The old timeline cache is gone: the day view replaced it.
    final eskiTablo = await db.customSelect("SELECT name FROM sqlite_master WHERE name = 'zaman_cizelgesi_onbellek'").get();
    expect(eskiTablo, isEmpty);

    expect(await db.select(db.gunGorunumOnbellek).get(), isEmpty, reason: 'the new tables exist');
    expect(await db.select(db.takvimOnbellek).get(), isEmpty);
    expect(await db.select(db.asistanAkisOnbellek).get(), isEmpty);
    expect(await db.select(db.bildirimOnbellek).get(), isEmpty);
    await db.into(db.asistanAkisOnbellek).insert(AsistanAkisOnbellekCompanion.insert(id: 'a1', sira: 0, govde: '{}'));
    await db.into(db.bildirimOnbellek).insert(BildirimOnbellekCompanion.insert(id: 'n1', sira: 0, govde: '{}'));
    expect(await db.select(db.asistanAkisOnbellek).get(), hasLength(1));
    expect(await db.select(db.bildirimOnbellek).get(), hasLength(1));
    await db.into(db.gunGorunumOnbellek).insert(GunGorunumOnbellekCompanion.insert(tarih: '2026-11-10', govde: '{}', okunma: DateTime.utc(2026, 11, 10)));
    await db.into(db.takvimOnbellek).insert(TakvimOnbellekCompanion.insert(aralik: '2026-11-09/2026-11-15', govde: '{}', okunma: DateTime.utc(2026, 11, 10)));
    expect(await db.select(db.gunGorunumOnbellek).get(), hasLength(1));
    expect(await db.select(db.takvimOnbellek).get(), hasLength(1));

    // The new kinds can be queued on the upgraded database.
    await db.into(db.bekleyenIslemler).insert(BekleyenIslemlerCompanion.insert(
          id: 'b2',
          tur: BekleyenTur.gunYaptim,
          hedefId: 'm:a1b2c3',
          govde: '{"geri":false}',
          olusturulma: DateTime.utc(2026, 11, 10),
        ));
    expect((await db.select(db.bekleyenIslemler).get()).map((b) => b.tur), [BekleyenTur.beyinMaddeIsaretle, BekleyenTur.gunYaptim]);
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 13);
  });

  test('schema 12 -> 13: the day plan cache and the let-go list of the old plan card are dropped; everything else survives', () async {
    final klasor = Directory.systemTemp.createTempSync('yukseltme12');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final dosya = File('${klasor.path}/eski12.sqlite');

    // A database as version 12 left it: the two old tables with a row each, a queued reminder, a cached notification page.
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
      raw.execute('CREATE TABLE sabah_birakilanlar (id TEXT NOT NULL, tarih TEXT NOT NULL, PRIMARY KEY (id, tarih))');
      raw.execute('CREATE TABLE bildirim_onbellek (id TEXT NOT NULL PRIMARY KEY, sira INTEGER NOT NULL, govde TEXT NOT NULL)');
      raw.execute("INSERT INTO bekleyen_islemler VALUES ('b1', 25, 'm:aa11bb', '2026-11-10', '{}', 1793000000, 0, NULL, NULL)");
      raw.execute("INSERT INTO gun_plani_onbellek VALUES ('2026-11-09', '{}', 1793000000)");
      raw.execute("INSERT INTO sabah_birakilanlar VALUES ('a3f09c', '2026-11-09')");
      raw.execute("INSERT INTO bildirim_onbellek VALUES ('n1', 0, '{}')");
      raw.execute('PRAGMA user_version = 12');
    }));
    addTearDown(db.close);

    expect((await db.select(db.bekleyenIslemler).get()).single.tur, BekleyenTur.ogeHatirlaticiYaz);
    expect((await db.select(db.bildirimOnbellek).get()).single.id, 'n1');
    expect(await db.customSelect("SELECT name FROM sqlite_master WHERE name IN ('gun_plani_onbellek', 'sabah_birakilanlar')").get(), isEmpty);
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 13);
  });
}
