import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import '../../data/models/user_profile.dart';
import '../../domain/repositories/friend_repository.dart';
import 'profile_controller.dart';
import 'my_mung_card_page.dart';
import '../auth/auth_controller.dart';
import 'widgets/profile_edit_form.dart';
import 'widgets/profile_settings.dart';
import 'widgets/live_stats_widget.dart';
import 'bookmarked_places_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'legal_pages.dart';
import 'inquiry_page.dart';
import 'notices_page.dart';

class ProfilePage extends StatelessWidget {
  final bool isOnboarding;
  final GlobalKey<LiveStatsWidgetState>? liveStatsKey;
  const ProfilePage({super.key, this.isOnboarding = false, this.liveStatsKey});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Obx(() => AppBar(
          automaticallyImplyLeading: false,
          leading: (controller.isEditing.value && !isOnboarding)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
                  onPressed: () => _showExitConfirmDialog(context, controller),
                )
              : null,
          title: const Text(
            '내 정보',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
              letterSpacing: -0.5,
            ),
          ),
          titleSpacing: 24,
          centerTitle: false,
          backgroundColor: const Color(0xFFFDFCFB),
          elevation: 0,
          toolbarHeight: 64,
          actions: const [
            SizedBox(width: 8),
          ],
        )),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!isOnboarding && controller.userProfile.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!controller.isEditing.value && controller.userProfile.value != null) {
          if (isOnboarding) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.completeOnboarding();
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('기존 프로필을 불러오는 중입니다...'),
                ],
              ),
            );
          }
          return _buildDashboard(context, controller);
        }

        return ProfileEditForm(controller: controller);
      }),
    );
  }

  Widget _buildDashboard(BuildContext context, ProfileController controller) {
    final profile = controller.userProfile.value!;
    final dogs = controller.dogs;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, controller, profile, dogs),
          const SizedBox(height: 24),
          if (dogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildEmptyDogState(controller),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMungCardEntry(controller),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveStatsWidget(key: liveStatsKey),
            ),
          ],
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildBottomMenu(context, controller),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyDogState(ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.sand.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/icon/app_icon3.png',
              width: 40,
              height: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '아직 등록된 단카가 없어요!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '소중한 강아지의 프로필을 만들고\n다양한 활동을 시작해보세요 🐾',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.latte,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Get.to(() => const MyMungCardPage());
                controller.fetchProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBrown,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '첫 단카 추가하러 가기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProfileController controller,
    UserProfile profile,
    List dogs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 16, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD7CCC8), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepBrown.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.sand,
                  backgroundImage: profile.profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(profile.profileImageUrl)
                      : null,
                  child: profile.profileImageUrl.isEmpty
                      ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      profile.nickname,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (dogs.isNotEmpty)
                      Text(
                        dogs.map((d) => d.dogName).join(', '),
                        style: TextStyle(fontSize: 14, color: AppColors.latte, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showSettingsMenu(context, controller),
                icon: Icon(Icons.settings, color: AppColors.taupe, size: 24),
                splashRadius: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMungCardEntry(ProfileController controller) {
    return GestureDetector(
      onTap: () async {
        if (controller.isEditing.value) controller.isEditing.value = false;
        await Get.to(() => const MyMungCardPage());
        controller.fetchProfile();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sand, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.mocha.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.sand.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: AppColors.deepBrown, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 단추 카드 관리하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBrown,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.taupe, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMenu(BuildContext context, ProfileController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _bottomMenuItem(
            icon: Icons.description_outlined,
            label: '이용약관',
            onTap: () => Get.to(() => const TermsOfServicePage()),
          ),
          Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
          _bottomMenuItem(
            icon: Icons.lock_outline,
            label: '개인정보처리방침',
            onTap: () => Get.to(() => const PrivacyPolicyPage()),
          ),
          Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
          _bottomMenuItem(
            icon: Icons.help_outline,
            label: '문의하기',
            onTap: () => Get.to(() => const InquiryPage()),
          ),
          Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
          _bottomMenuItem(
            icon: Icons.campaign_outlined,
            label: '공지사항',
            onTap: () => Get.to(() => const NoticesPage()),
          ),
          Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
          // 앱 버전 (탭 없음)
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '-';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.latte, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('앱 버전', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.latte)),
                    ),
                    Text('v$version', style: TextStyle(fontSize: 14, color: AppColors.taupe)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bottomMenuItem({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? AppColors.latte;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c)),
            ),
            Icon(Icons.chevron_right, color: AppColors.sand, size: 20),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmDialog(BuildContext context, ProfileController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('수정 취소', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('변경사항이 저장되지 않습니다.\n나가시겠습니까?', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('계속 수정', style: TextStyle(color: AppColors.taupe)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.isEditing.value = false;
              controller.fetchProfile(); // 수정 내용 초기화
            },
            child: const Text('나가기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
