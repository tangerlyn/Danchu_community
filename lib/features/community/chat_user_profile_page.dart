import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/profile_repository.dart';
import 'package:get/get.dart';
import '../profile/widgets/mung_card_widget.dart';

class ChatUserProfilePage extends StatefulWidget {
  final String uid;

  const ChatUserProfilePage({super.key, required this.uid});

  @override
  State<ChatUserProfilePage> createState() => _ChatUserProfilePageState();
}

class _ChatUserProfilePageState extends State<ChatUserProfilePage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentDogIndex = 0;
  
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileRepository.getUserProfile(widget.uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('프로필', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
    }

    if (_profile == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다.', style: TextStyle(color: AppColors.taupe)));
    }

    final profile = _profile!;
    final dogs = profile.effectiveDogs;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sand, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.sand,
                    backgroundImage: profile.profileImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profile.profileImageUrl)
                        : null,
                    child: profile.profileImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 40, color: AppColors.taupe)
                        : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBrown,
                        ),
                      ),
                      if (profile.intro.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          profile.intro,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mocha,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Dog Profiles Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.pets, size: 20, color: AppColors.deepBrown),
                const SizedBox(width: 8),
                const Text(
                  '멍프로필',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${dogs.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.taupe,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (dogs.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '등록된 강아지가 없습니다.',
                    style: TextStyle(color: AppColors.taupe, fontSize: 14),
                  ),
                ),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: dogs.length > 1
                    ? SizedBox(
                        height: 380,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: dogs.length,
                          onPageChanged: (index) {
                            setState(() => _currentDogIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: MungCardWidget(
                                dog: dogs[index],
                                profile: profile,
                              ),
                            );
                          },
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MungCardWidget(
                          dog: dogs.isNotEmpty ? dogs.first : null,
                          profile: profile,
                        ),
                      ),
              ),
            ),

            // Dot Indicator
            if (dogs.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(dogs.length, (index) {
                    final isActive = _currentDogIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.deepBrown : AppColors.sand,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              )
            else
              const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
