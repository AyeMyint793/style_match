import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static Future<Map<String, dynamic>?> getCurrentWeather() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Call OpenWeatherMap API
      final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "temp": data["main"]["temp"].toDouble(),
          "description": data["weather"][0]["description"],
          "city": data["name"],
          "humidity": data["main"]["humidity"],
          "feels_like": data["main"]["feels_like"].toDouble(),
        };
      }
    } catch (e) {
      print("Weather error: $e");
    }
    return null;
  }

  static String getWeatherContext(Map<String, dynamic> weather) {
    final temp = weather["temp"] as double;
    final description = weather["description"] as String;

    String context = "Current weather: ${temp.toStringAsFixed(0)}°C, $description. ";

    if (temp >= 30) {
      context += "It is very hot. ";
    } else if (temp >= 22) {
      context += "It is warm. ";
    } else if (temp >= 15) {
      context += "It is mild. ";
    } else if (temp >= 5) {
      context += "It is cold. ";
    } else {
      context += "It is very cold. ";
    }

    return context;
  }
}