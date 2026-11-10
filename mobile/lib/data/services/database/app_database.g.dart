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

class $GelenOnbellekTable extends GelenOnbellek
    with TableInfo<$GelenOnbellekTable, GelenOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GelenOnbellekTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'gelen_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<GelenOnbellekData> instance, {
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
  GelenOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GelenOnbellekData(
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
  $GelenOnbellekTable createAlias(String alias) {
    return $GelenOnbellekTable(attachedDatabase, alias);
  }
}

class GelenOnbellekData extends DataClass
    implements Insertable<GelenOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const GelenOnbellekData({
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

  GelenOnbellekCompanion toCompanion(bool nullToAbsent) {
    return GelenOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory GelenOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GelenOnbellekData(
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

  GelenOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      GelenOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  GelenOnbellekData copyWithCompanion(GelenOnbellekCompanion data) {
    return GelenOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GelenOnbellekData(')
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
      (other is GelenOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class GelenOnbellekCompanion extends UpdateCompanion<GelenOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const GelenOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GelenOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<GelenOnbellekData> custom({
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

  GelenOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return GelenOnbellekCompanion(
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
    return (StringBuffer('GelenOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrifingOnbellekTable extends BrifingOnbellek
    with TableInfo<$BrifingOnbellekTable, BrifingOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrifingOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gunMeta = const VerificationMeta('gun');
  @override
  late final GeneratedColumn<String> gun = GeneratedColumn<String>(
    'gun',
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
  List<GeneratedColumn> get $columns => [gun, govde, okunma];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brifing_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrifingOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gun')) {
      context.handle(
        _gunMeta,
        gun.isAcceptableOrUnknown(data['gun']!, _gunMeta),
      );
    } else if (isInserting) {
      context.missing(_gunMeta);
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
  Set<GeneratedColumn> get $primaryKey => {gun};
  @override
  BrifingOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrifingOnbellekData(
      gun: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gun'],
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
  $BrifingOnbellekTable createAlias(String alias) {
    return $BrifingOnbellekTable(attachedDatabase, alias);
  }
}

class BrifingOnbellekData extends DataClass
    implements Insertable<BrifingOnbellekData> {
  /// "2026-11-07".
  final String gun;
  final String govde;
  final DateTime okunma;
  const BrifingOnbellekData({
    required this.gun,
    required this.govde,
    required this.okunma,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gun'] = Variable<String>(gun);
    map['govde'] = Variable<String>(govde);
    map['okunma'] = Variable<DateTime>(okunma);
    return map;
  }

  BrifingOnbellekCompanion toCompanion(bool nullToAbsent) {
    return BrifingOnbellekCompanion(
      gun: Value(gun),
      govde: Value(govde),
      okunma: Value(okunma),
    );
  }

  factory BrifingOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrifingOnbellekData(
      gun: serializer.fromJson<String>(json['gun']),
      govde: serializer.fromJson<String>(json['govde']),
      okunma: serializer.fromJson<DateTime>(json['okunma']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gun': serializer.toJson<String>(gun),
      'govde': serializer.toJson<String>(govde),
      'okunma': serializer.toJson<DateTime>(okunma),
    };
  }

  BrifingOnbellekData copyWith({
    String? gun,
    String? govde,
    DateTime? okunma,
  }) => BrifingOnbellekData(
    gun: gun ?? this.gun,
    govde: govde ?? this.govde,
    okunma: okunma ?? this.okunma,
  );
  BrifingOnbellekData copyWithCompanion(BrifingOnbellekCompanion data) {
    return BrifingOnbellekData(
      gun: data.gun.present ? data.gun.value : this.gun,
      govde: data.govde.present ? data.govde.value : this.govde,
      okunma: data.okunma.present ? data.okunma.value : this.okunma,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrifingOnbellekData(')
          ..write('gun: $gun, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gun, govde, okunma);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrifingOnbellekData &&
          other.gun == this.gun &&
          other.govde == this.govde &&
          other.okunma == this.okunma);
}

class BrifingOnbellekCompanion extends UpdateCompanion<BrifingOnbellekData> {
  final Value<String> gun;
  final Value<String> govde;
  final Value<DateTime> okunma;
  final Value<int> rowid;
  const BrifingOnbellekCompanion({
    this.gun = const Value.absent(),
    this.govde = const Value.absent(),
    this.okunma = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrifingOnbellekCompanion.insert({
    required String gun,
    required String govde,
    required DateTime okunma,
    this.rowid = const Value.absent(),
  }) : gun = Value(gun),
       govde = Value(govde),
       okunma = Value(okunma);
  static Insertable<BrifingOnbellekData> custom({
    Expression<String>? gun,
    Expression<String>? govde,
    Expression<DateTime>? okunma,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gun != null) 'gun': gun,
      if (govde != null) 'govde': govde,
      if (okunma != null) 'okunma': okunma,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrifingOnbellekCompanion copyWith({
    Value<String>? gun,
    Value<String>? govde,
    Value<DateTime>? okunma,
    Value<int>? rowid,
  }) {
    return BrifingOnbellekCompanion(
      gun: gun ?? this.gun,
      govde: govde ?? this.govde,
      okunma: okunma ?? this.okunma,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gun.present) {
      map['gun'] = Variable<String>(gun.value);
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
    return (StringBuffer('BrifingOnbellekCompanion(')
          ..write('gun: $gun, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AyarKayitlariTable extends AyarKayitlari
    with TableInfo<$AyarKayitlariTable, AyarKayitlariData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AyarKayitlariTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anahtarMeta = const VerificationMeta(
    'anahtar',
  );
  @override
  late final GeneratedColumn<String> anahtar = GeneratedColumn<String>(
    'anahtar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _degerMeta = const VerificationMeta('deger');
  @override
  late final GeneratedColumn<String> deger = GeneratedColumn<String>(
    'deger',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [anahtar, deger];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ayar_kayitlari';
  @override
  VerificationContext validateIntegrity(
    Insertable<AyarKayitlariData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anahtar')) {
      context.handle(
        _anahtarMeta,
        anahtar.isAcceptableOrUnknown(data['anahtar']!, _anahtarMeta),
      );
    } else if (isInserting) {
      context.missing(_anahtarMeta);
    }
    if (data.containsKey('deger')) {
      context.handle(
        _degerMeta,
        deger.isAcceptableOrUnknown(data['deger']!, _degerMeta),
      );
    } else if (isInserting) {
      context.missing(_degerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anahtar};
  @override
  AyarKayitlariData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AyarKayitlariData(
      anahtar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anahtar'],
      )!,
      deger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deger'],
      )!,
    );
  }

  @override
  $AyarKayitlariTable createAlias(String alias) {
    return $AyarKayitlariTable(attachedDatabase, alias);
  }
}

class AyarKayitlariData extends DataClass
    implements Insertable<AyarKayitlariData> {
  final String anahtar;
  final String deger;
  const AyarKayitlariData({required this.anahtar, required this.deger});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anahtar'] = Variable<String>(anahtar);
    map['deger'] = Variable<String>(deger);
    return map;
  }

  AyarKayitlariCompanion toCompanion(bool nullToAbsent) {
    return AyarKayitlariCompanion(anahtar: Value(anahtar), deger: Value(deger));
  }

  factory AyarKayitlariData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AyarKayitlariData(
      anahtar: serializer.fromJson<String>(json['anahtar']),
      deger: serializer.fromJson<String>(json['deger']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anahtar': serializer.toJson<String>(anahtar),
      'deger': serializer.toJson<String>(deger),
    };
  }

  AyarKayitlariData copyWith({String? anahtar, String? deger}) =>
      AyarKayitlariData(
        anahtar: anahtar ?? this.anahtar,
        deger: deger ?? this.deger,
      );
  AyarKayitlariData copyWithCompanion(AyarKayitlariCompanion data) {
    return AyarKayitlariData(
      anahtar: data.anahtar.present ? data.anahtar.value : this.anahtar,
      deger: data.deger.present ? data.deger.value : this.deger,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AyarKayitlariData(')
          ..write('anahtar: $anahtar, ')
          ..write('deger: $deger')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(anahtar, deger);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AyarKayitlariData &&
          other.anahtar == this.anahtar &&
          other.deger == this.deger);
}

class AyarKayitlariCompanion extends UpdateCompanion<AyarKayitlariData> {
  final Value<String> anahtar;
  final Value<String> deger;
  final Value<int> rowid;
  const AyarKayitlariCompanion({
    this.anahtar = const Value.absent(),
    this.deger = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AyarKayitlariCompanion.insert({
    required String anahtar,
    required String deger,
    this.rowid = const Value.absent(),
  }) : anahtar = Value(anahtar),
       deger = Value(deger);
  static Insertable<AyarKayitlariData> custom({
    Expression<String>? anahtar,
    Expression<String>? deger,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anahtar != null) 'anahtar': anahtar,
      if (deger != null) 'deger': deger,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AyarKayitlariCompanion copyWith({
    Value<String>? anahtar,
    Value<String>? deger,
    Value<int>? rowid,
  }) {
    return AyarKayitlariCompanion(
      anahtar: anahtar ?? this.anahtar,
      deger: deger ?? this.deger,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anahtar.present) {
      map['anahtar'] = Variable<String>(anahtar.value);
    }
    if (deger.present) {
      map['deger'] = Variable<String>(deger.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AyarKayitlariCompanion(')
          ..write('anahtar: $anahtar, ')
          ..write('deger: $deger, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GunGorunumOnbellekTable extends GunGorunumOnbellek
    with TableInfo<$GunGorunumOnbellekTable, GunGorunumOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GunGorunumOnbellekTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'gun_gorunum_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<GunGorunumOnbellekData> instance, {
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
  GunGorunumOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GunGorunumOnbellekData(
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
  $GunGorunumOnbellekTable createAlias(String alias) {
    return $GunGorunumOnbellekTable(attachedDatabase, alias);
  }
}

class GunGorunumOnbellekData extends DataClass
    implements Insertable<GunGorunumOnbellekData> {
  /// "2026-11-10".
  final String tarih;
  final String govde;
  final DateTime okunma;
  const GunGorunumOnbellekData({
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

  GunGorunumOnbellekCompanion toCompanion(bool nullToAbsent) {
    return GunGorunumOnbellekCompanion(
      tarih: Value(tarih),
      govde: Value(govde),
      okunma: Value(okunma),
    );
  }

  factory GunGorunumOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GunGorunumOnbellekData(
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

  GunGorunumOnbellekData copyWith({
    String? tarih,
    String? govde,
    DateTime? okunma,
  }) => GunGorunumOnbellekData(
    tarih: tarih ?? this.tarih,
    govde: govde ?? this.govde,
    okunma: okunma ?? this.okunma,
  );
  GunGorunumOnbellekData copyWithCompanion(GunGorunumOnbellekCompanion data) {
    return GunGorunumOnbellekData(
      tarih: data.tarih.present ? data.tarih.value : this.tarih,
      govde: data.govde.present ? data.govde.value : this.govde,
      okunma: data.okunma.present ? data.okunma.value : this.okunma,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GunGorunumOnbellekData(')
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
      (other is GunGorunumOnbellekData &&
          other.tarih == this.tarih &&
          other.govde == this.govde &&
          other.okunma == this.okunma);
}

class GunGorunumOnbellekCompanion
    extends UpdateCompanion<GunGorunumOnbellekData> {
  final Value<String> tarih;
  final Value<String> govde;
  final Value<DateTime> okunma;
  final Value<int> rowid;
  const GunGorunumOnbellekCompanion({
    this.tarih = const Value.absent(),
    this.govde = const Value.absent(),
    this.okunma = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GunGorunumOnbellekCompanion.insert({
    required String tarih,
    required String govde,
    required DateTime okunma,
    this.rowid = const Value.absent(),
  }) : tarih = Value(tarih),
       govde = Value(govde),
       okunma = Value(okunma);
  static Insertable<GunGorunumOnbellekData> custom({
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

  GunGorunumOnbellekCompanion copyWith({
    Value<String>? tarih,
    Value<String>? govde,
    Value<DateTime>? okunma,
    Value<int>? rowid,
  }) {
    return GunGorunumOnbellekCompanion(
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
    return (StringBuffer('GunGorunumOnbellekCompanion(')
          ..write('tarih: $tarih, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TakvimOnbellekTable extends TakvimOnbellek
    with TableInfo<$TakvimOnbellekTable, TakvimOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TakvimOnbellekTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _aralikMeta = const VerificationMeta('aralik');
  @override
  late final GeneratedColumn<String> aralik = GeneratedColumn<String>(
    'aralik',
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
  List<GeneratedColumn> get $columns => [aralik, govde, okunma];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'takvim_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<TakvimOnbellekData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('aralik')) {
      context.handle(
        _aralikMeta,
        aralik.isAcceptableOrUnknown(data['aralik']!, _aralikMeta),
      );
    } else if (isInserting) {
      context.missing(_aralikMeta);
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
  Set<GeneratedColumn> get $primaryKey => {aralik};
  @override
  TakvimOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TakvimOnbellekData(
      aralik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aralik'],
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
  $TakvimOnbellekTable createAlias(String alias) {
    return $TakvimOnbellekTable(attachedDatabase, alias);
  }
}

class TakvimOnbellekData extends DataClass
    implements Insertable<TakvimOnbellekData> {
  final String aralik;
  final String govde;
  final DateTime okunma;
  const TakvimOnbellekData({
    required this.aralik,
    required this.govde,
    required this.okunma,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['aralik'] = Variable<String>(aralik);
    map['govde'] = Variable<String>(govde);
    map['okunma'] = Variable<DateTime>(okunma);
    return map;
  }

  TakvimOnbellekCompanion toCompanion(bool nullToAbsent) {
    return TakvimOnbellekCompanion(
      aralik: Value(aralik),
      govde: Value(govde),
      okunma: Value(okunma),
    );
  }

  factory TakvimOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TakvimOnbellekData(
      aralik: serializer.fromJson<String>(json['aralik']),
      govde: serializer.fromJson<String>(json['govde']),
      okunma: serializer.fromJson<DateTime>(json['okunma']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'aralik': serializer.toJson<String>(aralik),
      'govde': serializer.toJson<String>(govde),
      'okunma': serializer.toJson<DateTime>(okunma),
    };
  }

  TakvimOnbellekData copyWith({
    String? aralik,
    String? govde,
    DateTime? okunma,
  }) => TakvimOnbellekData(
    aralik: aralik ?? this.aralik,
    govde: govde ?? this.govde,
    okunma: okunma ?? this.okunma,
  );
  TakvimOnbellekData copyWithCompanion(TakvimOnbellekCompanion data) {
    return TakvimOnbellekData(
      aralik: data.aralik.present ? data.aralik.value : this.aralik,
      govde: data.govde.present ? data.govde.value : this.govde,
      okunma: data.okunma.present ? data.okunma.value : this.okunma,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TakvimOnbellekData(')
          ..write('aralik: $aralik, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(aralik, govde, okunma);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TakvimOnbellekData &&
          other.aralik == this.aralik &&
          other.govde == this.govde &&
          other.okunma == this.okunma);
}

class TakvimOnbellekCompanion extends UpdateCompanion<TakvimOnbellekData> {
  final Value<String> aralik;
  final Value<String> govde;
  final Value<DateTime> okunma;
  final Value<int> rowid;
  const TakvimOnbellekCompanion({
    this.aralik = const Value.absent(),
    this.govde = const Value.absent(),
    this.okunma = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TakvimOnbellekCompanion.insert({
    required String aralik,
    required String govde,
    required DateTime okunma,
    this.rowid = const Value.absent(),
  }) : aralik = Value(aralik),
       govde = Value(govde),
       okunma = Value(okunma);
  static Insertable<TakvimOnbellekData> custom({
    Expression<String>? aralik,
    Expression<String>? govde,
    Expression<DateTime>? okunma,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (aralik != null) 'aralik': aralik,
      if (govde != null) 'govde': govde,
      if (okunma != null) 'okunma': okunma,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TakvimOnbellekCompanion copyWith({
    Value<String>? aralik,
    Value<String>? govde,
    Value<DateTime>? okunma,
    Value<int>? rowid,
  }) {
    return TakvimOnbellekCompanion(
      aralik: aralik ?? this.aralik,
      govde: govde ?? this.govde,
      okunma: okunma ?? this.okunma,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (aralik.present) {
      map['aralik'] = Variable<String>(aralik.value);
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
    return (StringBuffer('TakvimOnbellekCompanion(')
          ..write('aralik: $aralik, ')
          ..write('govde: $govde, ')
          ..write('okunma: $okunma, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AsistanAkisOnbellekTable extends AsistanAkisOnbellek
    with TableInfo<$AsistanAkisOnbellekTable, AsistanAkisOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AsistanAkisOnbellekTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'asistan_akis_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<AsistanAkisOnbellekData> instance, {
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
  AsistanAkisOnbellekData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AsistanAkisOnbellekData(
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
  $AsistanAkisOnbellekTable createAlias(String alias) {
    return $AsistanAkisOnbellekTable(attachedDatabase, alias);
  }
}

class AsistanAkisOnbellekData extends DataClass
    implements Insertable<AsistanAkisOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const AsistanAkisOnbellekData({
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

  AsistanAkisOnbellekCompanion toCompanion(bool nullToAbsent) {
    return AsistanAkisOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory AsistanAkisOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AsistanAkisOnbellekData(
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

  AsistanAkisOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      AsistanAkisOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  AsistanAkisOnbellekData copyWithCompanion(AsistanAkisOnbellekCompanion data) {
    return AsistanAkisOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AsistanAkisOnbellekData(')
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
      (other is AsistanAkisOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class AsistanAkisOnbellekCompanion
    extends UpdateCompanion<AsistanAkisOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const AsistanAkisOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AsistanAkisOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<AsistanAkisOnbellekData> custom({
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

  AsistanAkisOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return AsistanAkisOnbellekCompanion(
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
    return (StringBuffer('AsistanAkisOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BildirimOnbellekTable extends BildirimOnbellek
    with TableInfo<$BildirimOnbellekTable, BildirimOnbellekData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BildirimOnbellekTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'bildirim_onbellek';
  @override
  VerificationContext validateIntegrity(
    Insertable<BildirimOnbellekData> instance, {
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
  BildirimOnbellekData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BildirimOnbellekData(
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
  $BildirimOnbellekTable createAlias(String alias) {
    return $BildirimOnbellekTable(attachedDatabase, alias);
  }
}

class BildirimOnbellekData extends DataClass
    implements Insertable<BildirimOnbellekData> {
  final String id;
  final int sira;
  final String govde;
  const BildirimOnbellekData({
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

  BildirimOnbellekCompanion toCompanion(bool nullToAbsent) {
    return BildirimOnbellekCompanion(
      id: Value(id),
      sira: Value(sira),
      govde: Value(govde),
    );
  }

  factory BildirimOnbellekData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BildirimOnbellekData(
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

  BildirimOnbellekData copyWith({String? id, int? sira, String? govde}) =>
      BildirimOnbellekData(
        id: id ?? this.id,
        sira: sira ?? this.sira,
        govde: govde ?? this.govde,
      );
  BildirimOnbellekData copyWithCompanion(BildirimOnbellekCompanion data) {
    return BildirimOnbellekData(
      id: data.id.present ? data.id.value : this.id,
      sira: data.sira.present ? data.sira.value : this.sira,
      govde: data.govde.present ? data.govde.value : this.govde,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BildirimOnbellekData(')
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
      (other is BildirimOnbellekData &&
          other.id == this.id &&
          other.sira == this.sira &&
          other.govde == this.govde);
}

class BildirimOnbellekCompanion extends UpdateCompanion<BildirimOnbellekData> {
  final Value<String> id;
  final Value<int> sira;
  final Value<String> govde;
  final Value<int> rowid;
  const BildirimOnbellekCompanion({
    this.id = const Value.absent(),
    this.sira = const Value.absent(),
    this.govde = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BildirimOnbellekCompanion.insert({
    required String id,
    required int sira,
    required String govde,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sira = Value(sira),
       govde = Value(govde);
  static Insertable<BildirimOnbellekData> custom({
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

  BildirimOnbellekCompanion copyWith({
    Value<String>? id,
    Value<int>? sira,
    Value<String>? govde,
    Value<int>? rowid,
  }) {
    return BildirimOnbellekCompanion(
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
    return (StringBuffer('BildirimOnbellekCompanion(')
          ..write('id: $id, ')
          ..write('sira: $sira, ')
          ..write('govde: $govde, ')
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
  late final $GelenOnbellekTable gelenOnbellek = $GelenOnbellekTable(this);
  late final $BrifingOnbellekTable brifingOnbellek = $BrifingOnbellekTable(
    this,
  );
  late final $AyarKayitlariTable ayarKayitlari = $AyarKayitlariTable(this);
  late final $GunGorunumOnbellekTable gunGorunumOnbellek =
      $GunGorunumOnbellekTable(this);
  late final $TakvimOnbellekTable takvimOnbellek = $TakvimOnbellekTable(this);
  late final $AsistanAkisOnbellekTable asistanAkisOnbellek =
      $AsistanAkisOnbellekTable(this);
  late final $BildirimOnbellekTable bildirimOnbellek = $BildirimOnbellekTable(
    this,
  );
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
    gelenOnbellek,
    brifingOnbellek,
    ayarKayitlari,
    gunGorunumOnbellek,
    takvimOnbellek,
    asistanAkisOnbellek,
    bildirimOnbellek,
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
typedef $$GelenOnbellekTableCreateCompanionBuilder =
    GelenOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$GelenOnbellekTableUpdateCompanionBuilder =
    GelenOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$GelenOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $GelenOnbellekTable> {
  $$GelenOnbellekTableFilterComposer({
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

class $$GelenOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $GelenOnbellekTable> {
  $$GelenOnbellekTableOrderingComposer({
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

class $$GelenOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $GelenOnbellekTable> {
  $$GelenOnbellekTableAnnotationComposer({
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

class $$GelenOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GelenOnbellekTable,
          GelenOnbellekData,
          $$GelenOnbellekTableFilterComposer,
          $$GelenOnbellekTableOrderingComposer,
          $$GelenOnbellekTableAnnotationComposer,
          $$GelenOnbellekTableCreateCompanionBuilder,
          $$GelenOnbellekTableUpdateCompanionBuilder,
          (
            GelenOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $GelenOnbellekTable,
              GelenOnbellekData
            >,
          ),
          GelenOnbellekData,
          PrefetchHooks Function()
        > {
  $$GelenOnbellekTableTableManager(_$AppDatabase db, $GelenOnbellekTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GelenOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GelenOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GelenOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GelenOnbellekCompanion(
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
              }) => GelenOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GelenOnbellekTable, GelenOnbellekData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GelenOnbellekTable,
                    GelenOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GelenOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GelenOnbellekTable,
      GelenOnbellekData,
      $$GelenOnbellekTableFilterComposer,
      $$GelenOnbellekTableOrderingComposer,
      $$GelenOnbellekTableAnnotationComposer,
      $$GelenOnbellekTableCreateCompanionBuilder,
      $$GelenOnbellekTableUpdateCompanionBuilder,
      (
        GelenOnbellekData,
        BaseReferences<_$AppDatabase, $GelenOnbellekTable, GelenOnbellekData>,
      ),
      GelenOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$BrifingOnbellekTableCreateCompanionBuilder =
    BrifingOnbellekCompanion Function({
      required String gun,
      required String govde,
      required DateTime okunma,
      Value<int> rowid,
    });
typedef $$BrifingOnbellekTableUpdateCompanionBuilder =
    BrifingOnbellekCompanion Function({
      Value<String> gun,
      Value<String> govde,
      Value<DateTime> okunma,
      Value<int> rowid,
    });

class $$BrifingOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $BrifingOnbellekTable> {
  $$BrifingOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gun => $composableBuilder(
    column: $table.gun,
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

class $$BrifingOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $BrifingOnbellekTable> {
  $$BrifingOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gun => $composableBuilder(
    column: $table.gun,
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

class $$BrifingOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrifingOnbellekTable> {
  $$BrifingOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gun =>
      $composableBuilder(column: $table.gun, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);

  GeneratedColumn<DateTime> get okunma =>
      $composableBuilder(column: $table.okunma, builder: (column) => column);
}

class $$BrifingOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrifingOnbellekTable,
          BrifingOnbellekData,
          $$BrifingOnbellekTableFilterComposer,
          $$BrifingOnbellekTableOrderingComposer,
          $$BrifingOnbellekTableAnnotationComposer,
          $$BrifingOnbellekTableCreateCompanionBuilder,
          $$BrifingOnbellekTableUpdateCompanionBuilder,
          (
            BrifingOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $BrifingOnbellekTable,
              BrifingOnbellekData
            >,
          ),
          BrifingOnbellekData,
          PrefetchHooks Function()
        > {
  $$BrifingOnbellekTableTableManager(
    _$AppDatabase db,
    $BrifingOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrifingOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrifingOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrifingOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gun = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<DateTime> okunma = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrifingOnbellekCompanion(
                gun: gun,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gun,
                required String govde,
                required DateTime okunma,
                Value<int> rowid = const Value.absent(),
              }) => BrifingOnbellekCompanion.insert(
                gun: gun,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BrifingOnbellekTable, BrifingOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BrifingOnbellekTable,
                    BrifingOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrifingOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrifingOnbellekTable,
      BrifingOnbellekData,
      $$BrifingOnbellekTableFilterComposer,
      $$BrifingOnbellekTableOrderingComposer,
      $$BrifingOnbellekTableAnnotationComposer,
      $$BrifingOnbellekTableCreateCompanionBuilder,
      $$BrifingOnbellekTableUpdateCompanionBuilder,
      (
        BrifingOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $BrifingOnbellekTable,
          BrifingOnbellekData
        >,
      ),
      BrifingOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$AyarKayitlariTableCreateCompanionBuilder =
    AyarKayitlariCompanion Function({
      required String anahtar,
      required String deger,
      Value<int> rowid,
    });
typedef $$AyarKayitlariTableUpdateCompanionBuilder =
    AyarKayitlariCompanion Function({
      Value<String> anahtar,
      Value<String> deger,
      Value<int> rowid,
    });

class $$AyarKayitlariTableFilterComposer
    extends Composer<_$AppDatabase, $AyarKayitlariTable> {
  $$AyarKayitlariTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get anahtar => $composableBuilder(
    column: $table.anahtar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deger => $composableBuilder(
    column: $table.deger,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AyarKayitlariTableOrderingComposer
    extends Composer<_$AppDatabase, $AyarKayitlariTable> {
  $$AyarKayitlariTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get anahtar => $composableBuilder(
    column: $table.anahtar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deger => $composableBuilder(
    column: $table.deger,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AyarKayitlariTableAnnotationComposer
    extends Composer<_$AppDatabase, $AyarKayitlariTable> {
  $$AyarKayitlariTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get anahtar =>
      $composableBuilder(column: $table.anahtar, builder: (column) => column);

  GeneratedColumn<String> get deger =>
      $composableBuilder(column: $table.deger, builder: (column) => column);
}

class $$AyarKayitlariTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AyarKayitlariTable,
          AyarKayitlariData,
          $$AyarKayitlariTableFilterComposer,
          $$AyarKayitlariTableOrderingComposer,
          $$AyarKayitlariTableAnnotationComposer,
          $$AyarKayitlariTableCreateCompanionBuilder,
          $$AyarKayitlariTableUpdateCompanionBuilder,
          (
            AyarKayitlariData,
            BaseReferences<
              _$AppDatabase,
              $AyarKayitlariTable,
              AyarKayitlariData
            >,
          ),
          AyarKayitlariData,
          PrefetchHooks Function()
        > {
  $$AyarKayitlariTableTableManager(_$AppDatabase db, $AyarKayitlariTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AyarKayitlariTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AyarKayitlariTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AyarKayitlariTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> anahtar = const Value.absent(),
                Value<String> deger = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AyarKayitlariCompanion(
                anahtar: anahtar,
                deger: deger,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String anahtar,
                required String deger,
                Value<int> rowid = const Value.absent(),
              }) => AyarKayitlariCompanion.insert(
                anahtar: anahtar,
                deger: deger,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AyarKayitlariTable, AyarKayitlariData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AyarKayitlariTable,
                    AyarKayitlariData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AyarKayitlariTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AyarKayitlariTable,
      AyarKayitlariData,
      $$AyarKayitlariTableFilterComposer,
      $$AyarKayitlariTableOrderingComposer,
      $$AyarKayitlariTableAnnotationComposer,
      $$AyarKayitlariTableCreateCompanionBuilder,
      $$AyarKayitlariTableUpdateCompanionBuilder,
      (
        AyarKayitlariData,
        BaseReferences<_$AppDatabase, $AyarKayitlariTable, AyarKayitlariData>,
      ),
      AyarKayitlariData,
      PrefetchHooks Function()
    >;
typedef $$GunGorunumOnbellekTableCreateCompanionBuilder =
    GunGorunumOnbellekCompanion Function({
      required String tarih,
      required String govde,
      required DateTime okunma,
      Value<int> rowid,
    });
typedef $$GunGorunumOnbellekTableUpdateCompanionBuilder =
    GunGorunumOnbellekCompanion Function({
      Value<String> tarih,
      Value<String> govde,
      Value<DateTime> okunma,
      Value<int> rowid,
    });

class $$GunGorunumOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $GunGorunumOnbellekTable> {
  $$GunGorunumOnbellekTableFilterComposer({
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

class $$GunGorunumOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $GunGorunumOnbellekTable> {
  $$GunGorunumOnbellekTableOrderingComposer({
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

class $$GunGorunumOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $GunGorunumOnbellekTable> {
  $$GunGorunumOnbellekTableAnnotationComposer({
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

class $$GunGorunumOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GunGorunumOnbellekTable,
          GunGorunumOnbellekData,
          $$GunGorunumOnbellekTableFilterComposer,
          $$GunGorunumOnbellekTableOrderingComposer,
          $$GunGorunumOnbellekTableAnnotationComposer,
          $$GunGorunumOnbellekTableCreateCompanionBuilder,
          $$GunGorunumOnbellekTableUpdateCompanionBuilder,
          (
            GunGorunumOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $GunGorunumOnbellekTable,
              GunGorunumOnbellekData
            >,
          ),
          GunGorunumOnbellekData,
          PrefetchHooks Function()
        > {
  $$GunGorunumOnbellekTableTableManager(
    _$AppDatabase db,
    $GunGorunumOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GunGorunumOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GunGorunumOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GunGorunumOnbellekTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> tarih = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<DateTime> okunma = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GunGorunumOnbellekCompanion(
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
              }) => GunGorunumOnbellekCompanion.insert(
                tarih: tarih,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GunGorunumOnbellekTable, GunGorunumOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $GunGorunumOnbellekTable,
                    GunGorunumOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GunGorunumOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GunGorunumOnbellekTable,
      GunGorunumOnbellekData,
      $$GunGorunumOnbellekTableFilterComposer,
      $$GunGorunumOnbellekTableOrderingComposer,
      $$GunGorunumOnbellekTableAnnotationComposer,
      $$GunGorunumOnbellekTableCreateCompanionBuilder,
      $$GunGorunumOnbellekTableUpdateCompanionBuilder,
      (
        GunGorunumOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $GunGorunumOnbellekTable,
          GunGorunumOnbellekData
        >,
      ),
      GunGorunumOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$TakvimOnbellekTableCreateCompanionBuilder =
    TakvimOnbellekCompanion Function({
      required String aralik,
      required String govde,
      required DateTime okunma,
      Value<int> rowid,
    });
typedef $$TakvimOnbellekTableUpdateCompanionBuilder =
    TakvimOnbellekCompanion Function({
      Value<String> aralik,
      Value<String> govde,
      Value<DateTime> okunma,
      Value<int> rowid,
    });

class $$TakvimOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $TakvimOnbellekTable> {
  $$TakvimOnbellekTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get aralik => $composableBuilder(
    column: $table.aralik,
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

class $$TakvimOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $TakvimOnbellekTable> {
  $$TakvimOnbellekTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get aralik => $composableBuilder(
    column: $table.aralik,
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

class $$TakvimOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $TakvimOnbellekTable> {
  $$TakvimOnbellekTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get aralik =>
      $composableBuilder(column: $table.aralik, builder: (column) => column);

  GeneratedColumn<String> get govde =>
      $composableBuilder(column: $table.govde, builder: (column) => column);

  GeneratedColumn<DateTime> get okunma =>
      $composableBuilder(column: $table.okunma, builder: (column) => column);
}

class $$TakvimOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TakvimOnbellekTable,
          TakvimOnbellekData,
          $$TakvimOnbellekTableFilterComposer,
          $$TakvimOnbellekTableOrderingComposer,
          $$TakvimOnbellekTableAnnotationComposer,
          $$TakvimOnbellekTableCreateCompanionBuilder,
          $$TakvimOnbellekTableUpdateCompanionBuilder,
          (
            TakvimOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $TakvimOnbellekTable,
              TakvimOnbellekData
            >,
          ),
          TakvimOnbellekData,
          PrefetchHooks Function()
        > {
  $$TakvimOnbellekTableTableManager(
    _$AppDatabase db,
    $TakvimOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TakvimOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TakvimOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TakvimOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> aralik = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<DateTime> okunma = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TakvimOnbellekCompanion(
                aralik: aralik,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String aralik,
                required String govde,
                required DateTime okunma,
                Value<int> rowid = const Value.absent(),
              }) => TakvimOnbellekCompanion.insert(
                aralik: aralik,
                govde: govde,
                okunma: okunma,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TakvimOnbellekTable, TakvimOnbellekData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TakvimOnbellekTable,
                    TakvimOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TakvimOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TakvimOnbellekTable,
      TakvimOnbellekData,
      $$TakvimOnbellekTableFilterComposer,
      $$TakvimOnbellekTableOrderingComposer,
      $$TakvimOnbellekTableAnnotationComposer,
      $$TakvimOnbellekTableCreateCompanionBuilder,
      $$TakvimOnbellekTableUpdateCompanionBuilder,
      (
        TakvimOnbellekData,
        BaseReferences<_$AppDatabase, $TakvimOnbellekTable, TakvimOnbellekData>,
      ),
      TakvimOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$AsistanAkisOnbellekTableCreateCompanionBuilder =
    AsistanAkisOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$AsistanAkisOnbellekTableUpdateCompanionBuilder =
    AsistanAkisOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$AsistanAkisOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $AsistanAkisOnbellekTable> {
  $$AsistanAkisOnbellekTableFilterComposer({
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

class $$AsistanAkisOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $AsistanAkisOnbellekTable> {
  $$AsistanAkisOnbellekTableOrderingComposer({
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

class $$AsistanAkisOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $AsistanAkisOnbellekTable> {
  $$AsistanAkisOnbellekTableAnnotationComposer({
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

class $$AsistanAkisOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AsistanAkisOnbellekTable,
          AsistanAkisOnbellekData,
          $$AsistanAkisOnbellekTableFilterComposer,
          $$AsistanAkisOnbellekTableOrderingComposer,
          $$AsistanAkisOnbellekTableAnnotationComposer,
          $$AsistanAkisOnbellekTableCreateCompanionBuilder,
          $$AsistanAkisOnbellekTableUpdateCompanionBuilder,
          (
            AsistanAkisOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $AsistanAkisOnbellekTable,
              AsistanAkisOnbellekData
            >,
          ),
          AsistanAkisOnbellekData,
          PrefetchHooks Function()
        > {
  $$AsistanAkisOnbellekTableTableManager(
    _$AppDatabase db,
    $AsistanAkisOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AsistanAkisOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AsistanAkisOnbellekTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AsistanAkisOnbellekTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AsistanAkisOnbellekCompanion(
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
              }) => AsistanAkisOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AsistanAkisOnbellekTable,
                    AsistanAkisOnbellekData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AsistanAkisOnbellekTable,
                    AsistanAkisOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AsistanAkisOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AsistanAkisOnbellekTable,
      AsistanAkisOnbellekData,
      $$AsistanAkisOnbellekTableFilterComposer,
      $$AsistanAkisOnbellekTableOrderingComposer,
      $$AsistanAkisOnbellekTableAnnotationComposer,
      $$AsistanAkisOnbellekTableCreateCompanionBuilder,
      $$AsistanAkisOnbellekTableUpdateCompanionBuilder,
      (
        AsistanAkisOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $AsistanAkisOnbellekTable,
          AsistanAkisOnbellekData
        >,
      ),
      AsistanAkisOnbellekData,
      PrefetchHooks Function()
    >;
typedef $$BildirimOnbellekTableCreateCompanionBuilder =
    BildirimOnbellekCompanion Function({
      required String id,
      required int sira,
      required String govde,
      Value<int> rowid,
    });
typedef $$BildirimOnbellekTableUpdateCompanionBuilder =
    BildirimOnbellekCompanion Function({
      Value<String> id,
      Value<int> sira,
      Value<String> govde,
      Value<int> rowid,
    });

class $$BildirimOnbellekTableFilterComposer
    extends Composer<_$AppDatabase, $BildirimOnbellekTable> {
  $$BildirimOnbellekTableFilterComposer({
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

class $$BildirimOnbellekTableOrderingComposer
    extends Composer<_$AppDatabase, $BildirimOnbellekTable> {
  $$BildirimOnbellekTableOrderingComposer({
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

class $$BildirimOnbellekTableAnnotationComposer
    extends Composer<_$AppDatabase, $BildirimOnbellekTable> {
  $$BildirimOnbellekTableAnnotationComposer({
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

class $$BildirimOnbellekTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BildirimOnbellekTable,
          BildirimOnbellekData,
          $$BildirimOnbellekTableFilterComposer,
          $$BildirimOnbellekTableOrderingComposer,
          $$BildirimOnbellekTableAnnotationComposer,
          $$BildirimOnbellekTableCreateCompanionBuilder,
          $$BildirimOnbellekTableUpdateCompanionBuilder,
          (
            BildirimOnbellekData,
            BaseReferences<
              _$AppDatabase,
              $BildirimOnbellekTable,
              BildirimOnbellekData
            >,
          ),
          BildirimOnbellekData,
          PrefetchHooks Function()
        > {
  $$BildirimOnbellekTableTableManager(
    _$AppDatabase db,
    $BildirimOnbellekTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BildirimOnbellekTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BildirimOnbellekTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BildirimOnbellekTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sira = const Value.absent(),
                Value<String> govde = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BildirimOnbellekCompanion(
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
              }) => BildirimOnbellekCompanion.insert(
                id: id,
                sira: sira,
                govde: govde,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BildirimOnbellekTable, BildirimOnbellekData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BildirimOnbellekTable,
                    BildirimOnbellekData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BildirimOnbellekTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BildirimOnbellekTable,
      BildirimOnbellekData,
      $$BildirimOnbellekTableFilterComposer,
      $$BildirimOnbellekTableOrderingComposer,
      $$BildirimOnbellekTableAnnotationComposer,
      $$BildirimOnbellekTableCreateCompanionBuilder,
      $$BildirimOnbellekTableUpdateCompanionBuilder,
      (
        BildirimOnbellekData,
        BaseReferences<
          _$AppDatabase,
          $BildirimOnbellekTable,
          BildirimOnbellekData
        >,
      ),
      BildirimOnbellekData,
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
  $$GelenOnbellekTableTableManager get gelenOnbellek =>
      $$GelenOnbellekTableTableManager(_db, _db.gelenOnbellek);
  $$BrifingOnbellekTableTableManager get brifingOnbellek =>
      $$BrifingOnbellekTableTableManager(_db, _db.brifingOnbellek);
  $$AyarKayitlariTableTableManager get ayarKayitlari =>
      $$AyarKayitlariTableTableManager(_db, _db.ayarKayitlari);
  $$GunGorunumOnbellekTableTableManager get gunGorunumOnbellek =>
      $$GunGorunumOnbellekTableTableManager(_db, _db.gunGorunumOnbellek);
  $$TakvimOnbellekTableTableManager get takvimOnbellek =>
      $$TakvimOnbellekTableTableManager(_db, _db.takvimOnbellek);
  $$AsistanAkisOnbellekTableTableManager get asistanAkisOnbellek =>
      $$AsistanAkisOnbellekTableTableManager(_db, _db.asistanAkisOnbellek);
  $$BildirimOnbellekTableTableManager get bildirimOnbellek =>
      $$BildirimOnbellekTableTableManager(_db, _db.bildirimOnbellek);
}
