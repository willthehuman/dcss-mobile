// Lightweight in-app debug log — web-only, remove before shipping.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int _maxEntries = 80;

class SocketLog extends StateNotifier<List<String>> {
  SocketLog() : super(const <String>[]);

  void add(String line) {
    if (!kIsWeb) return; // only collect on web
    final List<String> next = <String>[
      '[${DateTime.now().toIso8601String().substring(11, 23)}] $line',
      ...state,
    ];
    state = next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;
  }

  void clear() => state = const <String>[];
}

final socketLogProvider =
    StateNotifierProvider<SocketLog, List<String>>((ref) => SocketLog());
