// services/subscription_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_model.dart';

class SubscriptionService {
  static const String _baseUrl = 'http://103.126.116.119:5000'; // Ganti dengan URL API Anda
  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  Future<Subscription> getSubscription() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/subscription'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Subscription.fromJson(data['data']);
      } else {
        // Fallback ke data default jika API error
        return _defaultSubscription();
      }
    } catch (e) {
      print('Error fetching subscription: $e');
      return _defaultSubscription();
    }
  }

  Subscription _defaultSubscription() {
    return Subscription(
      plan: 'FREE',
      status: 'inactive',
      endDate: DateTime.now().add(const Duration(days: 0)),
      startDate: DateTime.now(),
    );
  }
}