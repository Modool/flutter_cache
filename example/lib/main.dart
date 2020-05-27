import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_object_cache/flutter_object_cache.dart';

import 'cache_list_preview.dart';

Future<void> main() async {
  final tempDirectory = await Directory.systemTemp.createTemp();

  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Cache list"),
        ),
        body: CacheList(
          tempDirectory: tempDirectory,
        ),
      ),
    ),
  );
}

class CacheList extends StatelessWidget {
  const CacheList({Key key, this.tempDirectory}) : super(key: key);

  final Directory tempDirectory;

  Widget _buildRowWidget({String title, VoidCallback onPressed}) => Row(
        children: [
          Center(
            child: MaterialButton(
              child: Text(title),
              onPressed: onPressed,
            ),
          )
        ],
      );

  MaterialPageRoute _createPageRouteBuilder({String title, String routeName, Future<ObjectStore> store}) => MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (context) => FutureBuilder<ObjectStore>(
          future: store,
          builder: (context, snapshot) => CacheListPreview(
            objectStore: snapshot.data,
          ),
        ),
      );

  Widget _buildRow(BuildContext context, {String title, Future<ObjectStore> store}) => _buildRowWidget(
        title: title,
        onPressed: () {
          Navigator.push(
            context,
            _createPageRouteBuilder(
              title: title,
              routeName: title.split(" ").join("_"),
              store: store,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(
          context,
          title: "Memory Cache",
          store: _memoryStore(),
        ),
        _buildRow(
          context,
          title: "Sqflite Database Cache",
          store: _databaseStore(),
        ),
        _buildRow(
          context,
          title: "Mixture Sqflite Database Cache",
          store: _mixtureStore(),
        ),
      ],
    );
  }

  Future<ObjectMemoryStore> _memoryStore() async {
    final store = ObjectMemoryStore();

    _addDefaultData(store);
    return store;
  }

  static bool databaseStoreEverInitialized = false;
  Future<ObjectDatabaseStore> _databaseStore() async {
    final store = await ObjectDatabaseStore.objectStore(
      "cache",
      DatabaseStoreSqfliteImpl(
        name: "cache",
        directory: tempDirectory,
      ),
    );

    if (!databaseStoreEverInitialized) {
      _addDefaultData(store);
      databaseStoreEverInitialized = true;
    }
    return store;
  }

  static bool mixtureStoreEverInitialized = false;

  Future<CacheStore> _mixtureStore() async {
    final store = await CacheStore.sqfliteStore(
      name: "mixture_cache",
      directory: tempDirectory,
    );

    if (!mixtureStoreEverInitialized) {
      _addDefaultData(store);
      mixtureStoreEverInitialized = true;
    }

    return store;
  }

  Future _addDefaultData(ObjectStore store) async {
    await store.setObject("A", "a");
    await store.setObject("B", "b");
  }
}
