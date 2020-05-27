import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'disk/database_store.dart';
import 'disk/database_store_sqflite_impl.dart';
import 'disk/object_database_store.dart';
import 'object_store.dart';

class _CacheStoreObject<T> implements StoreObject<T> {
  _CacheStoreObject(this.key, this.metadata, this.cost, this.duration, this.timestamp);

  @override
  final String key;

  @override
  final T metadata;

  @override
  final double timestamp;

  @override
  final double cost;

  @override
  final double duration;

  @override
  bool get isTimeout => (timestamp + duration) < StoreObject.now();
}

class CacheStore extends ObjectDatabaseStore {
  CacheStore(String name, DatabaseStore store) : super(name, store);

  final _map = <String, _CacheStoreObject>{};

  @override
  Future<T> decodingObjectForKey<T>(String key, {ObjectCodec<T> codec}) async {
    final storeObject = _map[key];
    if (null != storeObject) return storeObject.metadata;

    final databaseObject = await storeObjectForKey(key);
    final object = await objectFromStoreObject<T>(databaseObject, codec);

    if (null != object) {
      _map[key] = _CacheStoreObject<T>(key, object, databaseObject.cost, databaseObject.duration, databaseObject.timestamp);
    }
    return object;
  }

  @override
  Future<bool> setEncodingObject<T>(String key, T object,
      {ObjectCodec<T> codec,
      // ignore: invalid_override_different_default_values_named
      double cost = 0,
      double duration = ObjectStore.forever}) async {
    final result = await super.setEncodingObject<T>(key, object, codec: codec, cost: cost, duration: duration);
    if (result) {
      _map[key] = _CacheStoreObject(key, object, cost, duration, StoreObject.now());
    }
    return result;
  }

  @override
  @protected
  Future<bool> didClear() async {
    final result = await super.didClear();
    if (result) _map.clear();
    return result;
  }

  @override
  @protected
  Future<bool> didRemoveItem(StoreObject object) async {
    final result = await super.didRemoveItem(object);

    if (result) _map.remove(object.key);
    return result;
  }

  static Future<CacheStore> sqfliteStore({String name, Directory directory, DatabaseStore database}) async {
    final store = database ??
        DatabaseStoreSqfliteImpl(
          name: name,
          directory: directory,
        );
    final objectStore = CacheStore(name, store);
    await store.open();
    await objectStore.load();

    return objectStore;
  }
}
