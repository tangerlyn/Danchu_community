import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_colors.dart';
import '../../../features/tracking/tracking_page.dart';

void showDogSelectionSheet(BuildContext context, List dogs) {
  final selected = <String>{}.obs;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.6,
      ),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
              children: [
                TextSpan(text: "누구와 산책할까요? "),
                WidgetSpan(
                  child: Icon(Icons.pets, size: 20, color: AppColors.deepBrown),
                  alignment: PlaceholderAlignment.middle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "함께 산책할 강아지를 선택하세요",
            style: TextStyle(fontSize: 14, color: AppColors.taupe),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dogs.length,
              itemBuilder: (_, i) {
                final dog = dogs[i];
                return Obx(() {
                  final isSelected = selected.contains(dog.dogName);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (val) {
                      if (val == true) {
                        selected.add(dog.dogName);
                      } else {
                        selected.remove(dog.dogName);
                      }
                    },
                    title: Text(
                      dog.dogName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    subtitle: dog.dogBreed.isNotEmpty
                        ? Text(dog.dogBreed, style: const TextStyle(color: AppColors.taupe))
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor: AppColors.sand.withOpacity(0.3),
                      child: const Icon(Icons.pets, color: AppColors.deepBrown),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    activeColor: AppColors.deepBrown,
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TrackingPage(dogNames: selected.toList()),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                selected.isEmpty
                    ? "강아지를 선택하세요"
                    : "${selected.length}마리와 산책 시작!",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
