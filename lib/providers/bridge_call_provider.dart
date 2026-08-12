import 'dart:async';
import 'package:flutter/material.dart';

import '../models/lead_model.dart';
import '../services/bridge_call_service.dart';
import 'auth_provider.dart';

/// UI-facing phase of a bridge call.
enum BridgePhase {
  idle,
  initiating,
  ringing, // agent's phone ringing — "pick up & press 1"
  waitingCustomer, // agent confirmed, dialing the lead
  inProgress, // both connected
  completed,
  failed,
}

/// Drives the bridge-call flow: initiate → poll → live status → result.
/// Mirrors the web CRM's useBridgeCall hook.
class BridgeCallProvider extends ChangeNotifier {
  AuthProvider? _auth;
  late final BridgeCallService _service = BridgeCallService(
    () => _auth?.getIdToken() ?? Future<String?>.value(null),
  );

  BridgePhase _phase = BridgePhase.idle;
  String? _callId;
  String _error = '';
  String? _errorCode;
  int _elapsed = 0; // seconds since connected
  BridgeCallStatus? _result;
  Timer? _pollTimer;
  Timer? _elapsedTimer;

  BridgePhase get phase => _phase;
  String get error => _error;
  String? get errorCode => _errorCode;
  int get elapsed => _elapsed;
  BridgeCallStatus? get result => _result;
  bool get isActive =>
      _phase == BridgePhase.initiating ||
      _phase == BridgePhase.ringing ||
      _phase == BridgePhase.waitingCustomer ||
      _phase == BridgePhase.inProgress;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  String? get _orgId => _auth?.user?.activeOrgId;

  /// Start a bridge call for [lead].
  /// Returns true if the bridge flow started; false if the caller should fall
  /// back to a direct dial (only for hard/unknown failures — plan/wallet/number
  /// errors surface an in-sheet message and do NOT fall back).
  Future<bool> start(LeadModel lead) async {
    _reset(notify: false);
    _phase = BridgePhase.initiating;
    _error = '';
    _errorCode = null;
    notifyListeners();

    final orgId = _orgId;
    if (orgId == null) {
      _fail('No active organization.');
      return false;
    }

    final res = await _service.initiate(
      orgId: orgId,
      leadId: lead.id,
      leadPhone: lead.phone,
      leadName: lead.name,
    );

    if (!res.ok || res.data == null) {
      _errorCode = res.code;
      // Friendly messages for known, non-fallback cases.
      switch (res.code) {
        case 'plan_upgrade_required':
          _fail('Bridge calling is available on the Growth plan and above. Upgrade on the web app.');
          return false;
        case 'wallet_empty':
          final bal = res.balanceInr;
          _fail('Voice Wallet balance is too low${bal != null ? ' (₹${bal.toStringAsFixed(0)})' : ''}. Top up to make bridge calls.');
          return false;
        case 'no_voice_number':
          _fail('Your organization has no active calling number yet. Ask your admin to set up CodeSkate Voice.');
          return false;
        default:
          // Unknown/network failure → let the UI offer a direct dial.
          _fail(res.error ?? 'Could not start the bridge call.');
          return false;
      }
    }

    _callId = res.data;
    _phase = BridgePhase.ringing;
    notifyListeners();
    _startPolling();
    return true;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
    _pollOnce();
  }

  Future<void> _pollOnce() async {
    final id = _callId;
    if (id == null) return;
    final status = await _service.poll(id);
    if (status == null) return;

    switch (status.status) {
      case 'initiating':
      case 'ringing':
        _setPhase(BridgePhase.ringing);
        break;
      case 'waiting_customer':
        _setPhase(BridgePhase.waitingCustomer);
        break;
      case 'in-progress':
        if (_phase != BridgePhase.inProgress) {
          _setPhase(BridgePhase.inProgress);
          _startElapsedTimer();
        }
        break;
      default:
        if (status.isTerminal) {
          _finish(status);
        }
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsed = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      notifyListeners();
    });
  }

  void _finish(BridgeCallStatus status) {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _result = status;
    if (status.isSuccess) {
      _phase = BridgePhase.completed;
    } else {
      _phase = BridgePhase.failed;
      _error = _failureText(status.status, status.failureReason);
    }
    notifyListeners();
  }

  String _failureText(String status, String? reason) {
    switch (status) {
      case 'no-answer':
        return 'The customer didn\'t answer. No charge applied.';
      case 'customer_voicemail':
        return 'Reached voicemail / answering machine. No charge applied.';
      case 'agent_no_confirm':
        return 'Call cancelled — you didn\'t press 1 to connect.';
      default:
        return reason ?? 'The call could not be completed.';
    }
  }

  void _setPhase(BridgePhase p) {
    if (_phase == p) return;
    _phase = p;
    notifyListeners();
  }

  void _fail(String message) {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _phase = BridgePhase.failed;
    _error = message;
    notifyListeners();
  }

  void _reset({bool notify = true}) {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _pollTimer = null;
    _elapsedTimer = null;
    _phase = BridgePhase.idle;
    _callId = null;
    _error = '';
    _errorCode = null;
    _elapsed = 0;
    _result = null;
    if (notify) notifyListeners();
  }

  /// Public reset (e.g. when the sheet closes).
  void reset() => _reset();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
