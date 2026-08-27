import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/grocery_run.dart';
import '../models/grocery_run_item.dart';
import '../models/price_item.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

  String? _token;
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // --- Auth endpoints ---

  Future<bool> login(String email, String password) async {
    try {
      final url = '${ApiConfig.backendUrl}/api/auth/login';
      debugPrint("ApiService: Posting to $url");
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _token = body['token'];
        _currentUser = User.fromJson(body['user']);

        // Persist token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);

        return true;
      }
      debugPrint("ApiService: Login failed with code ${response.statusCode}: ${response.body}");
      return false;
    } catch (e) {
      debugPrint("ApiService: Login error: $e");
      return false;
    }
  }

  Future<bool> register(String email, String password, String name, double budgetGoal) async {
    try {
      final url = '${ApiConfig.backendUrl}/api/auth/register';
      debugPrint("ApiService: Posting to $url");
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'budgetGoal': budgetGoal,
        }),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        _token = body['token'];
        _currentUser = User.fromJson(body['user']);

        // Persist token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);

        return true;
      }
      debugPrint("ApiService: Registration failed with code ${response.statusCode}: ${response.body}");
      return false;
    } catch (e) {
      debugPrint("ApiService: Registration error: $e");
      return false;
    }
  }

  void logout() async {
    _token = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    } catch (e) {
      debugPrint("Error clearing persistent token: $e");
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      _token = token;
      final success = await fetchProfile();
      if (success) {
        return true;
      } else {
        _token = null;
        await prefs.remove('jwt_token');
        return false;
      }
    } catch (e) {
      debugPrint("ApiService: Auto login exception: $e");
      return false;
    }
  }

  Future<bool> fetchProfile() async {
    if (!isAuthenticated) return false;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.backendUrl}/api/auth/profile'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _currentUser = User.fromJson(body);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Fetch profile error: $e");
      return false;
    }
  }

  Future<List<PriceItem>> fetchCustomCommodities() async {
    if (!isAuthenticated) return [];
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/custom-commodities'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List body = jsonDecode(response.body) as List;
        return body.map((item) => PriceItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch custom commodities error: $e");
      return [];
    }
  }

  Future<bool> updateProfile({
    String? name,
    double? budgetGoal,
    String? language,
    String? preferredProvince,
    String? preferredMarket,
    int? runsCompleted,
    double? totalSaved,
  }) async {
    if (!isAuthenticated) return false;
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.backendUrl}/api/auth/profile'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (budgetGoal != null) 'budgetGoal': budgetGoal,
          if (language != null) 'language': language,
          if (preferredProvince != null) 'preferredProvince': preferredProvince,
          if (preferredMarket != null) 'preferredMarket': preferredMarket,
          if (runsCompleted != null) 'runsCompleted': runsCompleted,
          if (totalSaved != null) 'totalSaved': totalSaved,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _currentUser = User.fromJson(body);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Update profile error: $e");
      return false;
    }
  }

  // --- Runs Headers API ---

  Future<List<GroceryRun>> fetchRuns() async {
    if (!isAuthenticated) return [];
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.backendUrl}/api/runs'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List body = jsonDecode(response.body);
        return body.map((r) => GroceryRun.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch runs error: $e");
      return [];
    }
  }

  Future<GroceryRun?> createRun(String name, double budget) async {
    if (!isAuthenticated) return null;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendUrl}/api/runs'),
        headers: _headers,
        body: jsonEncode({'name': name, 'budget': budget}),
      );

      if (response.statusCode == 201) {
        return GroceryRun.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint("Create run error: $e");
      return null;
    }
  }

  Future<GroceryRun?> updateRun(String id, {String? name, double? budget, String? status}) async {
    if (!isAuthenticated) return null;
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/$id'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (budget != null) 'budget': budget,
          if (status != null) 'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return GroceryRun.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint("Update run error: $e");
      return null;
    }
  }

  Future<bool> deleteRun(String id) async {
    if (!isAuthenticated) return false;
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/$id'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete run error: $e");
      return false;
    }
  }

  // --- Run Items API ---

  Future<GroceryRunItem?> addRunItem(
    String runId, {
    required String commodity,
    required double price,
    required double quantity,
    required String unit,
    required String category,
    required String market,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/$runId/items'),
        headers: _headers,
        body: jsonEncode({
          'commodity': commodity,
          'price': price,
          'quantity': quantity,
          'unit': unit,
          'category': category,
          'market': market,
        }),
      );

      if (response.statusCode == 201) {
        return GroceryRunItem.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint("Add item error: $e");
      return null;
    }
  }

  Future<GroceryRunItem?> updateRunItem(
    String runId,
    String itemId, {
    double? price,
    double? quantity,
    bool? checked,
    String? category,
    String? market,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/$runId/items/$itemId'),
        headers: _headers,
        body: jsonEncode({
          if (price != null) 'price': price,
          if (quantity != null) 'quantity': quantity,
          if (checked != null) 'checked': checked,
          if (category != null) 'category': category,
          if (market != null) 'market': market,
        }),
      );

      if (response.statusCode == 200) {
        return GroceryRunItem.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint("Update item error: $e");
      return null;
    }
  }

  Future<bool> deleteRunItem(String runId, String itemId) async {
    if (!isAuthenticated) return false;
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.backendUrl}/api/runs/$runId/items/$itemId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete item error: $e");
      return false;
    }
  }

  // --- Scoped Dataset API ---

  Future<List<PriceItem>> fetchPriceDataset() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.datasetUrl}/api/prices'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List body = jsonDecode(response.body);
        return body.map((item) => PriceItem.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch price dataset error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchDatasetVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.datasetUrl}/api/version'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Fetch dataset version error: $e");
      return null;
    }
  }
}
