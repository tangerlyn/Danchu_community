class FriendInfo {
  final String uid;
  final String nickname;
  final String profileImageUrl;
  final DateTime addedAt;

  FriendInfo({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.addedAt,
  });

  factory FriendInfo.fromJson(String uid, Map<String, dynamic> data) {
    return FriendInfo(
      uid: uid,
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      addedAt: (data['addedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
