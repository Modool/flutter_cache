import 'dart:math';

import 'package:meta/meta.dart';

import '../object_store.dart';

typedef ObjectStoreRuleComparation = bool Function(StoreObject object1, StoreObject object2);

abstract class ObjectStoreRule {
  StoreObject lowWeightObject(Iterable<StoreObject> objects);

  static const filo = OrderObjectStoreRule(0);
  static const fifo = OrderObjectStoreRule(1, fifo: false);
  static const timeAndCost = MixtureObjectStoreRule(2);
  static const costAndTime = MixtureObjectStoreRule(3, reversal: true);

  static const rules = <int, ObjectStoreRule>{
    0: fifo,
    1: filo,
    2: timeAndCost,
    3: costAndTime,
  };
}

class _ObjectStoreRule {
  const _ObjectStoreRule(this.id);
  final int id;

  StoreObject lowWeightObjectByTest(Iterable<StoreObject> objects, ObjectStoreRuleComparation test) {
    final iterator = objects.iterator;

    StoreObject result;
    while (iterator.moveNext()) {
      final object = iterator.current;

      if (null == result) {
        result = object;
      } else if (result != object) {
        final replacing = test(result, object);

        if (replacing) result = object;
      }
    }
    return result;
  }
}

class OrderObjectStoreRule extends _ObjectStoreRule implements ObjectStoreRule {
  const OrderObjectStoreRule(int id, {this.fifo = true}) : super(id);

  final bool fifo;

  @override
  StoreObject lowWeightObject(Iterable<StoreObject> objects) {
    return lowWeightObjectByTest(objects, (object1, object2) {
      if (fifo) {
        return object1.timestamp < object2.timestamp;
      } else {
        return object1.timestamp > object2.timestamp;
      }
    });
  }
}

class MixtureObjectStoreRule extends _ObjectStoreRule implements ObjectStoreRule {
  const MixtureObjectStoreRule(int id, {this.reversal = false}) : super(id);

  /// Default is time and cost if reversal is false
  /// Or it is cost and time
  final bool reversal;

  @override
  StoreObject lowWeightObject(Iterable<StoreObject> objects) {
    return lowWeightObjectByTest(objects, (object1, object2) {
      if (reversal) {
        if (object1.cost < object2.cost) return true;
        if (object1.cost == object2.cost) {
          return object1.timestamp > object2.timestamp;
        }
        return false;
      } else {
        if (object1.timestamp > object2.timestamp) return true;
        if (object1.timestamp == object2.timestamp) {
          return object1.cost < object2.cost;
        }
        return false;
      }
    });
  }
}

abstract class ObjectStoreControl<T> {
  bool shouldAddObject(T storeObject);
  bool shouldRemoveObject(T object);

  void didAddObject(T storeObject);
  void didRemoveObject(T storeObject);

  void didClear();
}

class MemoryStoreObject<T> extends StoreObject<T> {
  MemoryStoreObject({
    String key,
    T metadata,
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
}

class ObjectMemoryStoreController implements ObjectStoreController<MemoryStoreObject>, ObjectStoreControl<MemoryStoreObject>, ObjectStoreMetaData {
  ObjectMemoryStoreController({this.rule = ObjectStoreRule.fifo});

  final ObjectStoreRule rule;

  int _maximumCount = ObjectStore.defaultMaximumCount;
  @override
  int get maximumCount => _maximumCount;
  set maximumCount(int maximumCount) {
    _maximumCount = maximumCount;

    _clearUselessObjects();
  }

  double _maximumCost = ObjectStore.defaultMaximumCost;

  @override
  double get maximumCost => _maximumCost;
  set maximumCost(double maximumCost) {
    _maximumCost = maximumCost;

    _clearUselessObjects();
  }

  double _maximumDuration = ObjectStore.forever;

  @override
  double get maximumDuration => _maximumDuration;
  set maximumDuration(double maximumDuration) {
    _maximumDuration = maximumDuration;

    _clearUselessObjects();
  }

  int _currentCount = 0;
  @override
  int get currentCount => _currentCount;

  double _currentCost = 0;

  @override
  double get currentCost => _currentCost;

  final _map = <String, MemoryStoreObject>{};

  @protected
  StoreObject lowWeightObject() => rule.lowWeightObject(_map.values);

  void _clearUselessObjects() {
    var object = lowWeightObject();

    while (object != null) {
      if (!shouldRemoveObject(object)) break;

      _map.remove(object.key);
      _currentCount--;
      _currentCost -= object.cost;

      object = lowWeightObject();
    }
  }

  @override
  @protected
  bool shouldAddObject(MemoryStoreObject storeObject) =>
      (storeObject.cost + _currentCost) <= maximumCost && storeObject.duration <= maximumDuration && _currentCount < maximumCount;

  @override
  @protected
  bool shouldRemoveObject(MemoryStoreObject object) =>
      _currentCost > _maximumCost || object.duration > _maximumDuration || _currentCount > _maximumCount;

  @override
  @protected
  void didAddObject(MemoryStoreObject storeObject) {
    final currentCost = _currentCost + storeObject.cost;
    if (currentCost > maximumCost) throw Exception('cost is overflow');

    final currentCount = _currentCount + 1;
    if (currentCount > maximumCount) throw Exception('count is overflow');

    if (storeObject.isTimeout) throw Exception('object is timeout');

    _currentCost = currentCost;
    _currentCount = currentCount;
  }

  @override
  @protected
  void didRemoveObject(MemoryStoreObject storeObject) => _currentCost = max(_currentCost - storeObject.cost, 0);

  @override
  @protected
  void didClear() => _currentCost = 0;

  @protected
  void removeStoreObject(MemoryStoreObject object) {
    _map.remove(object.key);
    didRemoveObject(object);
  }

  @protected
  bool validateObject(MemoryStoreObject object) {
    return !object.isTimeout;
  }

  Future<MemoryStoreObject> storeObjectForKey(String key) async => _map[key];

  Future<List<MemoryStoreObject>> storeObjectsByKeys(List<String> keys) async {
    final objects = Map<String, MemoryStoreObject>.from(_map);
    objects.removeWhere((key, value) => !keys.contains(key));

    return objects.values.toList();
  }

  Future<List<MemoryStoreObject>> allStoreObjects() async => _map.values.toList();
}

class ObjectMemoryStore extends ObjectMemoryStoreController implements ObjectStore {
  ObjectMemoryStore({ObjectStoreRule rule = ObjectStoreRule.fifo}) : super(rule: rule);

  @override
  Future<bool> containsObjectByKey(String key) async => _map.containsKey(key);

  @override
  Future<T> objectForKey<T>(String key) async {
    final storeObject = await storeObjectForKey(key);

    if (null == storeObject) return null;
    if (validateObject(storeObject)) return storeObject.metadata;

    removeStoreObject(storeObject);
    return null;
  }

  @override
  Future<void> setObject<T>(String key, T object, {double cost = 0, double duration = ObjectStore.forever}) async {
    final storeObject = MemoryStoreObject<T>(key: key, metadata: object, cost: cost, duration: duration);

    var should = shouldAddObject(storeObject);
    while (!should) {
      final object = lowWeightObject();
      if (null == object) return;

      remove(object.key);
      should = shouldAddObject(storeObject);
    }

    _map[key] = storeObject;
    didAddObject(storeObject);
  }

  @override
  Future<List> objectsByKeys(List<String> keys) async {
    final objects = await storeObjectsByKeys(keys);
    return objects.map((object) => object.metadata).toList();
  }

  @override
  Future<List> allObjects() async {
    return _map.values.map((object) => object.metadata).toList();
  }

  @override
  Future<void> clear() async {
    _map.clear();

    didClear();
  }

  @override
  Future<void> remove(String key) async {
    final storeObject = _map[key];
    if (null == storeObject) return;

    removeStoreObject(storeObject);
  }
}
