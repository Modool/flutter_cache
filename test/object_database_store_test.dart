import 'dart:io';

import 'package:flutter_object_cache/flutter_object_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockRule extends Mock implements DatabaseObjectStoreRule {
  final int id = 1;
}

class MockDatabaseStore extends Mock implements DatabaseStore {}

class MockDatabaseStoreMixin extends DatabaseStore with DatabaseStoreMixin {
  MockDatabaseStoreMixin(this.exi);

  final bool exi;

  @override
  Future<List<DatabaseStoreObject>> allObjects({bool decoding = true}) => null;

  @override
  Future close() => null;

  @override
  Future<bool> delete(String key) => null;

  @override
  Future<bool> deleteAll() => null;

  @override
  Future<bool> deleteObjects(List<String> keys) => null;

  @override
  Directory get directory => null;

  @override
  Future<bool> existByKey(String key) async => exi;

  @override
  Future<bool> existInfo(String name) => null;

  @override
  Future<ObjectStoreInfo> fetchInfo(String name) => null;

  @override
  Future<bool> insert(DatabaseStoreObject object, {bool encoding = true}) async => true;

  @override
  Future<bool> insertInfo(ObjectStoreInfo info) => null;

  @override
  bool get isOpen => null;

  @override
  int get maximumMetadataLength => null;

  @override
  Future<DatabaseStoreObject> objectByKey(String key, {bool decoding = true}) => null;

  @override
  Future<List<DatabaseStoreObject>> objectsByCondition({
    bool distinct,
    List<String> columns,
    String where,
    List whereArgs,
    String groupBy,
    String having,
    String orderBy,
    int limit,
    int offset,
    bool decoding = true,
  }) =>
      null;

  @override
  Future<List<DatabaseStoreObject>> objectsByKeys(List<String> keys, {bool decoding = true}) => null;

  @override
  Future<List<DatabaseStoreObject>> objectsOverCapacity(int capacity, {bool decoding = true}) => null;

  @override
  Future<List<DatabaseStoreObject>> oldObjects(double timestamp, {bool decoding = true}) => null;

  @override
  Future<bool> open() => null;

  @override
  Future<List<DatabaseStoreObject>> timeoutObjects(double basedTimestamp, {bool decoding = true}) => null;

  @override
  Future<bool> update(DatabaseStoreObject object, {bool encoding = true}) async => true;

  @override
  Future<bool> updateInfo(ObjectStoreInfo info) => null;
}

void main() {
  final stringCodec = StringCodec();

  group('DatabaseStoreObject', () {
    test('accessor', () {
      final object = DatabaseStoreObject(key: 'a', type: 1, metadata: null, cost: 1, duration: 1, timestamp: 1);

      expect(object.key, 'a');
      expect(object.type, 1);
      expect(object.metadata, null);
      expect(object.cost, 1);
      expect(object.duration, 1);
      expect(object.timestamp, 1);
    });

    test('description', () {
      const string = 'aaaa';
      final data = stringCodec.encode(string);

      final object = DatabaseStoreObject(key: 'a', type: ObjectType.valueOf<String>(), metadata: data, cost: 1, duration: 1, timestamp: 1);
      final description =
          "key: a, type: 4, metadata: aaaa, cost: 1.0, duration: 1.0, \ntime: ${DateTime.fromMicrosecondsSinceEpoch((1 * 1000 * 1000).toInt())}";
      expect(object.toString(), description);
    });
  });

  group('DatabaseObjectStoreRule', () {
    const string = 'aaaa';
    final data = stringCodec.encode(string);
    final databaseObject = DatabaseStoreObject(key: 'a', type: ObjectType.valueOf<String>(), metadata: data, cost: 1, duration: 1, timestamp: 1);

    test('fifo', () async {
      final rule = DatabaseObjectStoreRule.fifo;
      final database = MockDatabaseStore();

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => null);

      final object = await rule.lowWeightObject(database);
      expect(object, isNull);

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => [databaseObject]);

      final object2 = await rule.lowWeightObject(database);
      expect(object2, databaseObject);
    });

    test('filo', () async {
      final rule = DatabaseObjectStoreRule.filo;
      final database = MockDatabaseStore();

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => null);

      final object = await rule.lowWeightObject(database);
      expect(object, isNull);

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => [databaseObject]);

      final object2 = await rule.lowWeightObject(database);
      expect(object2, databaseObject);
    });

    test('timeAndCost', () async {
      final rule = DatabaseObjectStoreRule.timeAndCost;
      final database = MockDatabaseStore();

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => null);

      final object = await rule.lowWeightObject(database);
      expect(object, isNull);

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => [databaseObject]);

      final object2 = await rule.lowWeightObject(database);
      expect(object2, databaseObject);
    });

    test('costAndTime', () async {
      final rule = DatabaseObjectStoreRule.costAndTime;
      final database = MockDatabaseStore();

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => null);

      final object = await rule.lowWeightObject(database);
      expect(object, isNull);

      when(database.objectsByCondition(
        orderBy: anyNamed("orderBy"),
        limit: anyNamed("limit"),
        decoding: anyNamed("decoding"),
      )).thenAnswer((_) async => [databaseObject]);

      final object2 = await rule.lowWeightObject(database);
      expect(object2, databaseObject);
    });
  });

  group('ObjectStoreInfo', () {
    final info = ObjectStoreInfo(
      name: 'aaa',
      rule: DatabaseObjectStoreRule.fifo,
    );

    test('clone', () async {
      final clone = info.clone();

      expect(clone == info, true);
    });

    test('hash code', () async {
      final code = info.hashCode;

      expect(code, isNonZero);
    });

    test('map', () async {
      final map = info.toMap();

      expect(map, {
        StoreColumn.name: 'aaa',
        StoreColumn.maximumCount: info.maximumCount,
        StoreColumn.maximumCost: info.maximumCost,
        StoreColumn.maximumDuration: info.maximumDuration,
        StoreColumn.currentCount: info.currentCount,
        StoreColumn.currentCost: info.currentCost,
        StoreColumn.rule: info.rule.id,
      });
    });
  });

  group('DatabaseStoreMixin', () {
    const value = 'aaaa';
    final data = stringCodec.encode(value);
    final object = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 1, duration: 5);

    test('exist', () async {
      final database = MockDatabaseStoreMixin(true);
      final exist = await database.exist(object);
      expect(exist, true);
    });

    group('updateOrInsert', () {
      test('exist', () async {
        final database = MockDatabaseStoreMixin(true);
        final success = await database.updateOrInsert(object);
        expect(success, true);
      });
      test('no exist', () async {
        final database = MockDatabaseStoreMixin(false);
        final success = await database.updateOrInsert(object);
        expect(success, true);
      });
    });
  });

  group('ObjectDatabaseStore', () {
    const rule = DatabaseObjectStoreRule.fifo;
    final database = MockDatabaseStore();

    const value = 'aaaa';
    final data = stringCodec.encode(value);

    const value2 = 'bbbbb';
    final data2 = stringCodec.encode(value2);

    final object1 = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 1, duration: 5);
    final object2 = DatabaseStoreObject(key: 'key2', type: ObjectType.valueOf<String>(), metadata: data2, cost: 1, duration: 4);

    Directory directory;

    group('life cycle', () {
      setUp(() async {
        directory = await Directory.systemTemp.createTemp();
      });

      test('load when exist info', () async {
        final info = ObjectStoreInfo(
          name: 'a',
          maximumCount: 8,
          maximumDuration: 9,
          maximumCost: 10,
          currentCount: 11,
          currentCost: 12,
          rule: DatabaseObjectStoreRule.timeAndCost,
        );
        when(database.fetchInfo('a')).thenAnswer((_) async => info);
        when(database.updateInfo(any)).thenAnswer((_) async => true);

        final store = ObjectDatabaseStore('a', database, rule: rule);
        await store.load();

        expect(store.maximumCount, 8);
        expect(store.maximumDuration, 9);
        expect(store.maximumCost, 10);
        expect(store.currentCount, 11);
        expect(store.currentCost, 12);
        expect(store.rule, DatabaseObjectStoreRule.timeAndCost);
      });

      test('load when exist info and failed to update', () async {
        final info = ObjectStoreInfo(
          name: 'a',
          maximumCount: 8,
          maximumDuration: 9,
          maximumCost: 10,
          currentCount: 11,
          currentCost: 12,
          rule: DatabaseObjectStoreRule.timeAndCost,
        );
        when(database.fetchInfo('a')).thenAnswer((_) async => info);
        when(database.updateInfo(any)).thenAnswer((_) async => false);

        final store = ObjectDatabaseStore('a', database, rule: rule);
        try {
          await store.load();
        } catch (e) {
          expect(e.toString(), "Exception: failed to updated info: $info");
        }
      });

      test('dispose', () async {
        var open = false;
        when(database.open()).thenAnswer((_) async {
          open = true;
          return true;
        });
        when(database.close()).thenAnswer((_) async {
          open = false;
          return null;
        });

        when(database.isOpen).thenAnswer((_) => open);
        when(database.updateInfo(any)).thenAnswer((_) async => true);

        final store = ObjectDatabaseStore('a', database, rule: rule);
        final success = await database.open();
        expect(success, true);

        expect(store.isOpen, true);
        await store.dispose();
        expect(store.isOpen, false);
      });
    });

    group('access', () {
      ObjectDatabaseStore store;

      setUpAll(() async {
        directory = await Directory.systemTemp.createTemp();
      });

      setUp(() async {
        when(database.directory).thenReturn(directory);
        when(database.maximumMetadataLength).thenReturn(1000);

        when(database.open()).thenAnswer((_) async => true);
        when(database.close()).thenAnswer((_) async => null);

        when(database.updateInfo(any)).thenAnswer((_) async => true);
        when(database.insertInfo(any)).thenAnswer((_) async => true);
        when(database.existInfo(any)).thenAnswer((_) async => false);
        when(database.fetchInfo(any)).thenAnswer((_) async => null);

        when(database.updateOrInsert(any)).thenAnswer((_) async => true);
        when(database.update(any)).thenAnswer((_) async => true);
        when(database.insert(any)).thenAnswer((_) async => true);

        when(database.delete(any)).thenAnswer((_) async => true);
        when(database.deleteObjects(any)).thenAnswer((_) async => true);
        when(database.deleteAll()).thenAnswer((_) async => true);

        store = await ObjectDatabaseStore.objectStore('a', database, rule: rule);
        expect(store.currentCost, 0);
      });

      test('set rule', () async {
        final filo = DatabaseObjectStoreRule.filo;

        final success = await store.setRule(filo);
        expect(success, true);
        expect(store.rule == filo, true);
      });

      test('object for key', () async {
        when(database.objectByKey('key')).thenAnswer((_) async => null);

        expect(await store.objectForKey('key'), isNull);
      });

      test('object for key', () async {
        final databaseObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 0.5, duration: 0.01);
        when(database.objectByKey('key')).thenAnswer((_) async => databaseObject);

        final object = await store.objectForKey<String>('key');
        expect(object, value);

        sleep(const Duration(milliseconds: 15));

        final object2 = await store.objectForKey<String>('key');
        expect(object2, isNull);
      });

      test('set object for key', () async {
        final databaseObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 3, duration: 10);
        await store.setObject<String>('key', value);

        expect(store.currentCount, 1);

        when(database.objectByKey('key')).thenAnswer((_) async => databaseObject);
        final object = await store.objectForKey<String>('key');

        expect(object, value);

        final string = await store.stringForKey('key');
        expect(string, value);
      });

      test('set string for key', () async {
        final databaseObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 3, duration: 10);
        await store.setStringForKey('key', value);

        expect(store.currentCount, 1);

        when(database.objectByKey('key')).thenAnswer((_) async => databaseObject);

        final string = await store.stringForKey('key');
        expect(string, value);
      });

      test('set int for key', () async {
        const intValue = 2;
        final codec = IntCodec();
        final intData = codec.encode(intValue);

        final intObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<int>(), metadata: intData, cost: 3, duration: 10);
        await store.setIntForKey('key', intValue);

        expect(store.currentCount, 1);

        when(database.objectByKey('key')).thenAnswer((_) async => intObject);

        final integer = await store.intForKey('key');
        expect(integer, intValue);
      });

      test('set bool for key', () async {
        const boolValue = true;
        final codec = BooleanCodec();
        final boolData = codec.encode(boolValue);

        final boolObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<int>(), metadata: boolData, cost: 3, duration: 10);
        await store.setBoolForKey('key', boolean: boolValue);

        expect(store.currentCount, 1);

        when(database.objectByKey('key')).thenAnswer((_) async => boolObject);

        final boolean = await store.boolForKey('key');
        expect(boolean, boolValue);
      });

      group('set object for key when overflowed', () {
        final mockRule = MockRule();

        final databaseObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 3, duration: 10);
        setUp(() async {
          await store.setRule(mockRule);
          await store.setObject<String>('key', value, cost: 3, duration: 10);
          expect(store.currentCount, 1);

          bool once = false;
          when(mockRule.lowWeightObject(database)).thenAnswer((_) async {
            if (once) return null;

            once = true;
            return databaseObject;
          });
        });

        test('success to delete', () async {
          await store.setMaximumCost(1);
          expect(store.currentCount, 0);
        });

        test('failed to delete', () async {
          when(database.delete(any)).thenAnswer((_) async => false);
          try {
            await store.setMaximumCost(1);
          } catch (e) {
            expect(e.toString(), "Exception: failed to delete object ${databaseObject.toString()}");
          }

          expect(store.currentCount, 1);
        });

        test('shouldn\'t add', () async {
          when(database.delete(any)).thenAnswer((_) async => true);
          await store.setMaximumCost(4);
          await store.setObject<String>('key', value, cost: 3, duration: 10);
          expect(store.currentCost, 3);
          expect(store.currentCount, 1);

          bool once = false;
          when(mockRule.lowWeightObject(database)).thenAnswer((_) async {
            if (once) return null;

            once = true;
            return databaseObject;
          });
          await store.setObject<String>('key', value, cost: 2, duration: 10);
          expect(store.currentCost, 2);
          expect(store.currentCount, 1);
        });
      });

      test('remove', () async {
        final success = await store.remove('key');
        expect(success, true);
      });

      test('clear', () async {
        final success = await store.clear();
        expect(success, true);
      });

      test('set maximumCount', () async {
        final success = await store.setMaximumCount(1);
        expect(success, true);

        expect(store.maximumCount, 1);
      });

      test('set maximumCost', () async {
        final success = await store.setMaximumCost(1);
        expect(success, true);
        expect(store.maximumCost, 1);
      });

      group('set maximumDuration', () {
        final databaseObject = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 3, duration: 100);
        setUp(() async {
          await store.setMaximumDuration(100000);
          await store.setObject<String>('key', value, cost: 3, duration: 100);

          expect(store.currentCount, 1);
        });

        test('no timeout', () async {
          final success = await store.setMaximumDuration(4);
          expect(success, true);
          expect(store.maximumDuration, 4);
        });

        test('time out but no object to delete', () async {
          when(database.timeoutObjects(any)).thenAnswer((_) async => null);

          await store.setMaximumCost(1);
          expect(store.currentCount, 1);

          when(database.timeoutObjects(any)).thenAnswer((_) async => []);

          await store.setMaximumCost(1);
          expect(store.currentCount, 1);
        });

        test('object timeout', () async {
          when(database.timeoutObjects(any, decoding: false)).thenAnswer((_) async => <DatabaseStoreObject>[databaseObject]);

          await store.setMaximumDuration(1);
          expect(store.currentCount, 0);
        });

        test('failed to delete', () async {
          when(database.timeoutObjects(any)).thenAnswer((_) async => [databaseObject]);
          when(database.delete(any)).thenAnswer((_) async => false);
          try {
            await store.setMaximumDuration(1);
          } catch (e) {
            expect(e.toString(), "Exception: failed to delete object ${databaseObject.toString()}");
          }

          expect(store.currentCount, 1);
        });
      });

      test('objects for keys', () async {
        when(database.objectsByKeys(['key', 'key2'])).thenAnswer((_) async => [object1, object2]);

        final objects = await store.objectsByKeys(['key', 'key2']);
        expect(objects, [value, value2]);
      });

      test('store object for key', () async {
        when(database.objectByKey('key')).thenAnswer((_) async => object1);

        final object = await store.storeObjectForKey('key');
        expect(object, object1);
      });

      test('all store objects', () async {
        when(database.allObjects()).thenAnswer((_) async => [object1, object2]);

        final objects = await store.allStoreObjects();

        expect(objects.length, 2);
        expect(['key', 'key2'].contains(objects[0].key), true);
        expect(['key', 'key2'].contains(objects[1].key), true);
        expect([data, data2].contains(objects[0].metadata), true);
        expect([data, data2].contains(objects[1].metadata), true);
      });

      test('all objects', () async {
        when(database.allObjects()).thenAnswer((_) async => [object1, object2]);

        final objects = await store.allObjects();
        expect(objects, [value, value2]);
      });
    });
  });
}
