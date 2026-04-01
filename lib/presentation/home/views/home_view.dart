import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';

import '../../../features/tracking/tracking_page.dart';
import '../../../features/profile/profile_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/category_chips_widget.dart';
import '../widgets/bottom_results_sheet.dart';
import '../widgets/place_detail_panel.dart';
import '../widgets/search_in_map_button.dart';
import '../widgets/unified_search_panel.dart';
import '../widgets/dog_selection_sheet.dart';
import '../../../features/main_screen.dart';

/// Main home view with map, search, categories, results, and detail panel.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Handle in overlay
      // Intercept Back Button to close search first
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (controller.isSearchFocused.value) {
            controller.searchFocusNode.unfocus();
          } else if (controller.selectedPlace.value != null) {
            controller.onCloseDetailPanel();
          } else if (controller.showBottomSheet.value) {
             if (Navigator.canPop(context)) {
               Navigator.pop(context);
             }
          } else {
             // System exit
             if (Navigator.canPop(context)) {
               Navigator.pop(context);
             }
          }
        },
        child: Stack(
        children: [
          // 1. Naver Map (Full Background)
          NaverMap(
            options: const NaverMapViewOptions(
              customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
              indoorEnable: true,
              locationButtonEnable: true,
              consumeSymbolTapEvents: false,
              logoClickEnable: false,
            ),
            onMapReady: controller.onMapReady,
            onMapTapped: controller.onMapTapped,
            onCameraChange: (reason, animated) {
              controller.onCameraChange(reason);
            },
          ),

          // 2. Full Screen Search Overlay (When Focused)
          // Isolates map interaction and provides clean UI
          Obx(() {
            if (controller.isSearchFocused.value) {
              return Positioned.fill(
                child: Container(
                  color: const Color(0xFFF8F5F1),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Header: Back Button + Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  // Safe exit
                                  controller.searchFocusNode.unfocus();
                                },
                              ),
                              Expanded(
                                child: SearchBarWidget(isFullScreen: true),
                              ),
                            ],
                          ),
                        ),
                        // Expanded List (Unlimited Scroll)
                        Expanded(
                          child: UnifiedSearchPanel(
                            controller: controller,
                            hasInput: true,
                            showDropdown: controller.showDropdown.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // 3. Normal State (Floating Search Bar)
            // Hidden when full screen search is active
            return Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchBarWidget(isFullScreen: false),
                  
                  // Categories (Only when not focused & no selection)
                  if (!controller.isSearchFocused.value && 
                      !controller.showBottomSheet.value && 
                      controller.selectedPlace.value == null &&
                      controller.currentSearchQuery.value.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: const CategoryChipsWidget(),
                    ),
                ],
              ),
            );
          }),

          // 4. Bottom Results Sheet
          const BottomResultsSheet(),

          // 5. "현 지도에서 검색" Button (Moved above Sheet, Z-index higher)
          Obx(() {
            final show = controller.showSearchInMapButton.value &&
                !controller.isSearchFocused.value &&
                // !controller.showBottomSheet.value && // REMOVED: Show even if sheet is open
                controller.selectedPlace.value == null;
            return show
                ? Positioned(
                    top: topPadding + 100, // Slightly adjusted
                    left: 0,
                    right: 0,
                    child: const SearchInMapButton(),
                  )
                : const SizedBox.shrink();
          }),



          // 5. Place Detail Bottom Panel
          Obx(() {
            final place = controller.selectedPlace.value;
            if (place == null) return const SizedBox.shrink();
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PlaceDetailPanel(
                place: place,
                onClose: controller.onCloseDetailPanel,
              ),
            );
          }),
        ],
      ),
      ),
      floatingActionButton: Obx(() =>
        controller.selectedPlace.value == null && !controller.showBottomSheet.value && !controller.isSearchFocused.value
            ? FloatingActionButton.extended(
                heroTag: 'home_walk_fab',
                onPressed: () => _startWalk(context),
                label: const Text("산책하기", style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.directions_walk, color: AppColors.white),
                backgroundColor: AppColors.deepBrown,
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _startWalk(BuildContext context) {
    final profileCtrl = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    // ✅ 최신 dogs 데이터 확인
    final dogs = profileCtrl.dogs;

    if (dogs.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.pets, color: AppColors.deepBrown, size: 24),
              SizedBox(width: 8),
              Text('멍카가 없어요!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
            ],
          ),
          content: const Text(
            '산책을 시작하려면 먼저 강아지 멍카를 만들어야 해요 🐾',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.mocha),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final mainScreen = MainScreen.currentState;
                mainScreen?.switchToTab(3);
              },
              child: const Text('멍카 만들러 가기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else if (dogs.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackingPage(dogNames: [dogs.first.dogName]),
        ),
      );
    } else {
      showDogSelectionSheet(context, dogs);
    }
  }
}
