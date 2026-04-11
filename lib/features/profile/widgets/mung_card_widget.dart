import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import '../../../data/models/dog_profile.dart';
import '../../../data/models/user_profile.dart';

class MungCardWidget extends StatelessWidget {
  final DogProfile? dog;
  final UserProfile? profile; // For owner info + backward compat
  final VoidCallback? onTap;

  const MungCardWidget({
    super.key,
    this.dog,
    this.profile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use dog data if available, fall back to profile's legacy fields
    final dogName = dog?.dogName ?? profile?.dogName ?? 'Unknown';
    final ageString = dog?.ageString ?? _legacyAgeString();
    final breed = dog?.dogBreed ?? profile?.dogBreed ?? '';
    final imageUrl = dog?.profileImageUrl ?? profile?.profileImageUrl ?? '';
    final ownerName = profile?.nickname ?? '';
    final gender = dog?.dogGender ?? profile?.dogGender ?? 'Male';
    final genderLabel = gender == 'Female' ? '암컷 ♀' : '수컷 ♂';
    final isNeutered = dog?.isNeutered ?? profile?.isNeutered ?? false;
    final weight = dog?.weight ?? profile?.weight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFCFB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE0D8D0),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),

            // Dog Image
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD7CCC8),
                      width: 1.5,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.sand,
                  backgroundImage: imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(imageUrl)
                      : null,
                  child: imageUrl.isEmpty
                      ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                      : null,
                ),
               ],
            ),
            const SizedBox(height: 14),

            // Dog Name
            Text(
              dogName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E342E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Breed Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEBE9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                breed.isNotEmpty ? breed : '견종 미입력',
                style: const TextStyle(
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Age · Gender · Weight · Neuter Status
            Text(
              '${ageString.isNotEmpty ? '$ageString · ' : ''}$genderLabel${weight != null ? ' · ${weight}kg' : ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            if (dog?.bio?.isNotEmpty ?? false) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  dog!.bio!,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6D4C41),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Divider
            Divider(
              color: AppColors.deepBrown.withOpacity(0.1),
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
            const SizedBox(height: 10),

            // Owner Info
            if (ownerName.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: AppColors.taupe),
                  const SizedBox(width: 4),
                  Text(
                    ownerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D4C41),
                    ),
                  ),
                ],
              ),

            // Branding watermark at bottom-right
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '단추 카드',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown.withOpacity(0.2),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _legacyAgeString() {
    if (profile == null) return '';
    final now = DateTime.now();
    final bMonth = profile!.birthMonth;
    final bDay = profile!.birthDay;

    if (bMonth == null) {
      return '${now.year - profile!.birthYear}살';
    }

    int totalMonths = (now.year * 12 + now.month) - (profile!.birthYear * 12 + bMonth);
    if (bDay != null && now.day < bDay) totalMonths--;
    if (totalMonths < 0) return '';

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;
    if (years == 0) return '$months개월';
    if (months == 0) return '$years살';
    return '$years살 $months개월';
  }
}
