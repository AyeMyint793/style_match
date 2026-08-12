import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<bool> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Register API Error: $e");
    }
    return false;
  }

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Login API Error: $e");
    }
    return false;
  }

  static Future<bool> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Forgot Password API Error: $e");
    }
    return false;
  }

  static Future<bool> resetPassword(String email, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "new_password": newPassword}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Reset Password API Error: $e");
    }
    return false;
  }

  static Future<bool> checkProfile(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-profile?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["has_profile"] == true;
      }
    } catch (e) {
      print("CheckProfile API Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> getProfile(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-profile?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data;
      }
    } catch (e) {
      print("GetProfile API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPreferences(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-preferences?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data;
      }
    } catch (e) {
      print("GetPreferences API Error: $e");
    }
    return null;
  }

  static Future<bool> saveProfile(
      String email, String name, String height, String size) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save-profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "name": name, "height": height, "size": size}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("SaveProfile API Error: $e");
    }
    return false;
  }

  static Future<bool> savePreferences(String email, String fit, String style) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save-preferences"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "fit": fit, "style": style}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("SavePreferences API Error: $e");
    }
    return false;
  }

  static Future<bool> saveOutfit(String email, String occasion, String season,
      List<int> itemIds, String description) async {
    try {
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
    } catch (e) {
      print("SaveOutfit API Error: $e");
    }
    return false;
  }

  static Future<List<dynamic>> getSavedOutfits(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-saved-outfits?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data["saved_outfits"];
      }
    } catch (e) {
      print("GetSavedOutfits API Error: $e");
    }
    return [];
  }

  static Future<bool> deleteSavedOutfit(int id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/delete-saved-outfit/$id"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("DeleteSavedOutfit API Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> completeOutfit(
      String email, Map<String, dynamic> selectedItem, String weather) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/complete-outfit"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "selected_item": selectedItem, "weather": weather}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data["outfit"];
      }
    } catch (e) {
      print("CompleteOutfit API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> analyzeWardrobe(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/analyze-wardrobe?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data;
      }
    } catch (e) {
      print("AnalyzeWardrobe API Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getClothes(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-clothes?email=$email"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data["clothes"];
      }
    } catch (e) {
      print("GetClothes API Error: $e");
    }
    return [];
  }

  static Future<bool> saveClothes(
    String email,
    String imagePath,
    String category,
    String subcategory,
    String occasion,
    String season,
    String color,
    String stylistNote,
  ) async {
    try {
      final payload = {
        "email": email,
        "image_path": imagePath,
        "category": category,
        "subcategory": subcategory,
        "occasion": occasion,
        "season": season,
        "color": color,
        "stylist_note": stylistNote,
      };
      print('saveClothes payload: $payload');
      final response = await http.post(
        Uri.parse("$baseUrl/save-clothes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      print('saveClothes response status: ${response.statusCode}');
      print('saveClothes response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("SaveClothes API Error: $e");
    }
    return false;
  }

  static Future<bool> deleteClothes(int itemId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/delete-clothes/$itemId"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("DeleteClothes API Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> generateOutfit(
    String email,
    String occasion,
    String season,
    String weather,
    List<int> shownItemIds,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/generate-outfit"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "occasion": occasion,
          "season": season,
          "weather": weather,
          "shown_item_ids": shownItemIds,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("GenerateOutfit API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> tripPacking(
    String email,
    String destination,
    int days,
    String tripType,
    String activities,
    String weather,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/trip-packing"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "destination": destination,
          "days": days,
          "trip_type": tripType,
          "activities": activities,
          "weather": weather,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("TripPacking API Error: $e");
    }
    return null;
  }
}
