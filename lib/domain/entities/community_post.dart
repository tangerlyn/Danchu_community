import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentLocation {
  final String name;
  final double latitude;
  final double longitude;

  IncidentLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory IncidentLocation.fromJson(Map<String, dynamic> json) {
    return IncidentLocation(
      name: json['name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class CommunityPost {
  final String id;
  final String title;
  final String content;
  final String authorUid;
  final String authorNickname;
  final String mainCategory;
  final String subCategoryTag;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final List<String> likedBy;
  final int viewCount;
  final List<String> viewedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final int reportCount;
  final List<String> reportedBy;
  
  // Missing Pet / Care Fields
  final bool isMissing;
  final String missingStatus; // 'active', 'found', 'closed'
  final Map<String, dynamic>? petInfo;
  final List<IncidentLocation>? incidentLocations;
  
  // Group Meetup Fields
  final DateTime? meetupDate;
  final String? meetupLocation;
  final int? meetupCapacity;
  final int currentParticipantCount;
  
  // Geographic Fields (Phase 3)
  final double? lat;
  final double? lng;
  final Map<String, dynamic>? position; // { geohash, geopoint }
  
  final String? meetingPlace;
  final double? meetingLat;
  final double? meetingLng;
  
  // Route Points for Walk Share
  final List<Map<String, double>>? routePoints;
  final String? authorProfileImageUrl;
  final String? walkSummary;

  CommunityPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorUid,
    required this.authorNickname,
    required this.mainCategory,
    required this.subCategoryTag,
    required this.imageUrls,
    required this.likeCount,
    required this.commentCount,
    required this.likedBy,
    this.viewCount = 0,
    this.viewedBy = const [],
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.reportCount = 0,
    this.reportedBy = const [],
    this.isMissing = false,
    this.missingStatus = 'active',
    this.petInfo,
    this.incidentLocations,
    this.meetupDate,
    this.meetupLocation,
    this.meetupCapacity,
    this.currentParticipantCount = 0,
    this.lat,
    this.lng,
    this.position,
    this.meetingPlace,
    this.meetingLat,
    this.meetingLng,
    this.routePoints,
    this.authorProfileImageUrl,
    this.walkSummary,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json, String id) {
    return CommunityPost(
      id: id,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorUid: json['authorUid'] ?? '',
      authorNickname: json['authorNickname'] ?? '',
      mainCategory: json['mainCategory'] ?? '',
      subCategoryTag: json['subCategoryTag'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      viewCount: json['viewCount'] ?? 0,
      viewedBy: List<String>.from(json['viewedBy'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      isEdited: json['isEdited'] ?? false,
      reportCount: json['reportCount'] ?? 0,
      reportedBy: List<String>.from(json['reportedBy'] ?? []),
      isMissing: json['isMissing'] ?? false,
      missingStatus: json['missingStatus'] ?? 'active',
      petInfo: json['petInfo'] as Map<String, dynamic>?,
      incidentLocations: (json['incidentLocations'] as List?)
          ?.map((e) => IncidentLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
      meetupDate: (json['meetupDate'] as Timestamp?)?.toDate(),
      meetupLocation: json['meetupLocation'],
      meetupCapacity: (json['meetupCapacity'] as num?)?.toInt(),
      currentParticipantCount: json['currentParticipantCount'] ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      position: json['position'] as Map<String, dynamic>?,
      meetingPlace: json['meetingPlace'],
      meetingLat: (json['meetingLat'] as num?)?.toDouble(),
      meetingLng: (json['meetingLng'] as num?)?.toDouble(),
      routePoints: _parseRoutePoints(json['routePoints']),
      authorProfileImageUrl: json['authorProfileImageUrl'],
      walkSummary: json['walkSummary'],
    );
  }

  CommunityPost copyWith({
    String? id,
    String? title,
    String? content,
    String? authorUid,
    String? authorNickname,
    String? mainCategory,
    String? subCategoryTag,
    List<String>? imageUrls,
    int? likeCount,
    int? commentCount,
    List<String>? likedBy,
    int? viewCount,
    List<String>? viewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    int? reportCount,
    List<String>? reportedBy,
    bool? isMissing,
    String? missingStatus,
    Map<String, dynamic>? petInfo,
    List<IncidentLocation>? incidentLocations,
    DateTime? meetupDate,
    String? meetupLocation,
    int? meetupCapacity,
    int? currentParticipantCount,
    double? lat,
    double? lng,
    Map<String, dynamic>? position,
    String? meetingPlace,
    double? meetingLat,
    double? meetingLng,
    List<Map<String, double>>? routePoints,
    String? authorProfileImageUrl,
    String? walkSummary,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorUid: authorUid ?? this.authorUid,
      authorNickname: authorNickname ?? this.authorNickname,
      mainCategory: mainCategory ?? this.mainCategory,
      subCategoryTag: subCategoryTag ?? this.subCategoryTag,
      imageUrls: imageUrls ?? this.imageUrls,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedBy: likedBy ?? this.likedBy,
      viewCount: viewCount ?? this.viewCount,
      viewedBy: viewedBy ?? this.viewedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      reportCount: reportCount ?? this.reportCount,
      reportedBy: reportedBy ?? this.reportedBy,
      isMissing: isMissing ?? this.isMissing,
      missingStatus: missingStatus ?? this.missingStatus,
      petInfo: petInfo ?? this.petInfo,
      incidentLocations: incidentLocations ?? this.incidentLocations,
      meetupDate: meetupDate ?? this.meetupDate,
      meetupLocation: meetupLocation ?? this.meetupLocation,
      meetupCapacity: meetupCapacity ?? this.meetupCapacity,
      currentParticipantCount: currentParticipantCount ?? this.currentParticipantCount,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      position: position ?? this.position,
      meetingPlace: meetingPlace ?? this.meetingPlace,
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      routePoints: routePoints ?? this.routePoints,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      walkSummary: walkSummary ?? this.walkSummary,
    );
  }

  static List<Map<String, double>>? _parseRoutePoints(dynamic source) {
    if (source == null) return null;
    if (source is List) {
      try {
        return source.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'lat': (map['lat'] as num).toDouble(),
            'lng': (map['lng'] as num).toDouble(),
          };
        }).toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'mainCategory': mainCategory,
      'subCategoryTag': subCategoryTag,
      'imageUrls': imageUrls,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'likedBy': likedBy,
      'viewCount': viewCount,
      'viewedBy': viewedBy,
      'createdAt': FieldValue.serverTimestamp(),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isEdited': isEdited,
      'reportCount': reportCount,
      'reportedBy': reportedBy,
      'isMissing': isMissing,
      'missingStatus': missingStatus,
      if (petInfo != null) 'petInfo': petInfo,
      if (incidentLocations != null)
        'incidentLocations': incidentLocations!.map((e) => e.toJson()).toList(),
      if (meetupDate != null) 'meetupDate': Timestamp.fromDate(meetupDate!),
      if (meetupLocation != null) 'meetupLocation': meetupLocation,
      if (meetupCapacity != null) 'meetupCapacity': meetupCapacity,
      'currentParticipantCount': currentParticipantCount,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (position != null) 'position': position,
      if (meetingPlace != null) 'meetingPlace': meetingPlace,
      if (meetingLat != null) 'meetingLat': meetingLat,
      if (meetingLng != null) 'meetingLng': meetingLng,
      if (routePoints != null) 'routePoints': routePoints,
      if (authorProfileImageUrl != null) 'authorProfileImageUrl': authorProfileImageUrl,
      if (walkSummary != null) 'walkSummary': walkSummary,
    };
  }
}
