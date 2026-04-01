import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_colors.dart';

/// 날짜/시간/인원 선택 바텀시트 유틸.
/// PostCreateController와 PostEditController에서 중복 구현되어 있던 코드를 통합.
class DatePickerUtils {
  DatePickerUtils._();

  static int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // -------------------------------------------------------------------------
  // 날짜 선택 바텀시트
  // -------------------------------------------------------------------------
  static Future<void> showDateSheet({
    required BuildContext context,
    required String title,
    required DateTime initialDate,
    DateTime? maxDate,
    required Function(DateTime) onSelect,
  }) async {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index);

    int tmpYear = initialDate.year;
    int tmpMonth = initialDate.month;
    int tmpDay = initialDate.day;

    if (!years.contains(tmpYear)) {
      years.add(tmpYear);
      years.sort();
    }

    final yearController = FixedExtentScrollController(initialItem: years.indexOf(tmpYear));
    final monthController = FixedExtentScrollController(initialItem: tmpMonth - 1);
    final dayController = FixedExtentScrollController(initialItem: tmpDay - 1);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final daysInMonth = _getDaysInMonth(tmpYear, tmpMonth);
            return _buildSheetContainer(
              title: title,
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheelScroll(
                    controller: yearController,
                    count: years.length,
                    width: 90,
                    onChanged: (idx) => setSheetState(() => tmpYear = years[idx]),
                    labelBuilder: (idx) => '${years[idx]}년',
                    isSelected: (idx) => years[idx] == tmpYear,
                  ),
                  _buildWheelScroll(
                    controller: monthController,
                    count: 12,
                    onChanged: (idx) => setSheetState(() => tmpMonth = idx + 1),
                    labelBuilder: (idx) => '${idx + 1}월',
                    isSelected: (idx) => (idx + 1) == tmpMonth,
                  ),
                  _buildWheelScroll(
                    controller: dayController,
                    count: daysInMonth,
                    onChanged: (idx) => setSheetState(() => tmpDay = idx + 1),
                    labelBuilder: (idx) => '${idx + 1}일',
                    isSelected: (idx) => (idx + 1) == tmpDay,
                  ),
                ],
              ),
              onConfirm: () {
                final selected = DateTime(tmpYear, tmpMonth, tmpDay);
                if (maxDate != null && selected.isAfter(maxDate)) {
                  Get.snackbar('알림', '미래의 날짜는 선택할 수 없습니다.');
                  return;
                }
                Navigator.pop(ctx);
                onSelect(selected);
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 시간 선택 바텀시트
  // -------------------------------------------------------------------------
  static Future<void> showTimeSheet({
    required BuildContext context,
    required DateTime initialDateTime,
    required Function(int hour24, int minute) onSelect,
  }) async {
    int tmpHour24 = initialDateTime.hour;
    bool tmpIsAM = tmpHour24 < 12;
    int tmpHour12 = tmpHour24 % 12;
    if (tmpHour12 == 0) tmpHour12 = 12;
    int tmpMinute = initialDateTime.minute;

    final hourController = FixedExtentScrollController(initialItem: tmpHour12 - 1);
    final minuteController = FixedExtentScrollController(initialItem: tmpMinute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return _buildSheetContainer(
              title: '시간 선택',
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildAmPmButton(
                          label: '오전',
                          isSelected: tmpIsAM,
                          onTap: () => setSheetState(() => tmpIsAM = true),
                        ),
                        const SizedBox(height: 8),
                        buildAmPmButton(
                          label: '오후',
                          isSelected: !tmpIsAM,
                          onTap: () => setSheetState(() => tmpIsAM = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildWheelScroll(
                    controller: hourController,
                    count: 12,
                    width: 60,
                    onChanged: (idx) => setSheetState(() => tmpHour12 = idx + 1),
                    labelBuilder: (idx) => (idx + 1).toString().padLeft(2, '0'),
                    isSelected: (idx) => (idx + 1) == tmpHour12,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      ':',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                    ),
                  ),
                  _buildWheelScroll(
                    controller: minuteController,
                    count: 60,
                    width: 60,
                    onChanged: (idx) => setSheetState(() => tmpMinute = idx),
                    labelBuilder: (idx) => idx.toString().padLeft(2, '0'),
                    isSelected: (idx) => idx == tmpMinute,
                  ),
                ],
              ),
              onConfirm: () {
                Navigator.pop(ctx);
                int finalHour = tmpHour12 % 12;
                if (!tmpIsAM) finalHour += 12;
                onSelect(finalHour, tmpMinute);
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 인원 선택 바텀시트
  // -------------------------------------------------------------------------
  static Future<void> showCapacitySheet({
    required BuildContext context,
    required int initialCapacity,
    required Function(int) onSelect,
  }) async {
    int tempCapacity = initialCapacity;
    final controller = FixedExtentScrollController(initialItem: tempCapacity - 1);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return _buildSheetContainer(
              title: '모집 인원 선택',
              content: _buildWheelScroll(
                controller: controller,
                count: 20,
                onChanged: (idx) => setSheetState(() => tempCapacity = idx + 1),
                labelBuilder: (idx) => '${idx + 1}명',
                isSelected: (idx) => (idx + 1) == tempCapacity,
              ),
              onConfirm: () {
                Navigator.pop(ctx);
                onSelect(tempCapacity);
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 오전/오후 토글 버튼
  // -------------------------------------------------------------------------
  static Widget buildAmPmButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepBrown : AppColors.lightSand,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.white : AppColors.mocha,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 공통: 스크롤 휠 위젯
  // -------------------------------------------------------------------------
  static Widget _buildWheelScroll({
    required FixedExtentScrollController controller,
    required int count,
    required Function(int) onChanged,
    required String Function(int) labelBuilder,
    required bool Function(int) isSelected,
    double width = 70,
  }) {
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (ctx, index) {
            final selected = isSelected(index);
            return Center(
              child: Text(
                labelBuilder(index),
                style: TextStyle(
                  fontSize: selected ? 22 : 18,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppColors.deepBrown : AppColors.taupe,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 공통: 바텀시트 컨테이너 레이아웃
  // -------------------------------------------------------------------------
  static Widget _buildSheetContainer({
    required String title,
    required Widget content,
    required VoidCallback onConfirm,
  }) {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBrown,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: content),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBrown,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
