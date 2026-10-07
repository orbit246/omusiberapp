import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodMenu {
  final int id;
  final DateTime date;
  final List<String> items;
  final DateTime updatedAt;

  FoodMenu({
    required this.id,
    required this.date,
    required this.items,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FoodMenu.fromJson(Map<String, dynamic> json) {
    return FoodMenu(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      items: List<String>.from(json['items'] as List),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class FoodMenuService {
  static final FoodMenuService _instance = FoodMenuService._internal();
  factory FoodMenuService() => _instance;
  FoodMenuService._internal();

  String get _baseUrl => Constants.baseUrl;
  static const String _storageKey = 'cached_food_menus_v1';
  List<FoodMenu>? _cachedMenus;
  DateTime? _lastFetchAt;
  bool _persistentCacheLoaded = false;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<FoodMenu>> fetchMenus({bool forceRefresh = false}) async {
    await _loadPersistentCache();

    if (!forceRefresh &&
        _cachedMenus != null &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _cacheDuration) {
      return _cachedMenus!;
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/food-menu'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final menus = data
            .map((json) => FoodMenu.fromJson(json))
            .toList(growable: false);
        _cachedMenus = menus;
        _lastFetchAt = DateTime.now();
        await _savePersistentCache(menus, cachedAt: _lastFetchAt!);
        return menus;
      } else {
        throw Exception('Failed to load food menu: ${response.statusCode}');
      }
    } catch (e) {
      return _cachedMenus ?? [];
    }
  }

  Future<void> _loadPersistentCache() async {
    if (_persistentCacheLoaded) return;
    _persistentCacheLoaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      final rawMenus = decoded is Map<String, dynamic>
          ? decoded['menus']
          : decoded;
      if (rawMenus is! List) return;

      _cachedMenus = rawMenus
          .whereType<Map>()
          .map((item) => FoodMenu.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);

      final cachedAtValue = decoded is Map<String, dynamic>
          ? decoded['cachedAt']
          : null;
      _lastFetchAt =
          DateTime.tryParse(cachedAtValue?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } catch (e) {
      _cachedMenus = null;
      _lastFetchAt = null;
    }
  }

  Future<void> _savePersistentCache(
    List<FoodMenu> menus, {
    required DateTime cachedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'cachedAt': cachedAt.toIso8601String(),
          'menus': menus.map((menu) => menu.toJson()).toList(),
        }),
      );
    } catch (_) {
      // In-memory data remains available if persistent storage is unavailable.
    }
  }
}
