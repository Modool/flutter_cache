import 'dart:io';

import 'package:flutter_object_cache/flutter_object_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockDatabaseStore extends Mock implements DatabaseStore {}

Future<void> main() async {
  final database = MockDatabaseStore();
  final store = CacheStore('a', database);

  final stringCodec = StringCodec();

  const value = 'aaaa';
  final data = stringCodec.encode(value);

  const value2 = 'bbbbb';
  final data2 = stringCodec.encode(value2);

  final object1 = DatabaseStoreObject(key: 'key', type: ObjectType.valueOf<String>(), metadata: data, cost: 1, duration: 5);
  final object2 = DatabaseStoreObject(key: 'key2', type: ObjectType.valueOf<String>(), metadata: data2, cost: 1, duration: 4);
  final object3 = DatabaseStoreObject(key: 'key3', type: ObjectType.valueOf<String>(), metadata: data2, cost: 1, duration: 0.2);

  when(database.updateInfo(any)).thenAnswer((_) async => true);
  when(database.updateOrInsert(any)).thenAnswer((_) async => true);
  when(database.deleteAll()).thenAnswer((_) async => true);

  test('set object for key', () async {
    await store.setObject<String>('key', value);
    expect(store.currentCount, 1);

    when(database.objectByKey('key')).thenAnswer((_) async => object1);
    final object = await store.objectForKey<String>('key');

    expect(object, value);

    final string = await store.stringForKey('key');
    expect(string, value);

    when(database.objectByKey('key2')).thenAnswer((_) async => object2);
    final string2 = await store.stringForKey('key2');
    expect(string2, value2);

    sleep(Duration(milliseconds: 300));

    when(database.objectByKey('key3')).thenAnswer((_) async => object3);
    final string3 = await store.stringForKey('key3');
    expect(string3, isNull);
  });

  test('clear', () async {
    final success = await store.clear();
    expect(success, true);
  });
}
