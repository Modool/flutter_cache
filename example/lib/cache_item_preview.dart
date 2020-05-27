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
    return FutureBuilder<List<StoreObject>>(
      future: widget.objectStore.allObjects(),
      builder: (context, snapshot) => ListView.builder(
        itemBuilder: (context, index) => Text(
          snapshot.data[index].toString(),
        ),
      ),
    );
  }
}
