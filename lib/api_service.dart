import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.15.125:8000/api';
  
  // Store authentication token (you can use SharedPreferences for persistence)
  static String? _authToken;
  static String? _username;
  static String? _password;
  
  // For basic auth (temporary solution)
  static void setBasicAuth(String username, String password) {
    _username = username;
    _password = password;
  }
  
  // For token auth
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    // Add token authentication if available
    if (_authToken != null) {
      headers['Authorization'] = 'Token $_authToken';
      print('Using token auth'); // Debug
    }
    // Or use basic auth as fallback
    else if (_username != null && _password != null) {
      final credentials = base64Encode(utf8.encode('$_username:$_password'));
      headers['Authorization'] = 'Basic $credentials';
      print('Using basic auth for user: $_username'); // Debug
    } else {
      print('WARNING: No authentication credentials set!'); // Debug
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load dashboard stats: $e');
    }
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load analytics: $e');
    }
  }

  Future<Map<String, dynamic>> getHiveStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/hive-stats/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load hive stats: $e');
    }
  }

  Future<List<dynamic>> getUserHives(int userId) async {
    try {
      // Get hives from hive-stats endpoint and filter by user
      final response = await http.get(
        Uri.parse('$baseUrl/admin/hive-stats/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userStats = data['users_statistics'] as List;
        
        // Find the user and return their hives
        for (var userStat in userStats) {
          if (userStat['user']['id'] == userId) {
            return userStat['hives'] as List;
          }
        }
        return []; // User not found or has no hives
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load user hives: $e');
    }
  }

  Future<Map<String, dynamic>> addHive(Map<String, dynamic> hiveData) async {
    try {
      print('Adding hive with data: $hiveData'); // Debug
      final headers = _getHeaders();
      print('Request headers: $headers'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/hives/'),
        headers: headers,
        body: json.encode(hiveData),
      );
      
      print('Response status: ${response.statusCode}'); // Debug
      print('Response body: ${response.body}'); // Debug
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      final errorBody = response.body;
      throw Exception('Status: ${response.statusCode}, Body: $errorBody');
    } catch (e) {
      print('Error in addHive: $e'); // Debug
      throw Exception('Failed to add hive: $e');
    }
  }

  Future<Map<String, dynamic>> getHiveDetails(int hiveId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load hive details: $e');
    }
  }

  Future<Map<String, dynamic>> getHiveStatistics(int hiveId, {int hours = 24}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/statistics/?hours=$hours'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load hive statistics: $e');
    }
  }
}