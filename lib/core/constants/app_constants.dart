/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Codeskate CRM';
  static const String appTagline = 'Smart Lead Management';

  /// Base URL of the WhatsApp/CRM backend (same as web CRM's VITE_BACKEND_URL).
  /// Defaults to the production backend so billing/WhatsApp work out of the box.
  /// Can be overridden at build time:
  ///   flutter run --dart-define=BACKEND_URL=https://your-backend.com
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.codeskate.com',
  );

  static bool get hasBackend => backendBaseUrl.trim().isNotEmpty;

  // Country code for phone auth (India)
  static const String countryCode = '+91';

  // Default lead statuses matching web CRM
  static const List<String> leadStatuses = [
    'New',
    'Ringing',
    'Meeting Fixed',
    'Negotiation',
    'Follow-up',
    'Closed-Won',
    'Lost',
  ];

  // Follow-up task types
  static const List<String> followUpTypes = [
    'Call',
    'WhatsApp',
    'Email',
    'Meeting',
    'Visit',
  ];

  // Pagination
  static const int leadsPageSize = 50;
  static const int messagesPageSize = 30;
  static const int notificationsPageSize = 30;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
}
