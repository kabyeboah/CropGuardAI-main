class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isAnonymous;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.isAnonymous,
  });

  factory AppUser.guest() => AppUser(
        id: 'guest',
        email: '',
        displayName: 'Guest Farmer',
        isAnonymous: true,
      );
}
