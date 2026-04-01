import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/community_post.dart';

class PetReportForm extends StatelessWidget {
  final bool isMissing;
  final TextEditingController nameController;
  final TextEditingController breedController;
  final TextEditingController ageController;
  final TextEditingController featureController;
  final TextEditingController healthController;
  final RxString selectedGender;
  final RxBool isNeutered;
  final RxList<IncidentLocation> incidentLocations;
  final Rxn<DateTime> selectedDate;
  final Function(BuildContext) onSelectDate;
  final Function() onAddLocation;
  final Function(int) onRemoveLocation;

  const PetReportForm({
    super.key,
    required this.isMissing,
    required this.nameController,
    required this.breedController,
    required this.ageController,
    required this.featureController,
    required this.healthController,
    required this.selectedGender,
    required this.isNeutered,
    required this.incidentLocations,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onAddLocation,
    required this.onRemoveLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('반려견 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mocha)),
        const SizedBox(height: 16),
        
        // Name & Breed
        Row(
          children: [
            Expanded(
              child: _buildField(
                title: '이름',
                child: _buildTextField(nameController, '이름 입력'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                title: '견종',
                child: _buildTextField(breedController, '예: 푸들, 말티즈'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Age & Gender
        Row(
          children: [
            Expanded(
              child: _buildField(
                title: isMissing ? '나이' : '추정 나이',
                child: _buildTextField(ageController, '예: 3살, 모름'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                title: '성별',
                child: Obx(() => _buildDropdown(
                  value: selectedGender.value,
                  items: ['남', '여', '선택 안함'],
                  onChanged: (val) => selectedGender.value = val ?? '선택 안함',
                  hint: '성별 선택',
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Features / Personality
        _buildField(
          title: isMissing ? '색상 / 외형 특징' : '성격 / 특징',
          child: _buildTextField(featureController, isMissing ? '모색, 흉터, 착용 중인 인식표 등' : '사람을 좋아하는지, 겁이 많은지 등'),
        ),
        const SizedBox(height: 16),

        if (!isMissing) ...[
          // Health & Neutralization (Care only)
          Row(
            children: [
              Expanded(
                child: _buildField(
                  title: '건강 상태',
                  child: _buildTextField(healthController, '예: 양호, 진료 필요'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  title: '중성화 여부',
                child: Obx(() => Row(
                  children: [
                    Expanded(
                      child: _buildToggleButton(
                        label: '완료',
                        isSelected: isNeutered.value,
                        onTap: () => isNeutered.value = true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleButton(
                        label: '미완료',
                        isSelected: !isNeutered.value,
                        onTap: () => isNeutered.value = false,
                      ),
                    ),
                  ],
                )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (isMissing) ...[
          // Incident Date (Missing only)
          _buildField(
            title: '마지막 목격 날짜',
            child: InkWell(
              onTap: () => onSelectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.sand.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Obx(() => Text(
                      selectedDate.value != null
                          ? DateFormat('yyyy.MM.dd').format(selectedDate.value!)
                          : '날짜 선택',
                      style: TextStyle(
                        color: selectedDate.value != null ? AppColors.deepBrown : AppColors.taupe,
                        fontSize: 14,
                      ),
                    )),
                    const Spacer(),
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.taupe),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isMissing) ...[
          // Locations
          _buildField(
            title: '마지막 목격 장소 (복수 등록 가능)',
            child: Column(
              children: [
                Obx(() {
                  final list = incidentLocations.toList();
                  return Column(
                    children: list.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final loc = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightSand.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(child: Text(loc.name, style: const TextStyle(fontSize: 13, color: AppColors.deepBrown))),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.taupe),
                              onPressed: () => onRemoveLocation(idx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: onAddLocation,
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: const Text('목격 장소 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepBrown,
                    side: const BorderSide(color: AppColors.sand),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildField({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mocha)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 14),
        filled: true,
        fillColor: AppColors.sand.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      style: const TextStyle(color: AppColors.deepBrown, fontSize: 14),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String hint,
  }) {
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sand.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.taupe)),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.taupe),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: AppColors.deepBrown, fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepBrown : AppColors.sand.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.deepBrown : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.taupe,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
