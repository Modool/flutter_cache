import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../memory/object_file_store.dart';
import 'database_store.dart';

class DatabaseStoreSqfliteImpl extends DatabaseStore with DatabaseStoreMixin {
  DatabaseStoreSqfliteImpl({
    this.name,
    this.directory,
    FileStore fileStore,
    this.maximumMetadataLength = 2 * 1024,
  }) {
    _objectTableName = '${Table.objectNamePrefix}_$name';
    _fileStore = fileStore ?? FileStore(Directory('${directory.path}/${name}_cache'));
  }

  final String name;

  @override
  final Directory directory;

  String get filepath => p.join(directory.path, '$name.store');

  @override
  final int maximumMetadataLength;

  final _storeTableName = Table.storeName;

  FileStore _fileStore;

  Database _db;
  String _objectTableName;

  @override
  Future<bool> open() async {
    if (_db != null) return false;

    // Make sure the directory exists
    if (!directory.existsSync()) await directory.create(recursive: true);

    _db = await openDatabase(filepath, version: 1, onCreate: (db, version) async {
      final storeTableCreation = '''
      create table $_storeTableName ( 
        ${StoreColumn.id} integer primary key, 
        ${StoreColumn.name} text NOT NULL UNIQUE,
        ${StoreColumn.maximumCount} int, 
        ${StoreColumn.maximumCost} double,
        ${StoreColumn.maximumDuration} double,
        ${StoreColumn.currentCount} int,
        ${StoreColumn.currentCost} double,
        ${StoreColumn.rule} int
        )
      ''';
      final objectTableCreation = '''
      create table $_objectTableName ( 
        ${ObjectColumn.id} integer primary key, 
        ${ObjectColumn.key} text NOT NULL UNIQUE, 
        ${ObjectColumn.type} integer,
        ${ObjectColumn.cost} double,
        ${ObjectColumn.duration} double,
        ${ObjectColumn.timestamp} double,
        ${ObjectColumn.filename} text,
        ${ObjectColumn.metadata} text
        )
      ''';
      try {
        await db.execute(storeTableCreation);
        await db.execute(objectTableCreation);
      } catch (e) {
        print('Failed to create table with exception: ${e.toString()}');
      }
    });
    return _db != null;
  }

  bool _needsFileStore(ByteData data) {
    return data.lengthInBytes > maximumMetadataLength;
  }

  Future<Map> _transformObject(DatabaseStoreObject object, {bool encoding = true}) async {
    final metadata = object.metadata;
    final needsFile = _needsFileStore(metadata);

    final fileEnabled = encoding && needsFile;

    String filename;
    if (fileEnabled) {
      filename = _fileStore.filenameFromKey(object.key);

      if (!_fileStore.setData(object.key, metadata)) {
        return null;
      }
    }

    final map = {
      ObjectColumn.key: object.key,
      ObjectColumn.type: object.type,
      ObjectColumn.cost: object.cost,
      ObjectColumn.duration: object.duration,
      ObjectColumn.timestamp: object.timestamp,
      ObjectColumn.filename: filename ?? ''
    };
    if (!fileEnabled) map[ObjectColumn.metadata] = _encode(metadata);
    return map;
  }

  Future<List<DatabaseStoreObject>> _revertObjects(List<Map> maps, {bool decoding = true}) async {
    final objects = <DatabaseStoreObject>[];

    for (final map in maps) {
      objects.add(await _revertObject(map, decoding: decoding));
    }
    return objects;
  }

  Future<DatabaseStoreObject> _revertObject(Map map, {bool decoding = true}) async {
    final key = map[ObjectColumn.key];
    final filename = map[ObjectColumn.filename];
    final metadata = map[ObjectColumn.metadata];

    final data = decoding ? (filename.isEmpty ? _decode(metadata) : _fileStore.dataForKey(key)) : null;
    final type = map[ObjectColumn.type];
    final cost = map[ObjectColumn.cost];
    final duration = map[ObjectColumn.duration];
    final timestamp = map[ObjectColumn.timestamp];

    return DatabaseStoreObject(key: key, type: type, metadata: data, cost: cost, duration: duration, timestamp: timestamp);
  }

  ByteData _decode(String base64String) {
    final value = base64.decode(base64String);

    return ByteData.view(value.buffer);
  }

  String _encode(ByteData data) {
    final list = data.buffer.asUint8List();

    return base64.encode(list);
  }

  Future<T> wrapDatabaseExcutor<T>(Future<T> Function(Database database) excutor) async {
    try {
      return await excutor(_db);
    } catch (e) {
      print('Failed to excute sql with exception: ${e.toString()}');

      if (T is bool) {
        // ignore: avoid_as
        return false as T;
      }
      return null;
    }
  }

  @override
  Future<bool> updateInfo(ObjectStoreInfo info) async {
    final result = await wrapDatabaseExcutor<int>(
      (database) async => database.update(
        _storeTableName,
        info.toMap(),
      ),
    );
    return result != null;
  }

  @override
  Future<bool> insertInfo(ObjectStoreInfo info) async {
    final result = await wrapDatabaseExcutor<int>(
      (database) => database.insert(
        _storeTableName,
        info.toMap(),
      ),
    );

    return result != null;
  }

  @override
  Future<bool> existInfo(String name) async {
    final query = '''
      select 
      count(${StoreColumn.name}) 
      from $_storeTableName 
      where ${StoreColumn.name}= ?''';

    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.rawQuery(
        query,
        [name],
      ),
    );

    return maps?.first?.values?.first != 0;
  }

  @override
  Future<ObjectStoreInfo> fetchInfo(String name) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _storeTableName,
        columns: null,
        where: '${StoreColumn.name} = ?',
        whereArgs: [name],
      ),
    );
    if (maps.isNotEmpty) {
      final map = maps.first;

      return ObjectStoreInfo(
          name: map[StoreColumn.name],
          maximumCount: map[StoreColumn.maximumCount],
          maximumCost: map[StoreColumn.maximumCost],
          maximumDuration: map[StoreColumn.maximumDuration],
          currentCount: map[StoreColumn.currentCount],
          currentCost: map[StoreColumn.currentCost],
          rule: DatabaseObjectStoreRule.rules[map[StoreColumn.rule]]);
    }
    return null;
  }

  @override
  Future<DatabaseStoreObject> objectByKey(String key, {bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        columns: null,
        where: '${ObjectColumn.key} = ?',
        whereArgs: [key],
      ),
    );

    if (maps.isNotEmpty) return _revertObject(maps.first, decoding: decoding);
    return null;
  }

  @override
  Future<List<DatabaseStoreObject>> objectsByKeys(
    List<String> keys, {
    bool decoding = true,
  }) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        columns: null,
        where: '${ObjectColumn.key} IN (?)',
        whereArgs: [
          keys.join(","),
        ],
      ),
    );

    if (maps.isNotEmpty) return _revertObjects(maps, decoding: decoding);
    return null;
  }

  @override
  Future<List<DatabaseStoreObject>> objectsByCondition(
      {bool distinct,
      List<String> columns,
      String where,
      List<dynamic> whereArgs,
      String groupBy,
      String having,
      String orderBy,
      int limit,
      int offset,
      bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(_objectTableName,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset),
    );

    if (maps.isNotEmpty) return _revertObjects(maps, decoding: decoding);
    return null;
  }

  @override
  Future<List<DatabaseStoreObject>> allObjects({bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        columns: null,
      ),
    );
    if (maps != null) return _revertObjects(maps, decoding: decoding);

    return null;
  }

  @override
  Future<bool> update(DatabaseStoreObject object, {bool encoding = true}) async {
    final map = await _transformObject(object, encoding: encoding);
    if (null == map) return false;

    final result = await wrapDatabaseExcutor<int>(
      (database) => database.update(
        _objectTableName,
        map,
        where: '${ObjectColumn.key} = ?',
        whereArgs: [object.key],
      ),
    );

    return result != null;
  }

  @override
  Future<bool> insert(DatabaseStoreObject object, {bool encoding = true}) async {
    final map = await _transformObject(object, encoding: encoding);
    if (null == map) return false;

    final result = await wrapDatabaseExcutor<int>((database) => database.insert(_objectTableName, map));

    return result != null;
  }

  @override
  Future<bool> delete(String key) async {
    final result = await wrapDatabaseExcutor<int>(
      (database) => database.delete(
        _objectTableName,
        where: '${ObjectColumn.key} = ?',
        whereArgs: [
          key,
        ],
      ),
    );

    final success = result != null;
    if (success) _fileStore.removeForKey(key);

    return success;
  }

  @override
  Future<bool> deleteObjects(List<String> keys) async {
    final list = keys.join(',');

    final result = await wrapDatabaseExcutor<int>(
      (database) => database.delete(
        _objectTableName,
        where: '${ObjectColumn.key} IN ( $list )',
      ),
    );

    final success = result != null;
    if (success) {
      keys.forEach(_fileStore.removeForKey);
    }
    return success;
  }

  @override
  Future<bool> deleteAll() async {
    final result = await wrapDatabaseExcutor<int>((database) => database.delete(_objectTableName));

    final success = result != null;
    if (success) _fileStore.clear();

    return success;
  }

  @override
  Future<bool> existByKey(String key) async {
    final query = '''
      select 
      count(${ObjectColumn.key}) 
      from $_objectTableName 
      where ${ObjectColumn.key}= ?''';

    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.rawQuery(
        query,
        [key],
      ),
    );

    final value = maps?.first?.values?.first;
    return value != null && value != 0;
  }

  @override
  Future<List<DatabaseStoreObject>> objectsOverCapacity(int capacity, {bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        columns: null,
        orderBy: '${ObjectColumn.timestamp} ASC',
        limit: 100,
        offset: capacity,
      ),
    );

    return _revertObjects(maps, decoding: decoding);
  }

  @override
  Future<List<DatabaseStoreObject>> oldObjects(double timestamp, {bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        where: '${ObjectColumn.timestamp} < ?',
        columns: null,
        whereArgs: [timestamp],
        limit: 100,
      ),
    );

    return _revertObjects(maps, decoding: decoding);
  }

  @override
  Future<List<DatabaseStoreObject>> timeoutObjects(double basedTimestamp, {bool decoding = true}) async {
    final maps = await wrapDatabaseExcutor<List<Map<String, dynamic>>>(
      (database) => database.query(
        _objectTableName,
        where: '(${ObjectColumn.timestamp} + ${ObjectColumn.duration} ) > ?',
        columns: null,
        whereArgs: [basedTimestamp],
        limit: 100,
      ),
    );

    return _revertObjects(maps, decoding: decoding);
  }

  @override
  Future close() async => _db.isOpen ? _db.close() : null;

  @override
  bool get isOpen => _db.isOpen;
}
