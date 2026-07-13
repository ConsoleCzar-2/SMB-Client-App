// To store the credentials of SMB connection on-device

import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences storage
const _keyHost     = 'smb_host';
const _keyShare    = 'smb_share';
const _keyUsername = 'smb_username';
const _keyPassword = 'smb_password';
const _keyRemember = 'smb_remember';

class CredentialService {

  // Save all credentials to device storage
  static Future<void> save({
    required String host,
    required String share,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setString(_keyShare, share);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
    await prefs.setBool(_keyRemember, true);
  }

  // Load saved credentials — returns null for each field if not saved
  static Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'host':     prefs.getString(_keyHost),
      'share':    prefs.getString(_keyShare),
      'username': prefs.getString(_keyUsername),
      'password': prefs.getString(_keyPassword),
    };
  }

  // Check if "remember me" was previously enabled
  static Future<bool> isRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRemember) ?? false;
  }

  // Wipe all saved credentials (for a "forget me" / logout option later)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyShare);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    await prefs.setBool(_keyRemember, false);
  }
}