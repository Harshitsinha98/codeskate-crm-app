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

  // Follow-up task types (must match TASK_TYPES in backend followUpTasks.js)
  static const List<String> followUpTypes = [
    'Call',
    'WhatsApp',
    'Meeting',
    'Email',
    'Other',
  ];

  // Follow-up completion outcomes (must match TASK_OUTCOMES in the backend)
  static const List<String> followUpOutcomes = [
    'Connected',
    'No answer',
    'Follow-up required',
    'Meeting fixed',
    'Closed-won',
    'Lost',
  ];

  static const List<String> leadPriorities = ['Hot', 'Warm', 'Cold'];

  static const String appVersion = '1.0.0';
  static const String supportEmail = 'hello@codeskate.com';
  static const String supportWhatsApp = 'https://wa.me/919653043939';
  static const String webAppUrl = 'https://app.codeskate.com';

  // Pagination
  static const int leadsPageSize = 50;
  static const int messagesPageSize = 30;
  static const int notificationsPageSize = 30;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
}
