// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AliskanlikOnbellekTable extends AliskanlikOnbellek
    with TableInfo<$AliskanlikOnbellekTable, AliskanlikOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AliskanlikOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siraMeta = const VerificationMeta('sira');
  @override
  late final GeneratedColumn<int> sira = GeneratedColumn<int>(
    'sira',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sira, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aliskanlik_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<AliskanlikOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sira')) {
      context.handle(
        _siraMeta,
        sira.isAcceptableOrUnknown(data['sira']!, _siraMeta),
      );
    } else if (isInserting) {
      context.missing(_siraMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AliskanlikOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AliskanlikOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sira: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sira'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $AliskanlikOnbellekTable createAlias(String alias) {
    return $AliskanlikOnbellekTable(attachedDatabase, alias);
  }
}

class AliskanlikOnbellekData extends DataClass
    implements Insertable<AliskanlikOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const AliskanlikOnbellekData({
    required this.id,
    required this.sira,
    required this.govde,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sira'] = Variable<int>(sira);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  AliskanlikOnbellekCompanion toCompanion(bool nullToAbsent) {
    return AliskanlikOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory AliskanlikOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AliskanlikOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      sira: serializer.fromJson<int>(json['sira']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sira': serializer.toJson<int>(sira),
      'govde': serializer.toJson<String>(govde),
    };
  }

  AliskanlikOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      AliskanlikOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  AliskanlikOnbellekData copyWithCompanion(AliskanlikOnbellekCompanion data) {
    return AliskanlikOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AliskanlikOnbellekData(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sira, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AliskanlikOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class AliskanlikOnbellekCompanion
    extends UpdateCompanion<AliskanlikOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const AliskanlikOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AliskanlikOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<AliskanlikOnbellekData> custom({
    Expression<String>? id,
    Expression<int>? sira,
    Expression<String>? govde,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sira != null) 'sira': sira,
      if (govde != null) 'govde': govde,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AliskanlikOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return AliskanlikOnbellekCompanion(
      id: id ?? this.id,
      sira: sira ?? this.sira,
      govde: govde ?? this.govde,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sira.present) {
      map['sira'] = Variable<int>(sira.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AliskanlikOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OgeOnbellekTable extends OgeOnbellek
    with TableInfo<$OgeOnbellekTable, OgeOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OgeOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliskanlikIdMeta = const VerificationMeta(
    'aliskanlikId',
  );
  @override
  late final GeneratedColumn<String> aliskanlikId = GeneratedColumn<String>(
    'aliskanlik_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, aliskanlikId, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'oge_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<OgeOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('aliskanlik_id')) {
      context.handle(
        _aliskanlikIdMeta,
        aliskanlikId.isAcceptableOrUnknown(
          data['aliskanlik_id']!,
          _aliskanlikIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aliskanlikIdMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OgeOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OgeOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      aliskanlikId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliskanlik_id'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $OgeOnbellekTable createAlias(String alias) {
    return $OgeOnbellekTable(attachedDatabase, alias);
  }
}

class OgeOnbellekData extends DataClass implements Insertable<OgeOnbellekData> {
  final String id;
  final String aliskanlikId;
  final String govde;
  const OgeOnbellekData({
    required this.id,
    required this.aliskanlikId,
    required this.govde,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['aliskanlik_id'] = Variable<String>(aliskanlikId);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  OgeOnbellekCompanion toCompanion(bool nullToAbsent) {
    return OgeOnbellekCompanion(
      id: Value(id),
      aliskanlikId: Value(aliskanlikId),
      govde: Value(govde),
    );
  }

  factory OgeOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OgeOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      aliskanlikId: serializer.fromJson<String>(json['aliskanlikId']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'aliskanlikId': serializer.toJson<String>(aliskanlikId),
      'govde': serializer.toJson<String>(govde),
    };
  }

  OgeOnbellekData copyWith({String? id, String? aliskanlikId, String? govde}) =>
      OgeOnbellekData(
        id: id ?? this.id,
        aliskanlikId: aliskanlikId ?? this.aliskanlikId,
        govde: govde ?? this.govde,
      );
  OgeOnbellekData copyWithCompanion(OgeOnbellekCompanion data) {
    return OgeOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      aliskanlikId: data.aliskanlikId.present
          ? data.aliskanlikId.value
          : this.aliskanlikId,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OgeOnbellekData(')
          ..write('id: $id, ')
          ..write('aliskanlikId: $aliskanlikId, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, aliskanlikId, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OgeOnbellekData &&
          other.id == this.id &&
          other.aliskanlikId == this.aliskanlikId &&
          other.govde == this.govde);
}

class OgeOnbellekCompanion extends UpdateCompanion<OgeOnbellekData> {
  final Value<String> id;
  final Value<String> aliskanlikId;
  final Value<String> govde;
  final Value<int> rowid;
  const OgeOnbellekCompanion({
    this.id = const Value.absent(),
    this.aliskanlikId = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OgeOnbellekCompanion.insert({
    required String id,
    required String aliskanlikId,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       aliskanlikId = Value(aliskanlikId),
       govde = Value(govde);
  static Insertable<OgeOnbellekData> custom({
    Expression<String>? id,
    Expression<String>? aliskanlikId,
    Expression<String>? govde,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (aliskanlikId != null) 'aliskanlik_id': aliskanlikId,
      if (govde != null) 'govde': govde,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OgeOnbellekCompanion copyWith({
    Value<String>? id,
    Value<String>? aliskanlikId,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return OgeOnbellekCompanion(
      id: id ?? this.id,
      aliskanlikId: aliskanlikId ?? this.aliskanlikId,
      govde: govde ?? this.govde,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (aliskanlikId.present) {
      map['aliskanlik_id'] = Variable<String>(aliskanlikId.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OgeOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('aliskanlikId: $aliskanlikId, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BekleyenIslemlerTable extends BekleyenIslemler
    with TableInfo<$BekleyenIslemlerTable, BekleyenIslemlerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BekleyenIslemlerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BekleyenTur, int> tur =
      GeneratedColumn<int>(
        'tur',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<BekleyenTur>($BekleyenIslemlerTable.$convertertur);
  static const VerificationMeta _hedefIdMeta = const VerificationMeta(
    'hedefId',
  );
  @override
  late final GeneratedColumn<String> hedefId = GeneratedColumn<String>(
    'hedef_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tarihMeta = const VerificationMeta('tarih');
  @override
  late final GeneratedColumn<String> tarih = GeneratedColumn<String>(
    'tarih',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _olusturulmaMeta = const VerificationMeta(
    'olusturulma',
  );
  @override
  late final GeneratedColumn<DateTime> olusturulma = GeneratedColumn<DateTime>(
    'olusturulma',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gonderildiMeta = const VerificationMeta(
    'gonderildi',
  );
  @override
  late final GeneratedColumn<bool> gonderildi = GeneratedColumn<bool>(
    'gonderildi',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("gonderildi" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hataMeta = const VerificationMeta('hata');
  @override
  late final GeneratedColumn<String> hata = GeneratedColumn<String>(
    'hata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uyariMeta = const VerificationMeta('uyari');
  @override
  late final GeneratedColumn<String> uyari = GeneratedColumn<String>(
    'uyari',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tur,
    hedefId,
    tarih,
    govde,
    olusturulma,
    gonderildi,
    hata,
    uyari,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bekleyen_islemler';
  @override
  VerificationContext validateIntegrity(
    Insertable<BekleyenIslemlerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hedef_id')) {
      context.handle(
        _hedefIdMeta,
        hedefId.isAcceptableOrUnknown(data['hedef_id']!, _hedefIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hedefIdMeta);
    }
    if (data.containsKey('tarih')) {
      context.handle(
        _tarihMeta,
        tarih.isAcceptableOrUnknown(data['tarih']!, _tarihMeta),
      );
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    if (data.containsKey('olusturulma')) {
      context.handle(
        _olusturulmaMeta,
        olusturulma.isAcceptableOrUnknown(
          data['olusturulma']!,
          _olusturulmaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_olusturulmaMeta);
    }
    if (data.containsKey('gonderildi')) {
      context.handle(
        _gonderildiMeta,
        gonderildi.isAcceptableOrUnknown(data['gonderildi']!, _gonderildiMeta),
      );
    }
    if (data.containsKey('hata')) {
      context.handle(
        _hataMeta,
        hata.isAcceptableOrUnknown(data['hata']!, _hataMeta),
      );
    }
    if (data.containsKey('uyari')) {
      context.handle(
        _uyariMeta,
        uyari.isAcceptableOrUnknown(data['uyari']!, _uyariMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BekleyenIslemlerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BekleyenIslemlerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tur: $BekleyenIslemlerTable.$convertertur.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}tur'],
        )!,
      ),
      hedefId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hedef_id'],
      )!,
      tarih: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tarih'],
      ),
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
      olusturulma: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}olusturulma'],
      )!,
      gonderildi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}gonderildi'],
      )!,
      hata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hata'],
      ),
      uyari: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uyari'],
      ),
    );
  }

  @override
  $BekleyenIslemlerTable createAlias(String alias) {
    return $BekleyenIslemlerTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BekleyenTur, int, int> $convertertur =
      const EnumIndexConverter<BekleyenTur>(BekleyenTur.values);
}

class BekleyenIslemlerData extends DataClass
    implements Insertable<BekleyenIslemlerData> {
  final String id;
  final BekleyenTur tur;

  /// Habit id for [BekleyenTur.gunYaz], item id for [BekleyenTur.oturumEkle].
  final String hedefId;

  /// Habit day ("2026-10-31"); only for [BekleyenTur.gunYaz].
  final String? tarih;
  final String govde;
  final DateTime olusturulma;
  final bool gonderildi;

  /// Set when the server refused the entry for good (4xx); it is skipped later.
  final String? hata;

  /// A sent entry the user should still look at: the server said the write may have happened without a clear answer
  /// (202), or a split stopped half way (207). Cleared by dismissing it.
  final String? uyari;
  const BekleyenIslemlerData({
    required this.id,
    required this.tur,
    required this.hedefId,
    this.tarih,
    required this.govde,
    required this.olusturulma,
    required this.gonderildi,
    this.hata,
    this.uyari,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['tur'] = Variable<int>(
        $BekleyenIslemlerTable.$convertertur.toSql(tur),
      );
    }
    map['hedef_id'] = Variable<String>(hedefId);
    if (!nullToAbsent || tarih != null) {
      map['tarih'] = Variable<String>(tarih);
    }
    map['govde'] = Variable<String>(govde);
    map['olusturulma'] = Variable<DateTime>(olusturulma);
    map['gonderildi'] = Variable<bool>(gonderildi);
    if (!nullToAbsent || hata != null) {
      map['hata'] = Variable<String>(hata);
    }
    if (!nullToAbsent || uyari != null) {
      map['uyari'] = Variable<String>(uyari);
    }
    return map;
  }

  BekleyenIslemlerCompanion toCompanion(bool nullToAbsent) {
    return BekleyenIslemlerCompanion(
      id: Value(id),
      tur: Value(tur),
      hedefId: Value(hedefId),
      tarih: tarih == null && nullToAbsent
          ? const Value.absent()
          : Value(tarih),
      govde: Value(govde),
      olusturulma: Value(olusturulma),
      gonderildi: Value(gonderildi),
      hata: hata == null && nullToAbsent ? const Value.absent() : Value(hata),
      uyari: uyari == null && nullToAbsent
          ? const Value.absent()
          : Value(uyari),
    );
  }

  factory BekleyenIslemlerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BekleyenIslemlerData(
      id: serializer.fromJson<String>(json['id']),
      tur: $BekleyenIslemlerTable.$convertertur.fromJson(
        serializer.fromJson<int>(json['tur']),
      ),
      hedefId: serializer.fromJson<String>(json['hedefId']),
      tarih: serializer.fromJson<String?>(json['tarih']),
      govde: serializer.fromJson<String>(json['govde']),
      olusturulma: serializer.fromJson<DateTime>(json['olusturulma']),
      gonderildi: serializer.fromJson<bool>(json['gonderildi']),
      hata: serializer.fromJson<String?>(json['hata']),
      uyari: serializer.fromJson<String?>(json['uyari']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tur': serializer.toJson<int>(
        $BekleyenIslemlerTable.$convertertur.toJson(tur),
      ),
      'hedefId': serializer.toJson<String>(hedefId),
      'tarih': serializer.toJson<String?>(tarih),
      'govde': serializer.toJson<String>(govde),
      'olusturulma': serializer.toJson<DateTime>(olusturulma),
      'gonderildi': serializer.toJson<bool>(gonderildi),
      'hata': serializer.toJson<String?>(hata),
      'uyari': serializer.toJson<String?>(uyari),
    };
  }

  BekleyenIslemlerData copyWith({
    String? id,
    BekleyenTur? tur,
    String? hedefId,
    Value<String?> tarih = const Value.absent(),
    String? govde,
    DateTime? olusturulma,
    bool? gonderildi,
    Value<String?> hata = const Value.absent(),
    Value<String?> uyari = const Value.absent(),
  }) => BekleyenIslemlerData(
    id: id ?? this.id,
    tur: tur ?? this.tur,
    hedefId: hedefId ?? this.hedefId,
    tarih: tarih.present ? tarih.value : this.tarih,
    govde: govde ?? this.govde,
    olusturulma: olusturulma ?? this.olusturulma,
    gonderildi: gonderildi ?? this.gonderildi,
    hata: hata.present ? hata.value : this.hata,
    uyari: uyari.present ? uyari.value : this.uyari,
  );
  BekleyenIslemlerData copyWithCompanion(BekleyenIslemlerCompanion data) {
    return BekleyenIslemlerData(
      id: data.id.present ? data.id.value : this.id,
      tur: data.tur.present ? data.tur.value : this.tur,
      hedefId: data.hedefId.present ? data.hedefId.value : this.hedefId,
      tarih: data.tarih.present ? data.tarih.value : this.tarih,
      govde: data.govde.present ? data.govde.value : this.govde,
      olusturulma: data.olusturulma.present
          ? data.olusturulma.value
          : this.olusturulma,
      gonderildi: data.gonderildi.present
          ? data.gonderildi.value
          : this.gonderildi,
      hata: data.hata.present ? data.hata.value : this.hata,
      uyari: data.uyari.present ? data.uyari.value : this.uyari,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BekleyenIslemlerData(')
          ..write('id: $id, ')
          ..write('tur: $tur, ')
          ..write('hedefId: $hedefId, ')
          ..write('tarih: $tarih, ')
          ..write('govde: $govde, ')
          ..write('olusturulma: $olusturulma, ')
          ..write('gonderildi: $gonderildi, ')
          ..write('hata: $hata, ')
          ..write('uyari: $uyari')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tur,
    hedefId,
    tarih,
    govde,
    olusturulma,
    gonderildi,
    hata,
    uyari,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BekleyenIslemlerData &&
          other.id == this.id &&
          other.tur == this.tur &&
          other.hedefId == this.hedefId &&
          other.tarih == this.tarih &&
          other.govde == this.govde &&
          other.olusturulma == this.olusturulma &&
          other.gonderildi == this.gonderildi &&
          other.hata == this.hata &&
          other.uyari == this.uyari);
}

class BekleyenIslemlerCompanion extends UpdateCompanion<BekleyenIslemlerData> {
  final Value<String> id;
  final Value<BekleyenTur> tur;
  final Value<String> hedefId;
  final Value<String?> tarih;
  final Value<String> govde;
  final Value<DateTime> olusturulma;
  final Value<bool> gonderildi;
  final Value<String?> hata;
  final Value<String?> uyari;
  final Value<int> rowid;
  const BekleyenIslemlerCompanion({
    this.id = const Value.absent(),
    this.tur = const Value.absent(),
    this.hedefId = const Value.absent(),
    this.tarih = const Value.absent(),
    this.govde = const Value.absent(),
    this.olusturulma = const Value.absent(),
    this.gonderildi = const Value.absent(),
    this.hata = const Value.absent(),
    this.uyari = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BekleyenIslemlerCompanion.insert({
    required String id,
    required BekleyenTur tur,
    required String hedefId,
    this.tarih = const Value.absent(),
    required String govde,
    required DateTime olusturulma,
    this.gonderildi = const Value.absent(),
    this.hata = const Value.absent(),
    this.uyari = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tur = Value(tur),
       hedefId = Value(hedefId),
       govde = Value(govde),
       olusturulma = Value(olusturulma);
  static Insertable<BekleyenIslemlerData> custom({
    Expression<String>? id,
    Expression<int>? tur,
    Expression<String>? hedefId,
    Expression<String>? tarih,
    Expression<String>? govde,
    Expression<DateTime>? olusturulma,
    Expression<bool>? gonderildi,
    Expression<String>? hata,
    Expression<String>? uyari,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tur != null) 'tur': tur,
      if (hedefId != null) 'hedef_id': hedefId,
      if (tarih != null) 'tarih': tarih,
      if (govde != null) 'govde': govde,
      if (olusturulma != null) 'olusturulma': olusturulma,
      if (gonderildi != null) 'gonderildi': gonderildi,
      if (hata != null) 'hata': hata,
      if (uyari != null) 'uyari': uyari,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BekleyenIslemlerCompanion copyWith({
    Value<String>? id,
    Value<BekleyenTur>? tur,
    Value<String>? hedefId,
    Value<String?>? tarih,
    Value<String>? govde,
    Value<DateTime>? olusturulma,
    Value<bool>? gonderildi,
    Value<String?>? hata,
    Value<String?>? uyari,
    Value<int>? rowid,
  }) {
    return BekleyenIslemlerCompanion(
      id: id ?? this.id,
      tur: tur ?? this.tur,
      hedefId: hedefId ?? this.hedefId,
      tarih: tarih ?? this.tarih,
      govde: govde ?? this.govde,
      olusturulma: olusturulma ?? this.olusturulma,
      gonderildi: gonderildi ?? this.gonderildi,
      hata: hata ?? this.hata,
      uyari: uyari ?? this.uyari,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tur.present) {
      map['tur'] = Variable<int>(
        $BekleyenIslemlerTable.$convertertur.toSql(tur.value),
      );
    }
    if (hedefId.present) {
      map['hedef_id'] = Variable<String>(hedefId.value);
    }
    if (tarih.present) {
      map['tarih'] = Variable<String>(tarih.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (olusturulma.present) {
      map['olusturulma'] = Variable<DateTime>(olusturulma.value);
    }
    if (gonderildi.present) {
      map['gonderildi'] = Variable<bool>(gonderildi.value);
    }
    if (hata.present) {
      map['hata'] = Variable<String>(hata.value);
    }
    if (uyari.present) {
      map['uyari'] = Variable<String>(uyari.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BekleyenIslemlerCompanion(')
          ..write('id: $id, ')
          ..write('tur: $tur, ')
          ..write('hedefId: $hedefId, ')
          ..write('tarih: $tarih, ')
          ..write('govde: $govde, ')
          ..write('olusturulma: $olusturulma, ')
          ..write('gonderildi: $gonderildi, ')
          ..write('hata: $hata, ')
          ..write('uyari: $uyari, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KullaniciOnbellekTable extends KullaniciOnbellek
    with TableInfo<$KullaniciOnbellekTable, KullaniciOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KullaniciOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kullanici_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<KullaniciOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KullaniciOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KullaniciOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $KullaniciOnbellekTable createAlias(String alias) {
    return $KullaniciOnbellekTable(attachedDatabase, alias);
  }
}

class KullaniciOnbellekData extends DataClass
    implements Insertable<KullaniciOnbellekData> {
  final int id;
  final String govde;
  const KullaniciOnbellekData({required this.id, required this.govde});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  KullaniciOnbellekCompanion toCompanion(bool nullToAbsent) {
    return KullaniciOnbellekCompanion(id: Value(id), govde: Value(govde));
  }

  factory KullaniciOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KullaniciOnbellekData(
      id: serializer.fromJson<int>(json['id']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'govde': serializer.toJson<String>(govde),
    };
  }

  KullaniciOnbellekData copyWith({int? id, String? govde}) =>
      KullaniciOnbellekData(id: id ?? this.id, govde: govde ?? this.govde);
  KullaniciOnbellekData copyWithCompanion(KullaniciOnbellekCompanion data) {
    return KullaniciOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KullaniciOnbellekData(')
          ..write('id: $id, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KullaniciOnbellekData &&
          other.id == this.id &&
          other.govde == this.govde);
}

class KullaniciOnbellekCompanion
    extends UpdateCompanion<KullaniciOnbellekData> {
  final Value<int> id;
  final Value<String> govde;
  const KullaniciOnbellekCompanion({
    this.id = const Value.absent(),
    this.govde = const Value.absent(),
  });
  KullaniciOnbellekCompanion.insert({
    this.id = const Value.absent(),
    required String govde,
  }) : govde = Value(govde);
  static Insertable<KullaniciOnbellekData> custom({
    Expression<int>? id,
    Expression<String>? govde,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (govde != null) 'govde': govde,
    });
  }

  KullaniciOnbellekCompanion copyWith({Value<int>? id, Value<String>? govde}) {
    return KullaniciOnbellekCompanion(
      id: id ?? this.id,
      govde: govde ?? this.govde,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KullaniciOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }
}

class $KronometreKayitlariTable extends KronometreKayitlari
    with TableInfo<$KronometreKayitlariTable, KronometreKayitlariData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KronometreKayitlariTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hedefIdMeta = const VerificationMeta(
    'hedefId',
  );
  @override
  late final GeneratedColumn<String> hedefId = GeneratedColumn<String>(
    'hedef_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baslangicMeta = const VerificationMeta(
    'baslangic',
  );
  @override
  late final GeneratedColumn<DateTime> baslangic = GeneratedColumn<DateTime>(
    'baslangic',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [hedefId, baslangic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kronometre_kayitlari';
  @override
  VerificationContext validateIntegrity(
    Insertable<KronometreKayitlariData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hedef_id')) {
      context.handle(
        _hedefIdMeta,
        hedefId.isAcceptableOrUnknown(data['hedef_id']!, _hedefIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hedefIdMeta);
    }
    if (data.containsKey('baslangic')) {
      context.handle(
        _baslangicMeta,
        baslangic.isAcceptableOrUnknown(data['baslangic']!, _baslangicMeta),
      );
    } else if (isInserting) {
      context.missing(_baslangicMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hedefId};
  @override
  KronometreKayitlariData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KronometreKayitlariData(
      hedefId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hedef_id'],
      )!,
      baslangic: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}baslangic'],
      )!,
    );
  }

  @override
  $KronometreKayitlariTable createAlias(String alias) {
    return $KronometreKayitlariTable(attachedDatabase, alias);
  }
}

class KronometreKayitlariData extends DataClass
    implements Insertable<KronometreKayitlariData> {
  /// Item id (Raf) or habit id (minute-based Sayac).
  final String hedefId;
  final DateTime baslangic;
  const KronometreKayitlariData({
    required this.hedefId,
    required this.baslangic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hedef_id'] = Variable<String>(hedefId);
    map['baslangic'] = Variable<DateTime>(baslangic);
    return map;
  }

  KronometreKayitlariCompanion toCompanion(bool nullToAbsent) {
    return KronometreKayitlariCompanion(
      hedefId: Value(hedefId),
      baslangic: Value(baslangic),
    );
  }

  factory KronometreKayitlariData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KronometreKayitlariData(
      hedefId: serializer.fromJson<String>(json['hedefId']),
      baslangic: serializer.fromJson<DateTime>(json['baslangic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hedefId': serializer.toJson<String>(hedefId),
      'baslangic': serializer.toJson<DateTime>(baslangic),
    };
  }

  KronometreKayitlariData copyWith({String? hedefId, DateTime? baslangic}) =>
      KronometreKayitlariData(
        hedefId: hedefId ?? this.hedefId,
        baslangic: baslangic ?? this.baslangic,
      );
  KronometreKayitlariData copyWithCompanion(KronometreKayitlariCompanion data) {
    return KronometreKayitlariData(
      hedefId: data.hedefId.present ? data.hedefId.value : this.hedefId,
      baslangic: data.baslangic.present ? data.baslangic.value : this.baslangic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KronometreKayitlariData(')
          ..write('hedefId: $hedefId, ')
          ..write('baslangic: $baslangic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hedefId, baslangic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KronometreKayitlariData &&
          other.hedefId == this.hedefId &&
          other.baslangic == this.baslangic);
}

class KronometreKayitlariCompanion
    extends UpdateCompanion<KronometreKayitlariData> {
  final Value<String> hedefId;
  final Value<DateTime> baslangic;
  final Value<int> rowid;
  const KronometreKayitlariCompanion({
    this.hedefId = const Value.absent(),
    this.baslangic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KronometreKayitlariCompanion.insert({
    required String hedefId,
    required DateTime baslangic,
    this.rowid = const Value.absent(),
  }) : hedefId = Value(hedefId),
       baslangic = Value(baslangic);
  static Insertable<KronometreKayitlariData> custom({
    Expression<String>? hedefId,
    Expression<DateTime>? baslangic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hedefId != null) 'hedef_id': hedefId,
      if (baslangic != null) 'baslangic': baslangic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KronometreKayitlariCompanion copyWith({
    Value<String>? hedefId,
    Value<DateTime>? baslangic,
    Value<int>? rowid,
  }) {
    return KronometreKayitlariCompanion(
      hedefId: hedefId ?? this.hedefId,
      baslangic: baslangic ?? this.baslangic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hedefId.present) {
      map['hedef_id'] = Variable<String>(hedefId.value);
    }
    if (baslangic.present) {
      map['baslangic'] = Variable<DateTime>(baslangic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KronometreKayitlariCompanion(')
          ..write('hedefId: $hedefId, ')
          ..write('baslangic: $baslangic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $YakalamaOnbellekTable extends YakalamaOnbellek
    with TableInfo<$YakalamaOnbellekTable, YakalamaOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $YakalamaOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siraMeta = const VerificationMeta('sira');
  @override
  late final GeneratedColumn<int> sira = GeneratedColumn<int>(
    'sira',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sira, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'yakalama_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<YakalamaOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sira')) {
      context.handle(
        _siraMeta,
        sira.isAcceptableOrUnknown(data['sira']!, _siraMeta),
      );
    } else if (isInserting) {
      context.missing(_siraMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  YakalamaOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return YakalamaOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sira: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sira'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $YakalamaOnbellekTable createAlias(String alias) {
    return $YakalamaOnbellekTable(attachedDatabase, alias);
  }
}

class YakalamaOnbellekData extends DataClass
    implements Insertable<YakalamaOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const YakalamaOnbellekData({
    required this.id,
    required this.sira,
    required this.govde,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sira'] = Variable<int>(sira);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  YakalamaOnbellekCompanion toCompanion(bool nullToAbsent) {
    return YakalamaOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory YakalamaOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return YakalamaOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      sira: serializer.fromJson<int>(json['sira']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sira': serializer.toJson<int>(sira),
      'govde': serializer.toJson<String>(govde),
    };
  }

  YakalamaOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      YakalamaOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  YakalamaOnbellekData copyWithCompanion(YakalamaOnbellekCompanion data) {
    return YakalamaOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('YakalamaOnbellekData(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sira, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YakalamaOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class YakalamaOnbellekCompanion extends UpdateCompanion<YakalamaOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const YakalamaOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  YakalamaOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<YakalamaOnbellekData> custom({
    Expression<String>? id,
    Expression<int>? sira,
    Expression<String>? govde,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sira != null) 'sira': sira,
      if (govde != null) 'govde': govde,
      if (rowid != null) 'rowid': rowid,
    });
  }

  YakalamaOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return YakalamaOnbellekCompanion(
      id: id ?? this.id,
      sira: sira ?? this.sira,
      govde: govde ?? this.govde,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sira.present) {
      map['sira'] = Variable<int>(sira.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('YakalamaOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjeOnbellekTable extends ProjeOnbellek
    with TableInfo<$ProjeOnbellekTable, ProjeOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjeOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siraMeta = const VerificationMeta('sira');
  @override
  late final GeneratedColumn<int> sira = GeneratedColumn<int>(
    'sira',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sira, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proje_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjeOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sira')) {
      context.handle(
        _siraMeta,
        sira.isAcceptableOrUnknown(data['sira']!, _siraMeta),
      );
    } else if (isInserting) {
      context.missing(_siraMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjeOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjeOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sira: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sira'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $ProjeOnbellekTable createAlias(String alias) {
    return $ProjeOnbellekTable(attachedDatabase, alias);
  }
}

class ProjeOnbellekData extends DataClass
    implements Insertable<ProjeOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const ProjeOnbellekData({
    required this.id,
    required this.sira,
    required this.govde,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sira'] = Variable<int>(sira);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  ProjeOnbellekCompanion toCompanion(bool nullToAbsent) {
    return ProjeOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory ProjeOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjeOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      sira: serializer.fromJson<int>(json['sira']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sira': serializer.toJson<int>(sira),
      'govde': serializer.toJson<String>(govde),
    };
  }

  ProjeOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      ProjeOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  ProjeOnbellekData copyWithCompanion(ProjeOnbellekCompanion data) {
    return ProjeOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjeOnbellekData(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sira, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjeOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class ProjeOnbellekCompanion extends UpdateCompanion<ProjeOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const ProjeOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjeOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<ProjeOnbellekData> custom({
    Expression<String>? id,
    Expression<int>? sira,
    Expression<String>? govde,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sira != null) 'sira': sira,
      if (govde != null) 'govde': govde,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjeOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return ProjeOnbellekCompanion(
      id: id ?? this.id,
      sira: sira ?? this.sira,
      govde: govde ?? this.govde,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sira.present) {
      map['sira'] = Variable<int>(sira.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjeOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HatirlaticiOnbellekTable extends HatirlaticiOnbellek
    with TableInfo<$HatirlaticiOnbellekTable, HatirlaticiOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HatirlaticiOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siraMeta = const VerificationMeta('sira');
  @override
  late final GeneratedColumn<int> sira = GeneratedColumn<int>(
    'sira',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sira, govde];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hatirlatici_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<HatirlaticiOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sira')) {
      context.handle(
        _siraMeta,
        sira.isAcceptableOrUnknown(data['sira']!, _siraMeta),
      );
    } else if (isInserting) {
      context.missing(_siraMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HatirlaticiOnbellekData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HatirlaticiOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sira: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sira'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
    );
  }

  @override
  $HatirlaticiOnbellekTable createAlias(String alias) {
    return $HatirlaticiOnbellekTable(attachedDatabase, alias);
  }
}

class HatirlaticiOnbellekData extends DataClass
    implements Insertable<HatirlaticiOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const HatirlaticiOnbellekData({
    required this.id,
    required this.sira,
    required this.govde,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sira'] = Variable<int>(sira);
    map['govde'] = Variable<String>(govde);
    return map;
  }

  HatirlaticiOnbellekCompanion toCompanion(bool nullToAbsent) {
    return HatirlaticiOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory HatirlaticiOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HatirlaticiOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      sira: serializer.fromJson<int>(json['sira']),
      govde: serializer.fromJson<String>(json['govde']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sira': serializer.toJson<int>(sira),
      'govde': serializer.toJson<String>(govde),
    };
  }

  HatirlaticiOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      HatirlaticiOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  HatirlaticiOnbellekData copyWithCompanion(HatirlaticiOnbellekCompanion data) {
    return HatirlaticiOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HatirlaticiOnbellekData(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sira, govde);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HatirlaticiOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class HatirlaticiOnbellekCompanion
    extends UpdateCompanion<HatirlaticiOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const HatirlaticiOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HatirlaticiOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<HatirlaticiOnbellekData> custom({
    Expression<String>? id,
    Expression<int>? sira,
    Expression<String>? govde,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sira != null) 'sira': sira,
      if (govde != null) 'govde': govde,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HatirlaticiOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return HatirlaticiOnbellekCompanion(
      id: id ?? this.id,
      sira: sira ?? this.sira,
      govde: govde ?? this.govde,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sira.present) {
      map['sira'] = Variable<int>(sira.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HatirlaticiOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EylemOnbellekTable extends EylemOnbellek
    with TableInfo<$EylemOnbellekTable, EylemOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EylemOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siraMeta = const VerificationMeta('sira');
  @override
  late final GeneratedColumn<int> sira = GeneratedColumn<int>(
    'sira',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bildirildiMeta = const VerificationMeta(
    'bildirildi',
  );
  @override
  late final GeneratedColumn<bool> bildirildi = GeneratedColumn<bool>(
    'bildirildi',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bildirildi" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, sira, govde, bildirildi];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eylem_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<EylemOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sira')) {
      context.handle(
        _siraMeta,
        sira.isAcceptableOrUnknown(data['sira']!, _siraMeta),
      );
    } else if (isInserting) {
      context.missing(_siraMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    if (data.containsKey('bildirildi')) {
      context.handle(
        _bildirildiMeta,
        bildirildi.isAcceptableOrUnknown(data['bildirildi']!, _bildirildiMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EylemOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EylemOnbellekData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sira: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sira'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
      bildirildi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bildirildi'],
      )!,
    );
  }

  @override
  $EylemOnbellekTable createAlias(String alias) {
    return $EylemOnbellekTable(attachedDatabase, alias);
  }
}

class EylemOnbellekData extends DataClass
    implements Insertable<EylemOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  final bool bildirildi;
  const EylemOnbellekData({
    required this.id,
    required this.sira,
    required this.govde,
    required this.bildirildi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sira'] = Variable<int>(sira);
    map['govde'] = Variable<String>(govde);
    map['bildirildi'] = Variable<bool>(bildirildi);
    return map;
  }

  EylemOnbellekCompanion toCompanion(bool nullToAbsent) {
    return EylemOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
      bildirildi: Value(bildirildi),
    );
  }

  factory EylemOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EylemOnbellekData(
      id: serializer.fromJson<String>(json['id']),
      sira: serializer.fromJson<int>(json['sira']),
      govde: serializer.fromJson<String>(json['govde']),
      bildirildi: serializer.fromJson<bool>(json['bildirildi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sira': serializer.toJson<int>(sira),
      'govde': serializer.toJson<String>(govde),
      'bildirildi': serializer.toJson<bool>(bildirildi),
    };
  }

  EylemOnbellekData copyWith({
    String? id,
    int? sira,
    String? govde,
    bool? bildirildi,
  }) => EylemOnbellekData(
    id: id ?? this.id,
    sira: sira ?? this.sira,
    govde: govde ?? this.govde,
    bildirildi: bildirildi ?? this.bildirildi,
  );
  EylemOnbellekData copyWithCompanion(EylemOnbellekCompanion data) {
    return EylemOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
      bildirildi: data.bildirildi.present
          ? data.bildirildi.value
          : this.bildirildi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EylemOnbellekData(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('bildirildi: $bildirildi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sira, govde, bildirildi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EylemOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde &&
          other.bildirildi == this.bildirildi);
}

class EylemOnbellekCompanion extends UpdateCompanion<EylemOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<bool> bildirildi;
  final Value<int> rowid;
  const EylemOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.bildirildi = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EylemOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.bildirildi = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<EylemOnbellekData> custom({
    Expression<String>? id,
    Expression<int>? sira,
    Expression<String>? govde,
    Expression<bool>? bildirildi,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sira != null) 'sira': sira,
      if (govde != null) 'govde': govde,
      if (bildirildi != null) 'bildirildi': bildirildi,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EylemOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<bool>? bildirildi,
    Value<int>? rowid,
  }) {
    return EylemOnbellekCompanion(
      id: id ?? this.id,
      sira: sira ?? this.sira,
      govde: govde ?? this.govde,
      bildirildi: bildirildi ?? this.bildirildi,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sira.present) {
      map['sira'] = Variable<int>(sira.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (bildirildi.present) {
      map['bildirildi'] = Variable<bool>(bildirildi.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EylemOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('bildirildi: $bildirildi, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GunPlaniOnbellekTable extends GunPlaniOnbellek
    with TableInfo<$GunPlaniOnbellekTable, GunPlaniOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GunPlaniOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tarihMeta = const VerificationMeta('tarih');
  @override
  late final GeneratedColumn<String> tarih = GeneratedColumn<String>(
    'tarih',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _govdeMeta = const VerificationMeta('govde');
  @override
  late final GeneratedColumn<String> govde = GeneratedColumn<String>(
    'govde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _okunmaMeta = const VerificationMeta('okunma');
  @override
  late final GeneratedColumn<DateTime> okunma = GeneratedColumn<DateTime>(
    'okunma',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tarih, govde, okunma];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gun_plani_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<GunPlaniOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tarih')) {
      context.handle(
        _tarihMeta,
        tarih.isAcceptableOrUnknown(data['tarih']!, _tarihMeta),
      );
    } else if (isInserting) {
      context.missing(_tarihMeta);
    }
    if (data.containsKey('govde')) {
      context.handle(
        _govdeMeta,
        govde.isAcceptableOrUnknown(data['govde']!, _govdeMeta),
      );
    } else if (isInserting) {
      context.missing(_govdeMeta);
    }
    if (data.containsKey('okunma')) {
      context.handle(
        _okunmaMeta,
        okunma.isAcceptableOrUnknown(data['okunma']!, _okunmaMeta),
      );
    } else if (isInserting) {
      context.missing(_okunmaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tarih};
  @override
  GunPlaniOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GunPlaniOnbellekData(
      tarih: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tarih'],
      )!,
      govde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}govde'],
      )!,
      okunma: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}okunma'],
      )!,
    );
  }

  @override
  $GunPlaniOnbellekTable createAlias(String alias) {
    return $GunPlaniOnbellekTable(attachedDatabase, alias);
  }
}

class GunPlaniOnbellekData extends DataClass
    implements Insertable<GunPlaniOnbellekData> {
  /// "2026-11-03".
  final String tarih;
  final String govde;
  final DateTime okunma;
  const GunPlaniOnbellekData({
    required this.tarih,
    required this.govde,
    required this.okunma,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tarih'] = Variable<String>(tarih);
    map['govde'] = Variable<String>(govde);
    map['okunma'] = Variable<DateTime>(okunma);
    return map;
  }

  GunPlaniOnbellekCompanion toCompanion(bool nullToAbsent) {
    return GunPlaniOnbellekCompanion(
      tarih: Value(tarih),
      govde: Value(govde),
      okunma: Value(okunma),
    );
  }

  factory GunPlaniOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GunPlaniOnbellekData(
      tarih: serializer.fromJson<String>(json['tarih']),
      govde: serializer.fromJson<String>(json['govde']),
      okunma: serializer.fromJson<DateTime>(json['okunma']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tarih': serializer.toJson<String>(tarih),
      'govde': serializer.toJson<String>(govde),
      'okunma': serializer.toJson<DateTime>(okunma),
    };
  }

  GunPlaniOnbellekData copyWith({
    String? tarih,
    String? govde,
    DateTime? okunma,
  }) => GunPlaniOnbellekData(
    tarih: tarih ?? this.tarih,
    govde: govde ?? this.govde,
    okunma: okunma ?? this.okunma,
  );
  GunPlaniOnbellekData copyWithCompanion(GunPlaniOnbellekCompanion data) {
    return GunPlaniOnbellekData(
      tarih: data.tarih.present ? data.tarih.value : this.tarih,
      govde: data.govde.present ? data.govde.value : this.govde,
      okunma: data.okunma.present ? data.okunma.value : this.okunma,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GunPlaniOnbellekData(')
          ..write('tarih: $tarih, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tarih, govde, okunma);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GunPlaniOnbellekData &&
          other.tarih == this.tarih &&
          other.govde == this.govde &&
          other.okunma == this.okunma);
}

class GunPlaniOnbellekCompanion extends UpdateCompanion<GunPlaniOnbellekData> {
  final Value<String> tarih;
  final Value<String> govde;
  final Value<DateTime> okunma;
  final Value<int> rowid;
  const GunPlaniOnbellekCompanion({
    this.tarih = const Value.absent(),
    this.govde = const Value.absent(),
    this.okunma = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GunPlaniOnbellekCompanion.insert({
    required String tarih,
    required String govde,
    required DateTime okunma,
    this.rowid = const Value.absent(),
  }) : tarih = Value(tarih),
       govde = Value(govde),
       okunma = Value(okunma);
  static Insertable<GunPlaniOnbellekData> custom({
    Expression<String>? tarih,
    Expression<String>? govde,
    Expression<DateTime>? okunma,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tarih != null) 'tarih': tarih,
      if (govde != null) 'govde': govde,
      if (okunma != null) 'okunma': okunma,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GunPlaniOnbellekCompanion copyWith({
    Value<String>? tarih,
    Value<String>? govde,
    Value<DateTime>? okunma,
    Value<int>? rowid,
  }) {
    return GunPlaniOnbellekCompanion(
      tarih: tarih ?? this.tarih,
      govde: govde ?? this.govde,
      okunma: okunma ?? this.okunma,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tarih.present) {
      map['tarih'] = Variable<String>(tarih.value);
    }
    if (govde.present) {
      map['govde'] = Variable<String>(govde.value);
    }
    if (okunma.present) {
      map['okunma'] = Variable<DateTime>(okunma.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GunPlaniOnbellekCompanion(')
          ..write('tarih: $tarih, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SabahBirakilanlarTable extends SabahBirakilanlar
    with TableInfo<$SabahBirakilanlarTable, SabahBirakilanlarData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SabahBirakilanlarTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tarihMeta = const VerificationMeta('tarih');
  @override
  late final GeneratedColumn<String> tarih = GeneratedColumn<String>(
    'tarih',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tarih];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sabah_birakilanlar';
  @override
  VerificationContext validateIntegrity(
    Insertable<SabahBirakilanlarData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tarih')) {
      context.handle(
        _tarihMeta,
        tarih.isAcceptableOrUnknown(data['tarih']!, _tarihMeta),
      );
    } else if (isInserting) {
      context.missing(_tarihMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, tarih};
  @override
  SabahBirakilanlarData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SabahBirakilanlarData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tarih: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tarih'],
      )!,
    );
  }

  @override
  $SabahBirakilanlarTable createAlias(String alias) {
    return $SabahBirakilanlarTable(attachedDatabase, alias);
  }
}

class SabahBirakilanlarData extends DataClass
    implements Insertable<SabahBirakilanlarData> {
  final String id;
  final String tarih;
  const SabahBirakilanlarData({required this.id, required this.tarih});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tarih'] = Variable<String>(tarih);
    return map;
  }

  SabahBirakilanlarCompanion toCompanion(bool nullToAbsent) {
    return SabahBirakilanlarCompanion(id: Value(id), tarih: Value(tarih));
  }

  factory SabahBirakilanlarData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SabahBirakilanlarData(
      id: serializer.fromJson<String>(json['id']),
      tarih: serializer.fromJson<String>(json['tarih']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tarih': serializer.toJson<String>(tarih),
    };
  }

  SabahBirakilanlarData copyWith({String? id, String? tarih}) =>
      SabahBirakilanlarData(id: id ?? this.id, tarih: tarih ?? this.tarih);
  SabahBirakilanlarData copyWithCompanion(SabahBirakilanlarCompanion data) {
    return SabahBirakilanlarData(
      id: data.id.present ? data.id.value : this.id,
      tarih: data.tarih.present ? data.tarih.value : this.tarih,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SabahBirakilanlarData(')
          ..write('id: $id, ')
          ..write('tarih: $tarih')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tarih);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SabahBirakilanlarData &&
          other.id == this.id &&
          other.tarih == this.tarih);
}

class SabahBirakilanlarCompanion
    extends UpdateCompanion<SabahBirakilanlarData> {
  final Value<String> id;
  final Value<String> tarih;
  final Value<int> rowid;
  const SabahBirakilanlarCompanion({
    this.id = const Value.absent(),
    this.tarih = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SabahBirakilanlarCompanion.insert({
    required String id,
    required String tarih,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tarih = Value(tarih);
  static Insertable<SabahBirakilanlarData> custom({
    Expression<String>? id,
    Expression<String>? tarih,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tarih != null) 'tarih': tarih,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SabahBirakilanlarCompanion copyWith({
    Value<String>? id,
    Value<String>? tarih,
    Value<int>? rowid,
  }) {
    return SabahBirakilanlarCompanion(
      id: id ?? this.id,
      tarih: tarih ?? this.tarih,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tarih.present) {
      map['tarih'] = Variable<String>(tarih.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SabahBirakilanlarCompanion(')
          ..write('id: $id, ')
          ..write('tarih: $tarih, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AliskanlikOnbellekTable aliskanlikOnbellek =
      $AliskanlikOnbellekTable(this);
  late final $OgeOnbellekTable ogeOnbellek = $OgeOnbellekTable(this);
  late final $BekleyenIslemlerTable bekleyenIslemler = $BekleyenIslemlerTable(
    this,
  );
  late final $KullaniciOnbellekTable kullaniciOnbellek =
      $KullaniciOnbellekTable(this);
  late final $KronometreKayitlariTable kronometreKayitlari =
      $KronometreKayitlariTable(this);
  late final $YakalamaOnbellekTable yakalamaOnbellek = $YakalamaOnbellekTable(
    this,
  );
  late final $ProjeOnbellekTable projeOnbellek = $ProjeOnbellekTable(this);
  late final $HatirlaticiOnbellekTable hatirlaticiOnbellek =
      $HatirlaticiOnbellekTable(this);
  late final $EylemOnbellekTable eylemOnbellek = $EylemOnbellekTable(this);
  late final $GunPlaniOnbellekTable gunPlaniOnbellek = $GunPlaniOnbellekTable(
    this,
  );
  late final $SabahBirakilanlarTable sabahBirakilanlar =
      $SabahBirakilanlarTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aliskanlikOnbellek,
    ogeOnbellek,
    bekleyenIslemler,
    kullaniciOnbellek,
    kronometreKayitlari,
    yakalamaOnbellek,
    projeOnbellek,
    hatirlaticiOnbellek,
    eylemOnbellek,
    gunPlaniOnbellek,
    sabahBirakilanlar,
  ];
}

typedef $$AliskanlikOnbellekTableCreateCompanionBuilder =
    AliskanlikOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$AliskanlikOnbellekTableUpdateCompanionBuilder =
    AliskanlikOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$AliskanlikOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $AliskanlikOnbellekTable> {
  $$AliskanlikOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AliskanlikOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $AliskanlikOnbellekTable> {
  $$AliskanlikOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AliskanlikOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $AliskanlikOnbellekTable> {
  $$AliskanlikOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sira =>
      $composableBuilder(column: $table.sira, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$AliskanlikOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AliskanlikOnbellekTable,
          AliskanlikOnbellekData,
          $$AliskanlikOnbellekTableFilterComposer,
          $$AliskanlikOnbellekTableOrderingComposer,
          $$AliskanlikOnbellekTableAnnotationComposer,
          $$AliskanlikOnbellekTableCreateCompanionBuilder,
          $$AliskanlikOnbellekTableUpdateCompanionBuilder,
          (
            AliskanlikOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $AliskanlikOnbellekTable,
              AliskanlikOnbellekData
            >,
          ),
          AliskanlikOnbellekData,
          PrefetchHooks Function()
        > {
  $$AliskanlikOnbellekTableTableManager(
    _$AppDatabase db,
    $AliskanlikOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AliskanlikOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AliskanlikOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AliskanlikOnbellekTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AliskanlikOnbellekCompanion(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sira,
                required String govde,
                Value<int> rowid = const Value.absent(),
              }) => AliskanlikOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AliskanlikOnbellekTable, AliskanlikOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AliskanlikOnbellekTable,
                    AliskanlikOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AliskanlikOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AliskanlikOnbellekTable,
      AliskanlikOnbellekData,
      $$AliskanlikOnbellekTableFilterComposer,
      $$AliskanlikOnbellekTableOrderingComposer,
      $$AliskanlikOnbellekTableAnnotationComposer,
      $$AliskanlikOnbellekTableCreateCompanionBuilder,
      $$AliskanlikOnbellekTableUpdateCompanionBuilder,
      (
        AliskanlikOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $AliskanlikOnbellekTable,
          AliskanlikOnbellekData
        >,
      ),
      AliskanlikOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$OgeOnbellekTableCreateCompanionBuilder =
    OgeOnbellekCompanion Function({
      required String id,
      required String aliskanlikId,
      required String govde,
      Value<int> rowid,
    });
typedef $$OgeOnbellekTableUpdateCompanionBuilder =
    OgeOnbellekCompanion Function({
      Value<String> id,
      Value<String> aliskanlikId,
      Value<String> govde,
      Value<int> rowid,
    });

class $$OgeOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $OgeOnbellekTable> {
  $$OgeOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliskanlikId => $composableBuilder(
    column: $table.aliskanlikId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OgeOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $OgeOnbellekTable> {
  $$OgeOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliskanlikId => $composableBuilder(
    column: $table.aliskanlikId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OgeOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $OgeOnbellekTable> {
  $$OgeOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get aliskanlikId => $composableBuilder(
    column: $table.aliskanlikId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$OgeOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OgeOnbellekTable,
          OgeOnbellekData,
          $$OgeOnbellekTableFilterComposer,
          $$OgeOnbellekTableOrderingComposer,
          $$OgeOnbellekTableAnnotationComposer,
          $$OgeOnbellekTableCreateCompanionBuilder,
          $$OgeOnbellekTableUpdateCompanionBuilder,
          (
            OgeOnbellekData,
            BaseReferences<_$AppDatabase, $OgeOnbellekTable, OgeOnbellekData>,
          ),
          OgeOnbellekData,
          PrefetchHooks Function()
        > {
  $$OgeOnbellekTableTableManager(_$AppDatabase db, $OgeOnbellekTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OgeOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OgeOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OgeOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> aliskanlikId = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OgeOnbellekCompanion(
                id: id,
                aliskanlikId: aliskanlikId,
                govde: govde,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String aliskanlikId,
                required String govde,
                Value<int> rowid = const Value.absent(),
              }) => OgeOnbellekCompanion.insert(
                id: id,
                aliskanlikId: aliskanlikId,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OgeOnbellekTable, OgeOnbellekData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OgeOnbellekTable,
                    OgeOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OgeOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OgeOnbellekTable,
      OgeOnbellekData,
      $$OgeOnbellekTableFilterComposer,
      $$OgeOnbellekTableOrderingComposer,
      $$OgeOnbellekTableAnnotationComposer,
      $$OgeOnbellekTableCreateCompanionBuilder,
      $$OgeOnbellekTableUpdateCompanionBuilder,
      (
        OgeOnbellekData,
        BaseReferences<_$AppDatabase, $OgeOnbellekTable, OgeOnbellekData>,
      ),
      OgeOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$BekleyenIslemlerTableCreateCompanionBuilder =
    BekleyenIslemlerCompanion Function({
      required String id,
      required BekleyenTur tur,
      required String hedefId,
      Value<String?> tarih,
      required String govde,
      required DateTime olusturulma,
      Value<bool> gonderildi,
      Value<String?> hata,
      Value<String?> uyari,
      Value<int> rowid,
    });
typedef $$BekleyenIslemlerTableUpdateCompanionBuilder =
    BekleyenIslemlerCompanion Function({
      Value<String> id,
      Value<BekleyenTur> tur,
      Value<String> hedefId,
      Value<String?> tarih,
      Value<String> govde,
      Value<DateTime> olusturulma,
      Value<bool> gonderildi,
      Value<String?> hata,
      Value<String?> uyari,
      Value<int> rowid,
    });

class $$BekleyenIslemlerTableFilterComposer
    extends Composer<_$AppDatabase, $BekleyenIslemlerTable> {
  $$BekleyenIslemlerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BekleyenTur, BekleyenTur, int> get tur =>
      $composableBuilder(
        column: $table.tur,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get hedefId => $composableBuilder(
    column: $table.hedefId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get olusturulma => $composableBuilder(
    column: $table.olusturulma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get gonderildi => $composableBuilder(
    column: $table.gonderildi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hata => $composableBuilder(
    column: $table.hata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uyari => $composableBuilder(
    column: $table.uyari,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BekleyenIslemlerTableOrderingComposer
    extends Composer<_$AppDatabase, $BekleyenIslemlerTable> {
  $$BekleyenIslemlerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tur => $composableBuilder(
    column: $table.tur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hedefId => $composableBuilder(
    column: $table.hedefId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get olusturulma => $composableBuilder(
    column: $table.olusturulma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get gonderildi => $composableBuilder(
    column: $table.gonderildi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hata => $composableBuilder(
    column: $table.hata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uyari => $composableBuilder(
    column: $table.uyari,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BekleyenIslemlerTableAnnotationComposer
    extends Composer<_$AppDatabase, $BekleyenIslemlerTable> {
  $$BekleyenIslemlerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BekleyenTur, int> get tur =>
      $composableBuilder(column: $table.tur, builder: (column) => column);

  GeneratedColumn<String> get hedefId =>
      $composableBuilder(column: $table.hedefId, builder: (column) => column);

  GeneratedColumn<String> get tarih =>
      $composableBuilder(column: $table.tarih, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);

  GeneratedColumn<DateTime> get olusturulma => $composableBuilder(
    column: $table.olusturulma,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get gonderildi => $composableBuilder(
    column: $table.gonderildi,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hata =>
      $composableBuilder(column: $table.hata, builder: (column) => column);

  GeneratedColumn<String> get uyari =>
      $composableBuilder(column: $table.uyari, builder: (column) => column);
}

class $$BekleyenIslemlerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BekleyenIslemlerTable,
          BekleyenIslemlerData,
          $$BekleyenIslemlerTableFilterComposer,
          $$BekleyenIslemlerTableOrderingComposer,
          $$BekleyenIslemlerTableAnnotationComposer,
          $$BekleyenIslemlerTableCreateCompanionBuilder,
          $$BekleyenIslemlerTableUpdateCompanionBuilder,
          (
            BekleyenIslemlerData,
            BaseReferences<
              _$AppDatabase,
              $BekleyenIslemlerTable,
              BekleyenIslemlerData
            >,
          ),
          BekleyenIslemlerData,
          PrefetchHooks Function()
        > {
  $$BekleyenIslemlerTableTableManager(
    _$AppDatabase db,
    $BekleyenIslemlerTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BekleyenIslemlerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BekleyenIslemlerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BekleyenIslemlerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<BekleyenTur> tur = const Value.absent(),
                Value<String> hedefId = const Value.absent(),
                Value<String?> tarih = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<DateTime> olusturulma = const Value.absent(),
                Value<bool> gonderildi = const Value.absent(),
                Value<String?> hata = const Value.absent(),
                Value<String?> uyari = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BekleyenIslemlerCompanion(
                id: id,
                tur: tur,
                hedefId: hedefId,
                tarih: tarih,
                govde: govde,
                olusturulma: olusturulma,
                gonderildi: gonderildi,
                hata: hata,
                uyari: uyari,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required BekleyenTur tur,
                required String hedefId,
                Value<String?> tarih = const Value.absent(),
                required String govde,
                required DateTime olusturulma,
                Value<bool> gonderildi = const Value.absent(),
                Value<String?> hata = const Value.absent(),
                Value<String?> uyari = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BekleyenIslemlerCompanion.insert(
                id: id,
                tur: tur,
                hedefId: hedefId,
                tarih: tarih,
                govde: govde,
                olusturulma: olusturulma,
                gonderildi: gonderildi,
                hata: hata,
                uyari: uyari,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BekleyenIslemlerTable, BekleyenIslemlerData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BekleyenIslemlerTable,
                    BekleyenIslemlerData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BekleyenIslemlerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BekleyenIslemlerTable,
      BekleyenIslemlerData,
      $$BekleyenIslemlerTableFilterComposer,
      $$BekleyenIslemlerTableOrderingComposer,
      $$BekleyenIslemlerTableAnnotationComposer,
      $$BekleyenIslemlerTableCreateCompanionBuilder,
      $$BekleyenIslemlerTableUpdateCompanionBuilder,
      (
        BekleyenIslemlerData,
        BaseReferences<
          _$AppDatabase,
          $BekleyenIslemlerTable,
          BekleyenIslemlerData
        >,
      ),
      BekleyenIslemlerData,
      PrefetchHooks Function()
    >;
typedef $$KullaniciOnbellekTableCreateCompanionBuilder =
    KullaniciOnbellekCompanion Function({Value<int> id, required String govde});
typedef $$KullaniciOnbellekTableUpdateCompanionBuilder =
    KullaniciOnbellekCompanion Function({Value<int> id, Value<String> govde});

class $$KullaniciOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $KullaniciOnbellekTable> {
  $$KullaniciOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KullaniciOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $KullaniciOnbellekTable> {
  $$KullaniciOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KullaniciOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $KullaniciOnbellekTable> {
  $$KullaniciOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$KullaniciOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KullaniciOnbellekTable,
          KullaniciOnbellekData,
          $$KullaniciOnbellekTableFilterComposer,
          $$KullaniciOnbellekTableOrderingComposer,
          $$KullaniciOnbellekTableAnnotationComposer,
          $$KullaniciOnbellekTableCreateCompanionBuilder,
          $$KullaniciOnbellekTableUpdateCompanionBuilder,
          (
            KullaniciOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $KullaniciOnbellekTable,
              KullaniciOnbellekData
            >,
          ),
          KullaniciOnbellekData,
          PrefetchHooks Function()
        > {
  $$KullaniciOnbellekTableTableManager(
    _$AppDatabase db,
    $KullaniciOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KullaniciOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KullaniciOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KullaniciOnbellekTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> govde = const Value.absent(),
          }) => KullaniciOnbellekCompanion(id: id, govde: govde),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String govde,
          }) => KullaniciOnbellekCompanion.insert(id: id, govde: govde),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KullaniciOnbellekTable, KullaniciOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $KullaniciOnbellekTable,
                    KullaniciOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KullaniciOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KullaniciOnbellekTable,
      KullaniciOnbellekData,
      $$KullaniciOnbellekTableFilterComposer,
      $$KullaniciOnbellekTableOrderingComposer,
      $$KullaniciOnbellekTableAnnotationComposer,
      $$KullaniciOnbellekTableCreateCompanionBuilder,
      $$KullaniciOnbellekTableUpdateCompanionBuilder,
      (
        KullaniciOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $KullaniciOnbellekTable,
          KullaniciOnbellekData
        >,
      ),
      KullaniciOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$KronometreKayitlariTableCreateCompanionBuilder =
    KronometreKayitlariCompanion Function({
      required String hedefId,
      required DateTime baslangic,
      Value<int> rowid,
    });
typedef $$KronometreKayitlariTableUpdateCompanionBuilder =
    KronometreKayitlariCompanion Function({
      Value<String> hedefId,
      Value<DateTime> baslangic,
      Value<int> rowid,
    });

class $$KronometreKayitlariTableFilterComposer
    extends Composer<_$AppDatabase, $KronometreKayitlariTable> {
  $$KronometreKayitlariTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hedefId => $composableBuilder(
    column: $table.hedefId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get baslangic => $composableBuilder(
    column: $table.baslangic,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KronometreKayitlariTableOrderingComposer
    extends Composer<_$AppDatabase, $KronometreKayitlariTable> {
  $$KronometreKayitlariTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hedefId => $composableBuilder(
    column: $table.hedefId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get baslangic => $composableBuilder(
    column: $table.baslangic,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KronometreKayitlariTableAnnotationComposer
    extends Composer<_$AppDatabase, $KronometreKayitlariTable> {
  $$KronometreKayitlariTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hedefId =>
      $composableBuilder(column: $table.hedefId, builder: (column) => column);

  GeneratedColumn<DateTime> get baslangic =>
      $composableBuilder(column: $table.baslangic, builder: (column) => column);
}

class $$KronometreKayitlariTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KronometreKayitlariTable,
          KronometreKayitlariData,
          $$KronometreKayitlariTableFilterComposer,
          $$KronometreKayitlariTableOrderingComposer,
          $$KronometreKayitlariTableAnnotationComposer,
          $$KronometreKayitlariTableCreateCompanionBuilder,
          $$KronometreKayitlariTableUpdateCompanionBuilder,
          (
            KronometreKayitlariData,
            BaseReferences<
              _$AppDatabase,
              $KronometreKayitlariTable,
              KronometreKayitlariData
            >,
          ),
          KronometreKayitlariData,
          PrefetchHooks Function()
        > {
  $$KronometreKayitlariTableTableManager(
    _$AppDatabase db,
    $KronometreKayitlariTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KronometreKayitlariTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KronometreKayitlariTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$KronometreKayitlariTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> hedefId = const Value.absent(),
                Value<DateTime> baslangic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KronometreKayitlariCompanion(
                hedefId: hedefId,
                baslangic: baslangic,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hedefId,
                required DateTime baslangic,
                Value<int> rowid = const Value.absent(),
              }) => KronometreKayitlariCompanion.insert(
                hedefId: hedefId,
                baslangic: baslangic,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $KronometreKayitlariTable,
                    KronometreKayitlariData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $KronometreKayitlariTable,
                    KronometreKayitlariData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KronometreKayitlariTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KronometreKayitlariTable,
      KronometreKayitlariData,
      $$KronometreKayitlariTableFilterComposer,
      $$KronometreKayitlariTableOrderingComposer,
      $$KronometreKayitlariTableAnnotationComposer,
      $$KronometreKayitlariTableCreateCompanionBuilder,
      $$KronometreKayitlariTableUpdateCompanionBuilder,
      (
        KronometreKayitlariData,
        BaseReferences<
          _$AppDatabase,
          $KronometreKayitlariTable,
          KronometreKayitlariData
        >,
      ),
      KronometreKayitlariData,
      PrefetchHooks Function()
    >;
typedef $$YakalamaOnbellekTableCreateCompanionBuilder =
    YakalamaOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$YakalamaOnbellekTableUpdateCompanionBuilder =
    YakalamaOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$YakalamaOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $YakalamaOnbellekTable> {
  $$YakalamaOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$YakalamaOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $YakalamaOnbellekTable> {
  $$YakalamaOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$YakalamaOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $YakalamaOnbellekTable> {
  $$YakalamaOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sira =>
      $composableBuilder(column: $table.sira, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$YakalamaOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $YakalamaOnbellekTable,
          YakalamaOnbellekData,
          $$YakalamaOnbellekTableFilterComposer,
          $$YakalamaOnbellekTableOrderingComposer,
          $$YakalamaOnbellekTableAnnotationComposer,
          $$YakalamaOnbellekTableCreateCompanionBuilder,
          $$YakalamaOnbellekTableUpdateCompanionBuilder,
          (
            YakalamaOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $YakalamaOnbellekTable,
              YakalamaOnbellekData
            >,
          ),
          YakalamaOnbellekData,
          PrefetchHooks Function()
        > {
  $$YakalamaOnbellekTableTableManager(
    _$AppDatabase db,
    $YakalamaOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$YakalamaOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$YakalamaOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$YakalamaOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => YakalamaOnbellekCompanion(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sira,
                required String govde,
                Value<int> rowid = const Value.absent(),
              }) => YakalamaOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$YakalamaOnbellekTable, YakalamaOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $YakalamaOnbellekTable,
                    YakalamaOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$YakalamaOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $YakalamaOnbellekTable,
      YakalamaOnbellekData,
      $$YakalamaOnbellekTableFilterComposer,
      $$YakalamaOnbellekTableOrderingComposer,
      $$YakalamaOnbellekTableAnnotationComposer,
      $$YakalamaOnbellekTableCreateCompanionBuilder,
      $$YakalamaOnbellekTableUpdateCompanionBuilder,
      (
        YakalamaOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $YakalamaOnbellekTable,
          YakalamaOnbellekData
        >,
      ),
      YakalamaOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$ProjeOnbellekTableCreateCompanionBuilder =
    ProjeOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$ProjeOnbellekTableUpdateCompanionBuilder =
    ProjeOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$ProjeOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $ProjeOnbellekTable> {
  $$ProjeOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjeOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjeOnbellekTable> {
  $$ProjeOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjeOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjeOnbellekTable> {
  $$ProjeOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sira =>
      $composableBuilder(column: $table.sira, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$ProjeOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjeOnbellekTable,
          ProjeOnbellekData,
          $$ProjeOnbellekTableFilterComposer,
          $$ProjeOnbellekTableOrderingComposer,
          $$ProjeOnbellekTableAnnotationComposer,
          $$ProjeOnbellekTableCreateCompanionBuilder,
          $$ProjeOnbellekTableUpdateCompanionBuilder,
          (
            ProjeOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $ProjeOnbellekTable,
              ProjeOnbellekData
            >,
          ),
          ProjeOnbellekData,
          PrefetchHooks Function()
        > {
  $$ProjeOnbellekTableTableManager(_$AppDatabase db, $ProjeOnbellekTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjeOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjeOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjeOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjeOnbellekCompanion(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sira,
                required String govde,
                Value<int> rowid = const Value.absent(),
              }) => ProjeOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjeOnbellekTable, ProjeOnbellekData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProjeOnbellekTable,
                    ProjeOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjeOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjeOnbellekTable,
      ProjeOnbellekData,
      $$ProjeOnbellekTableFilterComposer,
      $$ProjeOnbellekTableOrderingComposer,
      $$ProjeOnbellekTableAnnotationComposer,
      $$ProjeOnbellekTableCreateCompanionBuilder,
      $$ProjeOnbellekTableUpdateCompanionBuilder,
      (
        ProjeOnbellekData,
        BaseReferences<_$AppDatabase, $ProjeOnbellekTable, ProjeOnbellekData>,
      ),
      ProjeOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$HatirlaticiOnbellekTableCreateCompanionBuilder =
    HatirlaticiOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$HatirlaticiOnbellekTableUpdateCompanionBuilder =
    HatirlaticiOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$HatirlaticiOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $HatirlaticiOnbellekTable> {
  $$HatirlaticiOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HatirlaticiOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $HatirlaticiOnbellekTable> {
  $$HatirlaticiOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HatirlaticiOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $HatirlaticiOnbellekTable> {
  $$HatirlaticiOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sira =>
      $composableBuilder(column: $table.sira, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);
}

class $$HatirlaticiOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HatirlaticiOnbellekTable,
          HatirlaticiOnbellekData,
          $$HatirlaticiOnbellekTableFilterComposer,
          $$HatirlaticiOnbellekTableOrderingComposer,
          $$HatirlaticiOnbellekTableAnnotationComposer,
          $$HatirlaticiOnbellekTableCreateCompanionBuilder,
          $$HatirlaticiOnbellekTableUpdateCompanionBuilder,
          (
            HatirlaticiOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $HatirlaticiOnbellekTable,
              HatirlaticiOnbellekData
            >,
          ),
          HatirlaticiOnbellekData,
          PrefetchHooks Function()
        > {
  $$HatirlaticiOnbellekTableTableManager(
    _$AppDatabase db,
    $HatirlaticiOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HatirlaticiOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HatirlaticiOnbellekTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HatirlaticiOnbellekTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HatirlaticiOnbellekCompanion(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sira,
                required String govde,
                Value<int> rowid = const Value.absent(),
              }) => HatirlaticiOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $HatirlaticiOnbellekTable,
                    HatirlaticiOnbellekData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HatirlaticiOnbellekTable,
                    HatirlaticiOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HatirlaticiOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HatirlaticiOnbellekTable,
      HatirlaticiOnbellekData,
      $$HatirlaticiOnbellekTableFilterComposer,
      $$HatirlaticiOnbellekTableOrderingComposer,
      $$HatirlaticiOnbellekTableAnnotationComposer,
      $$HatirlaticiOnbellekTableCreateCompanionBuilder,
      $$HatirlaticiOnbellekTableUpdateCompanionBuilder,
      (
        HatirlaticiOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $HatirlaticiOnbellekTable,
          HatirlaticiOnbellekData
        >,
      ),
      HatirlaticiOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$EylemOnbellekTableCreateCompanionBuilder =
    EylemOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<bool> bildirildi,
      Value<int> rowid,
    });
typedef $$EylemOnbellekTableUpdateCompanionBuilder =
    EylemOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<bool> bildirildi,
      Value<int> rowid,
    });

class $$EylemOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $EylemOnbellekTable> {
  $$EylemOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bildirildi => $composableBuilder(
    column: $table.bildirildi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EylemOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $EylemOnbellekTable> {
  $$EylemOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sira => $composableBuilder(
    column: $table.sira,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bildirildi => $composableBuilder(
    column: $table.bildirildi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EylemOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $EylemOnbellekTable> {
  $$EylemOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sira =>
      $composableBuilder(column: $table.sira, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);

  GeneratedColumn<bool> get bildirildi => $composableBuilder(
    column: $table.bildirildi,
    builder: (column) => column,
  );
}

class $$EylemOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EylemOnbellekTable,
          EylemOnbellekData,
          $$EylemOnbellekTableFilterComposer,
          $$EylemOnbellekTableOrderingComposer,
          $$EylemOnbellekTableAnnotationComposer,
          $$EylemOnbellekTableCreateCompanionBuilder,
          $$EylemOnbellekTableUpdateCompanionBuilder,
          (
            EylemOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $EylemOnbellekTable,
              EylemOnbellekData
            >,
          ),
          EylemOnbellekData,
          PrefetchHooks Function()
        > {
  $$EylemOnbellekTableTableManager(_$AppDatabase db, $EylemOnbellekTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EylemOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EylemOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EylemOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<bool> bildirildi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EylemOnbellekCompanion(
                id: id,
                sira: sira,
                govde: govde,
                bildirildi: bildirildi,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sira,
                required String govde,
                Value<bool> bildirildi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EylemOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                bildirildi: bildirildi,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EylemOnbellekTable, EylemOnbellekData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EylemOnbellekTable,
                    EylemOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EylemOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EylemOnbellekTable,
      EylemOnbellekData,
      $$EylemOnbellekTableFilterComposer,
      $$EylemOnbellekTableOrderingComposer,
      $$EylemOnbellekTableAnnotationComposer,
      $$EylemOnbellekTableCreateCompanionBuilder,
      $$EylemOnbellekTableUpdateCompanionBuilder,
      (
        EylemOnbellekData,
        BaseReferences<_$AppDatabase, $EylemOnbellekTable, EylemOnbellekData>,
      ),
      EylemOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$GunPlaniOnbellekTableCreateCompanionBuilder =
    GunPlaniOnbellekCompanion Function({
      required String tarih,
      required String govde,
      required DateTime okunma,
      Value<int> rowid,
    });
typedef $$GunPlaniOnbellekTableUpdateCompanionBuilder =
    GunPlaniOnbellekCompanion Function({
      Value<String> tarih,
      Value<String> govde,
      Value<DateTime> okunma,
      Value<int> rowid,
    });

class $$GunPlaniOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $GunPlaniOnbellekTable> {
  $$GunPlaniOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get okunma => $composableBuilder(
    column: $table.okunma,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GunPlaniOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $GunPlaniOnbellekTable> {
  $$GunPlaniOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get govde => $composableBuilder(
    column: $table.govde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get okunma => $composableBuilder(
    column: $table.okunma,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GunPlaniOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $GunPlaniOnbellekTable> {
  $$GunPlaniOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tarih =>
      $composableBuilder(column: $table.tarih, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);

  GeneratedColumn<DateTime> get okunma =>
      $composableBuilder(column: $table.okunma, builder: (column) => column);
}

class $$GunPlaniOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GunPlaniOnbellekTable,
          GunPlaniOnbellekData,
          $$GunPlaniOnbellekTableFilterComposer,
          $$GunPlaniOnbellekTableOrderingComposer,
          $$GunPlaniOnbellekTableAnnotationComposer,
          $$GunPlaniOnbellekTableCreateCompanionBuilder,
          $$GunPlaniOnbellekTableUpdateCompanionBuilder,
          (
            GunPlaniOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $GunPlaniOnbellekTable,
              GunPlaniOnbellekData
            >,
          ),
          GunPlaniOnbellekData,
          PrefetchHooks Function()
        > {
  $$GunPlaniOnbellekTableTableManager(
    _$AppDatabase db,
    $GunPlaniOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GunPlaniOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GunPlaniOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GunPlaniOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tarih = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<DateTime> okunma = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GunPlaniOnbellekCompanion(
                tarih: tarih,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tarih,
                required String govde,
                required DateTime okunma,
                Value<int> rowid = const Value.absent(),
              }) => GunPlaniOnbellekCompanion.insert(
                tarih: tarih,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GunPlaniOnbellekTable, GunPlaniOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $GunPlaniOnbellekTable,
                    GunPlaniOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GunPlaniOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GunPlaniOnbellekTable,
      GunPlaniOnbellekData,
      $$GunPlaniOnbellekTableFilterComposer,
      $$GunPlaniOnbellekTableOrderingComposer,
      $$GunPlaniOnbellekTableAnnotationComposer,
      $$GunPlaniOnbellekTableCreateCompanionBuilder,
      $$GunPlaniOnbellekTableUpdateCompanionBuilder,
      (
        GunPlaniOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $GunPlaniOnbellekTable,
          GunPlaniOnbellekData
        >,
      ),
      GunPlaniOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$SabahBirakilanlarTableCreateCompanionBuilder =
    SabahBirakilanlarCompanion Function({
      required String id,
      required String tarih,
      Value<int> rowid,
    });
typedef $$SabahBirakilanlarTableUpdateCompanionBuilder =
    SabahBirakilanlarCompanion Function({
      Value<String> id,
      Value<String> tarih,
      Value<int> rowid,
    });

class $$SabahBirakilanlarTableFilterComposer
    extends Composer<_$AppDatabase, $SabahBirakilanlarTable> {
  $$SabahBirakilanlarTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SabahBirakilanlarTableOrderingComposer
    extends Composer<_$AppDatabase, $SabahBirakilanlarTable> {
  $$SabahBirakilanlarTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tarih => $composableBuilder(
    column: $table.tarih,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SabahBirakilanlarTableAnnotationComposer
    extends Composer<_$AppDatabase, $SabahBirakilanlarTable> {
  $$SabahBirakilanlarTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tarih =>
      $composableBuilder(column: $table.tarih, builder: (column) => column);
}

class $$SabahBirakilanlarTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SabahBirakilanlarTable,
          SabahBirakilanlarData,
          $$SabahBirakilanlarTableFilterComposer,
          $$SabahBirakilanlarTableOrderingComposer,
          $$SabahBirakilanlarTableAnnotationComposer,
          $$SabahBirakilanlarTableCreateCompanionBuilder,
          $$SabahBirakilanlarTableUpdateCompanionBuilder,
          (
            SabahBirakilanlarData,
            BaseReferences<
              _$AppDatabase,
              $SabahBirakilanlarTable,
              SabahBirakilanlarData
            >,
          ),
          SabahBirakilanlarData,
          PrefetchHooks Function()
        > {
  $$SabahBirakilanlarTableTableManager(
    _$AppDatabase db,
    $SabahBirakilanlarTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SabahBirakilanlarTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SabahBirakilanlarTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SabahBirakilanlarTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tarih = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SabahBirakilanlarCompanion(id: id, tarih: tarih, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String tarih,
                Value<int> rowid = const Value.absent(),
              }) => SabahBirakilanlarCompanion.insert(
                id: id,
                tarih: tarih,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SabahBirakilanlarTable, SabahBirakilanlarData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SabahBirakilanlarTable,
                    SabahBirakilanlarData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SabahBirakilanlarTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SabahBirakilanlarTable,
      SabahBirakilanlarData,
      $$SabahBirakilanlarTableFilterComposer,
      $$SabahBirakilanlarTableOrderingComposer,
      $$SabahBirakilanlarTableAnnotationComposer,
      $$SabahBirakilanlarTableCreateCompanionBuilder,
      $$SabahBirakilanlarTableUpdateCompanionBuilder,
      (
        SabahBirakilanlarData,
        BaseReferences<
          _$AppDatabase,
          $SabahBirakilanlarTable,
          SabahBirakilanlarData
        >,
      ),
      SabahBirakilanlarData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AliskanlikOnbellekTableTableManager get aliskanlikOnbellek =>
      $$AliskanlikOnbellekTableTableManager(_db, _db.aliskanlikOnbellek);
  $$OgeOnbellekTableTableManager get ogeOnbellek =>
      $$OgeOnbellekTableTableManager(_db, _db.ogeOnbellek);
  $$BekleyenIslemlerTableTableManager get bekleyenIslemler =>
      $$BekleyenIslemlerTableTableManager(_db, _db.bekleyenIslemler);
  $$KullaniciOnbellekTableTableManager get kullaniciOnbellek =>
      $$KullaniciOnbellekTableTableManager(_db, _db.kullaniciOnbellek);
  $$KronometreKayitlariTableTableManager get kronometreKayitlari =>
      $$KronometreKayitlariTableTableManager(_db, _db.kronometreKayitlari);
  $$YakalamaOnbellekTableTableManager get yakalamaOnbellek =>
      $$YakalamaOnbellekTableTableManager(_db, _db.yakalamaOnbellek);
  $$ProjeOnbellekTableTableManager get projeOnbellek =>
      $$ProjeOnbellekTableTableManager(_db, _db.projeOnbellek);
  $$HatirlaticiOnbellekTableTableManager get hatirlaticiOnbellek =>
      $$HatirlaticiOnbellekTableTableManager(_db, _db.hatirlaticiOnbellek);
  $$EylemOnbellekTableTableManager get eylemOnbellek =>
      $$EylemOnbellekTableTableManager(_db, _db.eylemOnbellek);
  $$GunPlaniOnbellekTableTableManager get gunPlaniOnbellek =>
      $$GunPlaniOnbellekTableTableManager(_db, _db.gunPlaniOnbellek);
  $$SabahBirakilanlarTableTableManager get sabahBirakilanlar =>
      $$SabahBirakilanlarTableTableManager(_db, _db.sabahBirakilanlar);
}
