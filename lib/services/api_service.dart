import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["message"] == "Login successful") {
        return true;
      }
    }

    return false;
  }

  static Future<bool> checkProfile(String email) async {
    final response = await http.get(
      Uri.parse("$baseUrl/get-profile?email=$email"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["has_profile"] == true;
    }

    return false;
  }

  static Future<Map<String, dynamic>?> getProfile(String email) async {
    final response = await http.get(
      Uri.parse("$baseUrl/get-profile?email=$email"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["has_profile"] == true) {
        return data;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getPreferences(String email) async {
    final response = await http.get(
      Uri.parse("$baseUrl/get-preferences?email=$email"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return data;
      }
    }

    return null;
  }

  static Future<bool> saveProfile(String email, String name, String height, String size) async {
    final response = await http.post(
      Uri.parse("$baseUrl/save-profile"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "name": name,
        "height": height,
        "size": size,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["success"] == true;
    }

    return false;
  }

  static Future<bool> savePreferences(String email, String fit, String style) async {
    final response = await http.post(
      Uri.parse("$baseUrl/save-preferences"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "fit": fit,
        "style": style,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["success"] == true;
    }

    return false;
  }
  // Save outfit
  static Future<bool> saveOutfit(String email, String occasion, String season, List<int> itemIds, String description) async {
    final response = await http.post(
      Uri.parse("$baseUrl/save-outfit"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "occasion": occasion,
        "season": season,
        "item_ids": itemIds,
        "description": description,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["success"] == true;
    }
    return false;
  }

// Get saved outfits
  static Future<List<dynamic>> getSavedOutfits(String email) async {
    final response = await http.get(
      Uri.parse("$baseUrl/get-saved-outfits?email=$email"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return data["saved_outfits"];
      }
    }
    return [];
  }

// Delete saved outfit
  static Future<bool> deleteSavedOutfit(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/delete-saved-outfit/$id"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["success"] == true;
    }
    return false;
  }

  // Complete outfit from selected item
  static Future<Map<String, dynamic>?> completeOutfit(
      String email, Map<String, dynamic> selectedItem, String weather) async {
    final response = await http.post(
      Uri.parse("$baseUrl/complete-outfit"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "selected_item": selectedItem,
        "weather": weather,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return data["outfit"];
      }
    }
    return null;
  }
  // Analyze wardrobe gaps
  static Future<Map<String, dynamic>?> analyzeWardrobe(String email) async {
    final response = await http.get(
      Uri.parse("$baseUrl/analyze-wardrobe?email=$email"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return data;
      }
    }
    return null;
  }
}