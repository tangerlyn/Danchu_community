import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';

// ─────────────────────────────────────────
//  공통 위젯
// ─────────────────────────────────────────

class _LegalPageScaffold extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;
  final String lastUpdated;

  const _LegalPageScaffold({
    required this.title,
    required this.sections,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBrown,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시행일
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.sand.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '시행일: $lastUpdated',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.taupe,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...sections.map((s) => _buildSection(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_LegalSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBrown,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mocha,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);
}

// ─────────────────────────────────────────
//  이용약관 페이지
// ─────────────────────────────────────────

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPageScaffold(
      title: '이용약관',
      lastUpdated: '2026년 X월 X일',
      sections: const [
        _LegalSection(
          '제1조 (목적)',
          '본 약관은 단추(이하 "서비스")가 제공하는 반려견 산책 기록, 커뮤니티, 강아지 프로필(멍카) 및 모임 서비스의 이용 조건과 절차, 이용자와 서비스 간의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.',
        ),
        _LegalSection(
          '제2조 (용어의 정의)',
          '① "서비스"란 단추 앱을 통해 제공되는 모든 기능을 의미합니다.\n'
          '② "이용자"란 본 약관에 동의하고 서비스를 이용하는 회원을 말합니다.\n'
          '③ "멍카"란 이용자가 등록한 반려견의 프로필 카드를 의미합니다.\n'
          '④ "게시물"이란 이용자가 서비스 내에 작성한 글, 사진, 댓글 등 모든 콘텐츠를 의미합니다.',
        ),
        _LegalSection(
          '제3조 (약관의 효력 및 변경)',
          '① 본 약관은 서비스를 이용하고자 하는 모든 이용자에게 적용됩니다.\n'
          '② 서비스는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 앱 내 공지를 통해 안내합니다.\n'
          '③ 이용자가 변경된 약관에 동의하지 않을 경우 서비스 이용을 중단하고 탈퇴할 수 있습니다.',
        ),
        _LegalSection(
          '제4조 (서비스 이용)',
          '① 서비스는 카카오 및 네이버 소셜 로그인을 통해 회원가입 후 이용할 수 있습니다.\n'
          '② 이용자는 하나의 계정만 생성할 수 있으며, 타인의 계정을 도용해서는 안 됩니다.\n'
          '③ 서비스는 운영상 필요한 경우 이용을 제한하거나 일시 중단할 수 있습니다.',
        ),
        _LegalSection(
          '제5조 (이용자의 의무)',
          '이용자는 다음 행위를 해서는 안 됩니다.\n\n'
          '· 타인을 비방하거나 명예를 훼손하는 행위\n'
          '· 허위 정보를 게시하거나 유포하는 행위\n'
          '· 타인의 개인정보를 무단으로 수집하거나 공유하는 행위\n'
          '· 서비스의 정상적인 운영을 방해하는 행위\n'
          '· 동물 학대 또는 관련 콘텐츠를 게시하는 행위\n'
          '· 영리 목적의 광고성 게시물을 반복 게시하는 행위\n'
          '· 기타 관련 법령에 위반되는 행위',
        ),
        _LegalSection(
          '제6조 (게시물의 관리)',
          '① 이용자가 작성한 게시물의 저작권은 해당 이용자에게 있습니다.\n'
          '② 이용자는 서비스 내에 게시물을 게재함으로써 서비스가 해당 게시물을 서비스 운영 목적으로 활용하는 것에 동의합니다.\n'
          '③ 서비스는 타인의 권리를 침해하거나 본 약관에 위반되는 게시물을 사전 통보 없이 삭제할 수 있습니다.\n'
          '④ 회원 탈퇴 시 게시글과 댓글은 "탈퇴한 사용자"로 표시되며 즉시 삭제되지 않을 수 있습니다.',
        ),
        _LegalSection(
          '제7조 (위치정보 이용)',
          '① 서비스는 산책 경로 기록 및 주변 게시글 탐색 기능을 위해 이용자의 위치정보를 수집·이용합니다.\n'
          '② 위치정보 수집은 이용자의 명시적 동의 후 이루어지며, 동의를 철회할 경우 관련 기능 이용이 제한될 수 있습니다.',
        ),
        _LegalSection(
          '제8조 (서비스 책임 제한)',
          '① 서비스는 천재지변, 시스템 장애 등 불가항력적 사유로 인한 서비스 중단에 대해 책임을 지지 않습니다.\n'
          '② 이용자 간의 분쟁 및 이용자의 귀책 사유로 발생한 손해에 대해 서비스는 책임을 지지 않습니다.\n'
          '③ 서비스가 제공하는 정보(산책 통계 등)의 정확성에 대해 보증하지 않습니다.',
        ),
        _LegalSection(
          '제9조 (계정 해지)',
          '① 이용자는 언제든지 앱 내 설정에서 회원 탈퇴를 신청할 수 있습니다.\n'
          '② 탈퇴 시 이용자의 개인정보 및 반려견 정보는 즉시 삭제됩니다.\n'
          '③ 서비스는 약관을 위반한 이용자의 계정을 제한하거나 삭제할 수 있습니다.',
        ),
        _LegalSection(
          '제10조 (준거법 및 관할)',
          '본 약관은 대한민국 법령에 따라 해석되며, 서비스 이용과 관련한 분쟁은 대한민국 법원을 관할 법원으로 합니다.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  개인정보처리방침 페이지
// ─────────────────────────────────────────

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPageScaffold(
      title: '개인정보처리방침',
      lastUpdated: '2026년 X월 X일',
      sections: const [
        _LegalSection(
          '1. 수집하는 개인정보 항목',
          '[소셜 로그인 시 수집]\n'
          '· 카카오 로그인: 닉네임, 프로필 사진\n'
          '· 네이버 로그인: 닉네임, 프로필 사진\n\n'
          '[서비스 이용 시 수집]\n'
          '· 이용자가 직접 입력한 닉네임, 프로필 사진\n'
          '· 반려견 정보 (이름, 견종, 나이, 성별, 사진 등)\n'
          '· 위치정보 (산책 경로 및 GPS 좌표)\n'
          '· 게시글, 댓글, 채팅 내용\n'
          '· 서비스 이용 기록, 접속 로그',
        ),
        _LegalSection(
          '2. 개인정보 수집 및 이용 목적',
          '· 회원 식별 및 서비스 제공\n'
          '· 산책 기록 저장 및 통계 제공\n'
          '· 커뮤니티 및 모임 서비스 운영\n'
          '· 주변 게시글 탐색 (위치정보 활용)\n'
          '· 푸시 알림 발송 (댓글, 좋아요, 모임 알림)\n'
          '· 서비스 개선 및 오류 대응',
        ),
        _LegalSection(
          '3. 개인정보 보유 및 이용 기간',
          '· 회원 탈퇴 시 즉시 삭제됩니다.\n'
          '· 단, 관련 법령에 의해 보존이 필요한 경우 해당 기간 동안 보관합니다.\n\n'
          '[관련 법령에 따른 보관]\n'
          '· 소비자 불만 또는 분쟁처리 기록: 3년 (전자상거래법)\n'
          '· 로그 기록: 3개월 (통신비밀보호법)',
        ),
        _LegalSection(
          '4. 개인정보의 제3자 제공',
          '단추는 이용자의 개인정보를 외부에 제공하지 않습니다.\n'
          '단, 다음의 경우는 예외로 합니다.\n\n'
          '· 이용자가 사전에 동의한 경우\n'
          '· 법령에 의거하거나 수사기관의 적법한 요청이 있는 경우',
        ),
        _LegalSection(
          '5. 개인정보 처리 위탁',
          '단추는 서비스 운영을 위해 아래와 같이 개인정보 처리를 위탁합니다.\n\n'
          '· Google Firebase (Firestore, Storage, Authentication)\n'
          '  - 위탁 목적: 데이터 저장, 인증, 파일 보관\n\n'
          '· Google Firebase Cloud Messaging (FCM)\n'
          '  - 위탁 목적: 푸시 알림 발송\n\n'
          '· 네이버 클라우드 플랫폼 (네이버 지도)\n'
          '  - 위탁 목적: 지도 서비스 및 장소 검색\n\n'
          '· 카카오 (카카오 로그인)\n'
          '  - 위탁 목적: 소셜 로그인 인증\n\n'
          '· 네이버 (네이버 로그인)\n'
          '  - 위탁 목적: 소셜 로그인 인증',
        ),
        _LegalSection(
          '6. 위치정보 처리',
          '· 수집 목적: 산책 경로 기록, 주변 게시글 탐색\n'
          '· 수집 방법: 이용자 동의 후 기기 GPS를 통해 수집\n'
          '· 보유 기간: 산책 기록은 회원 탈퇴 시까지 보관\n'
          '· 이용자는 기기 설정에서 위치 권한을 철회할 수 있으며, 철회 시 산책 기록 및 주변 탐색 기능이 제한됩니다.',
        ),
        _LegalSection(
          '7. 이용자의 권리',
          '이용자는 언제든지 다음의 권리를 행사할 수 있습니다.\n\n'
          '· 개인정보 조회 및 수정: 앱 내 프로필 수정 메뉴\n'
          '· 개인정보 삭제 및 계정 탈퇴: 앱 내 설정 > 회원 탈퇴\n'
          '· 위치정보 수집 동의 철회: 기기 설정에서 위치 권한 거부\n'
          '· 푸시 알림 수신 거부: 앱 내 설정 > 알림 설정',
        ),
        _LegalSection(
          '8. 개인정보의 안전성 확보 조치',
          '· 비밀번호 등 중요 정보는 암호화하여 저장합니다.\n'
          '· Firebase Security Rules를 통해 데이터 접근을 제어합니다.\n'
          '· 개인정보에 대한 접근 권한을 최소한의 인원으로 제한합니다.',
        ),
        _LegalSection(
          '9. 개인정보 보호책임자',
          '개인정보 처리에 관한 문의는 아래로 연락해 주세요.\n\n'
          '· 서비스명: 단추\n'
          '· 책임자: 김규린\n'
          '· 문의: 앱 내 문의하기 기능을 이용해 주세요.\n\n'
          '이용자는 개인정보보호법에 따른 개인정보 침해 신고를 개인정보보호위원회(privacy.go.kr) 또는 한국인터넷진흥원(118)에 할 수 있습니다.',
        ),
        _LegalSection(
          '10. 개인정보처리방침 변경',
          '본 방침은 법령 및 서비스 변경에 따라 업데이트될 수 있으며, 변경 시 앱 내 공지를 통해 안내드립니다.',
        ),
      ],
    );
  }
}
