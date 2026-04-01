import 'package:flutter/material.dart';

class PawLoadingIndicator extends StatefulWidget {
  final double size;
  const PawLoadingIndicator({super.key, this.size = 72});

  @override
  State<PawLoadingIndicator> createState() => _PawLoadingIndicatorState();
}

class _PawLoadingIndicatorState extends State<PawLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    const Color buttonColor = Color(0xFF5C3D2E); // AppColors.deepBrown
    const Color bgColor = Color(0xFFF5F0EB);    // Light beige background

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: buttonColor, width: 2),
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // 1. 배경 (베이지)
                Container(
                  width: size,
                  height: size,
                  color: bgColor,
                ),
                // 2. 밑에서부터 차오르는 deepBrown
                // Positioned with height based on controller value
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: size * _controller.value,
                  child: Container(color: buttonColor),
                ),
                // 3. 발바닥 아이콘 (항상 중앙 위에)
                Center(
                  child: Icon(
                    Icons.pets,
                    size: size * 0.65,
                    color: bgColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
