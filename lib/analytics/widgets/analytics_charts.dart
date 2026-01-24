import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../customization/colors.dart';
import '../models/analytics_models.dart';

class GrowthLineChart extends StatelessWidget {
  final List<GrowthPoint> points;
  final bool isRevenue;

  const GrowthLineChart({Key? key, required this.points, this.isRevenue = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return Center(child: Text("No Data"));

    final sorted = List<GrowthPoint>.from(points)..sort((a, b) => a.date.compareTo(b.date));
    double minY = sorted.map((e) => e.value.toDouble()).reduce((a, b) => a < b ? a : b);
    double maxY = sorted.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);
    
    // Add buffer
    minY = (minY * 0.9).floorToDouble();
    maxY = (maxY * 1.1).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.textDisabled.withOpacity(0.1), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false), // Hide dates for cleaner look, or implement flexible logic
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sorted.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: sorted.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppColors.primaryLavender,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryLavender.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class AudiencePieChart extends StatelessWidget {
  final List<AudienceDemographic> data;

  const AudiencePieChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate colors
    final colors = [
      AppColors.primaryLavender,
      AppColors.secondaryTeal,
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: data.asMap().entries.map((e) {
          final index = e.key;
          final item = e.value;
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: item.percentage,
            title: '${item.percentage.round()}%',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ActivityHeatmapBar extends StatelessWidget {
  final List<ActivityHour> activity;

  const ActivityHeatmapBar({Key? key, required this.activity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: activity.map((h) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Container(
                height: h.activityLevel.toDouble(), // Simple height scaling
                decoration: BoxDecoration(
                  color: AppColors.primaryLavender.withOpacity(h.activityLevel / 100),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
