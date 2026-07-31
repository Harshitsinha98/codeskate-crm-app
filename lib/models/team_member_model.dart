class TeamMemberModel {
  final String id;
  final String? uid;
  final String? phone;
  final String name;
  final String? email;
  final String role;
  final bool active;
  final bool pending;

  TeamMemberModel({
    required this.id,
    this.uid,
    this.phone,
    required this.name,
    this.email,
    this.role = 'employee',
    this.active = true,
    this.pending = false,
  });

  factory TeamMemberModel.fromMap(Map<String, dynamic> data, String id) {
    return TeamMemberModel(
      id: id,
      uid: data['uid'],
      phone: data['phone'],
      name: data['displayName'] ?? data['name'] ?? 'Team Member',
      email: data['email'],
      role: data['role'] ?? 'employee',
      active: data['active'] ?? true,
      pending: data['pending'] ?? false,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get isAdmin => role == 'admin' || role == 'owner';
}
