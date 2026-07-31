class UserModel {
  final String uid;
  final String? phone;
  final String? displayName;
  final String? email;
  final String? activeOrgId;
  final String? activeOrgRole;
  final String? activeOrgName;
  final bool isPlatformOwner;
  final bool needsSetup;
  final List<OrgMembership> memberships;

  UserModel({
    required this.uid,
    this.phone,
    this.displayName,
    this.email,
    this.activeOrgId,
    this.activeOrgRole,
    this.activeOrgName,
    this.isPlatformOwner = false,
    this.needsSetup = false,
    this.memberships = const [],
  });

  String get name => displayName ?? phone ?? 'User';
  String get initials {
    final n = name.trim().split(' ');
    if (n.length >= 2) return '${n[0][0]}${n[1][0]}'.toUpperCase();
    return n.isNotEmpty && n[0].isNotEmpty ? n[0][0].toUpperCase() : '?';
  }

  bool get isAdmin =>
      activeOrgRole == 'admin' || activeOrgRole == 'owner';
}

class OrgMembership {
  final String orgId;
  final String role;
  final String? displayName;
  final String? membershipId;

  OrgMembership({
    required this.orgId,
    required this.role,
    this.displayName,
    this.membershipId,
  });

  factory OrgMembership.fromMap(Map<String, dynamic> data) {
    return OrgMembership(
      orgId: data['orgId'] ?? '',
      role: data['role'] ?? 'employee',
      displayName: data['displayName'],
      membershipId: data['membershipId'],
    );
  }
}
