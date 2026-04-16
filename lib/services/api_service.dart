import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wsa_new/models/app_user.dart';
import 'package:wsa_new/models/emergency_alert.dart';
import 'package:wsa_new/models/guardian_contact.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  // Use 10.0.2.2 for Android Emulator, or your Local IP for physical devices
  static const String baseUrl = "http://10.233.219.21:3000/api";

  factory ApiService() => _instance;
  ApiService._internal();

  Future<bool> registerUser(AppUser user) async {
    final url = '$baseUrl/register';
    try {
      print("🚀 API: Attempting Sign Up at $url...");
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(user.toMap()),
          )
          .timeout(const Duration(seconds: 10));

      print("📩 API: Status Code: ${response.statusCode}");
      if (response.statusCode == 201) {
        print("✅ Signup Success!");
        return true;
      } else {
        print("❌ Signup Failed with body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("💥 API: CRITICAL Signup Error at $url: $e");
      return false;
    }
  }

  Future<AppUser?> updateUser(AppUser user) async {
    final url = '$baseUrl/users/${user.id}';
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(user.toMap()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AppUser.fromMap(jsonDecode(response.body));
      }
    } catch (e) {
      print("API: Update Error at $url: $e");
    }
    return null;
  }

  Future<bool> updateSafeStatus(String userId, bool isSafe) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/safe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isSafe': isSafe}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Safe Status Error: $e");
      return false;
    }
  }

  Future<AppUser?> login(String phone, String password) async {
    final url = '$baseUrl/login';
    try {
      print("🚀 API: Attempting Login at $url...");
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print("📩 API: Status Code: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("✅ Login Success!");
        return AppUser.fromMap(jsonDecode(response.body));
      } else {
        print("❌ Login Failed with body: ${response.body}");
      }
    } catch (e) {
      print("💥 API: CRITICAL Login Error at $url: $e");
    }
    return null;
  }

  Future<EmergencyAlert?> saveAlert(EmergencyAlert alert) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(alert.toMap()),
      );
      if (response.statusCode == 201) {
        return EmergencyAlert.fromMap(jsonDecode(response.body));
      }
    } catch (e) {
      print("Alert API Error: $e");
    }
    return null;
  }

  Future<List<EmergencyAlert>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/alerts'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((m) => EmergencyAlert.fromMap(m)).toList();
      }
    } catch (e) {
      print("Fetch Alerts API Error: $e");
    }
    return [];
  }

  Future<void> deleteAlert(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/alerts/$id'));
    } catch (e) {
      print("Delete Alert API Error: $e");
    }
  }

  Future<List<EmergencyAlert>> fetchGuardianAlerts(String guardianPhone) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/alerts/guardian/$guardianPhone'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((m) => EmergencyAlert.fromMap(m)).toList();
      }
    } catch (e) {
      print("Fetch Guardian Alerts API Error: $e");
    }
    return [];
  }

  Future<void> sendCommand(
    String userId,
    String commandType,
    String guardianPhone,
  ) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/commands'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'commandType': commandType,
          'guardianPhone': guardianPhone,
        }),
      );
    } catch (e) {
      print("Send Command API Error: $e");
    }
  }

  Future<List<dynamic>> getPendingCommands(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/commands/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Poll Commands Error: $e");
    }
    return [];
  }

  Future<void> markCommandDone(String commandId) async {
    try {
      await http.put(Uri.parse('$baseUrl/commands/$commandId'));
    } catch (e) {
      print("Mark Command Done Error: $e");
    }
  }

  Future<List<AppUser>> fetchProtectedUsers(String guardianPhone) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/protected/$guardianPhone'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((m) => AppUser.fromMap(m)).toList();
      }
    } catch (e) {
      print("Fetch Protected Users Error: $e");
    }
    return [];
  }

  Future<void> addContact(GuardianContact contact) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(contact.toMap()),
      );
    } catch (e) {
      print("Add Contact API Error: $e");
    }
  }

  Future<void> updateContact(GuardianContact contact) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/contacts/${contact.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(contact.toMap()),
      );
    } catch (e) {
      print("Update Contact API Error: $e");
    }
  }

  Future<List<GuardianContact>> fetchContacts(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/contacts/$userId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((m) => GuardianContact.fromMap(m)).toList();
      }
    } catch (e) {
      print("Fetch Contacts API Error: $e");
    }
    return [];
  }

  Future<void> deleteContact(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/contacts/$id'));
    } catch (e) {
      print("Delete Contact API Error: $e");
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$userId'));
      return response.statusCode == 200;
    } catch (e) {
      print("Delete User API Error: $e");
      return false;
    }
  }

  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'newPassword': newPassword}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Reset Password API Error: $e");
      return false;
    }
  }
}
