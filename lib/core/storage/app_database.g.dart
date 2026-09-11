// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncQueueItemsTable extends SyncQueueItems
    with TableInfo<$SyncQueueItemsTable, SyncQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _neverAbandonMeta = const VerificationMeta(
    'neverAbandon',
  );
  @override
  late final GeneratedColumn<bool> neverAbandon = GeneratedColumn<bool>(
    'never_abandon',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("never_abandon" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idempotencyKey,
    method,
    path,
    payload,
    priority,
    status,
    attempts,
    lastError,
    createdAt,
    nextAttemptAt,
    neverAbandon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('never_abandon')) {
      context.handle(
        _neverAbandonMeta,
        neverAbandon.isAcceptableOrUnknown(
          data['never_abandon']!,
          _neverAbandonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      neverAbandon: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}never_abandon'],
      )!,
    );
  }

  @override
  $SyncQueueItemsTable createAlias(String alias) {
    return $SyncQueueItemsTable(attachedDatabase, alias);
  }
}

class SyncQueueItem extends DataClass implements Insertable<SyncQueueItem> {
  final String id;

  /// Cle d'idempotence generee par le client (EXI-S01), stable entre reprises.
  final String idempotencyKey;
  final String method;
  final String path;
  final String payload;

  /// Ordre de priorite EXI-S02 : constats(0) > transitions(1) > positions(2) > notations(3).
  final int priority;

  /// `pending` | `inFlight` | `failed` | `abandoned`
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;

  /// Un constat n'est jamais abandonne automatiquement (EXI-S05).
  final bool neverAbandon;
  const SyncQueueItem({
    required this.id,
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.payload,
    required this.priority,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    this.nextAttemptAt,
    required this.neverAbandon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['payload'] = Variable<String>(payload);
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['never_abandon'] = Variable<bool>(neverAbandon);
    return map;
  }

  SyncQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueItemsCompanion(
      id: Value(id),
      idempotencyKey: Value(idempotencyKey),
      method: Value(method),
      path: Value(path),
      payload: Value(payload),
      priority: Value(priority),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      neverAbandon: Value(neverAbandon),
    );
  }

  factory SyncQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueItem(
      id: serializer.fromJson<String>(json['id']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      payload: serializer.fromJson<String>(json['payload']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      neverAbandon: serializer.fromJson<bool>(json['neverAbandon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'payload': serializer.toJson<String>(payload),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'neverAbandon': serializer.toJson<bool>(neverAbandon),
    };
  }

  SyncQueueItem copyWith({
    String? id,
    String? idempotencyKey,
    String? method,
    String? path,
    String? payload,
    int? priority,
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    bool? neverAbandon,
  }) => SyncQueueItem(
    id: id ?? this.id,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    method: method ?? this.method,
    path: path ?? this.path,
    payload: payload ?? this.payload,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    neverAbandon: neverAbandon ?? this.neverAbandon,
  );
  SyncQueueItem copyWithCompanion(SyncQueueItemsCompanion data) {
    return SyncQueueItem(
      id: data.id.present ? data.id.value : this.id,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      payload: data.payload.present ? data.payload.value : this.payload,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      neverAbandon: data.neverAbandon.present
          ? data.neverAbandon.value
          : this.neverAbandon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItem(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('neverAbandon: $neverAbandon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idempotencyKey,
    method,
    path,
    payload,
    priority,
    status,
    attempts,
    lastError,
    createdAt,
    nextAttemptAt,
    neverAbandon,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueItem &&
          other.id == this.id &&
          other.idempotencyKey == this.idempotencyKey &&
          other.method == this.method &&
          other.path == this.path &&
          other.payload == this.payload &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.neverAbandon == this.neverAbandon);
}

class SyncQueueItemsCompanion extends UpdateCompanion<SyncQueueItem> {
  final Value<String> id;
  final Value<String> idempotencyKey;
  final Value<String> method;
  final Value<String> path;
  final Value<String> payload;
  final Value<int> priority;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<bool> neverAbandon;
  final Value<int> rowid;
  const SyncQueueItemsCompanion({
    this.id = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.payload = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.neverAbandon = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueItemsCompanion.insert({
    required String id,
    required String idempotencyKey,
    required String method,
    required String path,
    required String payload,
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.nextAttemptAt = const Value.absent(),
    this.neverAbandon = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       idempotencyKey = Value(idempotencyKey),
       method = Value(method),
       path = Value(path),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueItem> custom({
    Expression<String>? id,
    Expression<String>? idempotencyKey,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? payload,
    Expression<int>? priority,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<bool>? neverAbandon,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (payload != null) 'payload': payload,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (neverAbandon != null) 'never_abandon': neverAbandon,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? idempotencyKey,
    Value<String>? method,
    Value<String>? path,
    Value<String>? payload,
    Value<int>? priority,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime?>? nextAttemptAt,
    Value<bool>? neverAbandon,
    Value<int>? rowid,
  }) {
    return SyncQueueItemsCompanion(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      method: method ?? this.method,
      path: path ?? this.path,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      neverAbandon: neverAbandon ?? this.neverAbandon,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (neverAbandon.present) {
      map['never_abandon'] = Variable<bool>(neverAbandon.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('neverAbandon: $neverAbandon, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppEventsTable extends AppEvents
    with TableInfo<$AppEventsTable, AppEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, payload, occurredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $AppEventsTable createAlias(String alias) {
    return $AppEventsTable(attachedDatabase, alias);
  }
}

class AppEvent extends DataClass implements Insertable<AppEvent> {
  final int id;
  final String kind;
  final String? payload;
  final DateTime occurredAt;
  const AppEvent({
    required this.id,
    required this.kind,
    this.payload,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  AppEventsCompanion toCompanion(bool nullToAbsent) {
    return AppEventsCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      occurredAt: Value(occurredAt),
    );
  }

  factory AppEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppEvent(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String?>(json['payload']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String?>(payload),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  AppEvent copyWith({
    int? id,
    String? kind,
    Value<String?> payload = const Value.absent(),
    DateTime? occurredAt,
  }) => AppEvent(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload.present ? payload.value : this.payload,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  AppEvent copyWithCompanion(AppEventsCompanion data) {
    return AppEvent(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppEvent(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, payload, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppEvent &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.occurredAt == this.occurredAt);
}

class AppEventsCompanion extends UpdateCompanion<AppEvent> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String?> payload;
  final Value<DateTime> occurredAt;
  const AppEventsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  AppEventsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    this.payload = const Value.absent(),
    required DateTime occurredAt,
  }) : kind = Value(kind),
       occurredAt = Value(occurredAt);
  static Insertable<AppEvent> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  AppEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String?>? payload,
    Value<DateTime>? occurredAt,
  }) {
    return AppEventsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppEventsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $CachedDocumentsTable extends CachedDocuments
    with TableInfo<$CachedDocumentsTable, CachedDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, body, fetchedAt, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocument(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $CachedDocumentsTable createAlias(String alias) {
    return $CachedDocumentsTable(attachedDatabase, alias);
  }
}

class CachedDocument extends DataClass implements Insertable<CachedDocument> {
  final String key;
  final String body;
  final DateTime fetchedAt;
  final DateTime? expiresAt;
  const CachedDocument({
    required this.key,
    required this.body,
    required this.fetchedAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['body'] = Variable<String>(body);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  CachedDocumentsCompanion toCompanion(bool nullToAbsent) {
    return CachedDocumentsCompanion(
      key: Value(key),
      body: Value(body),
      fetchedAt: Value(fetchedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory CachedDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocument(
      key: serializer.fromJson<String>(json['key']),
      body: serializer.fromJson<String>(json['body']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'body': serializer.toJson<String>(body),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  CachedDocument copyWith({
    String? key,
    String? body,
    DateTime? fetchedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => CachedDocument(
    key: key ?? this.key,
    body: body ?? this.body,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  CachedDocument copyWithCompanion(CachedDocumentsCompanion data) {
    return CachedDocument(
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocument(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, body, fetchedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocument &&
          other.key == this.key &&
          other.body == this.body &&
          other.fetchedAt == this.fetchedAt &&
          other.expiresAt == this.expiresAt);
}

class CachedDocumentsCompanion extends UpdateCompanion<CachedDocument> {
  final Value<String> key;
  final Value<String> body;
  final Value<DateTime> fetchedAt;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const CachedDocumentsCompanion({
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocumentsCompanion.insert({
    required String key,
    required String body,
    required DateTime fetchedAt,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       body = Value(body),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedDocument> custom({
    Expression<String>? key,
    Expression<String>? body,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocumentsCompanion copyWith({
    Value<String>? key,
    Value<String>? body,
    Value<DateTime>? fetchedAt,
    Value<DateTime?>? expiresAt,
    Value<int>? rowid,
  }) {
    return CachedDocumentsCompanion(
      key: key ?? this.key,
      body: body ?? this.body,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsCompanion(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedAddressesTable extends SavedAddresses
    with TableInfo<$SavedAddressesTable, SavedAddressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedAddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    payload,
    useCount,
    lastUsedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedAddressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedAddressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedAddressesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SavedAddressesTable createAlias(String alias) {
    return $SavedAddressesTable(attachedDatabase, alias);
  }
}

class SavedAddressesData extends DataClass
    implements Insertable<SavedAddressesData> {
  final String id;
  final String label;

  /// Adresse serialisee. Un blob JSON plutot qu'une colonne par champ : la
  /// forme de l'adresse composite (§4.3) evoluera — photo de facade, note
  /// vocale, point relais — et chaque ajout imposerait sinon une migration.
  final String payload;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  const SavedAddressesData({
    required this.id,
    required this.label,
    required this.payload,
    required this.useCount,
    this.lastUsedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['payload'] = Variable<String>(payload);
    map['use_count'] = Variable<int>(useCount);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavedAddressesCompanion toCompanion(bool nullToAbsent) {
    return SavedAddressesCompanion(
      id: Value(id),
      label: Value(label),
      payload: Value(payload),
      useCount: Value(useCount),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SavedAddressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedAddressesData(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      payload: serializer.fromJson<String>(json['payload']),
      useCount: serializer.fromJson<int>(json['useCount']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'payload': serializer.toJson<String>(payload),
      'useCount': serializer.toJson<int>(useCount),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavedAddressesData copyWith({
    String? id,
    String? label,
    String? payload,
    int? useCount,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    DateTime? createdAt,
  }) => SavedAddressesData(
    id: id ?? this.id,
    label: label ?? this.label,
    payload: payload ?? this.payload,
    useCount: useCount ?? this.useCount,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SavedAddressesData copyWithCompanion(SavedAddressesCompanion data) {
    return SavedAddressesData(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      payload: data.payload.present ? data.payload.value : this.payload,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedAddressesData(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('payload: $payload, ')
          ..write('useCount: $useCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, payload, useCount, lastUsedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedAddressesData &&
          other.id == this.id &&
          other.label == this.label &&
          other.payload == this.payload &&
          other.useCount == this.useCount &&
          other.lastUsedAt == this.lastUsedAt &&
          other.createdAt == this.createdAt);
}

class SavedAddressesCompanion extends UpdateCompanion<SavedAddressesData> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> payload;
  final Value<int> useCount;
  final Value<DateTime?> lastUsedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SavedAddressesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.payload = const Value.absent(),
    this.useCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedAddressesCompanion.insert({
    required String id,
    required String label,
    required String payload,
    this.useCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SavedAddressesData> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? payload,
    Expression<int>? useCount,
    Expression<DateTime>? lastUsedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (payload != null) 'payload': payload,
      if (useCount != null) 'use_count': useCount,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedAddressesCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? payload,
    Value<int>? useCount,
    Value<DateTime?>? lastUsedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SavedAddressesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      payload: payload ?? this.payload,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedAddressesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('payload: $payload, ')
          ..write('useCount: $useCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDeliveriesTable extends CachedDeliveries
    with TableInfo<$CachedDeliveriesTable, CachedDelivery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDeliveriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    payload,
    createdAt,
    updatedAt,
    pendingSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_deliveries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDelivery> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedDelivery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDelivery(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
    );
  }

  @override
  $CachedDeliveriesTable createAlias(String alias) {
    return $CachedDeliveriesTable(attachedDatabase, alias);
  }
}

class CachedDelivery extends DataClass implements Insertable<CachedDelivery> {
  final String id;
  final String status;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Vrai tant que le serveur n'a pas confirme la course.
  final bool pendingSync;
  const CachedDelivery({
    required this.id,
    required this.status,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.pendingSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['pending_sync'] = Variable<bool>(pendingSync);
    return map;
  }

  CachedDeliveriesCompanion toCompanion(bool nullToAbsent) {
    return CachedDeliveriesCompanion(
      id: Value(id),
      status: Value(status),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pendingSync: Value(pendingSync),
    );
  }

  factory CachedDelivery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDelivery(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'pendingSync': serializer.toJson<bool>(pendingSync),
    };
  }

  CachedDelivery copyWith({
    String? id,
    String? status,
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
  }) => CachedDelivery(
    id: id ?? this.id,
    status: status ?? this.status,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pendingSync: pendingSync ?? this.pendingSync,
  );
  CachedDelivery copyWithCompanion(CachedDeliveriesCompanion data) {
    return CachedDelivery(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDelivery(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pendingSync: $pendingSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, status, payload, createdAt, updatedAt, pendingSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDelivery &&
          other.id == this.id &&
          other.status == this.status &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pendingSync == this.pendingSync);
}

class CachedDeliveriesCompanion extends UpdateCompanion<CachedDelivery> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> pendingSync;
  final Value<int> rowid;
  const CachedDeliveriesCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDeliveriesCompanion.insert({
    required String id,
    required String status,
    required String payload,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.pendingSync = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CachedDelivery> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? pendingSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDeliveriesCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? pendingSync,
    Value<int>? rowid,
  }) {
    return CachedDeliveriesCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDeliveriesCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BufferedPositionsTable extends BufferedPositions
    with TableInfo<$BufferedPositionsTable, BufferedPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BufferedPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deliveryIdMeta = const VerificationMeta(
    'deliveryId',
  );
  @override
  late final GeneratedColumn<String> deliveryId = GeneratedColumn<String>(
    'delivery_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedKmhMeta = const VerificationMeta(
    'speedKmh',
  );
  @override
  late final GeneratedColumn<double> speedKmh = GeneratedColumn<double>(
    'speed_kmh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accuracyMetersMeta = const VerificationMeta(
    'accuracyMeters',
  );
  @override
  late final GeneratedColumn<double> accuracyMeters = GeneratedColumn<double>(
    'accuracy_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deliveryId,
    latitude,
    longitude,
    speedKmh,
    accuracyMeters,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buffered_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BufferedPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('delivery_id')) {
      context.handle(
        _deliveryIdMeta,
        deliveryId.isAcceptableOrUnknown(data['delivery_id']!, _deliveryIdMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('speed_kmh')) {
      context.handle(
        _speedKmhMeta,
        speedKmh.isAcceptableOrUnknown(data['speed_kmh']!, _speedKmhMeta),
      );
    }
    if (data.containsKey('accuracy_meters')) {
      context.handle(
        _accuracyMetersMeta,
        accuracyMeters.isAcceptableOrUnknown(
          data['accuracy_meters']!,
          _accuracyMetersMeta,
        ),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BufferedPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BufferedPosition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deliveryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_id'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      speedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_kmh'],
      ),
      accuracyMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_meters'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $BufferedPositionsTable createAlias(String alias) {
    return $BufferedPositionsTable(attachedDatabase, alias);
  }
}

class BufferedPosition extends DataClass
    implements Insertable<BufferedPosition> {
  final int id;

  /// Course concernee, lorsque la position en accompagne une.
  final String? deliveryId;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? accuracyMeters;

  /// Horodatage de la mesure, pas de l'envoi : c'est le moment ou le livreur
  /// etait la, et il ne doit pas etre reecrit par la date de transmission.
  final DateTime recordedAt;
  const BufferedPosition({
    required this.id,
    this.deliveryId,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.accuracyMeters,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || deliveryId != null) {
      map['delivery_id'] = Variable<String>(deliveryId);
    }
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || speedKmh != null) {
      map['speed_kmh'] = Variable<double>(speedKmh);
    }
    if (!nullToAbsent || accuracyMeters != null) {
      map['accuracy_meters'] = Variable<double>(accuracyMeters);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  BufferedPositionsCompanion toCompanion(bool nullToAbsent) {
    return BufferedPositionsCompanion(
      id: Value(id),
      deliveryId: deliveryId == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveryId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      speedKmh: speedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(speedKmh),
      accuracyMeters: accuracyMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyMeters),
      recordedAt: Value(recordedAt),
    );
  }

  factory BufferedPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BufferedPosition(
      id: serializer.fromJson<int>(json['id']),
      deliveryId: serializer.fromJson<String?>(json['deliveryId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      speedKmh: serializer.fromJson<double?>(json['speedKmh']),
      accuracyMeters: serializer.fromJson<double?>(json['accuracyMeters']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deliveryId': serializer.toJson<String?>(deliveryId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'speedKmh': serializer.toJson<double?>(speedKmh),
      'accuracyMeters': serializer.toJson<double?>(accuracyMeters),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  BufferedPosition copyWith({
    int? id,
    Value<String?> deliveryId = const Value.absent(),
    double? latitude,
    double? longitude,
    Value<double?> speedKmh = const Value.absent(),
    Value<double?> accuracyMeters = const Value.absent(),
    DateTime? recordedAt,
  }) => BufferedPosition(
    id: id ?? this.id,
    deliveryId: deliveryId.present ? deliveryId.value : this.deliveryId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    speedKmh: speedKmh.present ? speedKmh.value : this.speedKmh,
    accuracyMeters: accuracyMeters.present
        ? accuracyMeters.value
        : this.accuracyMeters,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  BufferedPosition copyWithCompanion(BufferedPositionsCompanion data) {
    return BufferedPosition(
      id: data.id.present ? data.id.value : this.id,
      deliveryId: data.deliveryId.present
          ? data.deliveryId.value
          : this.deliveryId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      speedKmh: data.speedKmh.present ? data.speedKmh.value : this.speedKmh,
      accuracyMeters: data.accuracyMeters.present
          ? data.accuracyMeters.value
          : this.accuracyMeters,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BufferedPosition(')
          ..write('id: $id, ')
          ..write('deliveryId: $deliveryId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deliveryId,
    latitude,
    longitude,
    speedKmh,
    accuracyMeters,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BufferedPosition &&
          other.id == this.id &&
          other.deliveryId == this.deliveryId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.speedKmh == this.speedKmh &&
          other.accuracyMeters == this.accuracyMeters &&
          other.recordedAt == this.recordedAt);
}

class BufferedPositionsCompanion extends UpdateCompanion<BufferedPosition> {
  final Value<int> id;
  final Value<String?> deliveryId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> speedKmh;
  final Value<double?> accuracyMeters;
  final Value<DateTime> recordedAt;
  const BufferedPositionsCompanion({
    this.id = const Value.absent(),
    this.deliveryId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.speedKmh = const Value.absent(),
    this.accuracyMeters = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  BufferedPositionsCompanion.insert({
    this.id = const Value.absent(),
    this.deliveryId = const Value.absent(),
    required double latitude,
    required double longitude,
    this.speedKmh = const Value.absent(),
    this.accuracyMeters = const Value.absent(),
    required DateTime recordedAt,
  }) : latitude = Value(latitude),
       longitude = Value(longitude),
       recordedAt = Value(recordedAt);
  static Insertable<BufferedPosition> custom({
    Expression<int>? id,
    Expression<String>? deliveryId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? speedKmh,
    Expression<double>? accuracyMeters,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deliveryId != null) 'delivery_id': deliveryId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  BufferedPositionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? deliveryId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? speedKmh,
    Value<double?>? accuracyMeters,
    Value<DateTime>? recordedAt,
  }) {
    return BufferedPositionsCompanion(
      id: id ?? this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deliveryId.present) {
      map['delivery_id'] = Variable<String>(deliveryId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (speedKmh.present) {
      map['speed_kmh'] = Variable<double>(speedKmh.value);
    }
    if (accuracyMeters.present) {
      map['accuracy_meters'] = Variable<double>(accuracyMeters.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BufferedPositionsCompanion(')
          ..write('id: $id, ')
          ..write('deliveryId: $deliveryId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncQueueItemsTable syncQueueItems = $SyncQueueItemsTable(this);
  late final $AppEventsTable appEvents = $AppEventsTable(this);
  late final $CachedDocumentsTable cachedDocuments = $CachedDocumentsTable(
    this,
  );
  late final $SavedAddressesTable savedAddresses = $SavedAddressesTable(this);
  late final $CachedDeliveriesTable cachedDeliveries = $CachedDeliveriesTable(
    this,
  );
  late final $BufferedPositionsTable bufferedPositions =
      $BufferedPositionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncQueueItems,
    appEvents,
    cachedDocuments,
    savedAddresses,
    cachedDeliveries,
    bufferedPositions,
  ];
}

typedef $$SyncQueueItemsTableCreateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      required String id,
      required String idempotencyKey,
      required String method,
      required String path,
      required String payload,
      Value<int> priority,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<bool> neverAbandon,
      Value<int> rowid,
    });
typedef $$SyncQueueItemsTableUpdateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      Value<String> id,
      Value<String> idempotencyKey,
      Value<String> method,
      Value<String> path,
      Value<String> payload,
      Value<int> priority,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<bool> neverAbandon,
      Value<int> rowid,
    });

class $$SyncQueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableFilterComposer({
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

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get neverAbandon => $composableBuilder(
    column: $table.neverAbandon,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableOrderingComposer({
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

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get neverAbandon => $composableBuilder(
    column: $table.neverAbandon,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get neverAbandon => $composableBuilder(
    column: $table.neverAbandon,
    builder: (column) => column,
  );
}

class $$SyncQueueItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueItemsTable,
          SyncQueueItem,
          $$SyncQueueItemsTableFilterComposer,
          $$SyncQueueItemsTableOrderingComposer,
          $$SyncQueueItemsTableAnnotationComposer,
          $$SyncQueueItemsTableCreateCompanionBuilder,
          $$SyncQueueItemsTableUpdateCompanionBuilder,
          (
            SyncQueueItem,
            BaseReferences<_$AppDatabase, $SyncQueueItemsTable, SyncQueueItem>,
          ),
          SyncQueueItem,
          PrefetchHooks Function()
        > {
  $$SyncQueueItemsTableTableManager(
    _$AppDatabase db,
    $SyncQueueItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<bool> neverAbandon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueItemsCompanion(
                id: id,
                idempotencyKey: idempotencyKey,
                method: method,
                path: path,
                payload: payload,
                priority: priority,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                neverAbandon: neverAbandon,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String idempotencyKey,
                required String method,
                required String path,
                required String payload,
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<bool> neverAbandon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueItemsCompanion.insert(
                id: id,
                idempotencyKey: idempotencyKey,
                method: method,
                path: path,
                payload: payload,
                priority: priority,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                neverAbandon: neverAbandon,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueItemsTable,
      SyncQueueItem,
      $$SyncQueueItemsTableFilterComposer,
      $$SyncQueueItemsTableOrderingComposer,
      $$SyncQueueItemsTableAnnotationComposer,
      $$SyncQueueItemsTableCreateCompanionBuilder,
      $$SyncQueueItemsTableUpdateCompanionBuilder,
      (
        SyncQueueItem,
        BaseReferences<_$AppDatabase, $SyncQueueItemsTable, SyncQueueItem>,
      ),
      SyncQueueItem,
      PrefetchHooks Function()
    >;
typedef $$AppEventsTableCreateCompanionBuilder =
    AppEventsCompanion Function({
      Value<int> id,
      required String kind,
      Value<String?> payload,
      required DateTime occurredAt,
    });
typedef $$AppEventsTableUpdateCompanionBuilder =
    AppEventsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String?> payload,
      Value<DateTime> occurredAt,
    });

class $$AppEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$AppEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppEventsTable,
          AppEvent,
          $$AppEventsTableFilterComposer,
          $$AppEventsTableOrderingComposer,
          $$AppEventsTableAnnotationComposer,
          $$AppEventsTableCreateCompanionBuilder,
          $$AppEventsTableUpdateCompanionBuilder,
          (AppEvent, BaseReferences<_$AppDatabase, $AppEventsTable, AppEvent>),
          AppEvent,
          PrefetchHooks Function()
        > {
  $$AppEventsTableTableManager(_$AppDatabase db, $AppEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => AppEventsCompanion(
                id: id,
                kind: kind,
                payload: payload,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                Value<String?> payload = const Value.absent(),
                required DateTime occurredAt,
              }) => AppEventsCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppEventsTable,
      AppEvent,
      $$AppEventsTableFilterComposer,
      $$AppEventsTableOrderingComposer,
      $$AppEventsTableAnnotationComposer,
      $$AppEventsTableCreateCompanionBuilder,
      $$AppEventsTableUpdateCompanionBuilder,
      (AppEvent, BaseReferences<_$AppDatabase, $AppEventsTable, AppEvent>),
      AppEvent,
      PrefetchHooks Function()
    >;
typedef $$CachedDocumentsTableCreateCompanionBuilder =
    CachedDocumentsCompanion Function({
      required String key,
      required String body,
      required DateTime fetchedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });
typedef $$CachedDocumentsTableUpdateCompanionBuilder =
    CachedDocumentsCompanion Function({
      Value<String> key,
      Value<String> body,
      Value<DateTime> fetchedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });

class $$CachedDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CachedDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocumentsTable,
          CachedDocument,
          $$CachedDocumentsTableFilterComposer,
          $$CachedDocumentsTableOrderingComposer,
          $$CachedDocumentsTableAnnotationComposer,
          $$CachedDocumentsTableCreateCompanionBuilder,
          $$CachedDocumentsTableUpdateCompanionBuilder,
          (
            CachedDocument,
            BaseReferences<
              _$AppDatabase,
              $CachedDocumentsTable,
              CachedDocument
            >,
          ),
          CachedDocument,
          PrefetchHooks Function()
        > {
  $$CachedDocumentsTableTableManager(
    _$AppDatabase db,
    $CachedDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion(
                key: key,
                body: body,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String body,
                required DateTime fetchedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion.insert(
                key: key,
                body: body,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocumentsTable,
      CachedDocument,
      $$CachedDocumentsTableFilterComposer,
      $$CachedDocumentsTableOrderingComposer,
      $$CachedDocumentsTableAnnotationComposer,
      $$CachedDocumentsTableCreateCompanionBuilder,
      $$CachedDocumentsTableUpdateCompanionBuilder,
      (
        CachedDocument,
        BaseReferences<_$AppDatabase, $CachedDocumentsTable, CachedDocument>,
      ),
      CachedDocument,
      PrefetchHooks Function()
    >;
typedef $$SavedAddressesTableCreateCompanionBuilder =
    SavedAddressesCompanion Function({
      required String id,
      required String label,
      required String payload,
      Value<int> useCount,
      Value<DateTime?> lastUsedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SavedAddressesTableUpdateCompanionBuilder =
    SavedAddressesCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String> payload,
      Value<int> useCount,
      Value<DateTime?> lastUsedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SavedAddressesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedAddressesTable> {
  $$SavedAddressesTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedAddressesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedAddressesTable> {
  $$SavedAddressesTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedAddressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedAddressesTable> {
  $$SavedAddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SavedAddressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedAddressesTable,
          SavedAddressesData,
          $$SavedAddressesTableFilterComposer,
          $$SavedAddressesTableOrderingComposer,
          $$SavedAddressesTableAnnotationComposer,
          $$SavedAddressesTableCreateCompanionBuilder,
          $$SavedAddressesTableUpdateCompanionBuilder,
          (
            SavedAddressesData,
            BaseReferences<
              _$AppDatabase,
              $SavedAddressesTable,
              SavedAddressesData
            >,
          ),
          SavedAddressesData,
          PrefetchHooks Function()
        > {
  $$SavedAddressesTableTableManager(
    _$AppDatabase db,
    $SavedAddressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedAddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedAddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedAddressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedAddressesCompanion(
                id: id,
                label: label,
                payload: payload,
                useCount: useCount,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String payload,
                Value<int> useCount = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedAddressesCompanion.insert(
                id: id,
                label: label,
                payload: payload,
                useCount: useCount,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedAddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedAddressesTable,
      SavedAddressesData,
      $$SavedAddressesTableFilterComposer,
      $$SavedAddressesTableOrderingComposer,
      $$SavedAddressesTableAnnotationComposer,
      $$SavedAddressesTableCreateCompanionBuilder,
      $$SavedAddressesTableUpdateCompanionBuilder,
      (
        SavedAddressesData,
        BaseReferences<_$AppDatabase, $SavedAddressesTable, SavedAddressesData>,
      ),
      SavedAddressesData,
      PrefetchHooks Function()
    >;
typedef $$CachedDeliveriesTableCreateCompanionBuilder =
    CachedDeliveriesCompanion Function({
      required String id,
      required String status,
      required String payload,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> pendingSync,
      Value<int> rowid,
    });
typedef $$CachedDeliveriesTableUpdateCompanionBuilder =
    CachedDeliveriesCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> pendingSync,
      Value<int> rowid,
    });

class $$CachedDeliveriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDeliveriesTable> {
  $$CachedDeliveriesTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDeliveriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDeliveriesTable> {
  $$CachedDeliveriesTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDeliveriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDeliveriesTable> {
  $$CachedDeliveriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );
}

class $$CachedDeliveriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDeliveriesTable,
          CachedDelivery,
          $$CachedDeliveriesTableFilterComposer,
          $$CachedDeliveriesTableOrderingComposer,
          $$CachedDeliveriesTableAnnotationComposer,
          $$CachedDeliveriesTableCreateCompanionBuilder,
          $$CachedDeliveriesTableUpdateCompanionBuilder,
          (
            CachedDelivery,
            BaseReferences<
              _$AppDatabase,
              $CachedDeliveriesTable,
              CachedDelivery
            >,
          ),
          CachedDelivery,
          PrefetchHooks Function()
        > {
  $$CachedDeliveriesTableTableManager(
    _$AppDatabase db,
    $CachedDeliveriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDeliveriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDeliveriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDeliveriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDeliveriesCompanion(
                id: id,
                status: status,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pendingSync: pendingSync,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String payload,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> pendingSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDeliveriesCompanion.insert(
                id: id,
                status: status,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pendingSync: pendingSync,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDeliveriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDeliveriesTable,
      CachedDelivery,
      $$CachedDeliveriesTableFilterComposer,
      $$CachedDeliveriesTableOrderingComposer,
      $$CachedDeliveriesTableAnnotationComposer,
      $$CachedDeliveriesTableCreateCompanionBuilder,
      $$CachedDeliveriesTableUpdateCompanionBuilder,
      (
        CachedDelivery,
        BaseReferences<_$AppDatabase, $CachedDeliveriesTable, CachedDelivery>,
      ),
      CachedDelivery,
      PrefetchHooks Function()
    >;
typedef $$BufferedPositionsTableCreateCompanionBuilder =
    BufferedPositionsCompanion Function({
      Value<int> id,
      Value<String?> deliveryId,
      required double latitude,
      required double longitude,
      Value<double?> speedKmh,
      Value<double?> accuracyMeters,
      required DateTime recordedAt,
    });
typedef $$BufferedPositionsTableUpdateCompanionBuilder =
    BufferedPositionsCompanion Function({
      Value<int> id,
      Value<String?> deliveryId,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> speedKmh,
      Value<double?> accuracyMeters,
      Value<DateTime> recordedAt,
    });

class $$BufferedPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $BufferedPositionsTable> {
  $$BufferedPositionsTableFilterComposer({
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

  ColumnFilters<String> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracyMeters => $composableBuilder(
    column: $table.accuracyMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BufferedPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BufferedPositionsTable> {
  $$BufferedPositionsTableOrderingComposer({
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

  ColumnOrderings<String> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracyMeters => $composableBuilder(
    column: $table.accuracyMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BufferedPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BufferedPositionsTable> {
  $$BufferedPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get speedKmh =>
      $composableBuilder(column: $table.speedKmh, builder: (column) => column);

  GeneratedColumn<double> get accuracyMeters => $composableBuilder(
    column: $table.accuracyMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$BufferedPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BufferedPositionsTable,
          BufferedPosition,
          $$BufferedPositionsTableFilterComposer,
          $$BufferedPositionsTableOrderingComposer,
          $$BufferedPositionsTableAnnotationComposer,
          $$BufferedPositionsTableCreateCompanionBuilder,
          $$BufferedPositionsTableUpdateCompanionBuilder,
          (
            BufferedPosition,
            BaseReferences<
              _$AppDatabase,
              $BufferedPositionsTable,
              BufferedPosition
            >,
          ),
          BufferedPosition,
          PrefetchHooks Function()
        > {
  $$BufferedPositionsTableTableManager(
    _$AppDatabase db,
    $BufferedPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BufferedPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BufferedPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BufferedPositionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> deliveryId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> speedKmh = const Value.absent(),
                Value<double?> accuracyMeters = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => BufferedPositionsCompanion(
                id: id,
                deliveryId: deliveryId,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh,
                accuracyMeters: accuracyMeters,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> deliveryId = const Value.absent(),
                required double latitude,
                required double longitude,
                Value<double?> speedKmh = const Value.absent(),
                Value<double?> accuracyMeters = const Value.absent(),
                required DateTime recordedAt,
              }) => BufferedPositionsCompanion.insert(
                id: id,
                deliveryId: deliveryId,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh,
                accuracyMeters: accuracyMeters,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BufferedPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BufferedPositionsTable,
      BufferedPosition,
      $$BufferedPositionsTableFilterComposer,
      $$BufferedPositionsTableOrderingComposer,
      $$BufferedPositionsTableAnnotationComposer,
      $$BufferedPositionsTableCreateCompanionBuilder,
      $$BufferedPositionsTableUpdateCompanionBuilder,
      (
        BufferedPosition,
        BaseReferences<
          _$AppDatabase,
          $BufferedPositionsTable,
          BufferedPosition
        >,
      ),
      BufferedPosition,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncQueueItemsTableTableManager get syncQueueItems =>
      $$SyncQueueItemsTableTableManager(_db, _db.syncQueueItems);
  $$AppEventsTableTableManager get appEvents =>
      $$AppEventsTableTableManager(_db, _db.appEvents);
  $$CachedDocumentsTableTableManager get cachedDocuments =>
      $$CachedDocumentsTableTableManager(_db, _db.cachedDocuments);
  $$SavedAddressesTableTableManager get savedAddresses =>
      $$SavedAddressesTableTableManager(_db, _db.savedAddresses);
  $$CachedDeliveriesTableTableManager get cachedDeliveries =>
      $$CachedDeliveriesTableTableManager(_db, _db.cachedDeliveries);
  $$BufferedPositionsTableTableManager get bufferedPositions =>
      $$BufferedPositionsTableTableManager(_db, _db.bufferedPositions);
}
