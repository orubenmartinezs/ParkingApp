import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  static ConfigService get instance => _instance;

  ConfigService._internal();

  late SharedPreferences _prefs;
  static const String _keyApiUrl = 'api_base_url';
  static const String _keyTimezone = 'timezone';

  // Default to the one in constants
  String _apiUrl = AppConstants.defaultApiBaseUrl;
  String _timezone = 'America/Mexico_City';

  String get apiUrl => _apiUrl;
  String get timezone => _timezone;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    String? storedUrl = _prefs.getString(_keyApiUrl);
    String? storedTimezone = _prefs.getString(_keyTimezone);
    
    if (storedTimezone != null && storedTimezone.isNotEmpty) {
      _timezone = storedTimezone;
    }

    // Auto-fix: If stored URL is the known incorrect one, or null, use default
    // Also check for the one with trailing slash just in case
    if (storedUrl == null ||
        storedUrl == 'https://atmosfera22.online/parking-api' ||
        storedUrl == 'https://atmosfera22.online/parking-api/') {
      _apiUrl = AppConstants.defaultApiBaseUrl;
      await _prefs.setString(_keyApiUrl, _apiUrl);
    } else {
      _apiUrl = storedUrl;
    }
  }

  Future<void> setApiUrl(String url) async {
    // Remove trailing slash if present
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    _apiUrl = url;
    await _prefs.setString(_keyApiUrl, url);
  }

  Future<void> setTimezone(String tz) async {
    _timezone = tz;
    await _prefs.setString(_keyTimezone, tz);
  }
}
