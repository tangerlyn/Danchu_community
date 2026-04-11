import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_colors.dart';
import '../../profile/legal_pages.dart';

class TermsAgreementDialog extends StatefulWidget {
  /// 동의 시 호출되는 콜백
  final VoidCallback onAgreed;

  const TermsAgreementDialog({
    super.key,
    required this.onAgreed,
  });

  /// 동의 여부 확인 후 필요하면 다이얼로그 표시.
  /// 이미 동의했으면 onAgreed 바로 호출 후 false 반환,
  /// 다이얼로그를 띄웠으면 true 반환.
  static Future<bool> showIfNeeded({
    required VoidCallback onAgreed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('has_agreed_to_terms') ?? false;

    if (hasAgreed) {
      onAgreed();
      return false;
    }

    Get.dialog(
      TermsAgreementDialog(onAgreed: onAgreed),
      barrierDismissible: false,
    );
    return true;
  }

  @override
  State<TermsAgreementDialog> createState() => _TermsAgreementDialogState();
}

class _TermsAgreementDialogState extends State<TermsAgreementDialog> {
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;

  bool get _allAgreed => _agreedToTerms && _agreedToPrivacy;

  void _toggleAll(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _agreedToTerms = newValue;
      _agreedToPrivacy = newValue;
    });
  }

  Future<void> _handleAgree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_agreed_to_terms', true);
    Get.back();
    widget.onAgreed();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 헤더 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    const Icon(Icons.pets, color: AppColors.deepBrown, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      '단추 이용 약관 동의',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBrown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '서비스를 이용하시려면 아래 약관에\n동의해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mocha.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 전체 동의 ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sand.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: _allAgreed,
                  onChanged: _toggleAll,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.deepBrown,
                  title: const Text(
                    '전체 동의',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBrown,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── 개별 동의 항목들 ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildAgreementItem(
                      label: '이용약관 동의',
                      checked: _agreedToTerms,
                      onChanged: (value) {
                        setState(() => _agreedToTerms = value ?? false);
                      },
                      onViewDetail: () => Get.to(() => const TermsOfServicePage()),
                    ),
                    _buildAgreementItem(
                      label: '개인정보처리방침 동의',
                      checked: _agreedToPrivacy,
                      onChanged: (value) {
                        setState(() => _agreedToPrivacy = value ?? false);
                      },
                      onViewDetail: () => Get.to(() => const PrivacyPolicyPage()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── 약관 요약 미리보기 (스크롤 가능) ──
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sand.withOpacity(0.5)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '이용약관 요약',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '· 본 약관은 단추 서비스(반려견 산책 기록, 커뮤니티, 모임)의 이용 조건을 규정합니다.\n\n'
                          '· 이용자는 음란물, 폭력, 차별, 동물 학대 등 부적절한 콘텐츠를 게시할 수 없으며, 무관용 원칙(Zero Tolerance)이 적용됩니다.\n\n'
                          '· 부적절한 콘텐츠나 사용자는 신고/차단할 수 있으며, 신고된 내용은 24시간 이내에 검토됩니다.\n\n'
                          '· 위치정보는 산책 경로 기록에만 사용되며, 산책 종료 시 자동으로 수집이 중단됩니다.\n\n'
                          '자세한 내용은 위 "이용약관 동의" 항목의 보기를 눌러주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mocha.withOpacity(0.85),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '개인정보처리방침 요약',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '· 카카오/네이버 로그인 시 닉네임과 프로필 사진을 받습니다.\n\n'
                          '· 산책 경로(GPS), 게시글, 댓글, 반려견 정보 등을 저장합니다.\n\n'
                          '· 회원 탈퇴 시 모든 개인정보가 즉시 삭제됩니다.\n\n'
                          '· 광고 식별자(IDFA)는 수집하지 않으며, 사용자를 추적하지 않습니다.\n\n'
                          '· 만 14세 미만 아동의 가입은 받지 않습니다.\n\n'
                          '자세한 내용은 위 "개인정보처리방침 동의" 항목의 보기를 눌러주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mocha.withOpacity(0.85),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 하단 버튼 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _allAgreed ? _handleAgree : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepBrown,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor:
                          AppColors.deepBrown.withOpacity(0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '동의하고 시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementItem({
    required String label,
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDetail,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: AppColors.deepBrown,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!checked),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '(필수) $label',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.deepBrown,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onViewDetail,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '보기 >',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.taupe,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
