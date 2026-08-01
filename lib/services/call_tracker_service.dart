import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lead_model.dart';

/// Bridges the native Android call tracker (PHONE_STATE + CallLog) to Firestore.
///
/// After a call ends, the native side emits {id, number, duration, type, date}.
/// We match it to a lead by the last 10 digits of the phone number and write a
/// "call" note to organizations/{orgId}/leads/{leadId}/notes (idempotent by
/// call_{callLogId}), then tell native to advance its cursor. Mirrors the web
/// CRM's useCallTracker hook behavior.
class CallTrackerService {
  CallTrackerService._();
  static final CallTrackerService instance = CallTrackerService._();

  static const MethodChannel _method =
      MethodChannel('com.codeskate.crm/call_tracker');
  static const EventChannel _events =
      EventChannel('com.codeskate.crm/call_tracker_events');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription? _sub;
  bool _running = false;
  final Set<String> _inFlight = {};

  // Config providers (read latest values at event time).
  String? Function()? _getOrgId;
  String? Function()? _getUid;
  String Function()? _getUserName;
  String? Function()? _getRole;
  List<LeadModel> Function()? _getLeads;

  bool get isRunning => _running;

  void configure({
    required String? Function() getOrgId,
    required String? Function() getUid,
    required String Function() getUserName,
    required String? Function() getRole,
    required List<LeadModel> Function() getLeads,
  }) {
    _getOrgId = getOrgId;
    _getUid = getUid;
    _getUserName = getUserName;
    _getRole = getRole;
    _getLeads = getLeads;
  }

  String _last10(String? number) {
    final digits = (number ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  Future<void> start() async {
    if (_running) return;
    if (kIsWeb || !Platform.isAndroid) return; // Android-only feature.
    if (_getOrgId?.call() == null) return; // Not signed in yet.

    try {
      final granted = await _method.invokeMethod<bool>('requestPermissions');
      if (granted != true) {
        debugPrint('Call tracker: permissions not granted.');
        return;
      }
      await _method.invokeMethod('startListening');
      _sub = _events.receiveBroadcastStream().listen(
        (event) => _handleCall(Map<String, dynamic>.from(event as Map)),
        onError: (e) => debugPrint('Call tracker event error: $e'),
      );
      _running = true;

      // Catch up on a call that ended while the app was backgrounded.
      final last = await _method.invokeMethod<dynamic>('getLastCall');
      if (last is Map && last['found'] == true) {
        await _handleCall(Map<String, dynamic>.from(last));
      }
      debugPrint('Call tracker started.');
    } catch (e) {
      debugPrint('Call tracker unavailable: $e');
    }
  }

  Future<void> stop() async {
    _sub?.cancel();
    _sub = null;
    _running = false;
    try {
      await _method.invokeMethod('stopListening');
    } catch (_) {}
  }

  Future<void> _handleCall(Map<String, dynamic> event) async {
    final id = event['id']?.toString();
    final duration = (event['duration'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty || duration <= 0) return;
    if (_inFlight.contains(id)) return;

    final orgId = _getOrgId?.call();
    final uid = _getUid?.call();
    if (orgId == null || uid == null) return;

    final leads = _getLeads?.call() ?? const [];
    final target = _last10(event['number']?.toString());
    LeadModel? matched;
    for (final lead in leads) {
      if (_last10(lead.phone) == target && target.isNotEmpty) {
        matched = lead;
        break;
      }
    }

    // Personal / unmatched calls never enter the CRM, but still advance the
    // native cursor so they don't block later matched calls.
    if (matched == null) {
      await _markProcessed(id);
      return;
    }

    _inFlight.add(id);
    try {
      final type = event['type']?.toString() ?? 'other';
      final callDate = (event['date'] as num?)?.toInt();
      final noteId = 'call_${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}';
      final ref = _db
          .collection('organizations')
          .doc(orgId)
          .collection('leads')
          .doc(matched.id)
          .collection('notes')
          .doc(noteId);

      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set({
          'type': 'call',
          'text': type == 'outgoing'
              ? 'Outgoing call logged from Android dialer.'
              : type == 'incoming'
                  ? 'Incoming call logged from Android dialer.'
                  : 'Call logged from Android dialer.',
          'visibility': 'team',
          'authorId': uid,
          'authorName': _getUserName?.call() ?? 'Employee',
          'authorRole': _getRole?.call() ?? 'employee',
          'callLogId': id,
          'callStartedAt': callDate,
          'duration': duration,
          'callType': type,
          'at': DateTime.now().toIso8601String(),
        });
      }
      await _markProcessed(id);
    } catch (e) {
      debugPrint('Call note not persisted (will retry): $e');
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _markProcessed(String id) async {
    try {
      await _method.invokeMethod('markCallProcessed', {'id': id});
    } catch (_) {}
  }
}
