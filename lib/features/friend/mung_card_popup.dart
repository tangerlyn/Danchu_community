import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../profile/widgets/mung_card_widget.dart';

class MungCardPopup extends StatefulWidget {
  final UserProfile profile;
  final bool isAlreadyFriend;
  final VoidCallback? onExchange;

  const MungCardPopup({
    super.key,
    required this.profile,
    this.isAlreadyFriend = false,
    this.onExchange,
  });

  @override
  State<MungCardPopup> createState() => _MungCardPopupState();
}

class _MungCardPopupState extends State<MungCardPopup> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: widget.profile.effectiveDogs.length > 1 ? 0.88 : 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dogs = widget.profile.effectiveDogs;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card Content
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mocha.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),

                // Carousel or single card
                SizedBox(
                  height: 380,
                  child: dogs.length > 1
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: dogs.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: MungCardWidget(
                                dog: dogs[index],
                                profile: widget.profile,
                              ),
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: MungCardWidget(
                            dog: dogs.isNotEmpty ? dogs.first : null,
                            profile: widget.profile,
                          ),
                        ),
                ),

                // Dot indicator (only for multi-dog)
                if (dogs.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(dogs.length, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF5D4037) : const Color(0xFFD7CCC8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),

                // Exchange Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: widget.isAlreadyFriend ? null : widget.onExchange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isAlreadyFriend
                            ? AppColors.sand
                            : const Color(0xFF5D4037),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: widget.isAlreadyFriend ? 0 : 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isAlreadyFriend ? Icons.check_circle : Icons.pets,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isAlreadyFriend ? "이미 친구입니다" : "멍카 교환하기",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // X Close Button
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mocha.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 20, color: AppColors.latte),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
