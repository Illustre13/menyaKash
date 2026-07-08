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
  static const VerificationMeta _smsMessageIdMeta =
      const VerificationMeta('smsMessageId');
  @override
  late final GeneratedColumn<int> smsMessageId = GeneratedColumn<int>(
      'sms_message_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<int> providerId = GeneratedColumn<int>(
      'provider_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _merchantIdMeta =
      const VerificationMeta('merchantId');
  @override
  late final GeneratedColumn<int> merchantId = GeneratedColumn<int>(
      'merchant_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
        smsMessageId,
        providerId,
        accountId,
        merchantId,
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
    if (data.containsKey('sms_message_id')) {
      context.handle(
          _smsMessageIdMeta,
          smsMessageId.isAcceptableOrUnknown(
              data['sms_message_id']!, _smsMessageIdMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
          _merchantIdMeta,
          merchantId.isAcceptableOrUnknown(
              data['merchant_id']!, _merchantIdMeta));
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
      smsMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sms_message_id']),
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}provider_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id']),
      merchantId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}merchant_id']),
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

  /// Links back to the exact SMS this transaction was extracted from —
  /// the "financial ledger built from evidence" link the v1 schema
  /// lacked (v1 only kept a copy of the body on the transaction row
  /// itself, with no way to distinguish "reprocessed the same message"
  /// from "a genuinely new message"). Nullable only for rows migrated
  /// from v1 history where no matching sms_messages row could be
  /// reconstructed with full confidence (see migration `onUpgrade`).
  final int? smsMessageId;

  /// Real FK now — was a bare unvalidated string in v1. See
  /// [FinancialProviders].
  final int? providerId;

  /// Which of the user's own [Accounts] this transaction moved money
  /// into or out of. Nullable for the same reason [smsMessageId] is:
  /// v1/v2 history predates accounts existing at all, and v2->v3
  /// migrated rows are attributed to the default account for their
  /// provider (see `AppDatabase._backfillAccountsFromV2`) rather than
  /// left permanently unset.
  final int? accountId;

  /// Which real-world [Merchants] row this transaction's counterparty
  /// resolves to, once merchant-name normalization has run on it (Phase
  /// 4). Nullable and independent of [categoryId]/[counterparty] — this
  /// is new plumbing that doesn't yet drive any UI; existing
  /// categorization continues to work off [counterparty] +
  /// `CategoryCodes` exactly as before.
  final int? merchantId;
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
  /// and for the "Review unparsed" screen's context. Now also duplicated
  /// in [SmsMessages.body] via [smsMessageId] — kept here too rather than
  /// dropped, since removing a NOT NULL column that many existing v1 rows
  /// depend on is a bigger migration risk than a few KB of duplication.
  final String rawSmsBody;
  final int? categoryId;
  const Transaction(
      {required this.id,
      this.smsMessageId,
      this.providerId,
      this.accountId,
      this.merchantId,
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
    if (!nullToAbsent || smsMessageId != null) {
      map['sms_message_id'] = Variable<int>(smsMessageId);
    }
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<int>(providerId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || merchantId != null) {
      map['merchant_id'] = Variable<int>(merchantId);
    }
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
      smsMessageId: smsMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(smsMessageId),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      merchantId: merchantId == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantId),
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
      smsMessageId: serializer.fromJson<int?>(json['smsMessageId']),
      providerId: serializer.fromJson<int?>(json['providerId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      merchantId: serializer.fromJson<int?>(json['merchantId']),
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
      'smsMessageId': serializer.toJson<int?>(smsMessageId),
      'providerId': serializer.toJson<int?>(providerId),
      'accountId': serializer.toJson<int?>(accountId),
      'merchantId': serializer.toJson<int?>(merchantId),
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
          Value<int?> smsMessageId = const Value.absent(),
          Value<int?> providerId = const Value.absent(),
          Value<int?> accountId = const Value.absent(),
          Value<int?> merchantId = const Value.absent(),
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
        smsMessageId:
            smsMessageId.present ? smsMessageId.value : this.smsMessageId,
        providerId: providerId.present ? providerId.value : this.providerId,
        accountId: accountId.present ? accountId.value : this.accountId,
        merchantId: merchantId.present ? merchantId.value : this.merchantId,
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
      smsMessageId: data.smsMessageId.present
          ? data.smsMessageId.value
          : this.smsMessageId,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      merchantId:
          data.merchantId.present ? data.merchantId.value : this.merchantId,
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
          ..write('smsMessageId: $smsMessageId, ')
          ..write('providerId: $providerId, ')
          ..write('accountId: $accountId, ')
          ..write('merchantId: $merchantId, ')
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
  int get hashCode => Object.hash(
      id,
      smsMessageId,
      providerId,
      accountId,
      merchantId,
      type,
      amount,
      fee,
      counterparty,
      txRef,
      balanceAfter,
      timestamp,
      rawSmsBody,
      categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.smsMessageId == this.smsMessageId &&
          other.providerId == this.providerId &&
          other.accountId == this.accountId &&
          other.merchantId == this.merchantId &&
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
  final Value<int?> smsMessageId;
  final Value<int?> providerId;
  final Value<int?> accountId;
  final Value<int?> merchantId;
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
    this.smsMessageId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.merchantId = const Value.absent(),
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
    this.smsMessageId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.merchantId = const Value.absent(),
    required TransactionType type,
    required double amount,
    this.fee = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.txRef = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    required DateTime timestamp,
    required String rawSmsBody,
    this.categoryId = const Value.absent(),
  })  : type = Value(type),
        amount = Value(amount),
        timestamp = Value(timestamp),
        rawSmsBody = Value(rawSmsBody);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<int>? smsMessageId,
    Expression<int>? providerId,
    Expression<int>? accountId,
    Expression<int>? merchantId,
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
      if (smsMessageId != null) 'sms_message_id': smsMessageId,
      if (providerId != null) 'provider_id': providerId,
      if (accountId != null) 'account_id': accountId,
      if (merchantId != null) 'merchant_id': merchantId,
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
      Value<int?>? smsMessageId,
      Value<int?>? providerId,
      Value<int?>? accountId,
      Value<int?>? merchantId,
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
      smsMessageId: smsMessageId ?? this.smsMessageId,
      providerId: providerId ?? this.providerId,
      accountId: accountId ?? this.accountId,
      merchantId: merchantId ?? this.merchantId,
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
    if (smsMessageId.present) {
      map['sms_message_id'] = Variable<int>(smsMessageId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<int>(providerId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<int>(merchantId.value);
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
          ..write('smsMessageId: $smsMessageId, ')
          ..write('providerId: $providerId, ')
          ..write('accountId: $accountId, ')
          ..write('merchantId: $merchantId, ')
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
  static const VerificationMeta _smsMessageIdMeta =
      const VerificationMeta('smsMessageId');
  @override
  late final GeneratedColumn<int> smsMessageId = GeneratedColumn<int>(
      'sms_message_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
      [id, smsMessageId, sender, body, receivedAt, resolved];
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
    if (data.containsKey('sms_message_id')) {
      context.handle(
          _smsMessageIdMeta,
          smsMessageId.isAcceptableOrUnknown(
              data['sms_message_id']!, _smsMessageIdMeta));
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
      smsMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sms_message_id']),
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

  /// Links to the evidence row. Nullable for the same v1-migration
  /// reason as [Transactions.smsMessageId].
  final int? smsMessageId;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool resolved;
  const UnparsedMessage(
      {required this.id,
      this.smsMessageId,
      required this.sender,
      required this.body,
      required this.receivedAt,
      required this.resolved});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || smsMessageId != null) {
      map['sms_message_id'] = Variable<int>(smsMessageId);
    }
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['resolved'] = Variable<bool>(resolved);
    return map;
  }

  UnparsedMessagesCompanion toCompanion(bool nullToAbsent) {
    return UnparsedMessagesCompanion(
      id: Value(id),
      smsMessageId: smsMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(smsMessageId),
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
      smsMessageId: serializer.fromJson<int?>(json['smsMessageId']),
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
      'smsMessageId': serializer.toJson<int?>(smsMessageId),
      'sender': serializer.toJson<String>(sender),
      'body': serializer.toJson<String>(body),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'resolved': serializer.toJson<bool>(resolved),
    };
  }

  UnparsedMessage copyWith(
          {int? id,
          Value<int?> smsMessageId = const Value.absent(),
          String? sender,
          String? body,
          DateTime? receivedAt,
          bool? resolved}) =>
      UnparsedMessage(
        id: id ?? this.id,
        smsMessageId:
            smsMessageId.present ? smsMessageId.value : this.smsMessageId,
        sender: sender ?? this.sender,
        body: body ?? this.body,
        receivedAt: receivedAt ?? this.receivedAt,
        resolved: resolved ?? this.resolved,
      );
  UnparsedMessage copyWithCompanion(UnparsedMessagesCompanion data) {
    return UnparsedMessage(
      id: data.id.present ? data.id.value : this.id,
      smsMessageId: data.smsMessageId.present
          ? data.smsMessageId.value
          : this.smsMessageId,
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
          ..write('smsMessageId: $smsMessageId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, smsMessageId, sender, body, receivedAt, resolved);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnparsedMessage &&
          other.id == this.id &&
          other.smsMessageId == this.smsMessageId &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.receivedAt == this.receivedAt &&
          other.resolved == this.resolved);
}

class UnparsedMessagesCompanion extends UpdateCompanion<UnparsedMessage> {
  final Value<int> id;
  final Value<int?> smsMessageId;
  final Value<String> sender;
  final Value<String> body;
  final Value<DateTime> receivedAt;
  final Value<bool> resolved;
  const UnparsedMessagesCompanion({
    this.id = const Value.absent(),
    this.smsMessageId = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.resolved = const Value.absent(),
  });
  UnparsedMessagesCompanion.insert({
    this.id = const Value.absent(),
    this.smsMessageId = const Value.absent(),
    required String sender,
    required String body,
    required DateTime receivedAt,
    this.resolved = const Value.absent(),
  })  : sender = Value(sender),
        body = Value(body),
        receivedAt = Value(receivedAt);
  static Insertable<UnparsedMessage> custom({
    Expression<int>? id,
    Expression<int>? smsMessageId,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<DateTime>? receivedAt,
    Expression<bool>? resolved,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (smsMessageId != null) 'sms_message_id': smsMessageId,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (receivedAt != null) 'received_at': receivedAt,
      if (resolved != null) 'resolved': resolved,
    });
  }

  UnparsedMessagesCompanion copyWith(
      {Value<int>? id,
      Value<int?>? smsMessageId,
      Value<String>? sender,
      Value<String>? body,
      Value<DateTime>? receivedAt,
      Value<bool>? resolved}) {
    return UnparsedMessagesCompanion(
      id: id ?? this.id,
      smsMessageId: smsMessageId ?? this.smsMessageId,
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
    if (smsMessageId.present) {
      map['sms_message_id'] = Variable<int>(smsMessageId.value);
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
          ..write('smsMessageId: $smsMessageId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }
}

class $FinancialProvidersTable extends FinancialProviders
    with TableInfo<$FinancialProvidersTable, FinancialProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinancialProvidersTable(this.attachedDatabase, [this._alias]);
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
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 32),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 32),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, code, displayName, category];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'financial_providers';
  @override
  VerificationContext validateIntegrity(Insertable<FinancialProvider> instance,
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
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
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
  FinancialProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinancialProvider(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
    );
  }

  @override
  $FinancialProvidersTable createAlias(String alias) {
    return $FinancialProvidersTable(attachedDatabase, alias);
  }
}

class FinancialProvider extends DataClass
    implements Insertable<FinancialProvider> {
  final int id;

  /// Stable machine identifier, e.g. "mtn_momo_rw". Referenced by
  /// [Transactions.providerId] and by parser/detector code — never
  /// shown to the user directly.
  final String code;

  /// Human-readable name for UI, e.g. "MTN Mobile Money".
  final String displayName;

  /// "mobile_money" or "bank" — coarse grouping for the provider-picker
  /// UI (spec Phase 6) and for deciding which parser family applies.
  final String category;
  const FinancialProvider(
      {required this.id,
      required this.code,
      required this.displayName,
      required this.category});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['display_name'] = Variable<String>(displayName);
    map['category'] = Variable<String>(category);
    return map;
  }

  FinancialProvidersCompanion toCompanion(bool nullToAbsent) {
    return FinancialProvidersCompanion(
      id: Value(id),
      code: Value(code),
      displayName: Value(displayName),
      category: Value(category),
    );
  }

  factory FinancialProvider.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinancialProvider(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      displayName: serializer.fromJson<String>(json['displayName']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'displayName': serializer.toJson<String>(displayName),
      'category': serializer.toJson<String>(category),
    };
  }

  FinancialProvider copyWith(
          {int? id, String? code, String? displayName, String? category}) =>
      FinancialProvider(
        id: id ?? this.id,
        code: code ?? this.code,
        displayName: displayName ?? this.displayName,
        category: category ?? this.category,
      );
  FinancialProvider copyWithCompanion(FinancialProvidersCompanion data) {
    return FinancialProvider(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinancialProvider(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, displayName, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinancialProvider &&
          other.id == this.id &&
          other.code == this.code &&
          other.displayName == this.displayName &&
          other.category == this.category);
}

class FinancialProvidersCompanion extends UpdateCompanion<FinancialProvider> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> displayName;
  final Value<String> category;
  const FinancialProvidersCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.displayName = const Value.absent(),
    this.category = const Value.absent(),
  });
  FinancialProvidersCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String displayName,
    required String category,
  })  : code = Value(code),
        displayName = Value(displayName),
        category = Value(category);
  static Insertable<FinancialProvider> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? displayName,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (displayName != null) 'display_name': displayName,
      if (category != null) 'category': category,
    });
  }

  FinancialProvidersCompanion copyWith(
      {Value<int>? id,
      Value<String>? code,
      Value<String>? displayName,
      Value<String>? category}) {
    return FinancialProvidersCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinancialProvidersCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $ProviderSendersTable extends ProviderSenders
    with TableInfo<$ProviderSendersTable, ProviderSender> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderSendersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _senderPatternMeta =
      const VerificationMeta('senderPattern');
  @override
  late final GeneratedColumn<String> senderPattern = GeneratedColumn<String>(
      'sender_pattern', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<int> providerId = GeneratedColumn<int>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, senderPattern, providerId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_senders';
  @override
  VerificationContext validateIntegrity(Insertable<ProviderSender> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sender_pattern')) {
      context.handle(
          _senderPatternMeta,
          senderPattern.isAcceptableOrUnknown(
              data['sender_pattern']!, _senderPatternMeta));
    } else if (isInserting) {
      context.missing(_senderPatternMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {senderPattern, providerId},
      ];
  @override
  ProviderSender map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderSender(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      senderPattern: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_pattern'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}provider_id'])!,
    );
  }

  @override
  $ProviderSendersTable createAlias(String alias) {
    return $ProviderSendersTable(attachedDatabase, alias);
  }
}

class ProviderSender extends DataClass implements Insertable<ProviderSender> {
  final int id;
  final String senderPattern;
  final int providerId;
  const ProviderSender(
      {required this.id,
      required this.senderPattern,
      required this.providerId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sender_pattern'] = Variable<String>(senderPattern);
    map['provider_id'] = Variable<int>(providerId);
    return map;
  }

  ProviderSendersCompanion toCompanion(bool nullToAbsent) {
    return ProviderSendersCompanion(
      id: Value(id),
      senderPattern: Value(senderPattern),
      providerId: Value(providerId),
    );
  }

  factory ProviderSender.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderSender(
      id: serializer.fromJson<int>(json['id']),
      senderPattern: serializer.fromJson<String>(json['senderPattern']),
      providerId: serializer.fromJson<int>(json['providerId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'senderPattern': serializer.toJson<String>(senderPattern),
      'providerId': serializer.toJson<int>(providerId),
    };
  }

  ProviderSender copyWith({int? id, String? senderPattern, int? providerId}) =>
      ProviderSender(
        id: id ?? this.id,
        senderPattern: senderPattern ?? this.senderPattern,
        providerId: providerId ?? this.providerId,
      );
  ProviderSender copyWithCompanion(ProviderSendersCompanion data) {
    return ProviderSender(
      id: data.id.present ? data.id.value : this.id,
      senderPattern: data.senderPattern.present
          ? data.senderPattern.value
          : this.senderPattern,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderSender(')
          ..write('id: $id, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('providerId: $providerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, senderPattern, providerId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderSender &&
          other.id == this.id &&
          other.senderPattern == this.senderPattern &&
          other.providerId == this.providerId);
}

class ProviderSendersCompanion extends UpdateCompanion<ProviderSender> {
  final Value<int> id;
  final Value<String> senderPattern;
  final Value<int> providerId;
  const ProviderSendersCompanion({
    this.id = const Value.absent(),
    this.senderPattern = const Value.absent(),
    this.providerId = const Value.absent(),
  });
  ProviderSendersCompanion.insert({
    this.id = const Value.absent(),
    required String senderPattern,
    required int providerId,
  })  : senderPattern = Value(senderPattern),
        providerId = Value(providerId);
  static Insertable<ProviderSender> custom({
    Expression<int>? id,
    Expression<String>? senderPattern,
    Expression<int>? providerId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (senderPattern != null) 'sender_pattern': senderPattern,
      if (providerId != null) 'provider_id': providerId,
    });
  }

  ProviderSendersCompanion copyWith(
      {Value<int>? id, Value<String>? senderPattern, Value<int>? providerId}) {
    return ProviderSendersCompanion(
      id: id ?? this.id,
      senderPattern: senderPattern ?? this.senderPattern,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (senderPattern.present) {
      map['sender_pattern'] = Variable<String>(senderPattern.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<int>(providerId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderSendersCompanion(')
          ..write('id: $id, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('providerId: $providerId')
          ..write(')'))
        .toString();
  }
}

class $SmsMessagesTable extends SmsMessages
    with TableInfo<$SmsMessagesTable, SmsMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmsMessagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _smsHashMeta =
      const VerificationMeta('smsHash');
  @override
  late final GeneratedColumn<String> smsHash = GeneratedColumn<String>(
      'sms_hash', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 64, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<int> providerId = GeneratedColumn<int>(
      'provider_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<SmsProcessingStatus, String>
      processingStatus = GeneratedColumn<String>(
              'processing_status', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: Constant(SmsProcessingStatus.pending.name))
          .withConverter<SmsProcessingStatus>(
              $SmsMessagesTable.$converterprocessingStatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sender,
        body,
        receivedAt,
        smsHash,
        providerId,
        processingStatus,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sms_messages';
  @override
  VerificationContext validateIntegrity(Insertable<SmsMessage> instance,
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
    if (data.containsKey('sms_hash')) {
      context.handle(_smsHashMeta,
          smsHash.isAcceptableOrUnknown(data['sms_hash']!, _smsHashMeta));
    } else if (isInserting) {
      context.missing(_smsHashMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {smsHash},
      ];
  @override
  SmsMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmsMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      smsHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sms_hash'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}provider_id']),
      processingStatus: $SmsMessagesTable.$converterprocessingStatus.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}processing_status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SmsMessagesTable createAlias(String alias) {
    return $SmsMessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SmsProcessingStatus, String, String>
      $converterprocessingStatus =
      const EnumNameConverter<SmsProcessingStatus>(SmsProcessingStatus.values);
}

class SmsMessage extends DataClass implements Insertable<SmsMessage> {
  final int id;
  final String sender;
  final String body;
  final DateTime receivedAt;

  /// SHA-256 of `sender|body|receivedAt.millisecondsSinceEpoch`, computed
  /// at insert time (see [AppDatabase.hashSmsMessage]). This is the
  /// dedup key: re-running a historical scan (a known v1 gap — see
  /// docs/AUDIT_PHASE_0.md §3.5) hits the unique constraint below and is
  /// silently skipped instead of double-inserting.
  final String smsHash;

  /// Nullable: set once a provider is identified for this message.
  /// Null means either not yet processed, or processed but no known
  /// provider matched the sender at all (a step before "parsed the
  /// body" — see ProviderDetector).
  final int? providerId;
  final SmsProcessingStatus processingStatus;
  final DateTime createdAt;
  const SmsMessage(
      {required this.id,
      required this.sender,
      required this.body,
      required this.receivedAt,
      required this.smsHash,
      this.providerId,
      required this.processingStatus,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['sms_hash'] = Variable<String>(smsHash);
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<int>(providerId);
    }
    {
      map['processing_status'] = Variable<String>(
          $SmsMessagesTable.$converterprocessingStatus.toSql(processingStatus));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SmsMessagesCompanion toCompanion(bool nullToAbsent) {
    return SmsMessagesCompanion(
      id: Value(id),
      sender: Value(sender),
      body: Value(body),
      receivedAt: Value(receivedAt),
      smsHash: Value(smsHash),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      processingStatus: Value(processingStatus),
      createdAt: Value(createdAt),
    );
  }

  factory SmsMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmsMessage(
      id: serializer.fromJson<int>(json['id']),
      sender: serializer.fromJson<String>(json['sender']),
      body: serializer.fromJson<String>(json['body']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      smsHash: serializer.fromJson<String>(json['smsHash']),
      providerId: serializer.fromJson<int?>(json['providerId']),
      processingStatus: $SmsMessagesTable.$converterprocessingStatus
          .fromJson(serializer.fromJson<String>(json['processingStatus'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
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
      'smsHash': serializer.toJson<String>(smsHash),
      'providerId': serializer.toJson<int?>(providerId),
      'processingStatus': serializer.toJson<String>($SmsMessagesTable
          .$converterprocessingStatus
          .toJson(processingStatus)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SmsMessage copyWith(
          {int? id,
          String? sender,
          String? body,
          DateTime? receivedAt,
          String? smsHash,
          Value<int?> providerId = const Value.absent(),
          SmsProcessingStatus? processingStatus,
          DateTime? createdAt}) =>
      SmsMessage(
        id: id ?? this.id,
        sender: sender ?? this.sender,
        body: body ?? this.body,
        receivedAt: receivedAt ?? this.receivedAt,
        smsHash: smsHash ?? this.smsHash,
        providerId: providerId.present ? providerId.value : this.providerId,
        processingStatus: processingStatus ?? this.processingStatus,
        createdAt: createdAt ?? this.createdAt,
      );
  SmsMessage copyWithCompanion(SmsMessagesCompanion data) {
    return SmsMessage(
      id: data.id.present ? data.id.value : this.id,
      sender: data.sender.present ? data.sender.value : this.sender,
      body: data.body.present ? data.body.value : this.body,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      smsHash: data.smsHash.present ? data.smsHash.value : this.smsHash,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      processingStatus: data.processingStatus.present
          ? data.processingStatus.value
          : this.processingStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmsMessage(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('smsHash: $smsHash, ')
          ..write('providerId: $providerId, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sender, body, receivedAt, smsHash,
      providerId, processingStatus, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmsMessage &&
          other.id == this.id &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.receivedAt == this.receivedAt &&
          other.smsHash == this.smsHash &&
          other.providerId == this.providerId &&
          other.processingStatus == this.processingStatus &&
          other.createdAt == this.createdAt);
}

class SmsMessagesCompanion extends UpdateCompanion<SmsMessage> {
  final Value<int> id;
  final Value<String> sender;
  final Value<String> body;
  final Value<DateTime> receivedAt;
  final Value<String> smsHash;
  final Value<int?> providerId;
  final Value<SmsProcessingStatus> processingStatus;
  final Value<DateTime> createdAt;
  const SmsMessagesCompanion({
    this.id = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.smsHash = const Value.absent(),
    this.providerId = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SmsMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String sender,
    required String body,
    required DateTime receivedAt,
    required String smsHash,
    this.providerId = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : sender = Value(sender),
        body = Value(body),
        receivedAt = Value(receivedAt),
        smsHash = Value(smsHash);
  static Insertable<SmsMessage> custom({
    Expression<int>? id,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<DateTime>? receivedAt,
    Expression<String>? smsHash,
    Expression<int>? providerId,
    Expression<String>? processingStatus,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (receivedAt != null) 'received_at': receivedAt,
      if (smsHash != null) 'sms_hash': smsHash,
      if (providerId != null) 'provider_id': providerId,
      if (processingStatus != null) 'processing_status': processingStatus,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SmsMessagesCompanion copyWith(
      {Value<int>? id,
      Value<String>? sender,
      Value<String>? body,
      Value<DateTime>? receivedAt,
      Value<String>? smsHash,
      Value<int?>? providerId,
      Value<SmsProcessingStatus>? processingStatus,
      Value<DateTime>? createdAt}) {
    return SmsMessagesCompanion(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      receivedAt: receivedAt ?? this.receivedAt,
      smsHash: smsHash ?? this.smsHash,
      providerId: providerId ?? this.providerId,
      processingStatus: processingStatus ?? this.processingStatus,
      createdAt: createdAt ?? this.createdAt,
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
    if (smsHash.present) {
      map['sms_hash'] = Variable<String>(smsHash.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<int>(providerId.value);
    }
    if (processingStatus.present) {
      map['processing_status'] = Variable<String>($SmsMessagesTable
          .$converterprocessingStatus
          .toSql(processingStatus.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmsMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('smsHash: $smsHash, ')
          ..write('providerId: $providerId, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<int> providerId = GeneratedColumn<int>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, providerId, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}provider_id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final int providerId;

  /// User-facing label, e.g. "My MTN MoMo". Defaults to the provider's
  /// own display name at creation time but is independently editable
  /// (spec Phase 7's account list implies users may rename accounts).
  final String label;
  const Account(
      {required this.id, required this.providerId, required this.label});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider_id'] = Variable<int>(providerId);
    map['label'] = Variable<String>(label);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      label: Value(label),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      providerId: serializer.fromJson<int>(json['providerId']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'providerId': serializer.toJson<int>(providerId),
      'label': serializer.toJson<String>(label),
    };
  }

  Account copyWith({int? id, int? providerId, String? label}) => Account(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        label: label ?? this.label,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, providerId, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.label == this.label);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<int> providerId;
  final Value<String> label;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.label = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required int providerId,
    required String label,
  })  : providerId = Value(providerId),
        label = Value(label);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<int>? providerId,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (label != null) 'label': label,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? id, Value<int>? providerId, Value<String>? label}) {
    return AccountsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<int>(providerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $MerchantsTable extends Merchants
    with TableInfo<$MerchantsTable, Merchant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantsTable(this.attachedDatabase, [this._alias]);
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
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 128),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _normalizedNameMeta =
      const VerificationMeta('normalizedName');
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
      'normalized_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 128),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchants';
  @override
  VerificationContext validateIntegrity(Insertable<Merchant> instance,
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
    if (data.containsKey('normalized_name')) {
      context.handle(
          _normalizedNameMeta,
          normalizedName.isAcceptableOrUnknown(
              data['normalized_name']!, _normalizedNameMeta));
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {normalizedName},
      ];
  @override
  Merchant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Merchant(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      normalizedName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_name'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
    );
  }

  @override
  $MerchantsTable createAlias(String alias) {
    return $MerchantsTable(attachedDatabase, alias);
  }
}

class Merchant extends DataClass implements Insertable<Merchant> {
  final int id;

  /// The merchant name as extracted from the SMS, with the trailing
  /// account/till code stripped — e.g. "THE FAMILYS BAKERY LTD" from
  /// "THE FAMILYS BAKERY LTD 096957". See
  /// `MerchantNormalizationService.extractMerchantName`.
  final String name;

  /// Uppercased, punctuation-stripped, whitespace-collapsed form of
  /// [name] — the actual matching key, so "Family Bakery Ltd" and
  /// "FAMILY BAKERY LTD." (different real messages, same real business)
  /// resolve to the same merchant instead of creating two rows.
  final String normalizedName;
  final int? categoryId;
  const Merchant(
      {required this.id,
      required this.name,
      required this.normalizedName,
      this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    return map;
  }

  MerchantsCompanion toCompanion(bool nullToAbsent) {
    return MerchantsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
    );
  }

  factory Merchant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Merchant(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'categoryId': serializer.toJson<int?>(categoryId),
    };
  }

  Merchant copyWith(
          {int? id,
          String? name,
          String? normalizedName,
          Value<int?> categoryId = const Value.absent()}) =>
      Merchant(
        id: id ?? this.id,
        name: name ?? this.name,
        normalizedName: normalizedName ?? this.normalizedName,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
      );
  Merchant copyWithCompanion(MerchantsCompanion data) {
    return Merchant(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Merchant(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Merchant &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.categoryId == this.categoryId);
}

class MerchantsCompanion extends UpdateCompanion<Merchant> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int?> categoryId;
  const MerchantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.categoryId = const Value.absent(),
  });
  MerchantsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String normalizedName,
    this.categoryId = const Value.absent(),
  })  : name = Value(name),
        normalizedName = Value(normalizedName);
  static Insertable<Merchant> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? categoryId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  MerchantsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? normalizedName,
      Value<int?>? categoryId}) {
    return MerchantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      categoryId: categoryId ?? this.categoryId,
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
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }
}

class $TransferLinksTable extends TransferLinks
    with TableInfo<$TransferLinksTable, TransferLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransferLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _fromTransactionIdMeta =
      const VerificationMeta('fromTransactionId');
  @override
  late final GeneratedColumn<int> fromTransactionId = GeneratedColumn<int>(
      'from_transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _toTransactionIdMeta =
      const VerificationMeta('toTransactionId');
  @override
  late final GeneratedColumn<int> toTransactionId = GeneratedColumn<int>(
      'to_transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TransferMatchConfidence, String>
      confidence = GeneratedColumn<String>('confidence', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<TransferMatchConfidence>(
              $TransferLinksTable.$converterconfidence);
  static const VerificationMeta _matchReasonMeta =
      const VerificationMeta('matchReason');
  @override
  late final GeneratedColumn<String> matchReason = GeneratedColumn<String>(
      'match_reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fromTransactionId,
        toTransactionId,
        confidence,
        matchReason,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfer_links';
  @override
  VerificationContext validateIntegrity(Insertable<TransferLink> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_transaction_id')) {
      context.handle(
          _fromTransactionIdMeta,
          fromTransactionId.isAcceptableOrUnknown(
              data['from_transaction_id']!, _fromTransactionIdMeta));
    } else if (isInserting) {
      context.missing(_fromTransactionIdMeta);
    }
    if (data.containsKey('to_transaction_id')) {
      context.handle(
          _toTransactionIdMeta,
          toTransactionId.isAcceptableOrUnknown(
              data['to_transaction_id']!, _toTransactionIdMeta));
    } else if (isInserting) {
      context.missing(_toTransactionIdMeta);
    }
    if (data.containsKey('match_reason')) {
      context.handle(
          _matchReasonMeta,
          matchReason.isAcceptableOrUnknown(
              data['match_reason']!, _matchReasonMeta));
    } else if (isInserting) {
      context.missing(_matchReasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {fromTransactionId, toTransactionId},
      ];
  @override
  TransferLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransferLink(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fromTransactionId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}from_transaction_id'])!,
      toTransactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_transaction_id'])!,
      confidence: $TransferLinksTable.$converterconfidence.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}confidence'])!),
      matchReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_reason'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransferLinksTable createAlias(String alias) {
    return $TransferLinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransferMatchConfidence, String, String>
      $converterconfidence = const EnumNameConverter<TransferMatchConfidence>(
          TransferMatchConfidence.values);
}

class TransferLink extends DataClass implements Insertable<TransferLink> {
  final int id;
  final int fromTransactionId;
  final int toTransactionId;
  final TransferMatchConfidence confidence;

  /// Free-text note on *why* the engine matched these two, e.g. "matched
  /// via shared reference 541077019015" or "matched via amount+time
  /// proximity, no shared reference" — surfaced in a future "why is
  /// this a transfer?" UI affordance rather than being a silent,
  /// unexplainable link.
  final String matchReason;
  final DateTime createdAt;
  const TransferLink(
      {required this.id,
      required this.fromTransactionId,
      required this.toTransactionId,
      required this.confidence,
      required this.matchReason,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_transaction_id'] = Variable<int>(fromTransactionId);
    map['to_transaction_id'] = Variable<int>(toTransactionId);
    {
      map['confidence'] = Variable<String>(
          $TransferLinksTable.$converterconfidence.toSql(confidence));
    }
    map['match_reason'] = Variable<String>(matchReason);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransferLinksCompanion toCompanion(bool nullToAbsent) {
    return TransferLinksCompanion(
      id: Value(id),
      fromTransactionId: Value(fromTransactionId),
      toTransactionId: Value(toTransactionId),
      confidence: Value(confidence),
      matchReason: Value(matchReason),
      createdAt: Value(createdAt),
    );
  }

  factory TransferLink.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransferLink(
      id: serializer.fromJson<int>(json['id']),
      fromTransactionId: serializer.fromJson<int>(json['fromTransactionId']),
      toTransactionId: serializer.fromJson<int>(json['toTransactionId']),
      confidence: $TransferLinksTable.$converterconfidence
          .fromJson(serializer.fromJson<String>(json['confidence'])),
      matchReason: serializer.fromJson<String>(json['matchReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromTransactionId': serializer.toJson<int>(fromTransactionId),
      'toTransactionId': serializer.toJson<int>(toTransactionId),
      'confidence': serializer.toJson<String>(
          $TransferLinksTable.$converterconfidence.toJson(confidence)),
      'matchReason': serializer.toJson<String>(matchReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransferLink copyWith(
          {int? id,
          int? fromTransactionId,
          int? toTransactionId,
          TransferMatchConfidence? confidence,
          String? matchReason,
          DateTime? createdAt}) =>
      TransferLink(
        id: id ?? this.id,
        fromTransactionId: fromTransactionId ?? this.fromTransactionId,
        toTransactionId: toTransactionId ?? this.toTransactionId,
        confidence: confidence ?? this.confidence,
        matchReason: matchReason ?? this.matchReason,
        createdAt: createdAt ?? this.createdAt,
      );
  TransferLink copyWithCompanion(TransferLinksCompanion data) {
    return TransferLink(
      id: data.id.present ? data.id.value : this.id,
      fromTransactionId: data.fromTransactionId.present
          ? data.fromTransactionId.value
          : this.fromTransactionId,
      toTransactionId: data.toTransactionId.present
          ? data.toTransactionId.value
          : this.toTransactionId,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
      matchReason:
          data.matchReason.present ? data.matchReason.value : this.matchReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransferLink(')
          ..write('id: $id, ')
          ..write('fromTransactionId: $fromTransactionId, ')
          ..write('toTransactionId: $toTransactionId, ')
          ..write('confidence: $confidence, ')
          ..write('matchReason: $matchReason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fromTransactionId, toTransactionId,
      confidence, matchReason, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransferLink &&
          other.id == this.id &&
          other.fromTransactionId == this.fromTransactionId &&
          other.toTransactionId == this.toTransactionId &&
          other.confidence == this.confidence &&
          other.matchReason == this.matchReason &&
          other.createdAt == this.createdAt);
}

class TransferLinksCompanion extends UpdateCompanion<TransferLink> {
  final Value<int> id;
  final Value<int> fromTransactionId;
  final Value<int> toTransactionId;
  final Value<TransferMatchConfidence> confidence;
  final Value<String> matchReason;
  final Value<DateTime> createdAt;
  const TransferLinksCompanion({
    this.id = const Value.absent(),
    this.fromTransactionId = const Value.absent(),
    this.toTransactionId = const Value.absent(),
    this.confidence = const Value.absent(),
    this.matchReason = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransferLinksCompanion.insert({
    this.id = const Value.absent(),
    required int fromTransactionId,
    required int toTransactionId,
    required TransferMatchConfidence confidence,
    required String matchReason,
    this.createdAt = const Value.absent(),
  })  : fromTransactionId = Value(fromTransactionId),
        toTransactionId = Value(toTransactionId),
        confidence = Value(confidence),
        matchReason = Value(matchReason);
  static Insertable<TransferLink> custom({
    Expression<int>? id,
    Expression<int>? fromTransactionId,
    Expression<int>? toTransactionId,
    Expression<String>? confidence,
    Expression<String>? matchReason,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromTransactionId != null) 'from_transaction_id': fromTransactionId,
      if (toTransactionId != null) 'to_transaction_id': toTransactionId,
      if (confidence != null) 'confidence': confidence,
      if (matchReason != null) 'match_reason': matchReason,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransferLinksCompanion copyWith(
      {Value<int>? id,
      Value<int>? fromTransactionId,
      Value<int>? toTransactionId,
      Value<TransferMatchConfidence>? confidence,
      Value<String>? matchReason,
      Value<DateTime>? createdAt}) {
    return TransferLinksCompanion(
      id: id ?? this.id,
      fromTransactionId: fromTransactionId ?? this.fromTransactionId,
      toTransactionId: toTransactionId ?? this.toTransactionId,
      confidence: confidence ?? this.confidence,
      matchReason: matchReason ?? this.matchReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromTransactionId.present) {
      map['from_transaction_id'] = Variable<int>(fromTransactionId.value);
    }
    if (toTransactionId.present) {
      map['to_transaction_id'] = Variable<int>(toTransactionId.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(
          $TransferLinksTable.$converterconfidence.toSql(confidence.value));
    }
    if (matchReason.present) {
      map['match_reason'] = Variable<String>(matchReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransferLinksCompanion(')
          ..write('id: $id, ')
          ..write('fromTransactionId: $fromTransactionId, ')
          ..write('toTransactionId: $toTransactionId, ')
          ..write('confidence: $confidence, ')
          ..write('matchReason: $matchReason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _appLockEnabledMeta =
      const VerificationMeta('appLockEnabled');
  @override
  late final GeneratedColumn<bool> appLockEnabled = GeneratedColumn<bool>(
      'app_lock_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("app_lock_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _onboardingCompletedAtMeta =
      const VerificationMeta('onboardingCompletedAt');
  @override
  late final GeneratedColumn<DateTime> onboardingCompletedAt =
      GeneratedColumn<DateTime>('onboarding_completed_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        displayName,
        email,
        phone,
        avatarPath,
        appLockEnabled,
        onboardingCompletedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('app_lock_enabled')) {
      context.handle(
          _appLockEnabledMeta,
          appLockEnabled.isAcceptableOrUnknown(
              data['app_lock_enabled']!, _appLockEnabledMeta));
    }
    if (data.containsKey('onboarding_completed_at')) {
      context.handle(
          _onboardingCompletedAtMeta,
          onboardingCompletedAt.isAcceptableOrUnknown(
              data['onboarding_completed_at']!, _onboardingCompletedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      appLockEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}app_lock_enabled'])!,
      onboardingCompletedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}onboarding_completed_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final int id;
  final String? displayName;

  /// Format-validated and confirmed via a code generated and displayed
  /// on this device's own screen — never actually delivered anywhere.
  /// This app declares no INTERNET permission and has no network-
  /// capable dependency, so there is no real OTP-delivery path; the
  /// confirmation step only catches typos/misreads, it does not prove
  /// mailbox ownership. See docs/ARCHITECTURE.md's onboarding section.
  final String? email;

  /// Format-validated only, not yet verified by any means — phone
  /// verification is explicitly deferred past this phase.
  final String? phone;

  /// Local file path under app storage, never a remote URL.
  final String? avatarPath;
  final bool appLockEnabled;

  /// Set once the onboarding flow (Welcome through Provider Setup) has
  /// been completed at least once. This is the source of truth
  /// `HomeShell` checks to decide whether to show onboarding — replacing
  /// the pre-Phase-5 proxy of "is SMS permission currently granted,"
  /// which conflated permission state with identity/setup completion.
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;
  const UserProfileData(
      {required this.id,
      this.displayName,
      this.email,
      this.phone,
      this.avatarPath,
      required this.appLockEnabled,
      this.onboardingCompletedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['app_lock_enabled'] = Variable<bool>(appLockEnabled);
    if (!nullToAbsent || onboardingCompletedAt != null) {
      map['onboarding_completed_at'] =
          Variable<DateTime>(onboardingCompletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      appLockEnabled: Value(appLockEnabled),
      onboardingCompletedAt: onboardingCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(onboardingCompletedAt),
      createdAt: Value(createdAt),
    );
  }

  factory UserProfileData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      appLockEnabled: serializer.fromJson<bool>(json['appLockEnabled']),
      onboardingCompletedAt:
          serializer.fromJson<DateTime?>(json['onboardingCompletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'appLockEnabled': serializer.toJson<bool>(appLockEnabled),
      'onboardingCompletedAt':
          serializer.toJson<DateTime?>(onboardingCompletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserProfileData copyWith(
          {int? id,
          Value<String?> displayName = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> avatarPath = const Value.absent(),
          bool? appLockEnabled,
          Value<DateTime?> onboardingCompletedAt = const Value.absent(),
          DateTime? createdAt}) =>
      UserProfileData(
        id: id ?? this.id,
        displayName: displayName.present ? displayName.value : this.displayName,
        email: email.present ? email.value : this.email,
        phone: phone.present ? phone.value : this.phone,
        avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        onboardingCompletedAt: onboardingCompletedAt.present
            ? onboardingCompletedAt.value
            : this.onboardingCompletedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatarPath:
          data.avatarPath.present ? data.avatarPath.value : this.avatarPath,
      appLockEnabled: data.appLockEnabled.present
          ? data.appLockEnabled.value
          : this.appLockEnabled,
      onboardingCompletedAt: data.onboardingCompletedAt.present
          ? data.onboardingCompletedAt.value
          : this.onboardingCompletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('appLockEnabled: $appLockEnabled, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, email, phone, avatarPath,
      appLockEnabled, onboardingCompletedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.avatarPath == this.avatarPath &&
          other.appLockEnabled == this.appLockEnabled &&
          other.onboardingCompletedAt == this.onboardingCompletedAt &&
          other.createdAt == this.createdAt);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<int> id;
  final Value<String?> displayName;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> avatarPath;
  final Value<bool> appLockEnabled;
  final Value<DateTime?> onboardingCompletedAt;
  final Value<DateTime> createdAt;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.appLockEnabled = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UserProfileCompanion.insert({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.appLockEnabled = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  static Insertable<UserProfileData> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? avatarPath,
    Expression<bool>? appLockEnabled,
    Expression<DateTime>? onboardingCompletedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (appLockEnabled != null) 'app_lock_enabled': appLockEnabled,
      if (onboardingCompletedAt != null)
        'onboarding_completed_at': onboardingCompletedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UserProfileCompanion copyWith(
      {Value<int>? id,
      Value<String?>? displayName,
      Value<String?>? email,
      Value<String?>? phone,
      Value<String?>? avatarPath,
      Value<bool>? appLockEnabled,
      Value<DateTime?>? onboardingCompletedAt,
      Value<DateTime>? createdAt}) {
    return UserProfileCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (appLockEnabled.present) {
      map['app_lock_enabled'] = Variable<bool>(appLockEnabled.value);
    }
    if (onboardingCompletedAt.present) {
      map['onboarding_completed_at'] =
          Variable<DateTime>(onboardingCompletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('appLockEnabled: $appLockEnabled, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserFinancialSourcesTable extends UserFinancialSources
    with TableInfo<$UserFinancialSourcesTable, UserFinancialSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserFinancialSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<int> providerId = GeneratedColumn<int>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _selectedAtMeta =
      const VerificationMeta('selectedAt');
  @override
  late final GeneratedColumn<DateTime> selectedAt = GeneratedColumn<DateTime>(
      'selected_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, providerId, selectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_financial_sources';
  @override
  VerificationContext validateIntegrity(
      Insertable<UserFinancialSource> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('selected_at')) {
      context.handle(
          _selectedAtMeta,
          selectedAt.isAcceptableOrUnknown(
              data['selected_at']!, _selectedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {providerId},
      ];
  @override
  UserFinancialSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserFinancialSource(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}provider_id'])!,
      selectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}selected_at'])!,
    );
  }

  @override
  $UserFinancialSourcesTable createAlias(String alias) {
    return $UserFinancialSourcesTable(attachedDatabase, alias);
  }
}

class UserFinancialSource extends DataClass
    implements Insertable<UserFinancialSource> {
  final int id;
  final int providerId;
  final DateTime selectedAt;
  const UserFinancialSource(
      {required this.id, required this.providerId, required this.selectedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider_id'] = Variable<int>(providerId);
    map['selected_at'] = Variable<DateTime>(selectedAt);
    return map;
  }

  UserFinancialSourcesCompanion toCompanion(bool nullToAbsent) {
    return UserFinancialSourcesCompanion(
      id: Value(id),
      providerId: Value(providerId),
      selectedAt: Value(selectedAt),
    );
  }

  factory UserFinancialSource.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserFinancialSource(
      id: serializer.fromJson<int>(json['id']),
      providerId: serializer.fromJson<int>(json['providerId']),
      selectedAt: serializer.fromJson<DateTime>(json['selectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'providerId': serializer.toJson<int>(providerId),
      'selectedAt': serializer.toJson<DateTime>(selectedAt),
    };
  }

  UserFinancialSource copyWith(
          {int? id, int? providerId, DateTime? selectedAt}) =>
      UserFinancialSource(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        selectedAt: selectedAt ?? this.selectedAt,
      );
  UserFinancialSource copyWithCompanion(UserFinancialSourcesCompanion data) {
    return UserFinancialSource(
      id: data.id.present ? data.id.value : this.id,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      selectedAt:
          data.selectedAt.present ? data.selectedAt.value : this.selectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserFinancialSource(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('selectedAt: $selectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, providerId, selectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserFinancialSource &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.selectedAt == this.selectedAt);
}

class UserFinancialSourcesCompanion
    extends UpdateCompanion<UserFinancialSource> {
  final Value<int> id;
  final Value<int> providerId;
  final Value<DateTime> selectedAt;
  const UserFinancialSourcesCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.selectedAt = const Value.absent(),
  });
  UserFinancialSourcesCompanion.insert({
    this.id = const Value.absent(),
    required int providerId,
    this.selectedAt = const Value.absent(),
  }) : providerId = Value(providerId);
  static Insertable<UserFinancialSource> custom({
    Expression<int>? id,
    Expression<int>? providerId,
    Expression<DateTime>? selectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (selectedAt != null) 'selected_at': selectedAt,
    });
  }

  UserFinancialSourcesCompanion copyWith(
      {Value<int>? id, Value<int>? providerId, Value<DateTime>? selectedAt}) {
    return UserFinancialSourcesCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      selectedAt: selectedAt ?? this.selectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<int>(providerId.value);
    }
    if (selectedAt.present) {
      map['selected_at'] = Variable<DateTime>(selectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserFinancialSourcesCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('selectedAt: $selectedAt')
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
  late final $FinancialProvidersTable financialProviders =
      $FinancialProvidersTable(this);
  late final $ProviderSendersTable providerSenders =
      $ProviderSendersTable(this);
  late final $SmsMessagesTable smsMessages = $SmsMessagesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $MerchantsTable merchants = $MerchantsTable(this);
  late final $TransferLinksTable transferLinks = $TransferLinksTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $UserFinancialSourcesTable userFinancialSources =
      $UserFinancialSourcesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        categories,
        categoryCodes,
        transactions,
        unparsedMessages,
        financialProviders,
        providerSenders,
        smsMessages,
        accounts,
        merchants,
        transferLinks,
        userProfile,
        userFinancialSources
      ];
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
  Value<int?> smsMessageId,
  Value<int?> providerId,
  Value<int?> accountId,
  Value<int?> merchantId,
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
  Value<int?> smsMessageId,
  Value<int?> providerId,
  Value<int?> accountId,
  Value<int?> merchantId,
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

  ColumnFilters<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get merchantId => $composableBuilder(
      column: $table.merchantId, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get merchantId => $composableBuilder(
      column: $table.merchantId, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId, builder: (column) => column);

  GeneratedColumn<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get merchantId => $composableBuilder(
      column: $table.merchantId, builder: (column) => column);

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
            Value<int?> smsMessageId = const Value.absent(),
            Value<int?> providerId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> merchantId = const Value.absent(),
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
            smsMessageId: smsMessageId,
            providerId: providerId,
            accountId: accountId,
            merchantId: merchantId,
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
            Value<int?> smsMessageId = const Value.absent(),
            Value<int?> providerId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> merchantId = const Value.absent(),
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
            smsMessageId: smsMessageId,
            providerId: providerId,
            accountId: accountId,
            merchantId: merchantId,
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
  Value<int?> smsMessageId,
  required String sender,
  required String body,
  required DateTime receivedAt,
  Value<bool> resolved,
});
typedef $$UnparsedMessagesTableUpdateCompanionBuilder
    = UnparsedMessagesCompanion Function({
  Value<int> id,
  Value<int?> smsMessageId,
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

  ColumnFilters<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId,
      builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<int> get smsMessageId => $composableBuilder(
      column: $table.smsMessageId, builder: (column) => column);

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
            Value<int?> smsMessageId = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<bool> resolved = const Value.absent(),
          }) =>
              UnparsedMessagesCompanion(
            id: id,
            smsMessageId: smsMessageId,
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            resolved: resolved,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> smsMessageId = const Value.absent(),
            required String sender,
            required String body,
            required DateTime receivedAt,
            Value<bool> resolved = const Value.absent(),
          }) =>
              UnparsedMessagesCompanion.insert(
            id: id,
            smsMessageId: smsMessageId,
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
typedef $$FinancialProvidersTableCreateCompanionBuilder
    = FinancialProvidersCompanion Function({
  Value<int> id,
  required String code,
  required String displayName,
  required String category,
});
typedef $$FinancialProvidersTableUpdateCompanionBuilder
    = FinancialProvidersCompanion Function({
  Value<int> id,
  Value<String> code,
  Value<String> displayName,
  Value<String> category,
});

class $$FinancialProvidersTableFilterComposer
    extends Composer<_$AppDatabase, $FinancialProvidersTable> {
  $$FinancialProvidersTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));
}

class $$FinancialProvidersTableOrderingComposer
    extends Composer<_$AppDatabase, $FinancialProvidersTable> {
  $$FinancialProvidersTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));
}

class $$FinancialProvidersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinancialProvidersTable> {
  $$FinancialProvidersTableAnnotationComposer({
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

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);
}

class $$FinancialProvidersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FinancialProvidersTable,
    FinancialProvider,
    $$FinancialProvidersTableFilterComposer,
    $$FinancialProvidersTableOrderingComposer,
    $$FinancialProvidersTableAnnotationComposer,
    $$FinancialProvidersTableCreateCompanionBuilder,
    $$FinancialProvidersTableUpdateCompanionBuilder,
    (
      FinancialProvider,
      BaseReferences<_$AppDatabase, $FinancialProvidersTable, FinancialProvider>
    ),
    FinancialProvider,
    PrefetchHooks Function()> {
  $$FinancialProvidersTableTableManager(
      _$AppDatabase db, $FinancialProvidersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinancialProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinancialProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinancialProvidersTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> category = const Value.absent(),
          }) =>
              FinancialProvidersCompanion(
            id: id,
            code: code,
            displayName: displayName,
            category: category,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String code,
            required String displayName,
            required String category,
          }) =>
              FinancialProvidersCompanion.insert(
            id: id,
            code: code,
            displayName: displayName,
            category: category,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FinancialProvidersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FinancialProvidersTable,
    FinancialProvider,
    $$FinancialProvidersTableFilterComposer,
    $$FinancialProvidersTableOrderingComposer,
    $$FinancialProvidersTableAnnotationComposer,
    $$FinancialProvidersTableCreateCompanionBuilder,
    $$FinancialProvidersTableUpdateCompanionBuilder,
    (
      FinancialProvider,
      BaseReferences<_$AppDatabase, $FinancialProvidersTable, FinancialProvider>
    ),
    FinancialProvider,
    PrefetchHooks Function()>;
typedef $$ProviderSendersTableCreateCompanionBuilder = ProviderSendersCompanion
    Function({
  Value<int> id,
  required String senderPattern,
  required int providerId,
});
typedef $$ProviderSendersTableUpdateCompanionBuilder = ProviderSendersCompanion
    Function({
  Value<int> id,
  Value<String> senderPattern,
  Value<int> providerId,
});

class $$ProviderSendersTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderSendersTable> {
  $$ProviderSendersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderPattern => $composableBuilder(
      column: $table.senderPattern, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));
}

class $$ProviderSendersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderSendersTable> {
  $$ProviderSendersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderPattern => $composableBuilder(
      column: $table.senderPattern,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));
}

class $$ProviderSendersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderSendersTable> {
  $$ProviderSendersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderPattern => $composableBuilder(
      column: $table.senderPattern, builder: (column) => column);

  GeneratedColumn<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);
}

class $$ProviderSendersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProviderSendersTable,
    ProviderSender,
    $$ProviderSendersTableFilterComposer,
    $$ProviderSendersTableOrderingComposer,
    $$ProviderSendersTableAnnotationComposer,
    $$ProviderSendersTableCreateCompanionBuilder,
    $$ProviderSendersTableUpdateCompanionBuilder,
    (
      ProviderSender,
      BaseReferences<_$AppDatabase, $ProviderSendersTable, ProviderSender>
    ),
    ProviderSender,
    PrefetchHooks Function()> {
  $$ProviderSendersTableTableManager(
      _$AppDatabase db, $ProviderSendersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderSendersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderSendersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderSendersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> senderPattern = const Value.absent(),
            Value<int> providerId = const Value.absent(),
          }) =>
              ProviderSendersCompanion(
            id: id,
            senderPattern: senderPattern,
            providerId: providerId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String senderPattern,
            required int providerId,
          }) =>
              ProviderSendersCompanion.insert(
            id: id,
            senderPattern: senderPattern,
            providerId: providerId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProviderSendersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProviderSendersTable,
    ProviderSender,
    $$ProviderSendersTableFilterComposer,
    $$ProviderSendersTableOrderingComposer,
    $$ProviderSendersTableAnnotationComposer,
    $$ProviderSendersTableCreateCompanionBuilder,
    $$ProviderSendersTableUpdateCompanionBuilder,
    (
      ProviderSender,
      BaseReferences<_$AppDatabase, $ProviderSendersTable, ProviderSender>
    ),
    ProviderSender,
    PrefetchHooks Function()>;
typedef $$SmsMessagesTableCreateCompanionBuilder = SmsMessagesCompanion
    Function({
  Value<int> id,
  required String sender,
  required String body,
  required DateTime receivedAt,
  required String smsHash,
  Value<int?> providerId,
  Value<SmsProcessingStatus> processingStatus,
  Value<DateTime> createdAt,
});
typedef $$SmsMessagesTableUpdateCompanionBuilder = SmsMessagesCompanion
    Function({
  Value<int> id,
  Value<String> sender,
  Value<String> body,
  Value<DateTime> receivedAt,
  Value<String> smsHash,
  Value<int?> providerId,
  Value<SmsProcessingStatus> processingStatus,
  Value<DateTime> createdAt,
});

class $$SmsMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $SmsMessagesTable> {
  $$SmsMessagesTableFilterComposer({
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

  ColumnFilters<String> get smsHash => $composableBuilder(
      column: $table.smsHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SmsProcessingStatus, SmsProcessingStatus,
          String>
      get processingStatus => $composableBuilder(
          column: $table.processingStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SmsMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SmsMessagesTable> {
  $$SmsMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get smsHash => $composableBuilder(
      column: $table.smsHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get processingStatus => $composableBuilder(
      column: $table.processingStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SmsMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SmsMessagesTable> {
  $$SmsMessagesTableAnnotationComposer({
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

  GeneratedColumn<String> get smsHash =>
      $composableBuilder(column: $table.smsHash, builder: (column) => column);

  GeneratedColumn<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SmsProcessingStatus, String>
      get processingStatus => $composableBuilder(
          column: $table.processingStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SmsMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SmsMessagesTable,
    SmsMessage,
    $$SmsMessagesTableFilterComposer,
    $$SmsMessagesTableOrderingComposer,
    $$SmsMessagesTableAnnotationComposer,
    $$SmsMessagesTableCreateCompanionBuilder,
    $$SmsMessagesTableUpdateCompanionBuilder,
    (SmsMessage, BaseReferences<_$AppDatabase, $SmsMessagesTable, SmsMessage>),
    SmsMessage,
    PrefetchHooks Function()> {
  $$SmsMessagesTableTableManager(_$AppDatabase db, $SmsMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmsMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmsMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmsMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<String> smsHash = const Value.absent(),
            Value<int?> providerId = const Value.absent(),
            Value<SmsProcessingStatus> processingStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SmsMessagesCompanion(
            id: id,
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            smsHash: smsHash,
            providerId: providerId,
            processingStatus: processingStatus,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sender,
            required String body,
            required DateTime receivedAt,
            required String smsHash,
            Value<int?> providerId = const Value.absent(),
            Value<SmsProcessingStatus> processingStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SmsMessagesCompanion.insert(
            id: id,
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            smsHash: smsHash,
            providerId: providerId,
            processingStatus: processingStatus,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SmsMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SmsMessagesTable,
    SmsMessage,
    $$SmsMessagesTableFilterComposer,
    $$SmsMessagesTableOrderingComposer,
    $$SmsMessagesTableAnnotationComposer,
    $$SmsMessagesTableCreateCompanionBuilder,
    $$SmsMessagesTableUpdateCompanionBuilder,
    (SmsMessage, BaseReferences<_$AppDatabase, $SmsMessagesTable, SmsMessage>),
    SmsMessage,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required int providerId,
  required String label,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<int> providerId,
  Value<String> label,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> providerId = const Value.absent(),
            Value<String> label = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            providerId: providerId,
            label: label,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int providerId,
            required String label,
          }) =>
              AccountsCompanion.insert(
            id: id,
            providerId: providerId,
            label: label,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$MerchantsTableCreateCompanionBuilder = MerchantsCompanion Function({
  Value<int> id,
  required String name,
  required String normalizedName,
  Value<int?> categoryId,
});
typedef $$MerchantsTableUpdateCompanionBuilder = MerchantsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<int?> categoryId,
});

class $$MerchantsTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableFilterComposer({
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

  ColumnFilters<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));
}

class $$MerchantsTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableOrderingComposer({
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

  ColumnOrderings<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));
}

class $$MerchantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableAnnotationComposer({
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

  GeneratedColumn<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);
}

class $$MerchantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MerchantsTable,
    Merchant,
    $$MerchantsTableFilterComposer,
    $$MerchantsTableOrderingComposer,
    $$MerchantsTableAnnotationComposer,
    $$MerchantsTableCreateCompanionBuilder,
    $$MerchantsTableUpdateCompanionBuilder,
    (Merchant, BaseReferences<_$AppDatabase, $MerchantsTable, Merchant>),
    Merchant,
    PrefetchHooks Function()> {
  $$MerchantsTableTableManager(_$AppDatabase db, $MerchantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> normalizedName = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
          }) =>
              MerchantsCompanion(
            id: id,
            name: name,
            normalizedName: normalizedName,
            categoryId: categoryId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String normalizedName,
            Value<int?> categoryId = const Value.absent(),
          }) =>
              MerchantsCompanion.insert(
            id: id,
            name: name,
            normalizedName: normalizedName,
            categoryId: categoryId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MerchantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MerchantsTable,
    Merchant,
    $$MerchantsTableFilterComposer,
    $$MerchantsTableOrderingComposer,
    $$MerchantsTableAnnotationComposer,
    $$MerchantsTableCreateCompanionBuilder,
    $$MerchantsTableUpdateCompanionBuilder,
    (Merchant, BaseReferences<_$AppDatabase, $MerchantsTable, Merchant>),
    Merchant,
    PrefetchHooks Function()>;
typedef $$TransferLinksTableCreateCompanionBuilder = TransferLinksCompanion
    Function({
  Value<int> id,
  required int fromTransactionId,
  required int toTransactionId,
  required TransferMatchConfidence confidence,
  required String matchReason,
  Value<DateTime> createdAt,
});
typedef $$TransferLinksTableUpdateCompanionBuilder = TransferLinksCompanion
    Function({
  Value<int> id,
  Value<int> fromTransactionId,
  Value<int> toTransactionId,
  Value<TransferMatchConfidence> confidence,
  Value<String> matchReason,
  Value<DateTime> createdAt,
});

class $$TransferLinksTableFilterComposer
    extends Composer<_$AppDatabase, $TransferLinksTable> {
  $$TransferLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fromTransactionId => $composableBuilder(
      column: $table.fromTransactionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toTransactionId => $composableBuilder(
      column: $table.toTransactionId,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TransferMatchConfidence,
          TransferMatchConfidence, String>
      get confidence => $composableBuilder(
          column: $table.confidence,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get matchReason => $composableBuilder(
      column: $table.matchReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TransferLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $TransferLinksTable> {
  $$TransferLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fromTransactionId => $composableBuilder(
      column: $table.fromTransactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toTransactionId => $composableBuilder(
      column: $table.toTransactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchReason => $composableBuilder(
      column: $table.matchReason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TransferLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransferLinksTable> {
  $$TransferLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fromTransactionId => $composableBuilder(
      column: $table.fromTransactionId, builder: (column) => column);

  GeneratedColumn<int> get toTransactionId => $composableBuilder(
      column: $table.toTransactionId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransferMatchConfidence, String>
      get confidence => $composableBuilder(
          column: $table.confidence, builder: (column) => column);

  GeneratedColumn<String> get matchReason => $composableBuilder(
      column: $table.matchReason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TransferLinksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransferLinksTable,
    TransferLink,
    $$TransferLinksTableFilterComposer,
    $$TransferLinksTableOrderingComposer,
    $$TransferLinksTableAnnotationComposer,
    $$TransferLinksTableCreateCompanionBuilder,
    $$TransferLinksTableUpdateCompanionBuilder,
    (
      TransferLink,
      BaseReferences<_$AppDatabase, $TransferLinksTable, TransferLink>
    ),
    TransferLink,
    PrefetchHooks Function()> {
  $$TransferLinksTableTableManager(_$AppDatabase db, $TransferLinksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransferLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransferLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransferLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> fromTransactionId = const Value.absent(),
            Value<int> toTransactionId = const Value.absent(),
            Value<TransferMatchConfidence> confidence = const Value.absent(),
            Value<String> matchReason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransferLinksCompanion(
            id: id,
            fromTransactionId: fromTransactionId,
            toTransactionId: toTransactionId,
            confidence: confidence,
            matchReason: matchReason,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int fromTransactionId,
            required int toTransactionId,
            required TransferMatchConfidence confidence,
            required String matchReason,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransferLinksCompanion.insert(
            id: id,
            fromTransactionId: fromTransactionId,
            toTransactionId: toTransactionId,
            confidence: confidence,
            matchReason: matchReason,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransferLinksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransferLinksTable,
    TransferLink,
    $$TransferLinksTableFilterComposer,
    $$TransferLinksTableOrderingComposer,
    $$TransferLinksTableAnnotationComposer,
    $$TransferLinksTableCreateCompanionBuilder,
    $$TransferLinksTableUpdateCompanionBuilder,
    (
      TransferLink,
      BaseReferences<_$AppDatabase, $TransferLinksTable, TransferLink>
    ),
    TransferLink,
    PrefetchHooks Function()>;
typedef $$UserProfileTableCreateCompanionBuilder = UserProfileCompanion
    Function({
  Value<int> id,
  Value<String?> displayName,
  Value<String?> email,
  Value<String?> phone,
  Value<String?> avatarPath,
  Value<bool> appLockEnabled,
  Value<DateTime?> onboardingCompletedAt,
  Value<DateTime> createdAt,
});
typedef $$UserProfileTableUpdateCompanionBuilder = UserProfileCompanion
    Function({
  Value<int> id,
  Value<String?> displayName,
  Value<String?> email,
  Value<String?> phone,
  Value<String?> avatarPath,
  Value<bool> appLockEnabled,
  Value<DateTime?> onboardingCompletedAt,
  Value<DateTime> createdAt,
});

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get appLockEnabled => $composableBuilder(
      column: $table.appLockEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get onboardingCompletedAt => $composableBuilder(
      column: $table.onboardingCompletedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get appLockEnabled => $composableBuilder(
      column: $table.appLockEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get onboardingCompletedAt => $composableBuilder(
      column: $table.onboardingCompletedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => column);

  GeneratedColumn<bool> get appLockEnabled => $composableBuilder(
      column: $table.appLockEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get onboardingCompletedAt => $composableBuilder(
      column: $table.onboardingCompletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UserProfileTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileData,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileData,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>
    ),
    UserProfileData,
    PrefetchHooks Function()> {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<bool> appLockEnabled = const Value.absent(),
            Value<DateTime?> onboardingCompletedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UserProfileCompanion(
            id: id,
            displayName: displayName,
            email: email,
            phone: phone,
            avatarPath: avatarPath,
            appLockEnabled: appLockEnabled,
            onboardingCompletedAt: onboardingCompletedAt,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<bool> appLockEnabled = const Value.absent(),
            Value<DateTime?> onboardingCompletedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UserProfileCompanion.insert(
            id: id,
            displayName: displayName,
            email: email,
            phone: phone,
            avatarPath: avatarPath,
            appLockEnabled: appLockEnabled,
            onboardingCompletedAt: onboardingCompletedAt,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfileTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileData,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileData,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>
    ),
    UserProfileData,
    PrefetchHooks Function()>;
typedef $$UserFinancialSourcesTableCreateCompanionBuilder
    = UserFinancialSourcesCompanion Function({
  Value<int> id,
  required int providerId,
  Value<DateTime> selectedAt,
});
typedef $$UserFinancialSourcesTableUpdateCompanionBuilder
    = UserFinancialSourcesCompanion Function({
  Value<int> id,
  Value<int> providerId,
  Value<DateTime> selectedAt,
});

class $$UserFinancialSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $UserFinancialSourcesTable> {
  $$UserFinancialSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get selectedAt => $composableBuilder(
      column: $table.selectedAt, builder: (column) => ColumnFilters(column));
}

class $$UserFinancialSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserFinancialSourcesTable> {
  $$UserFinancialSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get selectedAt => $composableBuilder(
      column: $table.selectedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserFinancialSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserFinancialSourcesTable> {
  $$UserFinancialSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<DateTime> get selectedAt => $composableBuilder(
      column: $table.selectedAt, builder: (column) => column);
}

class $$UserFinancialSourcesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserFinancialSourcesTable,
    UserFinancialSource,
    $$UserFinancialSourcesTableFilterComposer,
    $$UserFinancialSourcesTableOrderingComposer,
    $$UserFinancialSourcesTableAnnotationComposer,
    $$UserFinancialSourcesTableCreateCompanionBuilder,
    $$UserFinancialSourcesTableUpdateCompanionBuilder,
    (
      UserFinancialSource,
      BaseReferences<_$AppDatabase, $UserFinancialSourcesTable,
          UserFinancialSource>
    ),
    UserFinancialSource,
    PrefetchHooks Function()> {
  $$UserFinancialSourcesTableTableManager(
      _$AppDatabase db, $UserFinancialSourcesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserFinancialSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserFinancialSourcesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserFinancialSourcesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> providerId = const Value.absent(),
            Value<DateTime> selectedAt = const Value.absent(),
          }) =>
              UserFinancialSourcesCompanion(
            id: id,
            providerId: providerId,
            selectedAt: selectedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int providerId,
            Value<DateTime> selectedAt = const Value.absent(),
          }) =>
              UserFinancialSourcesCompanion.insert(
            id: id,
            providerId: providerId,
            selectedAt: selectedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserFinancialSourcesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $UserFinancialSourcesTable,
        UserFinancialSource,
        $$UserFinancialSourcesTableFilterComposer,
        $$UserFinancialSourcesTableOrderingComposer,
        $$UserFinancialSourcesTableAnnotationComposer,
        $$UserFinancialSourcesTableCreateCompanionBuilder,
        $$UserFinancialSourcesTableUpdateCompanionBuilder,
        (
          UserFinancialSource,
          BaseReferences<_$AppDatabase, $UserFinancialSourcesTable,
              UserFinancialSource>
        ),
        UserFinancialSource,
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
  $$FinancialProvidersTableTableManager get financialProviders =>
      $$FinancialProvidersTableTableManager(_db, _db.financialProviders);
  $$ProviderSendersTableTableManager get providerSenders =>
      $$ProviderSendersTableTableManager(_db, _db.providerSenders);
  $$SmsMessagesTableTableManager get smsMessages =>
      $$SmsMessagesTableTableManager(_db, _db.smsMessages);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$MerchantsTableTableManager get merchants =>
      $$MerchantsTableTableManager(_db, _db.merchants);
  $$TransferLinksTableTableManager get transferLinks =>
      $$TransferLinksTableTableManager(_db, _db.transferLinks);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$UserFinancialSourcesTableTableManager get userFinancialSources =>
      $$UserFinancialSourcesTableTableManager(_db, _db.userFinancialSources);
}
