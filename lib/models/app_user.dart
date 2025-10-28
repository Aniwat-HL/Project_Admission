class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String role;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'student',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin';
}
