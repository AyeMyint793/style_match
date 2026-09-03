import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WardrobeCacheService {
  static const String _prefixClothes = "wardrobe_clothes_";
  static const String _prefixStats = "wardrobe_stats_";
  static const String _prefixGaps = "wardrobe_gaps_";
  static const String _prefixOutfits = "wardrobe_saved_outfits_";

  static Future<void> saveCachedClothes(String email, List<Map<String, String>> clothes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(clothes);
      await prefs.setString("$_prefixClothes$email", jsonStr);
    } catch (e) {
      debugPrint("WardrobeCacheService: Error saving clothes to cache: $e");
    }
  }

  static Future<List<Map<String, String>>?> getCachedClothes(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString("$_prefixClothes$email");
      if (jsonStr == null) return null;
      final List<dynamic> decodedList = jsonDecode(jsonStr);
      return decodedList.map((item) => Map<String, String>.from(item)).toList();
    } catch (e) {
      debugPrint("WardrobeCacheService: Error loading clothes from cache: $e");
      return null;
    }
  }

  static Future<void> saveCachedStats(String email, Map<String, dynamic>? stats) async {
    if (stats == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("$_prefixStats$email", jsonEncode(stats));
    } catch (e) {
      debugPrint("WardrobeCacheService: Error saving stats to cache: $e");
    }
  }

  static Future<Map<String, dynamic>?> getCachedStats(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString("$_prefixStats$email");
      if (jsonStr == null) return null;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("WardrobeCacheService: Error loading stats from cache: $e");
      return null;
    }
  }

  static Future<void> saveCachedGaps(String email, List<dynamic>? gaps) async {
    if (gaps == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("$_prefixGaps$email", jsonEncode(gaps));
    } catch (e) {
      debugPrint("WardrobeCacheService: Error saving gaps to cache: $e");
    }
  }

  static Future<List<dynamic>?> getCachedGaps(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString("$_prefixGaps$email");
      if (jsonStr == null) return null;
      return jsonDecode(jsonStr) as List<dynamic>;
    } catch (e) {
      debugPrint("WardrobeCacheService: Error loading gaps from cache: $e");
      return null;
    }
  }

  static Future<void> saveCachedSavedOutfits(String email, List<dynamic> outfits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("$_prefixOutfits$email", jsonEncode(outfits));
    } catch (e) {
      debugPrint("WardrobeCacheService: Error saving saved outfits to cache: $e");
    }
  }

  static Future<List<dynamic>?> getCachedSavedOutfits(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString("$_prefixOutfits$email");
      if (jsonStr == null) return null;
      return jsonDecode(jsonStr) as List<dynamic>;
    } catch (e) {
      debugPrint("WardrobeCacheService: Error loading saved outfits from cache: $e");
      return null;
    }
  }

  static Future<void> clearUserCache(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("$_prefixClothes$email");
      await prefs.remove("$_prefixStats$email");
      await prefs.remove("$_prefixGaps$email");
      await prefs.remove("$_prefixOutfits$email");
    } catch (e) {
      debugPrint("WardrobeCacheService: Error clearing user cache: $e");
    }
  }
}
