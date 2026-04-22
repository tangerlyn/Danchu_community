class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromNickname;
  final String fromProfileImageUrl;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromNickname,
    required this.fromProfileImageUrl,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> data, String id) {
    return FriendRequest(
      id: id,
      fromUid: data['fromUid'] ?? '',
      toUid: data['toUid'] ?? '',
      fromNickname: data['fromNickname'] ?? '',
      fromProfileImageUrl: data['fromProfileImageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'fromUid': fromUid,
    'toUid': toUid,
    'fromNickname': fromNickname,
    'fromProfileImageUrl': fromProfileImageUrl,
    'status': status,
    'createdAt': createdAt,
  };
}
