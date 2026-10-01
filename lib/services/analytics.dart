class Analytics {
  static final List<Map<String, Object?>> buffer = [];

  static void log(String name, [Map<String, Object?> params = const {}]) {
    buffer.add({'e': name, 't': DateTime.now().toIso8601String(), ...params});
    if (buffer.length > 200) buffer.removeAt(0);
  }
}
