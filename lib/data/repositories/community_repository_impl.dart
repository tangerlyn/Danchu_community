import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/entities/community_comment.dart';
import '../../domain/entities/comment_reply.dart';
import '../../domain/repositories/community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final String _collectionPath = 'community_posts';

  String getNewDocId() {
    return _firestore.collection(_collectionPath).doc().id;
  }

  @override
  Stream<List<CommunityPost>> getPostsStream({String? mainCategory, String? subCategory}) {
    Query query = _firestore.collection(_collectionPath);

    if (mainCategory != null && mainCategory != '전체' && mainCategory.isNotEmpty) {
      if (mainCategory == '자유') {
        query = query.where('mainCategory', whereIn: ['자유', '장소']);
      } else {
        query = query.where('mainCategory', isEqualTo: mainCategory);
      }
    }
    
    if (subCategory != null && subCategory != '전체' && subCategory.isNotEmpty) {
       query = query.where('subCategoryTag', isEqualTo: subCategory);
    }

    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs.map((doc) {
        return CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort in memory to avoid needing a composite index for every mainCategory + createdAt combination
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<List<CommunityPost>> getNearbyPostsStream({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? mainCategory,
    String? subCategory,
  }) {
    // For report categories, we use a broader query radius (e.g., 50km) 
    // to capture sighting locations that might be far from the author's initial position.
    final double queryRadius = (mainCategory == '신고') ? 50.0 : radius;

    final collectionReference = _firestore.collection(_collectionPath);
    
    return GeoCollectionReference(collectionReference)
        .subscribeWithin(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: queryRadius,
      field: 'position',
      geopointFrom: (data) => (data['position']['geopoint'] as GeoPoint),
    ).map((snapshots) {
      final posts = snapshots.map((doc) => 
        CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();

      final filteredPosts = posts.where((post) {
        // 1. Category Filter
        bool matchMain = true;
        if (mainCategory != null && mainCategory != '전체' && mainCategory.isNotEmpty) {
          if (mainCategory == '자유') {
            matchMain = (post.mainCategory == '자유' || post.mainCategory == '장소');
          } else {
            matchMain = (post.mainCategory == mainCategory);
          }
        }

        bool matchSub = true;
        if (subCategory != null && subCategory != '전체' && subCategory.isNotEmpty) {
          matchSub = (post.subCategoryTag == subCategory);
        }

        if (!(matchMain && matchSub)) return false;

        // 2. Proximity Check (Primary: Author Position, Secondary: Incident Locations)
        bool isNearby = false;
        
        // Check Author Position (already handled by subscribeWithin geohash, but let's double check for radius)
        if (post.lat != null && post.lng != null) {
          final dist = Geolocator.distanceBetween(lat, lng, post.lat!, post.lng!) / 1000.0;
          if (dist <= radius) isNearby = true;
        }

        // Check Multi-location sightings for reports
        if (!isNearby && post.incidentLocations != null && post.incidentLocations!.isNotEmpty) {
           for (final loc in post.incidentLocations!) {
             final dist = Geolocator.distanceBetween(lat, lng, loc.latitude, loc.longitude) / 1000.0;
             if (dist <= radius) {
               isNearby = true;
               break;
             }
           }
        }

        return isNearby;
      }).toList();

      // Sort by creation date descending (newest first)
      filteredPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filteredPosts;
    });
  }

  /// Fetch popular posts: last 7 days, sorted by (likes + views) descending
  Stream<List<CommunityPost>> getPopularPostsStream() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _firestore
        .collection(_collectionPath)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by engagement score (likes + views) descending
      posts.sort((a, b) => (b.likeCount + b.viewCount).compareTo(a.likeCount + a.viewCount));
      return posts;
    });
  }

  /// Fetch missing pet posts (active / found / closed)
  Stream<List<CommunityPost>> getMissingPostsStream({String? status}) {
    Query query = _firestore.collection(_collectionPath).where('isMissing', isEqualTo: true);
    
    if (status != null && status != '전체') {
      // Map Korean status to English if needed, assuming status comes as 'active' etc. from UI
      query = query.where('missingStatus', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  /// Fetch hot missing pet posts for banner: active only, sorted by (likes * 2 + comments) descending
  Stream<List<CommunityPost>> getHotMissingPostsStream() {
    return _firestore
        .collection(_collectionPath)
        .where('isMissing', isEqualTo: true)
        .where('missingStatus', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      posts.sort((a, b) => ((b.likeCount * 2) + b.commentCount).compareTo((a.likeCount * 2) + a.commentCount));
      return posts.take(5).toList();
    });
  }

  /// Fetch hot posts for a specific category: last 3 days, top 5 by (likes + comments)
  Stream<List<CommunityPost>> getHotPostsStream(String category) {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    
    return _firestore
        .collection(_collectionPath)
        .where('mainCategory', isEqualTo: category)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (category == '산책') {
        // Walk Popular Posts: specific subcategories + likeCount sorting
        final filteredPosts = posts.where((p) => 
          p.subCategoryTag == '코스공유' || p.subCategoryTag == '일상'
        ).toList();
        
        filteredPosts.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        return filteredPosts.take(5).toList();
      } else {
        // Other Popular Posts (Report, Free): sort by engagement (likes + comments)
        posts.sort((a, b) =>
            (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
        return posts.take(5).toList();
      }
    });
  }

  @override
  Future<CommunityPost?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection(_collectionPath).doc(postId).get();
      if (doc.exists && doc.data() != null) {
        return CommunityPost.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch post details: $e');
    }
  }

  @override
  Future<List<String>> createPost(CommunityPost post, List<File> imageFiles) async {
    List<String> uploadedImageUrls = [];
    List<Reference> uploadedRefs = [];

    try {
      // 1. Upload Images one by one
      for (int i = 0; i < imageFiles.length; i++) {
        final File file = imageFiles[i];
        
        // Validate file exists before attempting upload
        if (!file.existsSync()) {
          print('⚠️ Image file does not exist at path: ${file.path}');
          throw Exception('이미지 파일을 찾을 수 없습니다. 다시 선택해주세요.');
        }
        
        final fileSize = await file.length();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${post.authorUid}_$i.jpg';
        final Reference ref = _storage.ref().child('community_images').child(fileName);
        
        print('📤 Uploading image $i: ${file.path} (${(fileSize / 1024).toStringAsFixed(1)} KB) → $fileName');

        // Set explicit content type metadata to help Firebase identify the file
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'postId': post.id, 'uploadedBy': post.authorUid},
        );

        // Upload with metadata and WAIT for full completion
        final UploadTask uploadTask = ref.putFile(file, metadata);
        final TaskSnapshot snapshot = await uploadTask;
        
        // Verify upload actually succeeded
        if (snapshot.state != TaskState.success) {
          throw Exception('이미지 업로드가 완료되지 않았습니다. (state: ${snapshot.state})');
        }

        // Now safe to get download URL
        final String downloadUrl = await ref.getDownloadURL();
        
        print('✅ Image $i uploaded (${snapshot.bytesTransferred} bytes): $downloadUrl');
        uploadedImageUrls.add(downloadUrl);
        uploadedRefs.add(ref);
      }

      // 2. Create the post object with the new image URLs
      final postData = post.toJson();
      postData['imageUrls'] = uploadedImageUrls;

      // 3. Save to Firestore
      await _firestore.collection(_collectionPath).doc(post.id).set(postData);

      // 4. If it's a Meetup, automatically add the author as a participant
      if (post.mainCategory == '모임') {
        await _firestore
            .collection(_collectionPath)
            .doc(post.id)
            .collection('participants')
            .doc(post.authorUid)
            .set({
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Also add to the user's joined_chats list
        await _firestore
            .collection('users')
            .doc(post.authorUid)
            .collection('joined_chats')
            .doc(post.id)
            .set({
          'chatRoomName': post.title,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Author added as participant for Meetup: ${post.id}');
      }
      
      print('✅ Post saved to Firestore: ${post.id}');
      return uploadedImageUrls;

    } catch (e) {
      print('❌ Post creation failed: $e');
      // Rollback: Delete any uploaded images
      for (final ref in uploadedRefs) {
        try {
          await ref.delete();
        } catch (deleteError) {
          print('Failed to cleanup uploaded image during rollback: $deleteError');
        }
      }
      throw Exception('게시글 업로드에 실패했습니다: $e');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    // Note: Security rules should also enforce that only the author can delete this.
    try {
      // Get the post to delete images first
      final post = await getPostById(postId);
      if (post != null && post.imageUrls.isNotEmpty) {
         for (String url in post.imageUrls) {
           try {
              final Reference ref = _storage.refFromURL(url);
              await ref.delete();
           } catch (e) {
              print('Failed to delete image: $url. Error: $e');
           }
         }
      }

      // Explicitly delete specific subcollections, preserving `chat`, `chat_read`, and `participants`
      final collectionsToDelete = ['comments', 'likes'];
      for (final collectionName in collectionsToDelete) {
        final collectionRef = _firestore
            .collection(_collectionPath)
            .doc(postId)
            .collection(collectionName);
        final snapshot = await collectionRef.get();
        final batch = _firestore.batch();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        
        if (snapshot.docs.isNotEmpty) {
          await batch.commit();
        }
      }

      // Delete document
      await _firestore.collection(_collectionPath).doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  @override
  Future<void> updatePost(
    String postId, 
    String title, 
    String content, {
    Map<String, dynamic>? petInfo,
    List<IncidentLocation>? incidentLocations,
    List<String>? imageUrls, // ← 추가
  }) async {
    try {
      final Map<String, dynamic> data = {
        'title': title,
        'content': content,
        'isEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (petInfo != null) 'petInfo': petInfo,
        if (incidentLocations != null)
          'incidentLocations': incidentLocations.map((e) => e.toJson()).toList(),
        if (imageUrls != null) 'imageUrls': imageUrls, // ← 추가
      };
      await _firestore.collection(_collectionPath).doc(postId).update(data);
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  @override
  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _firestore.collection(_collectionPath).doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Post does not exist!");
      
      final postData = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> likedBy = postData['likedBy'] ?? [];
      int likeCount = postData['likeCount'] ?? 0;
      
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likeCount--;
      } else {
        likedBy.add(userId);
        likeCount++;
      }
      
      transaction.update(docRef, {
        'likedBy': likedBy,
        'likeCount': likeCount,
      });
    });
  }

  @override
  Future<void> addComment(String postId, CommunityComment comment) async {
    final postRef = _firestore.collection(_collectionPath).doc(postId);
    final commentRef = postRef.collection('comments').doc(comment.id);
    
    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) throw Exception("Post does not exist!");
      
      final postData = postSnapshot.data() as Map<String, dynamic>;
      int commentCount = postData['commentCount'] ?? 0;
      
      transaction.set(commentRef, comment.toJson());
      transaction.update(postRef, {'commentCount': commentCount + 1});
    });
  }

  @override
  Future<void> updateComment(String postId, String commentId, String newContent) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
            'content': newContent,
            'updatedAt': FieldValue.serverTimestamp(),
            'isEdited': true,
          });
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  @override
  Stream<List<CommunityComment>> getCommentsStream(String postId) {
    return _firestore
        .collection(_collectionPath)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommunityComment.fromJson(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    final postRef = _firestore.collection(_collectionPath).doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);
    
    // Check for replies
    final repliesSnapshot = await commentRef.collection('replies').get();

    if (repliesSnapshot.docs.isNotEmpty) {
      // If there are replies, perform a "soft delete"
      await commentRef.update({
        'isDeleted': true,
        'content': '삭제된 댓글입니다.',
        'authorUid': '',
        'authorNickname': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) throw Exception("Post does not exist!");
      
      final postData = postSnapshot.data() as Map<String, dynamic>;
      int commentCount = postData['commentCount'] ?? 0;
      
      transaction.delete(commentRef);
      if (commentCount > 0) {
        transaction.update(postRef, {'commentCount': commentCount - 1});
      }
    });
  }

  @override
  Future<void> recordView(String postId, String userId) async {
    final docRef = _firestore.collection(_collectionPath).doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> viewedBy = List.from(data['viewedBy'] ?? []);

      if (!viewedBy.contains(userId)) {
        viewedBy.add(userId);
        final viewCount = (data['viewCount'] ?? 0) + 1;
        transaction.update(docRef, {
          'viewedBy': viewedBy,
          'viewCount': viewCount,
        });
      }
    });
  }

  @override
  Future<void> reportPost(String postId, String userId) async {
    final docRef = _firestore.collection(_collectionPath).doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Post does not exist!");

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> reportedBy = List.from(data['reportedBy'] ?? []);
      int reportCount = data['reportCount'] ?? 0;

      if (reportedBy.contains(userId)) {
        throw Exception("You have already reported this post.");
      }

      reportedBy.add(userId);
      reportCount++;

      if (reportCount >= 5) {
        // Auto-delete if reported 5 times
        transaction.delete(docRef);
      } else {
        transaction.update(docRef, {
          'reportedBy': reportedBy,
          'reportCount': reportCount,
        });
      }
    });
  }

  @override
  Future<void> reportComment(String postId, String commentId, String userId) async {
    final postRef = _firestore.collection(_collectionPath).doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) throw Exception("Comment does not exist!");

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> reportedBy = List.from(data['reportedBy'] ?? []);
      int reportCount = data['reportCount'] ?? 0;

      if (reportedBy.contains(userId)) {
        throw Exception("You have already reported this comment.");
      }

      reportedBy.add(userId);
      reportCount++;

      if (reportCount >= 5) {
        // Auto-delete if reported 5 times
        transaction.delete(commentRef);
        
        // Also reduce post's comment count
        final postSnapshot = await transaction.get(postRef);
        if (postSnapshot.exists) {
          final postData = postSnapshot.data() as Map<String, dynamic>;
          int commentCountNum = postData['commentCount'] ?? 0;
          if (commentCountNum > 0) {
            transaction.update(postRef, {'commentCount': commentCountNum - 1});
          }
        }
      } else {
        transaction.update(commentRef, {
          'reportedBy': reportedBy,
          'reportCount': reportCount,
        });
      }
    });
  }

  @override
  Future<void> toggleMeetupParticipation(String postId, String userId) async {
    final postRef = _firestore.collection(_collectionPath).doc(postId);
    final participantRef = postRef.collection('participants').doc(userId);
    final joinedChatRef = _firestore.collection('users').doc(userId).collection('joined_chats').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) throw Exception("Post does not exist!");

      final postData = postSnapshot.data() as Map<String, dynamic>;
      final int capacity = postData['meetupCapacity'] ?? 0;
      final int currentCount = postData['currentParticipantCount'] ?? 0;
      final String chatRoomName = postData['title'] ?? '(알 수 없음)'; // Fallback to title

      final participantSnapshot = await transaction.get(participantRef);

      if (participantSnapshot.exists) {
        // Leave Meetup
        transaction.delete(participantRef);
        transaction.delete(joinedChatRef);
        if (currentCount > 0) {
          transaction.update(postRef, {'currentParticipantCount': currentCount - 1});
        }
      } else {
        // Join Meetup
        if (currentCount >= capacity && capacity > 0) {
          throw Exception("모임 인원이 마감되었습니다.");
        }
        transaction.set(participantRef, {
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(joinedChatRef, {
          'chatRoomName': chatRoomName,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'currentParticipantCount': currentCount + 1});
      }
    });
  }

  @override
  Stream<List<String>> getMeetupParticipantsStream(String postId) {
    return _firestore
        .collection(_collectionPath)
        .doc(postId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  /// Fetch meetup posts where the given user is a participant via joined_chats collection.
  /// If the post is deleted, it yields a dummy CommunityPost to preserve the chat list.
  Stream<List<CommunityPost>> getMyMeetupPostsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('joined_chats')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<CommunityPost> myPosts = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final postId = doc.id;
        final roomName = data['chatRoomName'] as String? ?? '(알 수 없음)';
        final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // fetch the actual post document
        final postDoc = await _firestore.collection(_collectionPath).doc(postId).get();
        if (postDoc.exists && postDoc.data() != null) {
          myPosts.add(CommunityPost.fromJson(postDoc.data()!, postId));
        } else {
          // It's a deleted post, so we create a dummy CommunityPost
          myPosts.add(
            CommunityPost(
              id: postId,
              authorUid: '',
              authorNickname: '알 수 없음',
              title: roomName, // Fallback title is the saved room name
              content: '삭제된 모임입니다.',
              mainCategory: '모임',
              subCategoryTag: '',
              imageUrls: [],
              likeCount: 0,
              commentCount: 0,
              likedBy: [],
              createdAt: joinedAt, 
            )
          );
        }
      }
      myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return myPosts;
    });
  }

  /// Returns a set of post IDs where the user is a participant.
  /// Used to display [참가] badges on post cards.
  Future<Set<String>> getMyParticipatingPostIds(String uid) async {
    final set = <String>{};
    
    // 1. Check joined_chats
    final joinedQuery = await _firestore.collection('users').doc(uid).collection('joined_chats').get();
    for (var doc in joinedQuery.docs) {
      set.add(doc.id);
    }

    // 2. Fallback check for old meetups in `participants` subcollections
    // (Only checks active '모임' posts to save reads)
    try {
      final meetups = await _firestore.collection(_collectionPath).where('mainCategory', isEqualTo: '모임').get();
      // Use Future.wait for parallel execution
      await Future.wait(meetups.docs.map((doc) async {
        final pid = doc.id;
        if (!set.contains(pid)) {
          final partDoc = await _firestore.collection(_collectionPath).doc(pid).collection('participants').doc(uid).get();
          if (partDoc.exists) {
            set.add(pid);
          }
        }
      }));
    } catch (e) {
      // Ignore fallback failures
    }
    
    return set;
  }

  @override
  Future<void> addReply(String postId, String commentId, CommentReply reply) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(reply.id)
          .set(reply.toJson());

      // 게시글 commentCount 증가
      await _firestore
          .collection(_collectionPath)
          .doc(postId)
          .update({'commentCount': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to add reply: $e');
    }
  }

  @override
  Stream<List<CommentReply>> getRepliesStream(String postId, String commentId) {
    return _firestore
        .collection(_collectionPath)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommentReply.fromJson(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();

      // 게시글 commentCount 감소
      await _firestore
          .collection(_collectionPath)
          .doc(postId)
          .update({'commentCount': FieldValue.increment(-1)});
    } catch (e) {
      throw Exception('Failed to delete reply: $e');
    }
  }
}
