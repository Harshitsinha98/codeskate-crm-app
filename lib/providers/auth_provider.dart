import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, otpSent, error }

/// Authentication provider using the **backend multichannel OTP** flow
/// (WhatsApp → SMS → Voice) instead of Firebase Phone Auth directly.
///
/// Flow: POST /api/v1/otp/send → user enters code → POST /api/v1/otp/verify
///       → backend returns Firebase custom token → signInWithCustomToken
///       → onAuthStateChanged fires → load membership/profile → authenticated.
///
/// This mirrors the React web CRM's AuthContext.jsx (which also uses the same
/// backend endpoints + signInWithCustomToken on native/Capacitor).
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String _error = '';
  String _lastPhone = '';
  String? _otpChannel; // whatsapp_meta | sms | voice
  bool _autoVerified = false;
  DateTime? _rateLimitedUntil;

  AuthState get state => _state;
  UserModel? get user => _user;
  String get error => _error;
  String? get otpChannel => _otpChannel;
  bool get isAuthenticated => _user != null && _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get autoVerified => _autoVerified;

  /// Seconds remaining before retry is allowed (0 = can retry now).
  int get retrySecondsLeft {
    if (_rateLimitedUntil == null) return 0;
    final diff = _rateLimitedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
  bool get isRateLimited => retrySecondsLeft > 0;

  String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        if (_state != AuthState.otpSent && _state != AuthState.loading) {
          _state = AuthState.unauthenticated;
          notifyListeners();
        }
        return;
      }
      await _loadUserProfile(firebaseUser);
    });
  }

  // ── OTP: Send ──────────────────────────────────────────────────────────────

  /// Send OTP via the backend multichannel flow (WhatsApp first, SMS fallback).
  /// [phoneNumber] is the raw 10-digit Indian mobile number.
  /// [channel] can force a specific channel: "whatsapp", "sms", "voice".
  Future<bool> sendOtp(String phoneNumber, {String? channel}) async {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      _error = 'Enter a valid 10-digit mobile number.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _lastPhone = digits;
    _autoVerified = false;
    _rateLimitedUntil = null;
    _state = AuthState.loading;
    _error = '';
    _otpChannel = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{'phone': digits};
      if (channel != null) body['channel'] = channel;

      debugPrint('[OTP] Sending to $_base/api/v1/otp/send body=$body');

      final res = await http
          .post(
            Uri.parse('$_base/api/v1/otp/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      final data = _safeDecode(res.body);
      debugPrint('[OTP] Response status=${res.statusCode} body=${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true) {
        _otpChannel = data['channel']?.toString();
        _state = AuthState.otpSent;
        notifyListeners();
        return true;
      }

      // Rate limited
      if (res.statusCode == 429) {
        final retryAfter = data['retryAfter'] as int? ?? 60;
        _error = 'Too many attempts. Retry in ${retryAfter}s.';
        _rateLimitedUntil = DateTime.now().add(Duration(seconds: retryAfter));
      } else {
        _error = data['error']?.toString() ??
            'Could not send OTP. Please check your internet.';
      }
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[OTP] sendOtp error: $e');
      _error = 'Network error — could not reach the server. Check your internet.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  // ── OTP: Verify ────────────────────────────────────────────────────────────

  /// Verify the 6-digit OTP code via backend → receive Firebase custom token
  /// → sign in with it. The authStateChanges listener then loads the profile.
  Future<bool> verifyOtp(String otp) async {
    if (otp.trim().length != 6) {
      _error = 'Enter a valid 6-digit code.';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _error = '';
    notifyListeners();

    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/v1/otp/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': _lastPhone, 'code': otp.trim()}),
          )
          .timeout(const Duration(seconds: 25));

      final data = _safeDecode(res.body);

      if (res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true) {
        final token = data['token']?.toString();
        if (token == null || token.isEmpty) {
          _error = 'Server error — no auth token received.';
          _state = AuthState.otpSent;
          notifyListeners();
          return false;
        }

        // Sign in with the custom token — this triggers onAuthStateChanged
        // which calls _loadUserProfile. We don't navigate here; the router
        // redirect will pick up isAuthenticated and navigate to /dashboard.
        await _auth.signInWithCustomToken(token);
        return true;
      }

      _error = data['error']?.toString() ?? 'Invalid OTP. Please try again.';
      _state = AuthState.otpSent;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[OTP] verifyOtp error: $e');
      _error = 'Verification failed. Check your internet and retry.';
      _state = AuthState.otpSent;
      notifyListeners();
      return false;
    }
  }

  // ── OTP: Resend ────────────────────────────────────────────────────────────

  /// Resend OTP (optionally on a specific channel like "sms" or "voice").
  Future<bool> resendOtp(String phoneNumber, {String? channel}) =>
      sendOtp(phoneNumber, channel: channel);

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<void> _loadUserProfile(User firebaseUser, {int attempt = 0}) async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      final uid = firebaseUser.uid;
      final phone = firebaseUser.phoneNumber;

      final membershipsSnap = await _db
          .collection('memberships')
          .where('uid', isEqualTo: uid)
          .where('active', isEqualTo: true)
          .get();

      final activeMemberships = membershipsSnap.docs.where((doc) {
        final expiresAtMs = doc.data()['expiresAtMs'] as int?;
        return expiresAtMs == null ||
            expiresAtMs == 0 ||
            expiresAtMs > DateTime.now().millisecondsSinceEpoch;
      }).toList();

      if (activeMemberships.isEmpty) {
        _user = UserModel(uid: uid, phone: phone, needsSetup: true);
        _state = AuthState.authenticated;
        notifyListeners();
        return;
      }

      final userDoc = await _db.collection('users').doc(uid).get();

      final memberships = activeMemberships.map((m) {
        final data = m.data();
        return OrgMembership(
          orgId: data['orgId'] ?? '',
          role: data['role'] ?? 'employee',
          displayName: data['displayName'],
          membershipId: m.id,
        );
      }).toList();

      final activeOrgId = memberships.first.orgId;
      final activeMembership = memberships.first;

      final orgDoc =
          await _db.collection('organizations').doc(activeOrgId).get();

      final displayName = userDoc.exists
          ? (userDoc.data()?['displayName'] ??
              activeMembership.displayName ??
              phone ??
              'User')
          : (activeMembership.displayName ?? phone ?? 'User');

      _user = UserModel(
        uid: uid,
        phone: phone,
        displayName: displayName,
        activeOrgId: activeOrgId,
        activeOrgRole: activeMembership.role,
        activeOrgName: orgDoc.exists
            ? (orgDoc.data()?['name'] ?? 'Organization')
            : 'Organization',
        memberships: memberships,
      );

      _state = AuthState.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile (attempt $attempt): $e');
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
        return _loadUserProfile(firebaseUser, attempt: attempt + 1);
      }
      _error = 'Failed to load your profile. Check your connection and retry.';
      _state = AuthState.error;
      notifyListeners();
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _autoVerified = false;
    _state = AuthState.unauthenticated;
    _error = '';
    _otpChannel = null;
    notifyListeners();
  }

  // ── Org switch ─────────────────────────────────────────────────────────────

  Future<bool> switchOrg(String orgId) async {
    if (_user == null) return false;
    final membership =
        _user!.memberships.where((m) => m.orgId == orgId).firstOrNull;
    if (membership == null) return false;

    try {
      final orgDoc = await _db.collection('organizations').doc(orgId).get();
      _user = UserModel(
        uid: _user!.uid,
        phone: _user!.phone,
        displayName: _user!.displayName,
        activeOrgId: orgId,
        activeOrgRole: membership.role,
        activeOrgName: orgDoc.exists
            ? (orgDoc.data()?['name'] ?? 'Organization')
            : 'Organization',
        memberships: _user!.memberships,
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Token for authenticated REST calls ─────────────────────────────────────

  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _safeDecode(String body) {
    try {
      if (body.isNotEmpty) return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }
}
