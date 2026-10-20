import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../core/api/api_client.dart';
import '../core/constants/app_constants.dart';

/// Connects a Facebook Page for Meta Lead Ads, in-app.
///
/// Flow (same backend the web CRM uses):
///   1. Facebook Login for Business → user access token
///   2. POST /api/ad-leads/meta/pages  {userAccessToken} → pages the user manages
///   3. POST /api/ad-leads/meta/connect {pageId, userAccessToken}
class MetaConnectException implements Exception {
  final String message;
  MetaConnectException(this.message);
  @override
  String toString() => message;
}

class MetaConnect {
  MetaConnect._();

  /// Launches Facebook login and returns a user access token, or throws.
  static Future<String> login() async {
    if (!AppConstants.metaAdsEnabled) {
      throw MetaConnectException('Meta Lead Ads isn\'t enabled for this app build yet.');
    }
    final result = await FacebookAuth.instance.login(
      loginTracking: LoginTracking.enabled,
      permissions: const [
        'pages_show_list',
        'leads_retrieval',
        'pages_manage_metadata',
        'pages_read_engagement',
      ],
    );
    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw MetaConnectException('Meta login did not return an access token.');
        }
        return token;
      case LoginStatus.cancelled:
        throw MetaConnectException('Meta login was cancelled.');
      default:
        throw MetaConnectException(result.message ?? 'Meta login failed. Please try again.');
    }
  }

  /// Pages the logged-in user can use for Lead Ads.
  static Future<List<Map<String, String>>> pages(String orgId, String userAccessToken) async {
    final r = await ApiClient.post('/api/ad-leads/meta/pages', body: {'orgId': orgId, 'userAccessToken': userAccessToken});
    return ((r['pages'] as List?) ?? [])
        .whereType<Map>()
        .map((p) => {'id': '${p['id']}', 'name': '${p['name']}'})
        .toList();
  }

  /// Subscribe the chosen Page's instant-form leads to this workspace.
  static Future<String> connect(String orgId, String pageId, String userAccessToken) async {
    final r = await ApiClient.post('/api/ad-leads/meta/connect', body: {'orgId': orgId, 'pageId': pageId, 'userAccessToken': userAccessToken});
    return '${r['pageName'] ?? 'Meta Page'}';
  }

  static Future<void> signOut() => FacebookAuth.instance.logOut();
}
