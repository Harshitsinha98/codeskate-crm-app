/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Codeskate CRM';
  static const String appTagline = 'Smart Lead Management';

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
