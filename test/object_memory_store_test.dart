import 'dart:io';

import 'package:flutter_object_cache/flutter_object_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

class StoreObjectA extends StoreObject {
  StoreObjectA({
    @required String key,
    @required metadata,
    @required double cost,
    @required double duration,
    double timestamp,
  }) : super(key: key, metadata: metadata, cost: cost, duration: duration, timestamp: timestamp);
  @override
  bool get isTimeout => true;
}

void main() {
  test('StoreObject', () {
    final object = StoreObjectA(key: 'a', metadata: null, cost: 1, duration: 1, timestamp: 1);

    expect(object.key, 'a');
    expect(object.metadata, null);
    expect(object.cost, 1);
    expect(object.duration, 1);
    expect(object.timestamp, 1);
  });

  group('MemoryStoreObject', () {
    test('accessor', () {
      final object = MemoryStoreObject(key: 'a', metadata: null, cost: 1, duration: 1, timestamp: 1);

      expect(object.key, 'a');
      expect(object.metadata, null);
      expect(object.cost, 1);
      expect(object.duration, 1);
      expect(object.timestamp, 1);
    });

    test('description', () {
      final object = MemoryStoreObject(key: 'a', metadata: null, cost: 1, duration: 1, timestamp: 1);
      final description =
          "key: a, metadata: null, cost: 1.0, \nduration: 1.0, \ntime: ${DateTime.fromMicrosecondsSinceEpoch((1 * 1000 * 1000).toInt())}";
      expect(object.toString(), description);
    });
  });

  group('ObjectStoreRule', () {
    test('rules', () {
      expect(ObjectStoreRule.rules.length, 4);
    });

    final object1 = MemoryStoreObject(key: 'a', metadata: null, cost: 5, duration: 1, timestamp: 1);
    final object2 = MemoryStoreObject(key: 'b', metadata: null, cost: 10, duration: 1, timestamp: 4);
    final object3 = MemoryStoreObject(key: 'c', metadata: null, cost: 10, duration: 1, timestamp: 8);
    final object4 = MemoryStoreObject(key: 'd', metadata: null, cost: 15, duration: 1, timestamp: 8);
    final object5 = MemoryStoreObject(key: 'e', metadata: null, cost: 20, duration: 1, timestamp: 12);

    final object6 = MemoryStoreObject(key: 'f', metadata: null, cost: 25, duration: 1, timestamp: 9);
    final object7 = MemoryStoreObject(key: 'g', metadata: null, cost: 22, duration: 1, timestamp: 10);

    final object8 = MemoryStoreObject(key: 'g', metadata: null, cost: 6, duration: 1, timestamp: 1);

    final objects = [object1, object2, object3, object4, object5];

    test('fifo', () {
      const rule = ObjectStoreRule.fifo;
      final object = rule.lowWeightObject(objects);
      expect(object, object1);
    });

    test('fofi', () {
      const rule = ObjectStoreRule.filo;
      final object = rule.lowWeightObject(objects);
      expect(object, object5);
    });

    test('cost and timestamp', () {
      final objects2 = [object1, object2, object3, object4, object5, object6, object7];

      const rule = ObjectStoreRule.costAndTime;
      final object = rule.lowWeightObject(objects2);
      expect(object, object6);
    });

    test('timestamp and cost', () {
      final objects2 = [object1, object2, object3, object4, object5, object6, object7];

      const rule = ObjectStoreRule.timeAndCost;
      final object = rule.lowWeightObject(objects2);
      expect(object, object1);
    });

    test('same timestamp and different cost', () {
      final objects2 = [object1, object2, object3, object4, object5, object6, object7, object8];

      const rule = ObjectStoreRule.timeAndCost;
      final object = rule.lowWeightObject(objects2);
      expect(object, object8);
    });

    test('same timestamp and different cost', () {
      final objects2 = [object1, object2, object3, object4, object5, object6, object7, object8];

      const rule = ObjectStoreRule.timeAndCost;
      final object = rule.lowWeightObject(objects2);
      expect(object, object8);
    });
  });

  group('ObjectMemoryStore', () {
    const rule = ObjectStoreRule.fifo;

    ObjectMemoryStore store;
    setUp(() {
      store = ObjectMemoryStore(rule: rule);
      expect(store.currentCost, 0);
    });

    test('object for key', () async {
      expect(await store.objectForKey('key'), isNull);
    });

    test('object for key', () async {
      await store.setObject('key', 'string', duration: 0.01);

      final object = await store.objectForKey('key');
      expect(object, 'string');

      sleep(const Duration(milliseconds: 15));

      final object2 = await store.objectForKey('key');
      expect(object2, isNull);
    });

    test('remove', () async {
      await store.setObject('key', 'string', duration: 1);
      expect(await store.objectForKey('key'), 'string');

      await store.setObject('key2', 'string2', duration: 1);
      expect(await store.objectForKey('key2'), 'string2');

      await store.remove('key');
      expect(await store.objectForKey('key'), isNull);
      expect(await store.objectForKey('key2'), 'string2');
    });

    test('clear', () async {
      await store.setObject('key', 'string', duration: 0.01);
      expect(await store.objectForKey('key'), 'string');

      await store.clear();
      expect(await store.objectForKey('key'), isNull);
    });

    test('set maximumCount', () async {
      await store.setObject('key', 'string', duration: 1);
      await store.setObject('key2', 'string2', duration: 1);

      expect(store.currentCount, 2);

      store.maximumCount = 1;

      expect(store.currentCount, 1);
      expect(await store.objectForKey('key2'), 'string2');
    });

    test('set maximumCost', () async {
      await store.setObject('key', 'string', cost: 1, duration: 20);
      await store.setObject('key2', 'string2', cost: 1, duration: 20);

      expect(store.currentCost, 2);

      store.maximumCost = 1;

      expect(store.currentCost, 1);
      expect(await store.objectForKey('key2'), 'string2');

      await store.setObject('key3', 'string3', cost: 1, duration: 1);

      expect(store.currentCost, 1);
      expect(await store.objectForKey('key2'), isNull);
      expect(await store.objectForKey('key3'), 'string3');
    });

    test('set maximumDuration', () async {
      await store.setObject('key', 'string', cost: 1, duration: 5);
      await store.setObject('key2', 'string2', cost: 1, duration: 4);

      expect(store.currentCount, 2);

      store.maximumDuration = 4;

      expect(store.maximumDuration, 4);
      expect(store.currentCount, 1);
      expect(await store.objectForKey('key'), isNull);
      expect(await store.objectForKey('key2'), 'string2');
    });

    test('objects for keys', () async {
      await store.setObject('key', 'string', cost: 1, duration: 5);
      await store.setObject('key2', 'string2', cost: 1, duration: 4);

      expect(store.currentCount, 2);

      final objects = await store.objectsByKeys(['key', 'key2']);

      expect(objects, ['string', 'string2']);
    });

    test('all store objects', () async {
      await store.setObject('key', 'string', cost: 1, duration: 5);
      await store.setObject('key2', 'string2', cost: 1, duration: 4);

      final objects = await store.allStoreObjects();

      expect(objects.length, 2);
      expect(['key', 'key2'].contains(objects[0].key), true);
      expect(['key', 'key2'].contains(objects[1].key), true);
      expect(['string', 'string2'].contains(objects[0].metadata), true);
      expect(['string', 'string2'].contains(objects[1].metadata), true);
    });

    test('all objects', () async {
      await store.setObject('key', 'string', cost: 1, duration: 5);
      await store.setObject('key2', 'string2', cost: 1, duration: 4);

      final objects = await store.allObjects();
      expect(objects, ['string', 'string2']);
    });
  });
}
