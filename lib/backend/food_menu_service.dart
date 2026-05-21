import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';

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
  List<FoodMenu>? _cachedMenus;
  DateTime? _lastFetchAt;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<FoodMenu>> fetchMenus({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedMenus != null &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _cacheDuration) {
      return _cachedMenus!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/food-menu'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final menus = data
            .map((json) => FoodMenu.fromJson(json))
            .toList(growable: false);
        _cachedMenus = menus;
        _lastFetchAt = DateTime.now();
        return menus;
      } else {
        throw Exception('Failed to load food menu: ${response.statusCode}');
      }
    } catch (e) {
      return _cachedMenus ?? [];
    }
  }
}
