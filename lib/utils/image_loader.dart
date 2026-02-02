import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

class ImageLoader {
  static final Map<String, ui.Image> _cache = {};

  static final Map<String, int> _refCount = {};

  static final Map<String, Completer<ui.Image>> _loading = {};

  static const int _maxCacheSize = 100;

  static Future<ui.Image?> loadImage(String url) async {
    if (_cache.containsKey(url)) {
      _refCount[url] = (_refCount[url] ?? 0) + 1;
      return _cache[url];
    }

    if (_loading.containsKey(url)) {
      return _loading[url]!.future;
    }

    final completer = Completer<ui.Image>();
    _loading[url] = completer;

    try {
      final ui.Image image;

      image = await _loadNetworkImage(url);

      if (_cache.length >= _maxCacheSize) {
        _cleanupCache();
      }

      _cache[url] = image;
      _refCount[url] = 1;
      completer.complete(image);

      return image;
    } finally {
      _loading.remove(url);
    }
  }

  static void _cleanupCache() {
    if (_cache.isEmpty) return;

    String? leastUsedUrl;
    int minRefCount = 999999;

    for (var entry in _refCount.entries) {
      if (entry.value < minRefCount) {
        minRefCount = entry.value;
        leastUsedUrl = entry.key;
      }
    }

    if (leastUsedUrl != null) {
      _cache[leastUsedUrl]?.dispose();
      _cache.remove(leastUsedUrl);
      _refCount.remove(leastUsedUrl);
    }
  }

  static Future<ui.Image> _loadNetworkImage(String url) async {
    final imageProvider = NetworkImage(url);
    final imageStream = imageProvider.resolve(ImageConfiguration.empty);

    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;

    listener = ImageStreamListener((ImageInfo image, bool synchronousCall) {
      completer.complete(image.image);
      imageStream.removeListener(listener);
    }, onError: (exception, stackTrace) {
      completer.completeError(exception, stackTrace);
      imageStream.removeListener(listener);
    });

    imageStream.addListener(listener);

    return completer.future;
  }

  static Future<List<ui.Image?>> loadImages(List<String> urls) async {
    return Future.wait(urls.map(loadImage));
  }
}
