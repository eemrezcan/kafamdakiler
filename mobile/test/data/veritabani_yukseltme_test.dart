import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

void main() {
  test('schema 2 -> 3: the capture cache table is added and the queue survives', () async {
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
    final kuyruk = await db.select(db.bekleyenIslemler).get();
    expect(kuyruk.single.id, 'b1');
    expect(kuyruk.single.tur, BekleyenTur.gunYaz);
    final surum = await db.customSelect('PRAGMA user_version').getSingle();
    expect(surum.data.values.first, 3);
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
