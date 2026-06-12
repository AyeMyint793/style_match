import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static Future<Map<String, String>> detectClothing(String imagePath) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY']!;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: apiKey,
      );

      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      String mimeType = "image/jpeg";
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = "image/png";
      }

      final prompt = TextPart("""Look at this clothing image carefully.

Respond with ONLY this exact JSON format, no extra text:
{
  "category": "...",
  "subcategory": "...",
  "occasion": "...",
  "season": "...",
  "color": "..."
}

Category rules (choose ONE):
- Tops → t-shirt, shirt, blouse, crop top, tank top, kurta, hoodie
- Bottoms → jeans, trousers, shorts, skirt, leggings, salwar, dhoti
- Dress → dress, gown, saree, lehenga, salwar kameez (full outfit)
- Shoes → sneakers, heels, sandals, boots, flats, formal shoes, chappal
- Outerwear → jacket, coat, blazer, cardigan, shawl, dupatta
- Accessories → bag, belt, watch, jewelry, scarf, cap, sunglasses

Subcategory rules (be specific, choose ONE):
- For Tops: T-Shirt, Shirt, Blouse, Crop Top, Tank Top, Kurta, Hoodie, Sweater
- For Bottoms: Jeans, Trousers, Shorts, Skirt, Leggings, Salwar, Dhoti
- For Dress: Dress, Gown, Saree, Lehenga, Salwar Kameez
- For Shoes: Sneakers, Heels, Sandals, Boots, Flats, Formal Shoes
- For Outerwear: Jacket, Coat, Blazer, Cardigan, Shawl, Dupatta
- For Accessories: Bag, Belt, Watch, Jewelry, Scarf, Cap, Sunglasses

Occasion rules (choose ONE):
- Casual, Work, Formal, Date Night, Party, Brunch, Gym, Outdoor, Wedding, Travel

Season rules (choose ONE):
- Summer, Winter, All Season

Color rules:
- Identify the PRIMARY color of the item (e.g. Black, White, Blue, Red, Green, Yellow, Pink, Brown, Grey, Orange, Purple, Beige, Multicolor)

IMPORTANT: Return JSON only, no markdown, no explanation.""");

      final imagePart = DataPart(mimeType, imageBytes);

      final response = await model.generateContent([
        Content.multi([imagePart, prompt])
      ]);

      final text = response.text ?? "";
      print("Gemini Response: $text");

      final cleaned = text
          .replaceAll("```json", "")
          .replaceAll("```", "")
          .trim();

      final jsonResult = _parseJson(cleaned);

      return {
        "category": jsonResult["category"] ?? "Tops",
        "subcategory": jsonResult["subcategory"] ?? "T-Shirt",
        "occasion": jsonResult["occasion"] ?? "Casual",
        "season": jsonResult["season"] ?? "All Season",
        "color": jsonResult["color"] ?? "Unknown",
      };
    } catch (e) {
      print("AI Error: $e");
      return {
        "category": "Tops",
        "subcategory": "T-Shirt",
        "occasion": "Casual",
        "season": "All Season",
        "color": "Unknown",
      };
    }
  }

  static Map<String, dynamic> _parseJson(String text) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1) {
        final jsonStr = text.substring(start, end + 1);
        return jsonDecode(jsonStr);
      }
    } catch (e) {
      print("Parse error: $e");
    }
    return {};
  }
}