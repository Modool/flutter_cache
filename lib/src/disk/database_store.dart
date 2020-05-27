import 'dart:io';
import 'dart:typed_data';

import '../object_store.dart';

abstract class _DatabaseObjectStoreRule {
  Future<DatabaseStoreObject> lowWeightObject(DatabaseStore store);
}

class ObjectStoreInfo {
  const ObjectStoreInfo({
    this.name,
    this.maximumCount = ObjectStore.defaultMaximumCount,
    this.maximumCost = ObjectStore.defaultMaximumCost,
    this.maximumDuration = ObjectStore.forever,
    this.currentCount = 0,
    this.currentCost = 0,
    this.rule,
  });

  final String name;
  final int maximumCount;
  final double maximumCost;
  final double maximumDuration;

  final int currentCount;
  final double currentCost;

  final DatabaseObjectStoreRule rule;

  ObjectStoreInfo clone({
    String name,
    int maximumCount,
    double maximumCost,
    double maximumDuration,
    int currentCount,
    double currentCost,
    DatabaseObjectStoreRule rule,
  }) {
    return ObjectStoreInfo(
      name: name ?? this.name,
      maximumCount: maximumCount ?? this.maximumCount,
      maximumCost: maximumCost ?? this.maximumCost,
      maximumDuration: maximumDuration ?? this.maximumDuration,
      currentCount: currentCount ?? this.currentCount,
      currentCost: currentCost ?? this.currentCost,
      rule: rule ?? this.rule,
    );
  }

  bool operator ==(Object other) {
    if (other is ObjectStoreInfo) {
      return other.name == name &&
          other.maximumCount == maximumCount &&
          other.maximumCost == maximumCost &&
          other.maximumDuration == maximumDuration &&
          other.currentCount == currentCount &&
          other.currentCost == currentCount &&
          other.rule.id == rule.id;
    }
    return false;
  }

  Map toMap() {
    final map = {
      StoreColumn.name: name,
      StoreColumn.maximumCount: maximumCount,
      StoreColumn.maximumCost: maximumCost,
      StoreColumn.maximumDuration: maximumDuration,
      StoreColumn.currentCount: currentCount,
      StoreColumn.currentCost: currentCost,
    };

    if (rule is DatabaseObjectStoreRule) {
      final databaseRule = rule;

      map[StoreColumn.rule] = databaseRule.id;
    }
    return map;
  }

  @override
  int get hashCode => name.hashCode ^ maximumCount ^ maximumCost.hashCode ^ maximumDuration.hashCode ^ currentCount ^ currentCost.hashCode ^ rule.id;

  @override
  String toString() =>
      'name: $name, maximumCount: $maximumCount, maximumCost: $maximumCost, maximumDuration: $maximumDuration, currentCount: $currentCount, currentCost: $currentCost, rule.id: ${rule.id}';
}

abstract class DatabaseObjectStoreRule implements _DatabaseObjectStoreRule {
  const DatabaseObjectStoreRule(this.id);
  final int id;

  static const fifo = _TimestampDatabaseObjectStoreRule(0);
  static const filo = _TimestampDatabaseObjectStoreRule(1, asc: false);
  static const timeAndCost = _MixtureDatabaseObjectStoreRule(2);
  static const costAndTime = _MixtureDatabaseObjectStoreRule(3, exchanged: true);

  static const rules = <int, DatabaseObjectStoreRule>{
    0: fifo,
    1: filo,
    2: timeAndCost,
    3: costAndTime,
  };

  Future<DatabaseStoreObject> lowWeightObjectByCondition(DatabaseStore store, List<String> orders) async {
    final objects = await store.objectsByCondition(
      orderBy: orders.join(','),
      limit: 1,
      decoding: false,
    );

    if (null == objects || objects.isEmpty) {
      return null;
    }
    return objects.first;
  }
}

class _TimestampDatabaseObjectStoreRule extends DatabaseObjectStoreRule implements _DatabaseObjectStoreRule {
  const _TimestampDatabaseObjectStoreRule(int id, {this.asc = true}) : super(id);

  final bool asc;

  @override
  Future<DatabaseStoreObject> lowWeightObject(DatabaseStore store) async {
    return lowWeightObjectByCondition(store, ['${ObjectColumn.timestamp} ${asc ? 'asc' : 'desc'}']);
  }
}

class _MixtureDatabaseObjectStoreRule extends DatabaseObjectStoreRule implements _DatabaseObjectStoreRule {
  const _MixtureDatabaseObjectStoreRule(
    int id, {
    this.exchanged = false,
    this.asc = true,
  }) : super(id);

  /// Default is time and cost if exchanged is false
  /// Or it is cost and time
  final bool exchanged;
  final bool asc;

  @override
  Future<DatabaseStoreObject> lowWeightObject(DatabaseStore store) async {
    final timeOrder = '${ObjectColumn.timestamp} ${asc ? 'asc' : 'desc'}';
    final costOrder = '${ObjectColumn.cost} ${asc ? 'asc' : 'desc'}';

    return lowWeightObjectByCondition(
      store,
      exchanged ? [timeOrder, costOrder] : [costOrder, timeOrder],
    );
  }
}

class DatabaseStoreObject extends StoreObject<ByteData> {
  DatabaseStoreObject({
    String key,
    this.type,
    ByteData metadata,
    double cost = 0,
    double duration,
    double timestamp,
  }) : super(
          key: key,
          metadata: metadata,
          cost: cost,
          duration: duration,
          timestamp: timestamp,
        );

  final int type;

  @override
  String toString() => "key: $key, type: $type, metadata: ${ObjectCodec.codecByType(
        ObjectType.valueAt(type),
      ).decode(
        metadata,
      )}, cost: $cost, duration: $duration, \ntime: ${DateTime.fromMicrosecondsSinceEpoch(
        (timestamp * 1000 * 1000).toInt(),
      )}";
}

abstract class Table {
  static const storeName = 't_store_info';
  static const objectNamePrefix = 't_store_object';
}

abstract class StoreColumn {
  static const id = '_id';
  static const name = 'name';
  static const maximumCount = 'maximum_count';
  static const maximumCost = 'maximum_cost';
  static const maximumDuration = 'maximum_duration';
  static const currentCount = 'current_count';
  static const currentCost = 'current_cost';
  static const rule = 'rule_id';
}

abstract class ObjectColumn {
  static const id = '_id';
  static const key = 'key';
  static const type = 'type';
  static const cost = 'cost';
  static const duration = 'duration';
  static const timestamp = 'timestamp';
  static const filename = 'file';
  static const metadata = 'metadata';
}

mixin DatabaseStoreMixin on DatabaseStore {
  @override
  Future<bool> updateOrInsert(DatabaseStoreObject object, {bool encoding = true}) async {
    final ex = await exist(object);
    if (ex) {
      return update(object, encoding: encoding);
    } else {
      return insert(object, encoding: encoding);
    }
  }

  @override
  Future<bool> exist(DatabaseStoreObject object) => existByKey(object.key);
}

abstract class DatabaseStore {
  Directory get directory;
  int get maximumMetadataLength;

  bool get isOpen;
  Future<bool> open();
  Future close();

  Future<bool> existInfo(String name);
  Future<ObjectStoreInfo> fetchInfo(String name);

  Future<bool> updateInfo(ObjectStoreInfo info);
  Future<bool> insertInfo(ObjectStoreInfo info);

  Future<DatabaseStoreObject> objectByKey(String key, {bool decoding = true});
  Future<List<DatabaseStoreObject>> objectsByKeys(List<String> keys, {bool decoding = true});
  Future<List<DatabaseStoreObject>> objectsByCondition({
    bool distinct,
    List<String> columns,
    String where,
    List<dynamic> whereArgs,
    String groupBy,
    String having,
    String orderBy,
    int limit,
    int offset,
    bool decoding = true,
  });

  Future<List<DatabaseStoreObject>> allObjects({bool decoding = true});

  Future<bool> updateOrInsert(DatabaseStoreObject object, {bool encoding = true});
  Future<bool> update(DatabaseStoreObject object, {bool encoding = true});
  Future<bool> insert(DatabaseStoreObject object, {bool encoding = true});

  Future<bool> delete(String key);
  Future<bool> deleteObjects(List<String> keys);
  Future<bool> deleteAll();

  Future<bool> exist(DatabaseStoreObject object);
  Future<bool> existByKey(String key);

  Future<List<DatabaseStoreObject>> objectsOverCapacity(int capacity, {bool decoding = true});
  Future<List<DatabaseStoreObject>> oldObjects(double timestamp, {bool decoding = true});
  Future<List<DatabaseStoreObject>> timeoutObjects(double basedTimestamp, {bool decoding = true});
}
