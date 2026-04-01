# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug)
flutter run

# Build
flutter build apk          # Android
flutter build ios          # iOS

# Lint & analyze
flutter analyze

# Run tests
flutter test                                      # All unit/widget tests
flutter test test/widget_test.dart               # Single test file
flutter test integration_test/walk_flow_test.dart # Integration test (requires device)

# Generate launcher icons & splash screen
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Architecture

**State management**: GetX (`get` package). Controllers extend `GetxController` with reactive `.obs` variables. `Get.put()`/`Get.find()` for DI, `Get.offAll()` for navigation.

**Layer structure** inside `lib/`:

| Directory | Role |
|---|---|
| `core/` | App-wide constants, colors (`AppColors`), date utils, `NetworkController` |
| `domain/entities/` | Pure data classes (`PlaceEntity`, `PlaceReview`, etc.) |
| `domain/repositories/` | Abstract repository interfaces |
| `data/models/` | Concrete models (`DogProfile`, `UserProfile`, `PlaceModel`, etc.) |
| `data/repositories/` | Repository implementations (Firestore, Naver API, SQLite) |
| `data/providers/` | Raw API clients (`NaverApiProvider`) |
| `features/` | Feature-first screens and controllers (auth, chat, community, friend, history, notification, profile, report, tracking) |
| `presentation/home/` | Map home screen with its own binding/controller/view split (GetX pattern) |
| `services/` | App-wide singletons: `FcmService`, `LocalNotificationService` |
| `utils/` | Shared utilities and mock services |
| `widgets/` | Shared widgets (`NetworkBanner`, `OverlayNotification`, `PawLoadingIndicator`) |

**Navigation flow** (`main.dart` → `MainScreen`):
- App checks `SharedPreferences` for `is_profile_completed` and `has_seen_onboarding`, and `FirebaseAuth` for login state
- Routes: `LoginPage` → (Kakao/Naver OAuth) → `ProfilePage(isOnboarding: true)` → `MainScreen`
- `MainScreen` is a bottom-nav shell with 4 tabs: Home (map), History, Community, Profile

**Backend**: Firebase (Auth, Firestore, Storage, Messaging, Analytics) + Naver Map SDK + Naver/Kakao OAuth.

**Auth pattern**: Kakao/Naver social login is bridged to Firebase Auth via email+password (email = `kakao_{id}@pawprint.login` or real Naver email; password = SHA-256 of `{id} + "PAWPRINT_SECRET_SALT_2026"` truncated to 20 chars).

**Local DB**: SQLite via `sqflite` in `features/history/database_helper.dart` — stores walk records locally, cleared on logout.

**Map (Home) feature**: `HomeController` (`presentation/home/controllers/`) manages Naver Map markers, place search (via `SearchRepository` → `NaverApiProvider`), category filtering, and bookmark sync from Firestore in real time.

**Walk tracking**: `features/tracking/tracking_page.dart` and `summary_page.dart` — GPS tracking using `geolocator`, route drawn on Naver Map, saved to local SQLite and Firestore.

**Community**: `features/community/` — posts, comments, meetup chat (`cloud_firestore` streams), location pick, missing pet reports. `CommunityController` is explicitly deleted before `Get.deleteAll()` on logout to avoid stream leaks.
