/// Model representing an authenticated Ranger user session.
class UserAuthModel {
  final String? userId;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? badgeNumber;
  final String? assignedPark;
  final String? phoneNumber;
  final String token;

  const UserAuthModel({
    this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.badgeNumber,
    this.assignedPark,
    this.phoneNumber,
    required this.token,
  });

  factory UserAuthModel.fromJson(Map<String, dynamic> json) {
    return UserAuthModel(
      userId: json['userId'] as String?,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'ROLE_RANGER',
      badgeNumber: json['badgeNumber'] as String?,
      assignedPark: json['assignedPark'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
      'badgeNumber': badgeNumber,
      'assignedPark': assignedPark,
      'phoneNumber': phoneNumber,
      'token': token,
    };
  }
}
