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

  Future<List<FoodMenu>> fetchMenus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/food-menu'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => FoodMenu.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load food menu: ${response.statusCode}');
      }
    } catch (e) {
      // For demo/fallback purposes if API is down
      return [];
    }
  }
}
