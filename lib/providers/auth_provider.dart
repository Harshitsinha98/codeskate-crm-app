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

  AuthState get state => _state;
  UserModel? get user => _user;
  String get error => _error;
  bool get isAuthenticated => _user != null && _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

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

  Future<void> _loadUserProfile(User firebaseUser) async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      final uid = firebaseUser.uid;
      final phone = firebaseUser.phoneNumber;

      // Load memberships
      final membershipsSnap = await _db
          .collection('memberships')
          .where('uid', isEqualTo: uid)
          .where('active', isEqualTo: true)
          .get();

      final activeMemberships = membershipsSnap.docs.where((doc) {
        final expiresAtMs = doc.data()['expiresAtMs'] as int?;
        return expiresAtMs == null || expiresAtMs == 0 || expiresAtMs > DateTime.now().millisecondsSinceEpoch;
      }).toList();

      if (activeMemberships.isEmpty) {
        _user = UserModel(
          uid: uid,
          phone: phone,
          needsSetup: true,
        );
        _state = AuthState.authenticated;
        notifyListeners();
        return;
      }

      // Get user profile
      final userDoc = await _db.collection('users').doc(uid).get();

      // Build memberships list
      final memberships = activeMemberships.map((m) {
        final data = m.data();
        return OrgMembership(
          orgId: data['orgId'] ?? '',
          role: data['role'] ?? 'employee',
          displayName: data['displayName'],
          membershipId: m.id,
        );
      }).toList();

      // Determine active org
      final activeOrgId = memberships.first.orgId;
      final activeMembership = memberships.first;

      // Get org details
      final orgDoc = await _db.collection('organizations').doc(activeOrgId).get();

      final displayName = userDoc.exists
          ? (userDoc.data()?['displayName'] ?? activeMembership.displayName ?? phone ?? 'User')
          : (activeMembership.displayName ?? phone ?? 'User');

      _user = UserModel(
        uid: uid,
        phone: phone,
        displayName: displayName,
        activeOrgId: activeOrgId,
        activeOrgRole: activeMembership.role,
        activeOrgName: orgDoc.exists ? (orgDoc.data()?['name'] ?? 'Organization') : 'Organization',
        memberships: memberships,
      );

      _state = AuthState.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _error = 'Failed to load profile. Please try again.';
      _state = AuthState.error;
      notifyListeners();
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      _state = AuthState.loading;
      _error = '';
      notifyListeners();

      final phone = '+91${phoneNumber.replaceAll(RegExp(r'\D'), '').substring(phoneNumber.replaceAll(RegExp(r'\D'), '').length - 10)}';

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in (Android only)
          await _auth.signInWithCredential(credential);
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

  /// Verify OTP code
  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _error = 'Session expired. Please request a new OTP.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    try {
      _state = AuthState.loading;
      _error = '';
      notifyListeners();

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _state = AuthState.otpSent; // Stay on OTP screen
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'OTP verification failed. Please try again.';
      _state = AuthState.otpSent;
      notifyListeners();
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOtp(String phoneNumber) async {
    return sendOtp(phoneNumber);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _verificationId = null;
    _resendToken = null;
    _state = AuthState.unauthenticated;
    _error = '';
    notifyListeners();
  }

  /// Switch active organization
  Future<bool> switchOrg(String orgId) async {
    if (_user == null) return false;

    final membership = _user!.memberships.where((m) => m.orgId == orgId).firstOrNull;
    if (membership == null) return false;

    try {
      final orgDoc = await _db.collection('organizations').doc(orgId).get();
      _user = UserModel(
        uid: _user!.uid,
        phone: _user!.phone,
        displayName: _user!.displayName,
        activeOrgId: orgId,
        activeOrgRole: membership.role,
        activeOrgName: orgDoc.exists ? (orgDoc.data()?['name'] ?? 'Organization') : 'Organization',
        memberships: _user!.memberships,
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please enter a valid 10-digit number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and try again.';
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
