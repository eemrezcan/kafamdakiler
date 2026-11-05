import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

void main() {
  test('schema 3 -> 4: the project cache table is added; the capture cache and the queue survive', () async {
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
    await db.into(db.projeOnbellek).insert(ProjeOnbellekCompanion.insert(id: 'kitap-kulubu', sira: 0, govde: '{}'));
    expect(await db.select(db.projeOnbellek).get(), hasLength(1), reason: 'and can be written');
    expect((await db.select(db.bekleyenIslemler).get()).single.id, 'y1');
    expect((await db.select(db.yakalamaOnbellek).get()).single.id, 'y2');
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 4);
  });

  test('schema 2 -> 4: both new cache tables are added and the queue survives', () async {
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
    expect(surum.data.values.first, 4);
  });

  test('the new queue kinds are appended after the old ones (the column stores the index)', () {
    expect(BekleyenTur.gunYaz.index, 0);
    expect(BekleyenTur.oturumEkle.index, 1);
    expect(BekleyenTur.gunSil.index, 2);
    expect(BekleyenTur.yakalamaEkle.index, 3);
    expect(BekleyenTur.yakalamaGuncelle.index, 4);
    expect(BekleyenTur.yakalamaSil.index, 5);
  });
}
