import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class FileStore {
  FileStore(this.directory);

  final Directory directory;

  String filenameFromKey(String key) {
    return md5.convert(utf8.encode(key)).toString();
  }

  String _filePathForKey(String key) {
    final filename = filenameFromKey(key);

    return _filePathForName(filename);
  }

  String _filePathForName(String filename) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return p.join(directory.path, filename);
  }

  bool _writeFile(String filePath, ByteData data) {
    final file = File(filePath);
    if (!file.existsSync()) {
      try {
        file.createSync();
      } on FileSystemException catch (e) {
        print('Failed to create file with exception: ${e.toString()}');
        return false;
      }
    }

    try {
      file.writeAsBytesSync(data.buffer.asInt8List());
    } on FileSystemException catch (e) {
      print('Failed to write file with exception: ${e.toString()}');
      return false;
    }
    return true;
  }

  ByteData _readFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    List<int> data;
    try {
      data = file.readAsBytesSync();
    } on FileSystemException catch (e) {
      print('Failed to read file with exception: ${e.toString()}');
      return null;
    }
    final list = Int8List.fromList(data);
    return ByteData.view(list.buffer);
  }

  ByteData dataForKey(String key) {
    final filePath = _filePathForKey(key);

    return _readFile(filePath);
  }

  bool setData(String key, ByteData data) {
    final filePath = _filePathForKey(key);

    return _writeFile(filePath, data);
  }

  bool removeForKey(String key) {
    final file = File(_filePathForKey(key));
    final exist = file.existsSync();

    if (exist) file.deleteSync();
    return exist;
  }

  void clear() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}
