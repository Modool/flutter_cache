import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_object_cache/flutter_object_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectCodec', () {
    test('default codecs', () {
      expect(ObjectCodec.intCodec, isNotNull);
      expect(ObjectCodec.stringCodec, isNotNull);
      expect(ObjectCodec.booleanCodec, isNotNull);
      expect(ObjectCodec.doubleCodec, isNotNull);
      expect(ObjectCodec.dataCodec, isNotNull);
    });

    test('default codecs map', () {
      expect(ObjectCodec.codec<int>(), ObjectCodec.intCodec);
    });
  });

  group('integer codec', () {
    final codec = ObjectCodec.intCodec;

    test('encoding', () {
      final data = codec.encode(-1);
      final value = codec.decode(data);
      expect(value, -1);
    });

    test('decoding', () {
      final data = ByteData(8);
      data.setInt64(0, -1);

      expect(codec.decode(data), -1);
    });
  });

  group('uinteger codec', () {
    final codec = ObjectCodec.intCodec;

    test('encoding', () {
      final data = codec.encode(1);
      final value = codec.decode(data);
      expect(value.toUnsigned(8), 1);
    });

    test('decoding', () {
      final data = ByteData(8);
      data.setInt64(0, 1);

      expect(codec.decode(data), 1);
    });
  });

  group('string codec', () {
    final codec = ObjectCodec.stringCodec;

    test('encoding', () {
      final data = codec.encode('test');
      final value = codec.decode(data);

      expect(value, 'test');
    });

    test('decoding', () {
      final list = utf8.encode('test');

      expect(
          codec.decode(ByteData.view(Int8List.fromList(list).buffer)), 'test');
    });
  });

  group('boolean codec', () {
    final codec = ObjectCodec.booleanCodec;

    test('encoding', () {
      final data = codec.encode(true);
      final value = codec.decode(data);

      expect(value, true);
    });

    test('decoding', () {
      final data = ByteData(1);
      data.setInt8(0, 1);

      expect(codec.decode(data), true);
    });
  });

  group('double codec', () {
    final codec = ObjectCodec.doubleCodec;

    test('encoding', () {
      final data = codec.encode(0.01);
      final value = codec.decode(data);

      expect(value, 0.01);
    });

    test('decoding', () {
      final data = ByteData(8);
      data.setFloat64(0, 0.01);

      expect(codec.decode(data), 0.01);
    });
  });

  group('data codec', () {
    final codec = ObjectCodec.dataCodec;

    test('encoding', () {
      final data = ByteData(1);
      final result = codec.encode(data);

      expect(data, result);
    });

    test('decoding', () {
      final data = ByteData(1);
      final result = codec.decode(data);

      expect(data, result);
    });
  });

  group('json codec', () {
    group('map', () {
      final codec = ObjectCodec.mapCodec;

      test('encoding', () {
        final data = codec.encode({'key': 'value'});
        final value = codec.decode(data);

        expect(value, {'key': 'value'});
      });

      test('decoding', () {
        final list = utf8.encode(jsonEncode({'key': 'value'}));
        final data = ByteData.view(Int8List.fromList(list).buffer);

        expect(codec.decode(data), {'key': 'value'});
      });
    });

    group('list', () {
      final codec = ObjectCodec.listCodec;

      test('encoding', () {
        final data = codec.encode([1, 2]);
        final value = codec.decode(data);

        expect(value, [1, 2]);
      });

      test('decoding', () {
        final list = utf8.encode(jsonEncode([1, 2]));
        final data = ByteData.view(Int8List.fromList(list).buffer);

        expect(codec.decode(data), [1, 2]);
      });
    });
  });

  group('ObjectType', () {
    test('map', () {
      final type = ObjectType.valueOf<int>();

      expect(type, 1);
    });
  });
}
