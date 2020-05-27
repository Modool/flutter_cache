# Flutter Object Cache Package

A Flutter package for caching object into memory or disk.

![Flutter Test](https://github.com/Modool/flutter_object_cache/workflows/Flutter%20Test/badge.svg) [![pub package](https://img.shields.io/pub/v/flutter_object_cache.svg)](https://pub.dartlang.org/packages/flutter_object_cache) [![Build Status](https://app.bitrise.io/app/fa4f5d4bf452bcfb/status.svg?token=HorGpL_AOw2llYz39CjmdQ&branch=master)](https://app.bitrise.io/app/fa4f5d4bf452bcfb) [![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)



## Features

* Provide 3 ways to cache object, memory cache, disk cache(sqlite database), mixed with disk and memory.
* Support to cache object of any type by ObjectCodec.
* Provide default codecs for base type, such as int, double, boolean, string, List, Map, ByteData.
* Support genericity to write object into database or read from database.
* Provide default rules(fifo, lifo) to control write operation,

## Usage

To use this package, add `flutter_object_cache` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/). For example:

```yaml
dependencies:
  flutter_object_cache: 0.0.1
```
 
## Issues

Please file any issues, bugs or feature request as an issue on our [Github](https://github.com/modool/flutter_object_cache/issues) page.

## Want to contribute

If you would like to contribute to the plugin (e.g. by improving the documentation, solving a bug or adding a cool new feature), please carefully review our [contribution guide](CONTRIBUTING.md) and send us your [pull request](https://github.com/modool/flutter_cache/pulls).

## Author

This Flutter object cache package for Flutter is developed by [modool](https://github.com/modool). You can contact us at <modool.go@gmail.com>
