import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'stats_controller.dart';

class DetailedStatsPage extends StatelessWidget {
  const DetailedStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final StatsController controller = Get.put(StatsController());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F1),
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5C3D2E)),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            '상세 통계',
            style: TextStyle(
              color: Color(0xFF5C3D2E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            onTap: (index) {
              final periods = ['이번 주', '이번 달', '이번 년'];
              controller.loadAllData(periods[index]);
            },
            labelColor: const Color(0xFF5C3D2E),
            unselectedLabelColor: AppColors.taupe,
            indicatorColor: const Color(0xFF5C3D2E),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: '이번 주'),
              Tab(text: '이번 달'),
              Tab(text: '이번 년'),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatsContent(controller, '이번 주'),
              _buildStatsContent(controller, '이번 달'),
              _buildStatsContent(controller, '이번 년'),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatsContent(StatsController controller, String period) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary Cards (Count, Distance, Time)
          _buildSummaryCards(controller, period),
          
          const SizedBox(height: 16),
          
          // 2. Daily Distance Bar Chart
          _buildBarChartSection(controller, period),
          
          const SizedBox(height: 16),
          
          // 4. Streak Card
          _buildStreakCard(controller),
          
          const SizedBox(height: 24),
          
          // 5. Dog Stats breakdown
          if (controller.dogStats.isNotEmpty) ...[
            const Text(
              '강아지별 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C3D2E),
              ),
            ),
            const SizedBox(height: 12),
            ...controller.dogStats.entries.map((entry) => _dogStatRow(entry.key, entry.value)),
          ],

          if (controller.walkCount.value == 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  '$period에 아직 산책 기록이 없어요 🐾',
                  style: TextStyle(fontSize: 15, color: AppColors.taupe),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(StatsController controller, String period) {
    final prevPeriodLabel = period == '이번 주' ? '지난 주' : (period == '이번 달' ? '지난 달' : '작년');
    
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              label: '산책 횟수',
              value: '${controller.walkCount.value}회',
              change: controller.countChange.value,
              unit: '회',
              prevPeriodLabel: prevPeriodLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              label: '총 거리',
              value: '${controller.totalDistance.value.toStringAsFixed(1)}km',
              change: controller.distanceChange.value,
              unit: 'km',
              prevPeriodLabel: prevPeriodLabel,
              isDouble: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              label: '총 시간',
              value: _formatMinutes(controller.totalDurationMinutes.value),
              change: controller.durationChange.value,
              unit: '분',
              prevPeriodLabel: prevPeriodLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required dynamic change,
    required String unit,
    required String prevPeriodLabel,
    bool isDouble = false,
  }) {
    Color changeColor = Colors.grey;
    String arrow = '—';
    String changeText = ' 동일';

    if (isDouble) {
      if (change > 0.05) {
        changeColor = Colors.green;
        arrow = '▲';
        changeText = ' ${change.toStringAsFixed(1)}$unit 증가';
      } else if (change < -0.05) {
        changeColor = Colors.red;
        arrow = '▼';
        changeText = ' ${change.abs().toStringAsFixed(1)}$unit 감소';
      }
    } else {
      if (change > 0) {
        changeColor = Colors.green;
        arrow = '▲';
        changeText = ' $change$unit 증가';
      } else if (change < 0) {
        changeColor = Colors.red;
        arrow = '▼';
        changeText = ' ${change.abs()}$unit 감소';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C3D2E).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.taupe, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C3D2E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(arrow, style: TextStyle(fontSize: 10, color: changeColor)),
                Text(
                  changeText,
                  style: TextStyle(fontSize: 10, color: changeColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            prevPeriodLabel,
            style: TextStyle(fontSize: 9, color: AppColors.taupe.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartSection(StatsController controller, String period) {
    final chartTitle = period == '이번 주' ? '요일별 산책 거리'
        : period == '이번 달' ? '일별 산책 거리'
        : '월별 산책 거리';

    final maxDistance = controller.dailyData.fold(0.0, (max, e) => e.distance > max ? e.distance : max);

    final rawMaxY = maxDistance < 0.5
        ? 0.5
        : ((maxDistance / 0.5).ceil() * 0.5);
    final maxY = rawMaxY + 0.25; // 0.001 대신 0.25를 더해서 다음 0.5 구간 중간까지 올림

    // 보조선 간격: rawMaxY 1.0 이하면 0.5, 초과면 1.0
    final interval = rawMaxY <= 1.0 ? 0.5 : 1.0;

    return Listener(
      onPointerDown: (event) {
        controller.isDaySelected.value = false;
        controller.selectedDayIndex.value = -1;
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A200B).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chartTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5C3D2E)),
            ),
            const SizedBox(height: 3),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                const leftReserved = 36.0;
                final barAreaWidth = chartWidth - leftReserved;
                const double tooltipAreaHeight = 62.0;
                const double chartHeight = 180.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 말풍선 전용 영역
                    SizedBox(
                      height: tooltipAreaHeight,
                      child: Obx(() {
                        final idx = controller.selectedDayIndex.value;
                        if (!controller.isDaySelected.value || idx < 0 || idx >= controller.dailyData.length) {
                          return const SizedBox.shrink();
                        }
                        final data = controller.dailyData[idx];
                        const tooltipWidth = 100.0;
                        final barCenterX = leftReserved + (idx + 0.5) / controller.dailyData.length * barAreaWidth;
                        double tooltipLeft = barCenterX - tooltipWidth / 2;
                        if (tooltipLeft + tooltipWidth > chartWidth) tooltipLeft = chartWidth - tooltipWidth;
                        if (tooltipLeft < leftReserved) tooltipLeft = leftReserved;

                        String dateLabel;
                        if (period == '이번 주') {
                          dateLabel = ['일','월','화','수','목','금','토'][data.date.weekday % 7];
                        } else if (period == '이번 달') {
                          dateLabel = '${data.date.month}월 ${data.date.day}일';
                        } else {
                          dateLabel = '${data.date.month}월';
                        }
                        final distanceLabel = data.distance >= 1.0
                            ? '${data.distance.toStringAsFixed(2)}km'
                            : '${(data.distance * 1000).toInt()}m';

                        return Stack(
                          children: [
                            Positioned(
                              left: tooltipLeft,
                              top: 6,
                              width: tooltipWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFC4A882),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      distanceLabel,
                                      style: const TextStyle(
                                        color: Color(0xFF5C3D2E),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: const Color(0xFF5C3D2E).withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    // 차트 영역 (세로선 포함)
                    SizedBox(
                      height: chartHeight,
                      child: Stack(
                        children: [
                          // 1. 세로선 (막대 뒤에 그려짐)
                          Obx(() {
                            final idx = controller.selectedDayIndex.value;
                            if (!controller.isDaySelected.value || idx < 0 || idx >= controller.dailyData.length) {
                              return const SizedBox.shrink();
                            }
                            final barCenterX = leftReserved + (idx + 0.5) / controller.dailyData.length * barAreaWidth;
                            return Positioned(
                              left: barCenterX - 0.5,
                              top: 0,
                              height: chartHeight - 24,
                              width: 1,
                              child: Container(
                                color: const Color(0xFFC4A882).withOpacity(0.4),
                              ),
                            );
                          }),
                          // 2. 차트 (세로선 위에 그려짐)
                          GestureDetector(
                            onTapDown: (details) {},
                            behavior: HitTestBehavior.opaque,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                minY: 0,
                                maxY: maxY,
                                baselineY: 0,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  handleBuiltInTouches: false,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) => Colors.transparent,
                                    tooltipPadding: EdgeInsets.zero,
                                    getTooltipItem: (_, __, ___, ____) => null,
                                  ),
                                  touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                                    if (event is FlPanEndEvent || event is FlTapUpEvent || event is FlLongPressEnd) {
                                      return;
                                    }
                                    if (event is FlPointerExitEvent) {
                                      controller.isDaySelected.value = false;
                                      controller.selectedDayIndex.value = -1;
                                      return;
                                    }
                                    if (response?.spot != null) {
                                      controller.selectedDayIndex.value = response!.spot!.touchedBarGroupIndex;
                                      controller.isDaySelected.value = true;
                                    }
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= controller.dailyData.length) return const SizedBox();
                                        final date = controller.dailyData[index].date;
                                        String text = '';
                                        if (period == '이번 주') {
                                          text = ['일','월','화','수','목','금','토'][date.weekday % 7];
                                        } else if (period == '이번 달') {
                                          if (index % 5 == 0) text = '${date.day}';
                                        } else {
                                          text = '${date.month}월';
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(text, style: TextStyle(color: AppColors.taupe, fontSize: 10)),
                                        );
                                      },
                                      reservedSize: 24,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: interval,
                                      reservedSize: 36,
                                      getTitlesWidget: (value, meta) {
                                        // fl_chart가 넘기는 value를 0.5 단위로 반올림해서 오차 제거
                                        final snapped = (value / 0.5).round() * 0.5;
                                        if (snapped <= 0) return const SizedBox();
                                        if (snapped > rawMaxY + 0.01) return const SizedBox();

                                        // 1km 미만 구간: 0.5, 1.0 모두 표시
                                        // 1km 이상 구간: 정수만 표시
                                        final isWhole = snapped == snapped.truncate();
                                        final isHalf = !isWhole;

                                        if (rawMaxY <= 1.0) {
                                          if (!isWhole && !isHalf) return const SizedBox();
                                        } else {
                                          if (!isWhole) return const SizedBox();
                                        }

                                        final label = snapped >= 1.0
                                            ? '${snapped.toInt()}km'
                                            : '${(snapped * 1000).toInt()}m';

                                        return SideTitleWidget(
                                          meta: meta,
                                          space: 4,
                                          child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.taupe)),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: interval,
                                    getDrawingHorizontalLine: (value) {
                                      if (value == 0) return const FlLine(color: Colors.transparent);
                                      if (value > rawMaxY + 0.01) return const FlLine(color: Colors.transparent);
                                      return FlLine(
                                        color: const Color(0xFF5C3D2E).withOpacity(0.08),
                                        strokeWidth: 1,
                                        dashArray: [4, 4],
                                      );
                                    },
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(controller.dailyData.length, (i) {
                                  final data = controller.dailyData[i];
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: data.distance > 0 ? data.distance.clamp(maxY * 0.04, double.infinity) : 0,
                                        color: const Color(0xFF5C3D2E),
                                        width: period == '이번 달' ? 4 : 14,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(StatsController controller) {
    final current = controller.currentStreak.value;
    final longest = controller.longestStreak.value;
    final isStark = current >= 7;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isStark ? const Color(0xFFFDF7E2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isStark ? Border.all(color: const Color(0xFFD4AF37), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A200B).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (current > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  '$current일째 매일 산책 중!',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: isStark ? const Color(0xFFB8860B) : const Color(0xFF5C3D2E)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '최고 기록: $longest일',
              style: TextStyle(fontSize: 14, color: AppColors.taupe),
            ),
          ] else ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🐾', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text(
                  '오늘 산책을 시작해보세요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5C3D2E)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dogStatRow(String name, DogStat stat) {
    final imageUrl = stat.profileImageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A200B).withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF5C3D2E).withOpacity(0.1),
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? const Icon(Icons.pets, size: 18, color: Color(0xFF5C3D2E))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5C3D2E)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stat.walkCount}회',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C3D2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatMinutes(stat.totalMinutes)} • ${stat.totalDistance.toStringAsFixed(1)}km',
                style: TextStyle(fontSize: 12, color: AppColors.taupe),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}시간 ${m}분' : '${h}시간';
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

