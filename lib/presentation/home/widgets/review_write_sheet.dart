import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class ReviewWriteSheet extends StatefulWidget {
  final Future<bool> Function(int rating, String content) onSubmit;
  final int initialRating;
  final String initialContent;

  const ReviewWriteSheet({
    super.key, 
    required this.onSubmit,
    this.initialRating = 0,
    this.initialContent = '',
  });

  @override
  State<ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<ReviewWriteSheet> {
  late int _rating;
  late final TextEditingController _contentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _contentController = TextEditingController(text: widget.initialContent);
    // 내용 변경 시 버튼 상태 업데이트
    _contentController.addListener(() => setState(() {}));
  }

  void _submit() async {
    final content = _contentController.text.trim();
    if (_rating == 0) {
      _showError('별점을 선택해주세요.');
      return;
    }
    if (content.isEmpty) {
      _showError('후기 내용을 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await widget.onSubmit(_rating, content);
    
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      if (success) {
        Navigator.pop(context); // Close the sheet on success
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 버튼 활성화 조건: 별점 1개 이상 + 내용 1자 이상
    final bool isValid = _rating > 0 && _contentController.text.trim().isNotEmpty;

    return Padding(
      // Add bottom padding for keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '후기 작성',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Star Rating Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starIndex;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: starIndex <= _rating ? Colors.amber : AppColors.taupe,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Text Field
          TextField(
            controller: _contentController,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: '장소에 대한 후기를 남겨주세요 (최소 1자 이상)',
              filled: true,
              fillColor: AppColors.sand.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          ElevatedButton(
            onPressed: (_isSubmitting || !isValid) ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isValid ? AppColors.deepBrown : AppColors.sand,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : Text(
                    '등록하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isValid ? AppColors.white : AppColors.taupe,
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
