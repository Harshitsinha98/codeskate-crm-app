import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription / plan state for the active organization.
/// Read live from Firestore `organizations/{orgId}` (same doc the web CRM's
/// BillingContext listens to).
class OrgBilling {
  final String id;
  final String name;
  final String status; // trialing | active | past_due | expired
  final String planName;
  final String planId; // starter | growth | enterprise | enterprise_plus
  final int seatsUsed;
  final int seatsLimit;
  final int leadsUsed;
  final int leadsLimit;
  final String? trialEndsAt; // ISO
  final int currentPeriodEndMs;
  final String billingCycle; // monthly | yearly
  final bool autopay;

  OrgBilling({
    required this.id,
    this.name = 'Organization',
    this.status = 'trialing',
    this.planName = 'Starter',
    this.planId = 'starter',
    this.seatsUsed = 1,
    this.seatsLimit = 1,
    this.leadsUsed = 0,
    this.leadsLimit = 0,
    this.trialEndsAt,
    this.currentPeriodEndMs = 0,
    this.billingCycle = 'monthly',
    this.autopay = false,
  });

  factory OrgBilling.fromSnapshot(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    int asInt(dynamic v, [int fallback = 0]) =>
        v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? fallback));
    return OrgBilling(
      id: doc.id,
      name: d['name'] ?? 'Organization',
      status: d['subscriptionStatus'] ?? 'trialing',
      planName: d['planName'] ?? 'Starter',
      planId: d['planId'] ?? 'starter',
      seatsUsed: asInt(d['seatsUsed'], 1),
      seatsLimit: asInt(d['seatsLimit'], 1),
      leadsUsed: asInt(d['leadsUsed']),
      leadsLimit: asInt(d['leadsLimit']),
      trialEndsAt: d['trialEndsAt']?.toString(),
      currentPeriodEndMs: asInt(d['currentPeriodEndMs']),
      billingCycle: d['billingCycle'] ?? 'monthly',
      autopay: d['autopay'] == true,
    );
  }

  bool get isTrialing => status == 'trialing';
  bool get isActive => status == 'active';
  bool get isPastDue => status == 'past_due';
  bool get isExpired => status == 'expired' || (isTrialing && _trialOver);
  bool get hasPaid => isActive || isPastDue;

  bool get _trialOver {
    if (trialEndsAt == null) return false;
    final ends = DateTime.tryParse(trialEndsAt!);
    return ends != null && ends.isBefore(DateTime.now());
  }

  int get trialDaysLeft {
    if (trialEndsAt == null) return 0;
    final ends = DateTime.tryParse(trialEndsAt!);
    if (ends == null) return 0;
    final diff = ends.difference(DateTime.now()).inHours / 24.0;
    return diff <= 0 ? 0 : diff.ceil();
  }

  int get seatsAvailable =>
      (seatsLimit - seatsUsed) < 0 ? 0 : (seatsLimit - seatsUsed);
  int get leadsAvailable =>
      (leadsLimit - leadsUsed) < 0 ? 0 : (leadsLimit - leadsUsed);

  bool get seatsUnlimited => seatsLimit < 0;
  bool get leadsUnlimited => leadsLimit < 0;
}

/// A purchasable add-on pack (from GET /api/billing/quota-status -> availableAddOns).
class AddOn {
  final String id;
  final String name;
  final String description;
  final int monthlyPrice; // INR
  final String unit;
  final int maxQuantity;
  final int owned;

  AddOn({
    required this.id,
    required this.name,
    this.description = '',
    this.monthlyPrice = 0,
    this.unit = '',
    this.maxQuantity = 1,
    this.owned = 0,
  });

  factory AddOn.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v, [int f = 0]) =>
        v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? f));
    return AddOn(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? 'Add-on',
      description: m['description']?.toString() ?? '',
      monthlyPrice: asInt(m['monthlyPrice']),
      unit: m['unit']?.toString() ?? '',
      maxQuantity: asInt(m['maxQuantity'], 1),
      owned: asInt(m['owned']),
    );
  }

  bool get maxedOut => owned >= maxQuantity;
}

/// A single quota metric (e.g. AI replies) from quota-status.quotas.
class QuotaMetric {
  final int used;
  final int limit;
  final bool unlimited;

  QuotaMetric({this.used = 0, this.limit = 0, this.unlimited = false});

  factory QuotaMetric.fromMap(Map<String, dynamic>? m) {
    if (m == null) return QuotaMetric();
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));
    return QuotaMetric(
      used: asInt(m['used']),
      limit: asInt(m['limit']),
      unlimited: m['unlimited'] == true,
    );
  }

  double get pct {
    if (unlimited) return 0.04;
    if (limit <= 0) return 0;
    final p = used / limit;
    return p > 1 ? 1 : p;
  }

  bool get exhausted => !unlimited && limit > 0 && used >= limit;
}

/// Parsed response of GET /api/billing/quota-status.
class QuotaStatus {
  final QuotaMetric aiMessages;
  final List<AddOn> availableAddOns;

  QuotaStatus({required this.aiMessages, required this.availableAddOns});

  factory QuotaStatus.fromMap(Map<String, dynamic> m) {
    final quotas = (m['quotas'] as Map<String, dynamic>?) ?? {};
    final addOns = (m['availableAddOns'] as List?) ?? [];
    return QuotaStatus(
      aiMessages: QuotaMetric.fromMap(quotas['aiMessages'] as Map<String, dynamic>?),
      availableAddOns: addOns
          .whereType<Map>()
          .map((e) => AddOn.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Voice Wallet balance (GET /api/wallet/balance).
class WalletBalance {
  final double balanceInr;
  final double totalSpentInr;

  WalletBalance({this.balanceInr = 0, this.totalSpentInr = 0});

  factory WalletBalance.fromMap(Map<String, dynamic> m) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return WalletBalance(
      balanceInr: asDouble(m['balanceInr']),
      totalSpentInr: asDouble(m['totalSpentInr']),
    );
  }
}

/// A wallet transaction row (GET /api/wallet/transactions).
class WalletTransaction {
  final String id;
  final String type; // topup | credit | debit | usage
  final String description;
  final double amountInr;
  final DateTime? createdAt;

  WalletTransaction({
    required this.id,
    this.type = '',
    this.description = '',
    this.amountInr = 0,
    this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> m) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return WalletTransaction(
      id: m['id']?.toString() ?? '',
      type: m['type']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      amountInr: asDouble(m['amountInr']),
      createdAt: parseDate(m['createdAt'] ?? m['timestamp']),
    );
  }

  /// Money coming IN (top-up / credit) vs going OUT (usage / debit).
  bool get isCredit => type == 'topup' || type == 'credit';
}

/// Payment gateway availability (GET /api/billing/config).
class BillingConfig {
  final bool razorpay;
  final String? razorpayKeyId;
  final bool payu;

  BillingConfig({this.razorpay = false, this.razorpayKeyId, this.payu = false});

  factory BillingConfig.fromMap(Map<String, dynamic> m) => BillingConfig(
        razorpay: m['razorpay'] == true,
        razorpayKeyId: m['razorpayKeyId']?.toString(),
        payu: m['payu'] == true,
      );
}
