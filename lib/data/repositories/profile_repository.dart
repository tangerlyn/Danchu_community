import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../models/dog_profile.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ProfileRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _usersRef => _firestore.collection('users');

  // ─── User Profile ───

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (doc.exists && data != null && data['nickname'] != null && data['nickname'].toString().isNotEmpty) {
        final profile = UserProfile.fromFirestore(doc);
        // Also fetch dogs subcollection
        final dogs = await getDogs(uid);
        return profile.withDogs(dogs);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ getUserProfile error: $e');
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    _usersRef.doc(profile.uid)
      .set(profile.toMap(), SetOptions(merge: true))
      .then((_) => debugPrint('✅ Firestore server sync complete for ${profile.uid}'))
      .catchError((e) => debugPrint('⚠️ Firestore server sync failed: $e'));
  }

  Future<void> updateUserProfileBasicInfo(String uid, String nickname, String profileImageUrl) async {
    await _usersRef.doc(uid).update({
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
    });
    debugPrint('✅ User basic info updated for $uid');
  }

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      // 1. Firestore에서 기존 프로필 이미지 URL 가져오기
      String? oldUrl;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          oldUrl = userDoc.data()?['profileImageUrl'] as String?;
        }
      } catch (_) {
        // 문서 없으면 무시하고 계속 진행
      }

      // 2. 기존 캐시 삭제 (이전 사진이 캐시에 남지 않도록)
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldUrl);
      }

      // 3. 기존 Storage 파일 삭제 (있으면)
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldUrl).delete();
        } catch (_) {
          // 기존 파일 없으면 무시하고 계속 진행
        }
      }

      // 4. 새 파일을 고유한 파일명으로 업로드
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _storage.ref()
          .child('profile_images')
          .child('${uid}_$timestamp.jpg');
      await newRef.putFile(imageFile);
      final newUrl = await newRef.getDownloadURL();

      // 5. Firestore users/{uid} 문서에 새 URL 저장
      // update 대신 set+merge 사용 (문서 없어도 동작)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'profileImageUrl': newUrl}, SetOptions(merge: true));

      return newUrl;
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  // ─── Dogs Subcollection ───

  CollectionReference _dogsRef(String uid) =>
      _usersRef.doc(uid).collection('dogs');

  Future<List<DogProfile>> getDogs(String uid) async {
    try {
      final snapshot = await _dogsRef(uid).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DogProfile.fromMap(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ getDogs error: $e');
      return [];
    }
  }

  /// Fire-and-forget: writes to local cache immediately, syncs in background.
  String saveDog(String uid, DogProfile dog) {
    if (dog.dogId.isEmpty || dog.dogId.startsWith('legacy_')) {
      // New dog: create a doc ref to get the ID immediately, then set
      final docRef = _dogsRef(uid).doc(); // auto-generated ID, no await
      docRef.set(dog.toMap())
        .then((_) => debugPrint('🐶 New dog synced: ${docRef.id}'))
        .catchError((e) => debugPrint('⚠️ saveDog sync failed (local OK): $e'));
      return docRef.id;
    } else {
      // Update existing
      _dogsRef(uid).doc(dog.dogId).set(dog.toMap())
        .then((_) => debugPrint('🐶 Dog updated: ${dog.dogId}'))
        .catchError((e) => debugPrint('⚠️ saveDog sync failed (local OK): $e'));
      return dog.dogId;
    }
  }

  /// Fire-and-forget delete
  void deleteDog(String uid, String dogId) {
    _dogsRef(uid).doc(dogId).delete()
      .then((_) => debugPrint('🗑️ Dog deleted: $dogId'))
      .catchError((e) => debugPrint('⚠️ deleteDog sync failed (local OK): $e'));
  }

  /// 닉네임 중복 체크
  Future<bool> isNicknameTaken(String nickname) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ isNicknameTaken error: $e');
      return false;
    }
  }

  Future<String> uploadDogImage(String uid, String dogId, File imageFile) async {
    try {
      final ref = _storage.ref().child('dog_images').child('${uid}_$dogId.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Dog image upload failed: $e');
    }
  }
}
