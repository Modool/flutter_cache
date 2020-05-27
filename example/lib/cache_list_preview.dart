import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_object_cache/flutter_object_cache.dart';

class CacheListPreview extends StatefulWidget {
  const CacheListPreview({Key key, this.objectStore}) : super(key: key);

  final ObjectStore objectStore;

  @override
  _CacheListPreviewState createState() => _CacheListPreviewState();
}

class _CacheListPreviewState extends State<CacheListPreview> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: widget.objectStore.allStoreObjects(),
      builder: (context, snapshot) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text(widget.objectStore.runtimeType.toString()),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView.separated(
            itemCount: snapshot.data is List ? snapshot.data.length : 0,
            separatorBuilder: (context, index) => SizedBox(
              height: 1,
              child: Container(
                color: Colors.grey,
              ),
            ),
            itemBuilder: (context, index) {
              final object = snapshot.data[index];

              return GestureDetector(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 80,
                    ),
                    Flexible(
                      child: Text(
                        object.toString(),
                        maxLines: 100,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.justify,
                      ),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                  ],
                ),
                onTap: () => _showActionSheetWith(context, object),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            child: Icon(
              Icons.add,
            ),
            onPressed: () async => _addTestObject(),
          ),
        ),
      ),
    );
  }

  Future _addTestObject() async {
    final random = Random.secure();
    final key = random.nextInt(1000);
    final value = random.nextInt(1000);

    await widget.objectStore.setObject(key.toString(), value);
    setState(() {});
  }

  void _showActionSheetWith(BuildContext context, StoreObject object) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('What do u want?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: Center(
              child: Text("delete"),
            ),
            onPressed: () async {
              await _deleteObject(object);
              Navigator.of(context).pop();
            },
          ),
          CupertinoActionSheetAction(
            child: Center(
              child: Text("cacnel"),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future _deleteObject(StoreObject object) async {
    await widget.objectStore.remove(object.key);
    setState(() {});
  }
}
