import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, otpSent, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _verificationId;
  int? _resendToken;
  String _error = '';
  String _lastPhone = '';
  bool _autoVerified = false;

  AuthState get state => _state;
  UserModel? get user => _user;
  String get error => _error;
  bool get isAuthenticated => _user != null && _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get autoVerified => _autoVerified;

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _state = AuthState.unauthenticated;
        notifyListeners();
        return;
      }
      await _loadUserProfile(firebaseUser);
    });
  }

  /// Normalize an Indian phone number to E.164 (+91XXXXXXXXXX).
  /// Returns null if it cannot produce a valid 10-digit number.
  String? _toE164(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    // Drop leading country code / trunk prefixes if present.
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(digits.length - 10);
    } else if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length != 10) return null;
    return '+91$digits';
  }

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
      // Transient Firestore errors (offline, cold start) — retry a couple times.
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
        return _loadUserProfile(firebaseUser, attempt: attempt + 1);
      }
      _error = 'Failed to load your profile. Check your connection and retry.';
      _state = AuthState.error;
      notifyListeners();
    }
  }

  /// Send OTP to phone number. [phoneNumber] is the raw 10-digit input.
  Future<bool> sendOtp(String phoneNumber) async {
    final e164 = _toE164(phoneNumber);
    if (e164 == null) {
      _error = 'Enter a valid 10-digit mobile number.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _lastPhone = e164;
    _autoVerified = false;
    _state = AuthState.loading;
    _error = '';
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android instant/auto verification — sign in directly.
          try {
            await _auth.signInWithCredential(credential);
            _autoVerified = true;
            notifyListeners();
          } catch (e) {
            debugPrint('Auto verification sign-in failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _error = _mapFirebaseError(e.code);
          _state = AuthState.error;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _state = AuthState.otpSent;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
      return true;
    } catch (e) {
      _error = 'Failed to send OTP. Please try again.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Verify the manually entered OTP code.
  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _error = 'Session expired. Please request a new OTP.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    // If auto-verification already signed us in, treat as success.
    if (_auth.currentUser != null) return true;

    _state = AuthState.loading;
    _error = '';
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp.trim(),
      );
      await _auth.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _state = AuthState.otpSent;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'OTP verification failed. Please try again.';
      _state = AuthState.otpSent;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendOtp(String phoneNumber) => sendOtp(phoneNumber);

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _verificationId = null;
    _resendToken = null;
    _autoVerified = false;
    _state = AuthState.unauthenticated;
    _error = '';
    notifyListeners();
  }

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

  /// Firebase ID token for authenticated backend calls (WhatsApp send, etc.).
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

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Enter a valid 10-digit number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again after some time.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and try again.';
      case 'missing-client-identifier':
        return 'App verification failed. Ensure SHA-1 & SHA-256 are added in Firebase and Play Integrity is enabled.';
      case 'session-expired':
      case 'code-expired':
        return 'OTP expired. Please request a new one.';
      case 'quota-exceeded':
        return 'OTP limit reached. Please try again tomorrow.';
      default:
        return 'Something went wrong ($code). Please try again.';
    }
  }
}
