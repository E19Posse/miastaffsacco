import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _prefix = 'cache_';
  static const _tsPrefix = 'cache_ts_';

  static Future<Map<String, dynamic>?> get(String key, {int ttlSeconds = 300}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts    = prefs.getInt('$_tsPrefix$key') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - ts > ttlSeconds * 1000) return null;
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  static Future<List<dynamic>?> getList(String key, {int ttlSeconds = 300}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts    = prefs.getInt('$_tsPrefix$key') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - ts > ttlSeconds * 1000) return null;
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try { return jsonDecode(raw) as List<dynamic>; } catch (_) { return null; }
  }

  static Future<void> set(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
    await prefs.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_tsPrefix$key');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix));
    for (final k in keys) await prefs.remove(k);
  }
}
