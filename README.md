# 🐾 단추 (Danchu)

### 반려견과 함께하는 산책 & 커뮤니티 앱

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)

<img src="assets/images/app_icon.png" width="120" alt="단추 앱 아이콘"/>

> 🐶 강아지와의 소중한 일상을 기록하고, 반려견 가족들과 함께해요

</div>

---

## 📱 주요 기능

### 🗺️ 산책 트래킹
- GPS 기반 실시간 산책 경로 기록
- 산책 거리 · 시간 · 발자국 경로 시각화
- 강아지별 산책 통계 및 주간/월간/연간 기록
- 산책 완료 후 커뮤니티에 코스 공유

### 🏠 홈 (지도)
- 네이버 지도 기반 반려동물 친화 장소 탐색
- 동물병원 · 애견카페 · 미용실 · 호텔 등 카테고리 검색
- 관심 장소 북마크 및 후기 작성
- 현 지도에서 재검색 기능

### 💬 이야기 (커뮤니티)
- 산책 · 자유 · 신고 · 모임 카테고리 게시판
- 실종/임시보호 반려견 신고 및 위치 지도 표시
- 모임 생성 · 참가 · 실시간 채팅
- 댓글 · 답글 · 좋아요 · 조회수

### 🐕 멍카 (강아지 프로필)
- 강아지 카드 등록 및 관리 (여러 마리 지원)
- 품종 · 나이 · 성별 · 몸무게 · 한줄 소개
- 프로필 사진 원형 크롭 기능

### 👤 내 정보
- 카카오 · 네이버 소셜 로그인
- 활동 통계 요약 및 상세 통계
- 알림 설정 (댓글 · 좋아요 · 모임 · 일정 · 답글)
- 공지사항 · 문의하기 · 이용약관

---

## 🛠️ 기술 스택

| 분류 | 기술 |
|------|------|
| **Framework** | Flutter 3.x |
| **Language** | Dart |
| **State Management** | GetX |
| **Backend** | Firebase (Firestore, Storage, Auth, FCM) |
| **지도** | Naver Map SDK |
| **로그인** | 카카오 SDK, 네이버 로그인 SDK |
| **로컬 DB** | SQLite (산책 기록) |
| **이미지** | cached_network_image, image_cropper |

---

## 📂 프로젝트 구조
```
lib/
├── core/                    # 앱 전역 설정
│   ├── app_colors.dart      # 컬러 팔레트
│   ├── app_constants.dart   # 상수
│   └── utils/               # 유틸리티
├── data/
│   ├── models/              # 데이터 모델
│   └── repositories/        # Repository 구현체
├── domain/
│   ├── entities/            # 도메인 엔티티
│   └── repositories/        # Repository 인터페이스
├── features/
│   ├── auth/                # 로그인/온보딩
│   ├── community/           # 이야기 (게시판/모임/채팅)
│   ├── history/             # 산책 기록
│   ├── profile/             # 내 정보/멍카
│   └── tracking/            # 산책 트래킹
├── presentation/
│   └── home/                # 홈 (지도/장소 탐색)
├── services/                # FCM, 로컬 알림
└── widgets/                 # 공통 위젯
```

---

## 🚀 시작하기

### 요구사항
- Flutter 3.x 이상
- Dart 3.x 이상
- Xcode (iOS 빌드)
- Android Studio (Android 빌드)

### 설치
```bash
# 저장소 클론
git clone https://github.com/your-username/pawprint_app.git
cd pawprint_app

# 패키지 설치
flutter pub get

# iOS 의존성 설치
cd ios && pod install && cd ..

# 앱 실행
flutter run
```

### 환경 설정

1. Firebase 프로젝트 생성 후 `google-services.json` (Android), `GoogleService-Info.plist` (iOS) 추가
2. 네이버 지도 API 키 설정
3. 카카오 SDK 설정
4. 네이버 로그인 SDK 설정

---

## 🔐 Firebase 보안 규칙

Firestore 및 Storage 보안 규칙이 적용되어 있어요:
- 본인 데이터만 수정/삭제 가능
- 신고 5회 이상 게시글 자동 삭제
- Storage 이미지 본인 uid 파일만 쓰기

---

## 📸 스크린샷

| 홈 (지도) | 이야기 | 멍카 | 내 정보 |
|:---------:|:------:|:----:|:-------:|
| 준비 중 | 준비 중 | 준비 중 | 준비 중 |

---

## 📋 라이선스

이 프로젝트는 개인 프로젝트입니다.

---

<div align="center">

🐾 **단추** — 반려견과의 특별한 순간을 함께해요

</div>
