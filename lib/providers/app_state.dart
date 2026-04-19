import 'package:flutter/material.dart';
import 'package:wsa_new/models/app_user.dart';
import 'package:wsa_new/models/guardian_contact.dart';
import 'package:wsa_new/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isEmergencyMode = false;
  List<GuardianContact> _contacts = [];

  AppUser? get currentUser => _currentUser;
  bool get isEmergencyMode => _isEmergencyMode;
  List<GuardianContact> get contacts => _contacts;
  List<String> get guardianPhones => _contacts.map((c) => c.phone).toList();

  void setCurrentUser(AppUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id);
    await prefs.setString('userName', user.name);
    await prefs.setBool('isSafe', user.isSafe);
    refreshContacts();
    notifyListeners();
  }

  Future<void> refreshContacts() async {
    if (_currentUser == null) return;
    _contacts = await ApiService().fetchContacts(_currentUser!.id);
    notifyListeners();
  }

  Future<void> addContact(String name, String phone) async {
    if (_currentUser == null) return;
    final contact = GuardianContact(
      id: '', // Server will handle ID
      userId: _currentUser!.id,
      name: name,
      phone: phone,
    );
    await ApiService().addContact(contact);
    await refreshContacts();
  }

  Future<void> removeContact(String contactId) async {
    await ApiService().deleteContact(contactId);
    await refreshContacts();
  }

  Future<void> updateContact(GuardianContact contact) async {
    await ApiService().updateContact(contact);
    await refreshContacts();
  }

  void setEmergencyMode(bool val) {
    _isEmergencyMode = val;
    notifyListeners();
  }

  bool get isSafe => _currentUser?.isSafe ?? true;

  Future<void> updateSafeStatus(bool val) async {
    if (_currentUser == null) return;
    final success = await ApiService().updateSafeStatus(_currentUser!.id, val);
    if (success) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        phone: _currentUser!.phone,
        password: _currentUser!.password,
        role: _currentUser!.role,
        isSafe: val,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSafe', val);
      notifyListeners();
    }
  }

  Future<bool> updateProfile(String name, String email, String phone) async {
    if (_currentUser == null) return false;
    final updatedUser = AppUser(
      id: _currentUser!.id,
      name: name,
      email: email,
      phone: phone,
      password: _currentUser!.password,
      role: _currentUser!.role,
      isSafe: _currentUser!.isSafe,
    );
    
    final result = await ApiService().updateUser(updatedUser);
    if (result != null) {
      _currentUser = result;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> login(String phone, String password) async {
    final user = await ApiService().login(phone, password);
    if (user != null) {
      _currentUser = user;
      await refreshContacts();
      return true;
    }
    return false;
  }

  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;
    final success = await ApiService().deleteUser(_currentUser!.id);
    if (success) {
      logout();
      return true;
    }
    return false;
  }

  void logout() async {
    _currentUser = null;
    _contacts = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
