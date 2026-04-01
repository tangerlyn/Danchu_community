import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_colors.dart';
import '../../../services/local_notification_service.dart';
import '../../../data/models/schedule_event.dart';
import '../../../data/repositories/schedule_repository.dart';
import '../../profile/profile_controller.dart';

class AddScheduleSheet extends StatefulWidget {
  final DateTime? initialDate;
  final VoidCallback onSaved;

  const AddScheduleSheet({
    super.key,
    this.initialDate,
    required this.onSaved,
  });

  @override
  State<AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<AddScheduleSheet> {
  final _scheduleRepo = ScheduleRepository();
  final _memoController = TextEditingController();
  final _customCategoryController = TextEditingController();
  int _customCategoryLength = 0;
  int _memoLength = 0;

  String _selectedCategory = '직접 입력';
  late DateTime _selectedDate;
  int _selectedHour = 10;   // 1-12
  int _selectedMinute = 0;  // 0-59
  bool _isAM = true;        // true=오전, false=오후
  String? _selectedDogName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();

    // Default to first dog if available
    if (Get.isRegistered<ProfileController>()) {
      final pc = Get.find<ProfileController>();
      if (pc.dogs.isNotEmpty) {
        _selectedDogName = pc.dogs.first.dogName;
      }
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  /// Convert 12h + AM/PM to 24h
  int _get24Hour() {
    if (_isAM) {
      return _selectedHour == 12 ? 0 : _selectedHour;
    } else {
      return _selectedHour == 12 ? 12 : _selectedHour + 12;
    }
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  Future<void> _pickDate() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 1 + index); // From last year to next 8 years

    int tmpYear = _selectedDate.year;
    int tmpMonth = _selectedDate.month;
    int tmpDay = _selectedDate.day;

    final yearController = FixedExtentScrollController(
        initialItem: years.indexOf(tmpYear));
    final monthController = FixedExtentScrollController(
        initialItem: tmpMonth - 1);
    final dayController = FixedExtentScrollController(
        initialItem: tmpDay - 1);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final daysInMonth = _getDaysInMonth(tmpYear, tmpMonth);
            
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('날짜 선택',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBrown)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Year scroll picker
                        SizedBox(
                          width: 90,
                          child: ListWheelScrollView.useDelegate(
                            controller: yearController,
                            itemExtent: 44,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setSheetState(() => tmpYear = years[index]);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: years.length,
                              builder: (ctx, index) {
                                final y = years[index];
                                final isSelected = y == tmpYear;
                                return Center(
                                  child: Text(
                                    '${y}년',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppColors.deepBrown : AppColors.taupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Month scroll picker
                        SizedBox(
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            controller: monthController,
                            itemExtent: 44,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setSheetState(() => tmpMonth = index + 1);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, index) {
                                final m = index + 1;
                                final isSelected = m == tmpMonth;
                                return Center(
                                  child: Text(
                                    '${m}월',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppColors.deepBrown : AppColors.taupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Day scroll picker
                        SizedBox(
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            controller: dayController,
                            itemExtent: 44,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setSheetState(() => tmpDay = index + 1);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: daysInMonth,
                              builder: (ctx, index) {
                                final d = index + 1;
                                final isSelected = d == tmpDay;
                                return Center(
                                  child: Text(
                                    '${d}일',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppColors.deepBrown : AppColors.taupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            // Ensure day is valid if month/year changed length of month
                            final maxDay = _getDaysInMonth(tmpYear, tmpMonth);
                            final validDay = tmpDay > maxDay ? maxDay : tmpDay;
                            _selectedDate = DateTime(tmpYear, tmpMonth, validDay);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepBrown,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTimePicker() async {
    int tmpHour = _selectedHour;
    int tmpMinute = _selectedMinute;
    bool tmpIsAM = _isAM;

    final hourController = FixedExtentScrollController(
        initialItem: _selectedHour - 1);
    final minuteController = FixedExtentScrollController(
        initialItem: _selectedMinute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('시간 선택',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBrown)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // AM/PM selector (left side)
                        SizedBox(
                          width: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _amPmButton('오전', tmpIsAM, () {
                                setSheetState(() => tmpIsAM = true);
                              }),
                              const SizedBox(height: 8),
                              _amPmButton('오후', !tmpIsAM, () {
                                setSheetState(() => tmpIsAM = false);
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Hour scroll picker
                        SizedBox(
                          width: 60,
                          child: ListWheelScrollView.useDelegate(
                            controller: hourController,
                            itemExtent: 44,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setSheetState(() => tmpHour = index + 1);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, index) {
                                final h = index + 1;
                                final isSelected = h == tmpHour;
                                return Center(
                                  child: Text(
                                    h.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.deepBrown
                                          : AppColors.taupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Colon separator
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(':',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepBrown)),
                        ),

                        // Minute scroll picker
                        SizedBox(
                          width: 60,
                          child: ListWheelScrollView.useDelegate(
                            controller: minuteController,
                            itemExtent: 44,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setSheetState(() => tmpMinute = index);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 60,
                              builder: (ctx, index) {
                                final isSelected = index == tmpMinute;
                                return Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.deepBrown
                                          : AppColors.taupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedHour = tmpHour;
                            _selectedMinute = tmpMinute;
                            _isAM = tmpIsAM;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepBrown,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('확인',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _amPmButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepBrown : AppColors.lightSand,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.white : AppColors.mocha,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedDogName == null || _selectedDogName!.isEmpty) {
      Get.snackbar('알림', '강아지를 선택해주세요.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final eventDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _get24Hour(),
        _selectedMinute,
      );

      final finalCategory = (_selectedCategory == '직접 입력') 
          ? _customCategoryController.text.trim()
          : _selectedCategory;
      
      if (finalCategory.isEmpty) {
        Get.snackbar('알림', '일정 제목을 입력해주세요.');
        setState(() => _isSaving = false);
        return;
      }

      final event = await _scheduleRepo.addSchedule(
        category: finalCategory,
        dateTime: eventDateTime,
        dogName: _selectedDogName!,
        memo: _memoController.text.trim(),
      );

      // 일정 알림 설정 확인 후 등록
      final prefDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('notification_settings')
          .doc('preferences')
          .get();
      final scheduleEnabled = prefDoc.data()?['schedule'] ?? true;

      if (scheduleEnabled) {
        await LocalNotificationService.scheduleScheduleNotification(
          id: LocalNotificationService.generateId(finalCategory, eventDateTime),
          title: finalCategory,
          scheduledTime: eventDateTime,
        );
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
      Get.snackbar('✅ 완료', '일정이 등록되었습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.deepBrown,
          colorText: AppColors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    } catch (e) {
      Get.snackbar('오류', '일정 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formattedTime() {
    final period = _isAM ? '오전' : '오후';
    final h = _selectedHour.toString().padLeft(2, '0');
    final m = _selectedMinute.toString().padLeft(2, '0');
    return '$period $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            const Text(
              '일정 추가',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBrown,
              ),
            ),
            const SizedBox(height: 24),

            // Category Selection
            const Text('일정 종류',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mocha)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScheduleEvent.categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = cat;
                    if (cat != '직접 입력') {
                      _customCategoryController.clear();
                      _customCategoryLength = 0;
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.deepBrown
                          : AppColors.lightSand.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.deepBrown
                            : AppColors.sand,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.deepBrown,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Custom Category Input Field (Only if '직접 입력' selected)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _selectedCategory == '직접 입력'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customCategoryController,
                          maxLength: 10,
                          onChanged: (val) => setState(() => _customCategoryLength = val.length),
                          style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                          decoration: InputDecoration(
                            hintText: '일정 제목을 입력하세요',
                            hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8F5F1),
                            counterText: "", // Hide default counter
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12, top: 14),
                              child: Text(
                                '$_customCategoryLength/10',
                                style: const TextStyle(color: AppColors.taupe, fontSize: 11),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Date & Time Row
            const Text('날짜 및 시간',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mocha)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_today,
                    label:
                        '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')}',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.access_time,
                    label: _formattedTime(),
                    onTap: _showTimePicker,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dog Selection
            const Text('강아지 선택',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mocha)),
            const SizedBox(height: 10),
            Obx(() {
              final dogNames = Get.isRegistered<ProfileController>()
                  ? Get.find<ProfileController>().dogs.map((d) => d.dogName).toList()
                  : <String>[];

              // 새 멍카 등록 시 자동 선택
              if (dogNames.isNotEmpty && (_selectedDogName == null || !dogNames.contains(_selectedDogName))) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _selectedDogName = dogNames.first);
                });
              }

              if (dogNames.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightSand.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '등록된 강아지가 없습니다. 프로필에서 먼저 강아지를 등록해주세요.',
                    style: TextStyle(color: AppColors.taupe, fontSize: 13),
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dogNames.map((name) {
                  final isSelected = _selectedDogName == name;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDogName = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.deepBrown : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.deepBrown : AppColors.sand,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.white : AppColors.deepBrown,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 24),

            // Memo
            const Text('메모 (선택)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mocha)),
            const SizedBox(height: 10),
            TextField(
              controller: _memoController,
              maxLines: 2,
              maxLength: 30,
              onChanged: (val) => setState(() => _memoLength = val.length),
              style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
              decoration: InputDecoration(
                hintText: '간단한 메모를 입력하세요...',
                hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF8F5F1),
                counterText: "", // Hide default counter
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 14),
                  child: Text(
                    '$_memoLength/30',
                    style: const TextStyle(color: AppColors.taupe, fontSize: 11),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 28),

            // Cancel + Save Buttons
            Row(
              children: [
                // Cancel button — small
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mocha,
                      side: const BorderSide(color: AppColors.sand, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save button — large
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBrown,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              '일정 등록',
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sand, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.taupe),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepBrown,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.taupe),
          ],
        ),
      ),
    );
  }
}
