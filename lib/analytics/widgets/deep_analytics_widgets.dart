import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../customization/colors.dart';
import '../../customization/fonts.dart';
import '../models/analytics_models.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../circle/groups.dart';

// --- Traffic Sources Widget ---
class TrafficSourcesSection extends StatelessWidget {
  final List<TrafficSourceData> sources;
  const TrafficSourcesSection({Key? key, required this.sources}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text("No traffic data yet.", style: secondaryTextStyle(color: AppColors.textMedium)),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           AspectRatio(
             aspectRatio: 1.5,
             child: PieChart(
               PieChartData(
                 sectionsSpace: 2,
                 centerSpaceRadius: 30,
                 sections: sources.asMap().entries.map((e) {
                   final index = e.key;
                   final item = e.value;
                   final color = [AppColors.primaryLavender, AppColors.secondaryTeal, Colors.blue, Colors.orange][index % 4];
                   return PieChartSectionData(
                     color: color,
                     value: item.percentage,
                     title: '${item.percentage.round()}%',
                     radius: 40,
                     titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                   );
                 }).toList(),
               ),
             ),
           ),
           SizedBox(height: 16),
           ...sources.map((s) => Padding(
             padding: const EdgeInsets.symmetric(vertical: 4.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(s.sourceName, style: secondaryTextStyle(fontSize: 12, color: AppColors.textHigh)),
                 Text("${s.visits} visits", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
               ],
             ),
           )).toList(),
        ],
      ),
    );
  }
}

// --- Geo Impact Widget ---
class GeoImpactList extends StatelessWidget {
  final List<GeoImpactData> data;
  const GeoImpactList({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Container(
       padding: EdgeInsets.all(24),
       width: double.infinity,
       alignment: Alignment.center,
       child: Text("No regional data from petitions yet.", textAlign: TextAlign.center, style: secondaryTextStyle(color: AppColors.textDisabled))
    );

    return Column(
      children: data.take(5).map((d) { // Show top 5
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 60, // Wider for full name if needed
                alignment: Alignment.centerLeft,
                child: Text(d.region.length > 8 ? d.region.substring(0, 8) + '..' : d.region, style: secondaryVeryBoldTextStyle(fontSize: 12, color: AppColors.textMedium)),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: d.percentage / 100,
                  backgroundColor: AppColors.elevation,
                  color: AppColors.secondaryTeal,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 8),
              Text("${d.percentage.round()}%", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// --- Petition Funnel Widget ---
class PetitionFunnelChart extends StatelessWidget {
  final List<PetitionFunnelData> funnel;
  const PetitionFunnelChart({Key? key, required this.funnel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (funnel.isEmpty || funnel.every((f) => f.count == 0)) {
       return Container(
         width: double.infinity,
         padding: EdgeInsets.all(24),
         alignment: Alignment.center,
         child: Text("Start a petition to see your advocacy funnel.", style: secondaryTextStyle(color: AppColors.textDisabled), textAlign: TextAlign.center),
       );
    }
    
    // Find max value for scaling width
    final maxVal = funnel.first.count.toDouble(); 

    return Column(
      children: funnel.asMap().entries.map((e) {
        final index = e.key;
        final item = e.value;
        final widthFactor = maxVal > 0 ? (item.count / maxVal) : 0.0;
        
        // Colors from funnel top to bottom
        final color = index == 0 ? AppColors.primaryLavender : 
                      index == 1 ? AppColors.secondaryTeal : 
                      Colors.orangeAccent;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.step, style: secondaryVeryBoldTextStyle(fontSize: 12, color: AppColors.textHigh)),
                    if (index > 0)
                      Text("${item.conversionRate.toStringAsFixed(1)}% conv", style: secondaryTextStyle(fontSize: 10, color: AppColors.textMedium)),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.elevation,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: widthFactor < 0.05 ? 0.05 : widthFactor, // Ensure at least small bar visible
                      child: Container(
                        height: 30,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            NumberFormat.compact().format(item.count),
                            style: secondaryVeryBoldTextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// --- Community List Widget ---
class CommunityPerformanceList extends StatelessWidget {
  final List<CommunityStats> communities;
  const CommunityPerformanceList({Key? key, required this.communities}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text("No communities found.", style: secondaryTextStyle(color: AppColors.textDisabled))
    );

    return Column(
      children: communities.map((c) {
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => GroupViewScreen(groupId: c.groupId, onJoinSuccess: null)
            ));
          },
          child: Container(
             margin: EdgeInsets.only(bottom: 8),
             padding: EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: AppColors.elevation,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: AppColors.primaryLavender.withOpacity(0.2)),
             ),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                   child: Row(
                     children: [
                       Icon(Feather.users, size: 16, color: AppColors.primaryLavender),
                       SizedBox(width: 8),
                       Expanded(child: Text(c.groupName, style: secondaryVeryBoldTextStyle(fontSize: 14, color: AppColors.textHigh), overflow: TextOverflow.ellipsis)),
                     ],
                   ),
                 ),
                 Icon(Feather.chevron_right, size: 14, color: AppColors.textDisabled),
               ],
             ),
          ),
        );
      }).toList(),
    );
  }
}
