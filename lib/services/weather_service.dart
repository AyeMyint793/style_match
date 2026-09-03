import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class WeatherService {
  static Future<void> saveLastCity(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("last_city", city);
    } catch (e) {
      debugPrint("Error saving last city to SharedPreferences: $e");
    }
  }

  static Future<String?> getLastCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString("last_city");
    } catch (e) {
      debugPrint("Error loading last city from SharedPreferences: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getIpLocation() async {
    try {
      final response = await http.get(Uri.parse("https://ipapi.co/json/")).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data["city"]?.toString();
        final lat = data["latitude"];
        final lon = data["longitude"];
        if (city != null && city.isNotEmpty && lat != null && lon != null) {
          return {
            "city": city,
            "lat": (lat is num) ? lat.toDouble() : double.tryParse(lat.toString()),
            "lon": (lon is num) ? lon.toDouble() : double.tryParse(lon.toString()),
          };
        }
      }
    } catch (_) {
      try {
        final res2 = await http.get(Uri.parse("http://ip-api.com/json")).timeout(const Duration(seconds: 4));
        if (res2.statusCode == 200) {
          final data = jsonDecode(res2.body);
          if (data["status"] == "success") {
            return {
              "city": data["city"]?.toString() ?? "",
              "lat": (data["lat"] as num).toDouble(),
              "lon": (data["lon"] as num).toDouble(),
            };
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentWeather() async {
    try {
      double? lat;
      double? lon;

      // 1. Attempt GPS location first
      try {
        final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
        if (isServiceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 4),
              ),
            );

            // Detect if this is the default Android emulator Mountain View coordinate
            final bool isEmulatorDefault =
                (position.latitude - 37.422).abs() < 0.05 && (position.longitude - (-122.084)).abs() < 0.05;

            if (!isEmulatorDefault) {
              lat = position.latitude;
              lon = position.longitude;
            }
          }
        }
      } catch (e) {
        debugPrint("GPS location check exception: $e");
      }

      // 2. If GPS was emulator default, unavailable, or denied, fallback to IP Geolocation
      if (lat == null || lon == null) {
        final ipLoc = await getIpLocation();
        if (ipLoc != null && ipLoc["lat"] != null && ipLoc["lon"] != null) {
          lat = ipLoc["lat"] as double;
          lon = ipLoc["lon"] as double;
        }
      }

      // If still no location, try last saved city if available
      if (lat == null || lon == null) {
        final lastCity = await getLastCity();
        if (lastCity != null && lastCity.isNotEmpty && lastCity != "Mountain View") {
          return await getWeatherByCity(lastCity);
        }
        return null;
      }

      // 3. Call OpenWeatherMap API with coordinates
      final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return null;

      final url = "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data["name"] as String?;
        if (city != null && city.isNotEmpty) {
          await saveLastCity(city);
        }
        return {
          "temp": (data["main"]["temp"] as num).toDouble(),
          "description": data["weather"][0]["description"]?.toString() ?? "",
          "city": data["name"]?.toString() ?? "Local",
          "humidity": data["main"]["humidity"],
          "feels_like": (data["main"]["feels_like"] as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint("Weather error: $e");
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

  static Future<Map<String, dynamic>?> getWeatherByCity(String city) async {
    try {
      final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
      final url =
          "https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city)}&appid=$apiKey&units=metric";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cityName = data["name"] as String?;
        if (cityName != null && cityName.isNotEmpty) {
          await saveLastCity(cityName);
        }
        return {
          "temp": data["main"]["temp"].toDouble(),
          "description": data["weather"][0]["description"],
          "city": data["name"],
          "humidity": data["main"]["humidity"],
          "feels_like": data["main"]["feels_like"].toDouble(),
        };
      }
    } catch (e) {
      debugPrint("Weather by city error: $e");
    }
    return null;
  }
}