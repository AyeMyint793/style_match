import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_URL'] ?? "http://10.0.2.2:8000";

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
      debugPrint("Register API Error: $e");
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
      debugPrint("Login API Error: $e");
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
      debugPrint("Forgot Password API Error: $e");
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
      debugPrint("Reset Password API Error: $e");
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
      debugPrint("CheckProfile API Error: $e");
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
      debugPrint("GetProfile API Error: $e");
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
      debugPrint("GetPreferences API Error: $e");
    }
    return null;
  }

  static Future<bool> saveProfile(
      String email, String name, String height, String size,
      {String? gender, String? avatarUrl}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save-profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "name": name,
          "height": height,
          "size": size,
          "gender": gender ?? "Female",
          "avatar_url": avatarUrl ?? "",
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      debugPrint("SaveProfile API Error: $e");
    }
    return false;
  }

  static Future<String?> uploadAvatar(String localPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload-avatar"),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data["avatar_url"]?.toString();
        }
      }
    } catch (e) {
      debugPrint("UploadAvatar API Error: $e");
    }
    return null;
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
      debugPrint("SavePreferences API Error: $e");
    }
    return false;
  }

  static Future<bool> saveOutfit(String email, String occasion, String season,
      List<int> itemIds, String description, {List<String>? tags}) async {
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
          "tags": tags ?? [],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      debugPrint("SaveOutfit API Error: $e");
    }
    return false;
  }

  static Future<bool> updateOutfitTags(int outfitId, List<String> tags) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update-outfit-tags"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": outfitId,
          "tags": tags,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      debugPrint("UpdateOutfitTags API Error: $e");
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
      debugPrint("GetSavedOutfits API Error: $e");
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
      debugPrint("DeleteSavedOutfit API Error: $e");
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
      debugPrint("CompleteOutfit API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> analyzeWardrobe(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/analyze-wardrobe?email=$email"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data;
      }
    } catch (e) {
      debugPrint("AnalyzeWardrobe API Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>?> getClothes(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-clothes?email=$email"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data["clothes"];
      }
    } catch (e) {
      debugPrint("GetClothes API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> processWardrobeImage(String localPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/process-image"),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data;
        }
      } else {
        debugPrint("processWardrobeImage API Error: Status ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("processWardrobeImage API Exception: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> processMultiWardrobeImage(String localPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/process-multi-image"),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      } else {
        debugPrint("processMultiWardrobeImage Error: Status ${response.statusCode} - ${response.body}");
        try {
          final errData = jsonDecode(response.body);
          if (errData is Map<String, dynamic>) {
            return errData;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("processMultiWardrobeImage Exception: $e");
    }
    return null;
  }

  static Future<bool> batchSaveClothes(String email, List<Map<String, dynamic>> items) async {
    try {
      final payload = {
        "email": email,
        "items": items,
      };
      final response = await http.post(
        Uri.parse("$baseUrl/batch-save-clothes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      debugPrint("batchSaveClothes Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> saveClothes(
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
      final response = await http.post(
        Uri.parse("$baseUrl/save-clothes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data;
        }
      }
    } catch (e) {
      debugPrint("SaveClothes API Error: $e");
    }
    return null;
  }

  static Future<bool> updateClothes({
    required int id,
    String? category,
    String? subcategory,
    String? occasion,
    String? season,
    String? color,
    String? stylistNote,
  }) async {
    try {
      final payload = {
        "id": id,
        if (category != null) "category": category,
        if (subcategory != null) "subcategory": subcategory,
        if (occasion != null) "occasion": occasion,
        if (season != null) "season": season,
        if (color != null) "color": color,
        if (stylistNote != null) "stylist_note": stylistNote,
      };
      final response = await http.post(
        Uri.parse("$baseUrl/update-clothes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      debugPrint("UpdateClothes API Error: $e");
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
      debugPrint("DeleteClothes API Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> generateOutfit(
    String email,
    String occasion,
    String season,
    String weather,
    List<List<int>> previousOutfits,
    List<int> styleItemIds,
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
          "previous_outfits": previousOutfits,
          "style_item_ids": styleItemIds,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("GenerateOutfit API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> tripPacking(
    String email,
    String destination,
    int days,
    String tripType,
    String activities,
    String weather, {
    String? startDate,
    String? endDate,
  }) async {
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
          "start_date": startDate,
          "end_date": endDate,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("TripPacking API Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> regenerateDayOutfit({
    required String email,
    required String destination,
    required int dayNumber,
    required String date,
    required String activity,
    required String weather,
    required String tripType,
    required List<int> previousOutfitItemIds,
    required List<List<int>> otherDaysOutfits,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/regenerate-day-outfit"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "destination": destination,
          "day_number": dayNumber,
          "date": date,
          "activity": activity,
          "weather": weather,
          "trip_type": tripType,
          "previous_outfit_item_ids": previousOutfitItemIds,
          "other_days_outfits": otherDaysOutfits,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("RegenerateDayOutfit API Error: $e");
    }
    return null;
  }
}
