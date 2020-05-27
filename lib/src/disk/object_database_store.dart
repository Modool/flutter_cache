import 'dart:math';

import 'package:meta/meta.dart';

import '../object_store.dart';
import 'database_store.dart';

abstract class FutureObjectStoreControl<T extends DatabaseStoreObject> {
  bool shouldAddObject(T object, ObjectStoreInfo info);
  bool shouldRemoveObject(T object, ObjectStoreInfo info);

  Future<bool> didAddItem(T object);
  Future<bool> didRemoveItem(T object);

  Future<bool> didClear();
}

class ObjectDatabaseStoreController
    implements ObjectStoreController<DatabaseStoreObject>, FutureObjectStoreControl<DatabaseStoreObject>, ObjectStoreMetaData {
  ObjectDatabaseStoreController(
    this.name,
    this._store, {
    DatabaseObjectStoreRule rule = DatabaseObjectStoreRule.fifo,
  }) {
    _info = ObjectStoreInfo(name: name, rule: rule);
  }

  final String name;

  DatabaseStore _store;
  ObjectStoreInfo _info;

  DatabaseObjectStoreRule get rule => _info.rule;
  Future<bool> setRule(DatabaseObjectStoreRule rule) async {
    if (null == rule) return false;

    final clone = _info.clone(rule: rule);

    final success = await _store.updateInfo(clone);
    if (success) _info = clone;

    return success;
  }

  @override
  int get maximumCount => _info.maximumCount;
  Future<bool> setMaximumCount(int maximumCount) async {
    final clone = _info.clone(maximumCount: maximumCount);

    final info = await _clearOverflowObjects(clone);
    final success = await _store.updateInfo(info);
    if (success) _info = info;

    return success;
  }

  @override
  double get maximumCost => _info.maximumCost;
  Future<bool> setMaximumCost(double maximumCost) async {
    final clone = _info.clone(maximumCost: maximumCost);

    final info = await _clearOverflowObjects(clone);
    final success = await _store.updateInfo(info);
    if (success) _info = info;

    return success;
  }

  @override
  double get maximumDuration => _info.maximumDuration;
  Future<bool> setMaximumDuration(double maximumDuration) async {
    final clone = _info.clone(maximumDuration: maximumDuration);

    final info = await _clearTimeoutObjects(clone);
    final success = await _store.updateInfo(info);
    if (success) _info = info;

    return success;
  }

  @override
  int get currentCount => _info.currentCount;

  @override
  double get currentCost => _info.currentCost;

  Future<void> load() async {
    final info = await _store.fetchInfo(_info.name);

    var updatedInfo = info;
    if (null != info) updatedInfo = await _clearTimeoutObjects(info);

    if (updatedInfo != null) {
      _info = updatedInfo;
    } else {
      updatedInfo = _info;
    }

    if (updatedInfo != info) {
      final success = await _store.updateInfo(updatedInfo);
      if (!success) throw Exception('failed to updated info: $updatedInfo');
    }
  }

  @override
  @protected
  bool shouldAddObject(DatabaseStoreObject object, ObjectStoreInfo info) =>
      (object.cost + info.currentCost) <= info.maximumCost && object.duration <= info.maximumDuration && _info.currentCount < info.maximumCount;

  @override
  @protected
  bool shouldRemoveObject(DatabaseStoreObject object, ObjectStoreInfo info) =>
      (object.cost + info.currentCost) > info.maximumCost || object.duration > info.maximumDuration || info.currentCount > info.maximumCount;

  @override
  @protected
  Future<bool> didAddItem(DatabaseStoreObject object) async {
    final cost = _info.currentCost + object.cost;
    if (cost > _info.maximumCost) throw Exception('cost is overflow');

    final count = _info.currentCount + 1;
    if (count > _info.maximumCount) throw Exception('count is overflow');

    if (object.isTimeout) throw Exception('object is timeout');

    _info = _info.clone(currentCost: cost, currentCount: count);

    return _store.updateInfo(_info);
  }

  @override
  @protected
  Future<bool> didRemoveItem(DatabaseStoreObject object) async {
    final cost = max(_info.currentCost - object.cost, 0.0);
    final count = max(_info.currentCount - 1, 0);

    _info = _info.clone(currentCost: cost, currentCount: count);

    return _store.updateInfo(_info);
  }

  @override
  @protected
  Future<bool> didClear() async {
    _info = _info.clone(currentCost: 0, currentCount: 0);

    return _store.updateInfo(_info);
  }

  Future<DatabaseStoreObject> _lowWeightObject() => _info.rule.lowWeightObject(_store);

  Future<ObjectStoreInfo> _clearOverflowObjects(ObjectStoreInfo info) async {
    var cost = info.currentCost;
    var count = info.currentCount;

    var infoUpdated = false;

    while (true) {
      final object = await _lowWeightObject();
      if (object == null) break;

      var should = shouldRemoveObject(object, info);
      if (!should) break;

      final success = await _store.delete(object.key);
      if (success) {
        count = max(count - 1, 0);
        cost = max(cost - object.cost, 0);

        infoUpdated = true;
      } else {
        throw Exception('failed to delete object ${object.toString()}');
      }
    }
    if (infoUpdated) info = info.clone(currentCost: cost, currentCount: count);

    return info;
  }

  Future<ObjectStoreInfo> _clearTimeoutObjects(ObjectStoreInfo info) async {
    final objects = await _store.timeoutObjects(StoreObject.now(), decoding: false);

    if (objects == null || objects.length == 0) return info;

    var cost = info.currentCost;
    var count = info.currentCount;

    var infoUpdated = false;
    for (final object in objects) {
      final success = await _store.delete(object.key);

      if (success) {
        count = max(count - 1, 0);
        cost = max(cost - object.cost, 0);

        infoUpdated = true;
      } else {
        throw Exception('failed to delete object ${object.toString()}');
      }
    }
    if (infoUpdated) info = info.clone(currentCost: cost, currentCount: count);

    return info;
  }

  @override
  Future<List<DatabaseStoreObject>> storeObjectsByKeys(List<String> keys) => _store.objectsByKeys(keys);

  @override
  Future<List<DatabaseStoreObject>> allStoreObjects() => _store.allObjects();

  @visibleForTesting
  @protected
  @override
  Future<DatabaseStoreObject> storeObjectForKey(String key) => _store.objectByKey(key);

  Future<List<dynamic>> _decodeObjects(List<DatabaseStoreObject> objects) async => objects?.map((object) {
        final type = ObjectType.valueAt(object.type);
        final codec = ObjectCodec.codecByType(type);
        if (codec == null) return null;

        return codec.decode(object.metadata);
      })?.toList();

  @protected
  Future<T> objectFromStoreObject<T>(DatabaseStoreObject object, ObjectCodec<T> codec) async {
    if (_validateObject(object)) {
      final resultCodec = _codecValidate<T>(codec);
      return resultCodec?.decode(object.metadata);
    } else {
      await _store.delete(object.key);
      await didRemoveItem(object);
    }
    return null;
  }

  Future<T> _objectForKeyAndCodec<T>(String key, ObjectCodec<T> codec) async {
    final storeObject = await _store.objectByKey(key);
    if (null == storeObject) return null;

    return objectFromStoreObject(storeObject, codec);
  }

  Future<bool> _setStoreObject<T>(String key, T object, {ObjectCodec<T> codec, double cost = 0, double duration = ObjectStore.forever}) async {
    final resultCodec = _codecValidate<T>(codec);
    if (null == resultCodec) return false;

    final data = resultCodec.encode(object);
    final storeObject = DatabaseStoreObject(
      key: key,
      type: ObjectType.valueOf<T>(),
      metadata: data,
      cost: cost,
      duration: duration,
    );

    var should = shouldAddObject(storeObject, _info);
    while (!should) {
      final object = await _lowWeightObject();
      if (null == object) return false;

      final success = await _removeObject(object);
      if (!success) return false;

      should = shouldAddObject(storeObject, _info);
    }

    final result = await _store.updateOrInsert(storeObject);
    if (result) await didAddItem(storeObject);

    return result;
  }

  Future<bool> clear() async {
    final result = await _store.deleteAll();
    if (result) await didClear();

    return result;
  }

  Future<bool> remove(String key) async {
    final object = await _store.objectByKey(key);
    if (null == object) return false;

    final result = await _store.delete(key);
    if (result) await didRemoveItem(object);

    return result;
  }

  Future<bool> _removeObject(DatabaseStoreObject object) async {
    final result = await _store.delete(object.key);
    if (result) await didRemoveItem(object);

    return result;
  }

  bool _validateObject(DatabaseStoreObject object) => !object.isTimeout;

  ObjectCodec<T> _codecValidate<T>(ObjectCodec<T> codec) => codec ?? ObjectCodec.codec<T>();

  Future<void> dispose() => _store.close();

  bool get isOpen => _store.isOpen;
}

class ObjectDatabaseStore extends ObjectDatabaseStoreController implements ObjectCodecStore {
  ObjectDatabaseStore(
    String name,
    DatabaseStore store, {
    DatabaseObjectStoreRule rule,
  }) : super(name, store, rule: rule);

  @override
  Future<T> objectForKey<T>(String key) => decodingObjectForKey<T>(key);

  @override
  Future<void> setObject<T>(
    String key,
    T object, {
    // ignore: invalid_override_different_default_values_named
    double cost = 0,
    double duration = ObjectStore.forever,
  }) =>
      setEncodingObject<T>(
        key,
        object,
        codec: null,
        cost: cost,
        duration: duration,
      );

  @override
  Future<List> objectsByKeys(List<String> keys) async => _decodeObjects(await storeObjectsByKeys(keys));

  @override
  Future<List> allObjects() async => _decodeObjects(await allStoreObjects());

  @override
  Future<String> stringForKey(String key) => decodingObjectForKey<String>(key);

  @override
  Future<bool> setStringForKey(String key, String string) => setObject<String>(key, string);

  @override
  Future<int> intForKey(String key) => decodingObjectForKey<int>(key);

  @override
  Future<bool> setIntForKey(String key, int integer) => setObject<int>(key, integer);

  @override
  Future<bool> boolForKey(String key) => decodingObjectForKey<bool>(key);

  @override
  Future<bool> setBoolForKey(String key, {@required bool boolean}) => setObject<bool>(key, boolean);

  @override
  Future<T> decodingObjectForKey<T>(String key, {ObjectCodec<T> codec}) async {
    final resultCodec = codec ?? ObjectCodec.codec<T>();
    return _objectForKeyAndCodec<T>(key, resultCodec);
  }

  @override
  Future<bool> setEncodingObject<T>(String key, T object,
      {ObjectCodec<T> codec,
      // ignore: invalid_override_different_default_values_named
      double cost = 0,
      double duration = ObjectStore.forever}) async {
    final resultCodec = codec ?? ObjectCodec.codec<T>();
    return _setStoreObject<T>(key, object, codec: resultCodec, cost: cost, duration: duration);
  }

  @override
  Future<bool> containsObjectByKey(String key) => _store.existByKey(key);

  static Future<ObjectDatabaseStore> objectStore(
    String name,
    DatabaseStore store, {
    DatabaseObjectStoreRule rule,
  }) async {
    final objectStore = ObjectDatabaseStore(name, store, rule: rule);
    await store.open();
    await objectStore.load();

    return objectStore;
  }
}
