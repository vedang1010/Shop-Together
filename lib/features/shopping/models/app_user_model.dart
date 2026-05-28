class AppUserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  AppUserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  factory AppUserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AppUserModel(
      uid: data['uid'] ?? id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      photoUrl: data['photoUrl'],
    );
  }
}
