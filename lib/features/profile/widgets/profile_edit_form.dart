import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../profile_controller.dart';
import '../../auth/auth_controller.dart';
import '../../community/community_constants.dart';

/// Profile edit mode for onboarding and editing.
/// Profile edit mode for onboarding and editing.
class ProfileEditForm extends StatefulWidget {
  final ProfileController controller;
  const ProfileEditForm({super.key, required this.controller});

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '보호자 정보를 입력해주세요',
              style: TextStyle(fontSize: 14, color: AppColors.latte),
            ),
            const SizedBox(height: 32),
            _buildImagePicker(),
            const SizedBox(height: 32),
            _buildNicknameField(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }


  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: widget.controller.pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Obx(() {
            if (widget.controller.pickedImage.value != null) {
              return CircleAvatar(
                radius: 60,
                backgroundImage: FileImage(widget.controller.pickedImage.value!),
              );
            }
            if (widget.controller.userProfile.value?.profileImageUrl.isNotEmpty == true) {
              return CircleAvatar(
                radius: 60,
                backgroundImage: CachedNetworkImageProvider(widget.controller.userProfile.value!.profileImageUrl),
              );
            }
            return const CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.sand,
              child: Icon(Icons.add_a_photo, size: 40, color: AppColors.deepBrown),
            );
          }),
          Container(
            decoration: const BoxDecoration(color: Color(0xFF5D4037), shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.camera_alt, color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameField() {
    final controller = widget.controller;
    return Obx(() {
      final canChange = controller.canChangeNickname.value;
      final lastChanged = controller.lastNicknameChangedAt.value;

      String? subText;

      if (!canChange && lastChanged != null) {
        final remaining = 30 - DateTime.now().difference(lastChanged).inDays;
        subText = '닉네임은 변경 후 30일이 지나야 바꿀 수 있어요. (${remaining}일 남음)';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller.nicknameController,
            maxLines: 1,
            maxLength: 10,
            enabled: canChange,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              counterText: '${controller.nicknameController.text.length}/10',
              counterStyle: const TextStyle(fontSize: 12, color: AppColors.taupe),
              labelText: '보호자 닉네임',
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF8D6E63)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
              ),
              filled: true,
              fillColor: canChange ? AppColors.white : AppColors.sand.withOpacity(0.3),
            ),
          ),
          if (subText != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                subText,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: widget.controller.saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D4037),
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: 10,
      onChanged: (val) => setState(() {}),
      decoration: InputDecoration(
        counterText: '${ctrl.text.length}/10',
        counterStyle: const TextStyle(fontSize: 12, color: AppColors.taupe),
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D6E63)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white,
      ),
    );
  }
}
