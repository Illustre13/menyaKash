// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 40),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {name},
      ];
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  const Category({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Category copyWith({int? id, String? name}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category && other.id == this.id && other.name == this.name);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  CategoriesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $CategoryCodesTable extends CategoryCodes
    with TableInfo<$CategoryCodesTable, CategoryCode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryCodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, code, displayName, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_codes';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryCode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {code},
      ];
  @override
  CategoryCode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryCode(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
    );
  }

  @override
  $CategoryCodesTable createAlias(String alias) {
    return $CategoryCodesTable(attachedDatabase, alias);
  }
}

class CategoryCode extends DataClass implements Insertable<CategoryCode> {
  final int id;

  /// The raw counterparty identifier as it appears in the SMS: a till
  /// number, a merchant code, or a phone number for P2P transfers.
  final String code;

  /// User-editable friendly label for the Frequent Codes screen, e.g.
  /// "Kigali Supermarket" for a raw code like "SUPERMARKET LTD (Code:
  /// 55123)". Falls back to [code] itself when not set.
  final String? displayName;
  final int categoryId;
  const CategoryCode(
      {required this.id,
      required this.code,
      this.displayName,
      required this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['category_id'] = Variable<int>(categoryId);
    return map;
  }

  CategoryCodesCompanion toCompanion(bool nullToAbsent) {
    return CategoryCodesCompanion(
      id: Value(id),
      code: Value(code),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      categoryId: Value(categoryId),
    );
  }

  factory CategoryCode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryCode(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'displayName': serializer.toJson<String?>(displayName),
      'categoryId': serializer.toJson<int>(categoryId),
    };
  }

  CategoryCode copyWith(
          {int? id,
          String? code,
          Value<String?> displayName = const Value.absent(),
          int? categoryId}) =>
      CategoryCode(
        id: id ?? this.id,
        code: code ?? this.code,
        displayName: displayName.present ? displayName.value : this.displayName,
        categoryId: categoryId ?? this.categoryId,
      );
  CategoryCode copyWithCompanion(CategoryCodesCompanion data) {
    return CategoryCode(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryCode(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, displayName, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryCode &&
          other.id == this.id &&
          other.code == this.code &&
          other.displayName == this.displayName &&
          other.categoryId == this.categoryId);
}

class CategoryCodesCompanion extends UpdateCompanion<CategoryCode> {
  final Value<int> id;
  final Value<String> code;
  final Value<String?> displayName;
  final Value<int> categoryId;
  const CategoryCodesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.displayName = const Value.absent(),
    this.categoryId = const Value.absent(),
  });
  CategoryCodesCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    this.displayName = const Value.absent(),
    required int categoryId,
  })  : code = Value(code),
        categoryId = Value(categoryId);
  static Insertable<CategoryCode> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? displayName,
    Expression<int>? categoryId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (displayName != null) 'display_name': displayName,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  CategoryCodesCompanion copyWith(
      {Value<int>? id,
      Value<String>? code,
      Value<String?>? displayName,
      Value<int>? categoryId}) {
    return CategoryCodesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      displayName: displayName ?? this.displayName,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryCodesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 32),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TransactionType, String> type =
      GeneratedColumn<String>('type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<TransactionType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<double> fee = GeneratedColumn<double>(
      'fee', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _counterpartyMeta =
      const VerificationMeta('counterparty');
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
      'counterparty', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _txRefMeta = const VerificationMeta('txRef');
  @override
  late final GeneratedColumn<String> txRef = GeneratedColumn<String>(
      'tx_ref', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _balanceAfterMeta =
      const VerificationMeta('balanceAfter');
  @override
  late final GeneratedColumn<double> balanceAfter = GeneratedColumn<double>(
      'balance_after', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _rawSmsBodyMeta =
      const VerificationMeta('rawSmsBody');
  @override
  late final GeneratedColumn<String> rawSmsBody = GeneratedColumn<String>(
      'raw_sms_body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        provider,
        type,
        amount,
        fee,
        counterparty,
        txRef,
        balanceAfter,
        timestamp,
        rawSmsBody,
        categoryId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('fee')) {
      context.handle(
          _feeMeta, fee.isAcceptableOrUnknown(data['fee']!, _feeMeta));
    }
    if (data.containsKey('counterparty')) {
      context.handle(
          _counterpartyMeta,
          counterparty.isAcceptableOrUnknown(
              data['counterparty']!, _counterpartyMeta));
    }
    if (data.containsKey('tx_ref')) {
      context.handle(
          _txRefMeta, txRef.isAcceptableOrUnknown(data['tx_ref']!, _txRefMeta));
    }
    if (data.containsKey('balance_after')) {
      context.handle(
          _balanceAfterMeta,
          balanceAfter.isAcceptableOrUnknown(
              data['balance_after']!, _balanceAfterMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('raw_sms_body')) {
      context.handle(
          _rawSmsBodyMeta,
          rawSmsBody.isAcceptableOrUnknown(
              data['raw_sms_body']!, _rawSmsBodyMeta));
    } else if (isInserting) {
      context.missing(_rawSmsBodyMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      type: $TransactionsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      fee: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fee'])!,
      counterparty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}counterparty']),
      txRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tx_ref']),
      balanceAfter: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance_after']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      rawSmsBody: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_sms_body'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionType, String, String> $convertertype =
      const EnumNameConverter<TransactionType>(TransactionType.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;

  /// e.g. "mtn_rw", "airtel_rw" — matches a MomoParser.providerId.
  final String provider;
  final TransactionType type;
  final double amount;
  final double fee;

  /// Raw counterparty identifier (phone number, till code, agent code,
  /// or free-text name) exactly as extracted from the SMS body.
  final String? counterparty;
  final String? txRef;
  final double? balanceAfter;
  final DateTime timestamp;

  /// Full original SMS body, kept for re-parsing if a regex is fixed later
  /// and for the "Review unparsed" screen's context.
  final String rawSmsBody;
  final int? categoryId;
  const Transaction(
      {required this.id,
      required this.provider,
      required this.type,
      required this.amount,
      required this.fee,
      this.counterparty,
      this.txRef,
      this.balanceAfter,
      required this.timestamp,
      required this.rawSmsBody,
      this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    {
      map['type'] =
          Variable<String>($TransactionsTable.$convertertype.toSql(type));
    }
    map['amount'] = Variable<double>(amount);
    map['fee'] = Variable<double>(fee);
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    if (!nullToAbsent || txRef != null) {
      map['tx_ref'] = Variable<String>(txRef);
    }
    if (!nullToAbsent || balanceAfter != null) {
      map['balance_after'] = Variable<double>(balanceAfter);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['raw_sms_body'] = Variable<String>(rawSmsBody);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      provider: Value(provider),
      type: Value(type),
      amount: Value(amount),
      fee: Value(fee),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      txRef:
          txRef == null && nullToAbsent ? const Value.absent() : Value(txRef),
      balanceAfter: balanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceAfter),
      timestamp: Value(timestamp),
      rawSmsBody: Value(rawSmsBody),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      type: $TransactionsTable.$convertertype
          .fromJson(serializer.fromJson<String>(json['type'])),
      amount: serializer.fromJson<double>(json['amount']),
      fee: serializer.fromJson<double>(json['fee']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      txRef: serializer.fromJson<String?>(json['txRef']),
      balanceAfter: serializer.fromJson<double?>(json['balanceAfter']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      rawSmsBody: serializer.fromJson<String>(json['rawSmsBody']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'type': serializer
          .toJson<String>($TransactionsTable.$convertertype.toJson(type)),
      'amount': serializer.toJson<double>(amount),
      'fee': serializer.toJson<double>(fee),
      'counterparty': serializer.toJson<String?>(counterparty),
      'txRef': serializer.toJson<String?>(txRef),
      'balanceAfter': serializer.toJson<double?>(balanceAfter),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'rawSmsBody': serializer.toJson<String>(rawSmsBody),
      'categoryId': serializer.toJson<int?>(categoryId),
    };
  }

  Transaction copyWith(
          {int? id,
          String? provider,
          TransactionType? type,
          double? amount,
          double? fee,
          Value<String?> counterparty = const Value.absent(),
          Value<String?> txRef = const Value.absent(),
          Value<double?> balanceAfter = const Value.absent(),
          DateTime? timestamp,
          String? rawSmsBody,
          Value<int?> categoryId = const Value.absent()}) =>
      Transaction(
        id: id ?? this.id,
        provider: provider ?? this.provider,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        fee: fee ?? this.fee,
        counterparty:
            counterparty.present ? counterparty.value : this.counterparty,
        txRef: txRef.present ? txRef.value : this.txRef,
        balanceAfter:
            balanceAfter.present ? balanceAfter.value : this.balanceAfter,
        timestamp: timestamp ?? this.timestamp,
        rawSmsBody: rawSmsBody ?? this.rawSmsBody,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      fee: data.fee.present ? data.fee.value : this.fee,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      txRef: data.txRef.present ? data.txRef.value : this.txRef,
      balanceAfter: data.balanceAfter.present
          ? data.balanceAfter.value
          : this.balanceAfter,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      rawSmsBody:
          data.rawSmsBody.present ? data.rawSmsBody.value : this.rawSmsBody,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('fee: $fee, ')
          ..write('counterparty: $counterparty, ')
          ..write('txRef: $txRef, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('timestamp: $timestamp, ')
          ..write('rawSmsBody: $rawSmsBody, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, provider, type, amount, fee, counterparty,
      txRef, balanceAfter, timestamp, rawSmsBody, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.fee == this.fee &&
          other.counterparty == this.counterparty &&
          other.txRef == this.txRef &&
          other.balanceAfter == this.balanceAfter &&
          other.timestamp == this.timestamp &&
          other.rawSmsBody == this.rawSmsBody &&
          other.categoryId == this.categoryId);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<String> provider;
  final Value<TransactionType> type;
  final Value<double> amount;
  final Value<double> fee;
  final Value<String?> counterparty;
  final Value<String?> txRef;
  final Value<double?> balanceAfter;
  final Value<DateTime> timestamp;
  final Value<String> rawSmsBody;
  final Value<int?> categoryId;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.fee = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.txRef = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rawSmsBody = const Value.absent(),
    this.categoryId = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    required TransactionType type,
    required double amount,
    this.fee = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.txRef = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    required DateTime timestamp,
    required String rawSmsBody,
    this.categoryId = const Value.absent(),
  })  : provider = Value(provider),
        type = Value(type),
        amount = Value(amount),
        timestamp = Value(timestamp),
        rawSmsBody = Value(rawSmsBody);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<double>? fee,
    Expression<String>? counterparty,
    Expression<String>? txRef,
    Expression<double>? balanceAfter,
    Expression<DateTime>? timestamp,
    Expression<String>? rawSmsBody,
    Expression<int>? categoryId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (fee != null) 'fee': fee,
      if (counterparty != null) 'counterparty': counterparty,
      if (txRef != null) 'tx_ref': txRef,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (timestamp != null) 'timestamp': timestamp,
      if (rawSmsBody != null) 'raw_sms_body': rawSmsBody,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? provider,
      Value<TransactionType>? type,
      Value<double>? amount,
      Value<double>? fee,
      Value<String?>? counterparty,
      Value<String?>? txRef,
      Value<double?>? balanceAfter,
      Value<DateTime>? timestamp,
      Value<String>? rawSmsBody,
      Value<int?>? categoryId}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      counterparty: counterparty ?? this.counterparty,
      txRef: txRef ?? this.txRef,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      timestamp: timestamp ?? this.timestamp,
      rawSmsBody: rawSmsBody ?? this.rawSmsBody,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (type.present) {
      map['type'] =
          Variable<String>($TransactionsTable.$convertertype.toSql(type.value));
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (fee.present) {
      map['fee'] = Variable<double>(fee.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (txRef.present) {
      map['tx_ref'] = Variable<String>(txRef.value);
    }
    if (balanceAfter.present) {
      map['balance_after'] = Variable<double>(balanceAfter.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rawSmsBody.present) {
      map['raw_sms_body'] = Variable<String>(rawSmsBody.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('fee: $fee, ')
          ..write('counterparty: $counterparty, ')
          ..write('txRef: $txRef, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('timestamp: $timestamp, ')
          ..write('rawSmsBody: $rawSmsBody, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }
}

class $UnparsedMessagesTable extends UnparsedMessages
    with TableInfo<$UnparsedMessagesTable, UnparsedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnparsedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
      'sender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resolvedMeta =
      const VerificationMeta('resolved');
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
      'resolved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("resolved" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, sender, body, receivedAt, resolved];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unparsed_messages';
  @override
  VerificationContext validateIntegrity(Insertable<UnparsedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender']!, _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('resolved')) {
      context.handle(_resolvedMeta,
          resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnparsedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnparsedMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      resolved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}resolved'])!,
    );
  }

  @override
  $UnparsedMessagesTable createAlias(String alias) {
    return $UnparsedMessagesTable(attachedDatabase, alias);
  }
}

class UnparsedMessage extends DataClass implements Insertable<UnparsedMessage> {
  final int id;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool resolved;
  const UnparsedMessage(
      {required this.id,
      required this.sender,
      required this.body,
      required this.receivedAt,
      required this.resolved});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['resolved'] = Variable<bool>(resolved);
    return map;
  }

  UnparsedMessagesCompanion toCompanion(bool nullToAbsent) {
    return UnparsedMessagesCompanion(
      id: Value(id),
      sender: Value(sender),
      body: Value(body),
      receivedAt: Value(receivedAt),
      resolved: Value(resolved),
    );
  }

  factory UnparsedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnparsedMessage(
      id: serializer.fromJson<int>(json['id']),
      sender: serializer.fromJson<String>(json['sender']),
      body: serializer.fromJson<String>(json['body']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      resolved: serializer.fromJson<bool>(json['resolved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sender': serializer.toJson<String>(sender),
      'body': serializer.toJson<String>(body),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'resolved': serializer.toJson<bool>(resolved),
    };
  }

  UnparsedMessage copyWith(
          {int? id,
          String? sender,
          String? body,
          DateTime? receivedAt,
          bool? resolved}) =>
      UnparsedMessage(
        id: id ?? this.id,
        sender: sender ?? this.sender,
        body: body ?? this.body,
        receivedAt: receivedAt ?? this.receivedAt,
        resolved: resolved ?? this.resolved,
      );
  UnparsedMessage copyWithCompanion(UnparsedMessagesCompanion data) {
    return UnparsedMessage(
      id: data.id.present ? data.id.value : this.id,
      sender: data.sender.present ? data.sender.value : this.sender,
      body: data.body.present ? data.body.value : this.body,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnparsedMessage(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sender, body, receivedAt, resolved);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnparsedMessage &&
          other.id == this.id &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.receivedAt == this.receivedAt &&
          other.resolved == this.resolved);
}

class UnparsedMessagesCompanion extends UpdateCompanion<UnparsedMessage> {
  final Value<int> id;
  final Value<String> sender;
  final Value<String> body;
  final Value<DateTime> receivedAt;
  final Value<bool> resolved;
  const UnparsedMessagesCompanion({
    this.id = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.resolved = const Value.absent(),
  });
  UnparsedMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String sender,
    required String body,
    required DateTime receivedAt,
    this.resolved = const Value.absent(),
  })  : sender = Value(sender),
        body = Value(body),
        receivedAt = Value(receivedAt);
  static Insertable<UnparsedMessage> custom({
    Expression<int>? id,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<DateTime>? receivedAt,
    Expression<bool>? resolved,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (receivedAt != null) 'received_at': receivedAt,
      if (resolved != null) 'resolved': resolved,
    });
  }

  UnparsedMessagesCompanion copyWith(
      {Value<int>? id,
      Value<String>? sender,
      Value<String>? body,
      Value<DateTime>? receivedAt,
      Value<bool>? resolved}) {
    return UnparsedMessagesCompanion(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      receivedAt: receivedAt ?? this.receivedAt,
      resolved: resolved ?? this.resolved,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnparsedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CategoryCodesTable categoryCodes = $CategoryCodesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $UnparsedMessagesTable unparsedMessages =
      $UnparsedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [categories, categoryCodes, transactions, unparsedMessages];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$CategoryCodesTableCreateCompanionBuilder = CategoryCodesCompanion
    Function({
  Value<int> id,
  required String code,
  Value<String?> displayName,
  required int categoryId,
});
typedef $$CategoryCodesTableUpdateCompanionBuilder = CategoryCodesCompanion
    Function({
  Value<int> id,
  Value<String> code,
  Value<String?> displayName,
  Value<int> categoryId,
});

class $$CategoryCodesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryCodesTable> {
  $$CategoryCodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));
}

class $$CategoryCodesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryCodesTable> {
  $$CategoryCodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));
}

class $$CategoryCodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryCodesTable> {
  $$CategoryCodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);
}

class $$CategoryCodesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoryCodesTable,
    CategoryCode,
    $$CategoryCodesTableFilterComposer,
    $$CategoryCodesTableOrderingComposer,
    $$CategoryCodesTableAnnotationComposer,
    $$CategoryCodesTableCreateCompanionBuilder,
    $$CategoryCodesTableUpdateCompanionBuilder,
    (
      CategoryCode,
      BaseReferences<_$AppDatabase, $CategoryCodesTable, CategoryCode>
    ),
    CategoryCode,
    PrefetchHooks Function()> {
  $$CategoryCodesTableTableManager(_$AppDatabase db, $CategoryCodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryCodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryCodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryCodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<int> categoryId = const Value.absent(),
          }) =>
              CategoryCodesCompanion(
            id: id,
            code: code,
            displayName: displayName,
            categoryId: categoryId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String code,
            Value<String?> displayName = const Value.absent(),
            required int categoryId,
          }) =>
              CategoryCodesCompanion.insert(
            id: id,
            code: code,
            displayName: displayName,
            categoryId: categoryId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoryCodesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoryCodesTable,
    CategoryCode,
    $$CategoryCodesTableFilterComposer,
    $$CategoryCodesTableOrderingComposer,
    $$CategoryCodesTableAnnotationComposer,
    $$CategoryCodesTableCreateCompanionBuilder,
    $$CategoryCodesTableUpdateCompanionBuilder,
    (
      CategoryCode,
      BaseReferences<_$AppDatabase, $CategoryCodesTable, CategoryCode>
    ),
    CategoryCode,
    PrefetchHooks Function()>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  required String provider,
  required TransactionType type,
  required double amount,
  Value<double> fee,
  Value<String?> counterparty,
  Value<String?> txRef,
  Value<double?> balanceAfter,
  required DateTime timestamp,
  required String rawSmsBody,
  Value<int?> categoryId,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<String> provider,
  Value<TransactionType> type,
  Value<double> amount,
  Value<double> fee,
  Value<String?> counterparty,
  Value<String?> txRef,
  Value<double?> balanceAfter,
  Value<DateTime> timestamp,
  Value<String> rawSmsBody,
  Value<int?> categoryId,
});

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fee => $composableBuilder(
      column: $table.fee, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get txRef => $composableBuilder(
      column: $table.txRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balanceAfter => $composableBuilder(
      column: $table.balanceAfter, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawSmsBody => $composableBuilder(
      column: $table.rawSmsBody, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fee => $composableBuilder(
      column: $table.fee, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get counterparty => $composableBuilder(
      column: $table.counterparty,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get txRef => $composableBuilder(
      column: $table.txRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balanceAfter => $composableBuilder(
      column: $table.balanceAfter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawSmsBody => $composableBuilder(
      column: $table.rawSmsBody, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => column);

  GeneratedColumn<String> get txRef =>
      $composableBuilder(column: $table.txRef, builder: (column) => column);

  GeneratedColumn<double> get balanceAfter => $composableBuilder(
      column: $table.balanceAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get rawSmsBody => $composableBuilder(
      column: $table.rawSmsBody, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<TransactionType> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<double> fee = const Value.absent(),
            Value<String?> counterparty = const Value.absent(),
            Value<String?> txRef = const Value.absent(),
            Value<double?> balanceAfter = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> rawSmsBody = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            provider: provider,
            type: type,
            amount: amount,
            fee: fee,
            counterparty: counterparty,
            txRef: txRef,
            balanceAfter: balanceAfter,
            timestamp: timestamp,
            rawSmsBody: rawSmsBody,
            categoryId: categoryId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String provider,
            required TransactionType type,
            required double amount,
            Value<double> fee = const Value.absent(),
            Value<String?> counterparty = const Value.absent(),
            Value<String?> txRef = const Value.absent(),
            Value<double?> balanceAfter = const Value.absent(),
            required DateTime timestamp,
            required String rawSmsBody,
            Value<int?> categoryId = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            provider: provider,
            type: type,
            amount: amount,
            fee: fee,
            counterparty: counterparty,
            txRef: txRef,
            balanceAfter: balanceAfter,
            timestamp: timestamp,
            rawSmsBody: rawSmsBody,
            categoryId: categoryId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()>;
typedef $$UnparsedMessagesTableCreateCompanionBuilder
    = UnparsedMessagesCompanion Function({
  Value<int> id,
  required String sender,
  required String body,
  required DateTime receivedAt,
  Value<bool> resolved,
});
typedef $$UnparsedMessagesTableUpdateCompanionBuilder
    = UnparsedMessagesCompanion Function({
  Value<int> id,
  Value<String> sender,
  Value<String> body,
  Value<DateTime> receivedAt,
  Value<bool> resolved,
});

class $$UnparsedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get resolved => $composableBuilder(
      column: $table.resolved, builder: (column) => ColumnFilters(column));
}

class $$UnparsedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get resolved => $composableBuilder(
      column: $table.resolved, builder: (column) => ColumnOrderings(column));
}

class $$UnparsedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<bool> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);
}

class $$UnparsedMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UnparsedMessagesTable,
    UnparsedMessage,
    $$UnparsedMessagesTableFilterComposer,
    $$UnparsedMessagesTableOrderingComposer,
    $$UnparsedMessagesTableAnnotationComposer,
    $$UnparsedMessagesTableCreateCompanionBuilder,
    $$UnparsedMessagesTableUpdateCompanionBuilder,
    (
      UnparsedMessage,
      BaseReferences<_$AppDatabase, $UnparsedMessagesTable, UnparsedMessage>
    ),
    UnparsedMessage,
    PrefetchHooks Function()> {
  $$UnparsedMessagesTableTableManager(
      _$AppDatabase db, $UnparsedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnparsedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnparsedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnparsedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<bool> resolved = const Value.absent(),
          }) =>
              UnparsedMessagesCompanion(
            id: id,
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            resolved: resolved,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sender,
            required String body,
            required DateTime receivedAt,
            Value<bool> resolved = const Value.absent(),
          }) =>
              UnparsedMessagesCompanion.insert(
            id: id,
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            resolved: resolved,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UnparsedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UnparsedMessagesTable,
    UnparsedMessage,
    $$UnparsedMessagesTableFilterComposer,
    $$UnparsedMessagesTableOrderingComposer,
    $$UnparsedMessagesTableAnnotationComposer,
    $$UnparsedMessagesTableCreateCompanionBuilder,
    $$UnparsedMessagesTableUpdateCompanionBuilder,
    (
      UnparsedMessage,
      BaseReferences<_$AppDatabase, $UnparsedMessagesTable, UnparsedMessage>
    ),
    UnparsedMessage,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CategoryCodesTableTableManager get categoryCodes =>
      $$CategoryCodesTableTableManager(_db, _db.categoryCodes);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$UnparsedMessagesTableTableManager get unparsedMessages =>
      $$UnparsedMessagesTableTableManager(_db, _db.unparsedMessages);
}
