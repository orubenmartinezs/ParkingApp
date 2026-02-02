class AppConstants {
  // Use 10.0.2.2 for Android Emulator, or your local IP for physical device
  // static const String apiBaseUrl = 'http://10.0.2.2/backend/api';
  static const String defaultApiBaseUrl =
      'https://atmosfera22.online/parking/api';
  // Note: apiBaseUrl is now dynamic via ConfigService

  // Fallback para tipos de entrada cuando la BD está corrupta o incompleta
  // (Solo usado en casos extremos, normalmente database_helper asegura el valor correcto)
  static const String fallbackEntryTypeName = 'SIN_CATEGORIA';
}
