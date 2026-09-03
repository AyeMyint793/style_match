import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:style_match/services/wardrobe_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WardrobeCacheService Tests', () {
    const String email = "test@example.com";

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and retrieve clothes cache', () async {
      final List<Map<String, String>> clothes = [
        {
          "id": "1",
          "path": "https://cloudinary.com/test1.jpg",
          "image_path": "https://cloudinary.com/test1.jpg",
          "category": "Tops",
          "subcategory": "T-Shirt",
          "occasion": "Casual",
          "season": "Summer",
          "color": "Blue",
        }
      ];

      await WardrobeCacheService.saveCachedClothes(email, clothes);
      final retrieved = await WardrobeCacheService.getCachedClothes(email);

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 1);
      expect(retrieved[0]["subcategory"], "T-Shirt");
      expect(retrieved[0]["color"], "Blue");
    });

    test('should save and retrieve stats cache', () async {
      final Map<String, dynamic> stats = {
        "total_items": 10,
        "dominant_colors": [{"value": "Blue", "count": 5}],
      };

      await WardrobeCacheService.saveCachedStats(email, stats);
      final retrieved = await WardrobeCacheService.getCachedStats(email);

      expect(retrieved, isNotNull);
      expect(retrieved!["total_items"], 10);
    });

    test('should save and retrieve gaps cache', () async {
      final List<dynamic> gaps = [
        {"suggestion": "Add more formal shoes"}
      ];

      await WardrobeCacheService.saveCachedGaps(email, gaps);
      final retrieved = await WardrobeCacheService.getCachedGaps(email);

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 1);
      expect(retrieved[0]["suggestion"], "Add more formal shoes");
    });

    test('should save and retrieve saved outfits cache', () async {
      final List<dynamic> outfits = [
        {
          "id": 1,
          "occasion": "Casual",
          "season": "Summer",
          "description": "Smart casual summer look",
          "items": [
            {"id": 1, "category": "Tops", "subcategory": "T-Shirt", "color": "White", "image_path": "https://..."}
          ],
          "tags": ["Casual", "Weekend"]
        }
      ];

      await WardrobeCacheService.saveCachedSavedOutfits(email, outfits);
      final retrieved = await WardrobeCacheService.getCachedSavedOutfits(email);

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 1);
      expect(retrieved[0]["occasion"], "Casual");
    });

    test('should clear user cache on logout', () async {
      final List<Map<String, String>> clothes = [
        {"id": "1", "path": "path", "category": "Tops"}
      ];
      await WardrobeCacheService.saveCachedClothes(email, clothes);
      expect(await WardrobeCacheService.getCachedClothes(email), isNotNull);

      await WardrobeCacheService.clearUserCache(email);
      expect(await WardrobeCacheService.getCachedClothes(email), isNull);
    });

    test('should return null when cache is empty', () async {
      final retrieved = await WardrobeCacheService.getCachedClothes(email);
      expect(retrieved, isNull);
    });
  });
}
