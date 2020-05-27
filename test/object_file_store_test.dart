import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_object_cache/flutter_object_cache.dart';

class MockFile extends Mock implements File {}

void main() {
  FileStore store;

  const string = 'aaaa';
  const key = 'key';
  final data = ByteData.view(Int8List.fromList(utf8.encode(string)).buffer);

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp();
    store = FileStore(Directory(p.join(temp.path, 'store')));
  });

  test('file path transform', () {
    final name1 = store.filenameFromKey('hhhhhhh');
    final name2 = store.filenameFromKey('hhhhhhh');

    expect(name1, isNotNull);
    expect(name1, name2);
  });

  const exception = FileSystemException('Failed');

  test('write', () async {
    final result = store.setData(key, data);
    expect(result, true);

    final file = MockFile();
    when(file.existsSync()).thenReturn(false);
    when(file.createSync(recursive: false)).thenReturn(null);

    when(file.writeAsBytesSync(any)).thenThrow(exception);
    IOOverrides.runZoned(() {
      final result = store.setData(key, data);
      expect(result, false);
    }, createFile: (path) => file);

    when(file.createSync(recursive: false)).thenThrow(exception);
    IOOverrides.runZoned(() {
      final result = store.setData(key, data);
      expect(result, false);
    }, createFile: (path) => file);
  });

  test('read', () async {
    final result = store.setData(key, data);
    expect(result, true);

    final local = store.dataForKey(key);
    expect(local, isNotNull);

    final file = MockFile();
    when(file.existsSync()).thenReturn(true);
    when(file.readAsBytesSync()).thenThrow(exception);

    IOOverrides.runZoned(() {
      final local = store.dataForKey(key);
      expect(local, isNull);
    }, createFile: (path) => file);
  });

  test('remove for key', () async {
    const string2 = 'bbbbbb';
    const key2 = 'key1';
    final data2 = ByteData.view(Int8List.fromList(utf8.encode(string2)).buffer);

    expect(store.setData(key, data), isTrue);
    expect(store.dataForKey(key), isNotNull);

    expect(store.setData(key2, data2), isTrue);
    expect(store.dataForKey(key2), isNotNull);

    expect(store.removeForKey(key), isTrue);
    expect(store.dataForKey(key), isNull);
    expect(store.dataForKey(key2), isNotNull);
  });

  test('clear', () async {
    expect(store.setData(key, data), isTrue);
    expect(store.dataForKey(key), isNotNull);

    store.clear();
    expect(store.dataForKey(key), isNull);
  });
}
