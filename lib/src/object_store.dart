import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

abstract class ObjectCodec<T> {
  ByteData encode(T value);
  T decode(ByteData data);

  static final ObjectCodec<int> intCodec = IntCodec();
  static final ObjectCodec<String> stringCodec = StringCodec();
  static final ObjectCodec<bool> booleanCodec = BooleanCodec();
  static final ObjectCodec<double> doubleCodec = DoubleCodec();
  static final ObjectCodec<Map> mapCodec = MapCodec();
  static final ObjectCodec<List> listCodec = ListCodec();
  static final ObjectCodec<ByteData> dataCodec = DataCodec();

  static final _codecs = <Type, ObjectCodec>{
    bool: booleanCodec,
    int: intCodec,
    String: stringCodec,
    double: doubleCodec,
    Map: mapCodec,
    List: listCodec,
    ByteData: dataCodec
  };

  static ObjectCodec<T> codec<T>() => _codecs[T];
  static ObjectCodec codecByType(Type type) => _codecs[type];
}

abstract class ObjectStore {
  static const forever = double.maxFinite;
  static const defaultMaximumCost = double.maxFinite;
  static const defaultMaximumCount = 0xFFFFFFFF;

  Future<bool> containsObjectByKey(String key);

  Future<T> objectForKey<T>(String key);
  Future<void> setObject<T>(String key, T object, {double cost = 0, double duration = ObjectStore.forever});

  Future<List> objectsByKeys(List<String> keys);
  Future<List> allObjects();

  Future<List<StoreObject>> allStoreObjects();

  Future<void> remove(String key);
  Future<void> clear();
}

abstract class ObjectStoreController<T extends StoreObject> {
  Future<T> storeObjectForKey(String key);

  Future<List<T>> storeObjectsByKeys(List<String> keys);
  Future<List<T>> allStoreObjects();
}

abstract class ObjectCodecStore extends ObjectStore {
  Future<T> decodingObjectForKey<T>(String key, {ObjectCodec<T> codec});
  Future<bool> setEncodingObject<T>(String key, T object, {ObjectCodec<T> codec, double cost = 0, double duration = ObjectStore.forever});

  Future<String> stringForKey(String key);
  Future<bool> setStringForKey(String key, String string);

  Future<int> intForKey(String key);
  Future<bool> setIntForKey(String key, int integer);

  Future<bool> boolForKey(String key);
  Future<bool> setBoolForKey(String key, {bool boolean});
}

abstract class StoreObject<T> {
  StoreObject({
    @required this.key,
    @required this.metadata,
    @required this.duration,
    this.cost = 0,
    double timestamp,
  }) {
    _timestamp = timestamp ?? StoreObject.now();
  }

  final String key;
  final T metadata;

  double _timestamp;
  double get timestamp => _timestamp;

  final double cost;
  final double duration;

  bool get isTimeout => (_timestamp + duration) < StoreObject.now();

  static double now() => DateTime.now().microsecondsSinceEpoch.toDouble() / 1000 / 1000;

  @override
  String toString() =>
      "key: $key, metadata: $metadata, cost: $cost, \nduration: ${ObjectStore.forever == duration ? "forever" : duration}, \ntime: ${DateTime.fromMicrosecondsSinceEpoch((_timestamp * 1000 * 1000).toInt())}";
}

abstract class ObjectStoreMetaData {
  int get currentCount;
  double get currentCost;

  int get maximumCount;
  double get maximumCost;
  double get maximumDuration;
}

class IntCodec extends ObjectCodec<int> {
  @override
  ByteData encode(int value) {
    final data = ByteData(8);
    data.setInt64(0, value);
    return data;
  }

  @override
  int decode(ByteData data) => data.getInt64(0);
}

class StringCodec extends ObjectCodec<String> {
  @override
  ByteData encode(String value) {
    final list = utf8.encode(value);

    return ByteData.view(Int8List.fromList(list).buffer);
  }

  @override
  String decode(ByteData data) {
    return utf8.decode(data.buffer.asInt8List());
  }
}

class DoubleCodec extends ObjectCodec<double> {
  @override
  ByteData encode(double value) {
    final data = ByteData(8);
    data.setFloat64(0, value);
    return data;
  }

  @override
  double decode(ByteData data) {
    return data.getFloat64(0);
  }
}

class BooleanCodec extends ObjectCodec<bool> {
  @override
  ByteData encode(bool value) {
    final data = ByteData(1);
    data.setInt8(0, value ? 1 : 0);
    return data;
  }

  @override
  bool decode(ByteData data) {
    return data.getInt8(0) == 1;
  }
}

class JsonCodec<T> extends ObjectCodec<T> {
  @override
  ByteData encode(T value) {
    final list = utf8.encode(jsonEncode(value));

    return ByteData.view(Int8List.fromList(list).buffer);
  }

  @override
  T decode(ByteData data) {
    final json = utf8.decode(data.buffer.asInt8List());
    if (json == null || json.isEmpty) return null;

    return jsonDecode(json);
  }
}

class MapCodec extends JsonCodec<Map> {}

class ListCodec extends JsonCodec<List> {}

class DataCodec extends ObjectCodec<ByteData> {
  @override
  ByteData encode(ByteData value) => value;

  @override
  ByteData decode(ByteData data) => data;
}

abstract class ObjectType {
  static final _values = [
    Object,
    int,
    bool,
    double,
    String,
    Map,
    List,
    ByteData,
  ];
  static int valueOf<T>() {
    return _values.indexOf(T) ?? 0;
  }

  static Type valueAt(int index) {
    if (index < 0 && index > _values.length) return null;
    return _values[index];
  }
}
