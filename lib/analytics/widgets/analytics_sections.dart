import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../customization/colors.dart';
import '../../customization/fonts.dart';
import '../models/analytics_models.dart';
import 'analytics_charts.dart';
import 'package:intl/intl.dart';

// Navigation Imports
import '../screens/expanded_post_screen.dart';
import '../../circle/petitions.dart';
import '../../circle/polls.dart';
import '../../circle/poll_detail_screen.dart'; 
import '../../hub_screens/post.dart'; // Standard Post Detail
import 'deep_analytics_widgets.dart'; // Add Deep Analytics Widgets

// --- Helper for Section Headers ---
class AnalyticsSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onMore;

  const AnalyticsSectionHeader({Key? key, required this.title, required this.icon, this.onMore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryLavender, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: primaryVeryBoldTextStyle(fontSize: 18, color: AppColors.textHigh),
              ),
            ],
          ),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Text("See All", style: secondaryTextStyle(fontSize: 12, color: AppColors.secondaryTeal)),
            ),
        ],
      ),
    );
  }
}

// --- 1. Overview Section ---
class OverviewSection extends StatelessWidget {
  final OverviewStats stats;
  final List<GrowthPoint> growth;

  const OverviewSection({Key? key, required this.stats, required this.growth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard("Followers", NumberFormat.compact().format(stats.totalFollowers), "+${stats.followersGained}", true)),
            SizedBox(width: 12),
            Expanded(child: _buildStatCard("Views", NumberFormat.compact().format(stats.totalViews), "---", true)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard("Engagement", "${stats.engagementRate.toStringAsFixed(1)}%", "Weighted Score", true)),
            SizedBox(width: 12),
            Expanded(child: _buildStatCard("Profile Visits", NumberFormat.compact().format(stats.profileVisits), "30d", true)),
          ],
        ),
        SizedBox(height: 24),
        
        // Only show chart if we have data (or at least one point)
        if (growth.isNotEmpty)
          Container(
            height: 200,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Growth Trend", style: secondaryTextStyle(fontSize: 14, color: AppColors.textMedium)),
                SizedBox(height: 16),
                Expanded(child: GrowthLineChart(points: growth)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtext, bool isPositive) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
          SizedBox(height: 8),
          Text(value, style: primaryVeryBoldTextStyle(fontSize: 20, color: AppColors.textHigh)),
          SizedBox(height: 4),
          Text(
            subtext, 
            style: secondaryTextStyle(
              fontSize: 12, 
              color: isPositive ? AppColors.secondaryTeal : AppColors.textMedium // Neutral color if not explicity pos/neg logic
            )
          ),
        ],
      ),
    );
  }
}

// --- 2. Content Section (Updated for Real Navigation) ---
class ContentSection extends StatelessWidget {
  final List<ContentPerformance> content;

  const ContentSection({Key? key, required this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: content.map((item) {
        return InkWell(
          onTap: () => _navigateToContent(context, item),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    // Handle image providers safely
                    image: (item.thumbnailUrl.isNotEmpty) 
                      ? DecorationImage(image: NetworkImage(item.thumbnailUrl), fit: BoxFit.cover)
                      : null,
                  ),
                  child: (item.thumbnailUrl.isEmpty) 
                    ? Icon(
                        item.type == 'petition' ? Feather.file_text : 
                        item.type == 'poll' ? Feather.bar_chart_2 : Feather.video, 
                        color: AppColors.textMedium, size: 20
                      ) 
                    : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: secondaryVeryBoldTextStyle(fontSize: 14, color: AppColors.textHigh), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon((item.type == 'petition') ? Feather.edit_2 : Feather.eye, size: 12, color: AppColors.textMedium),
                          SizedBox(width: 4),
                          Text(
                            "${NumberFormat.compact().format(item.views)} ${(item.type == 'petition' ? 'signatures' : item.type == 'poll' ? 'votes' : 'views')} • ${item.shares} shares • ${item.saves} saves", 
                            style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _navigateToContent(BuildContext context, ContentPerformance item) {
    if (item.type == 'post') {
      // Get userId from the original document if available
      final data = item.originalDoc?.data() as Map<String, dynamic>?;
      final userId = data?['userId'] ?? '';
      
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: item.id, 
          userId: userId,
          source: 'analytics'
        )
      ));
    } else if (item.type == 'petition') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EnhancedPetitionDetailScreen(petitionId: item.id)));
    } else if (item.type == 'poll') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PollDetailScreen(pollId: item.id)));
    }
  }
  
  String timeagoFormat(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat.MMMd().format(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

// --- 3. Audience Section ---
class AudienceSection extends StatelessWidget {
  final AudienceData data;

  const AudienceSection({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no data, show placeholder
    if (data.genderBreakdown.isEmpty && data.ageGroups.isEmpty) {
      return Container(
         padding: EdgeInsets.all(24),
         alignment: Alignment.center,
         child: Text("Not enough audience data collected yet.", style: secondaryTextStyle(color: AppColors.textDisabled)),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildChartContainer("Gender", AspectRatio(aspectRatio: 1, child: AudiencePieChart(data: data.genderBreakdown))),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildChartContainer(
                "Age", 
                Column(
                  children: data.ageGroups.map((e) => _buildSimpleBar(e.label, e.percentage)).toList(),
                )
              ),
            ),
          ],
        ),
        // Removed Activity Heatmap for now as real data is hard to query cheaply
      ],
    );
  }

  Widget _buildChartContainer(String title, Widget content) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: secondaryTextStyle(fontSize: 14, color: AppColors.textMedium)),
          SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSimpleBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(label, style: secondaryTextStyle(fontSize: 10, color: AppColors.textMedium)),
          SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white10,
              color: AppColors.primaryLavender,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. Campaigns & Advocacy ---
class CampaignSection extends StatelessWidget {
  final List<CampaignStats> campaigns;

  const CampaignSection({Key? key, required this.campaigns}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) return SizedBox.shrink();

    return Column(
      children: campaigns.map((c) {
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => EnhancedPetitionDetailScreen(petitionId: c.campaignId)
            ));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryLavender.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(c.title, style: primaryVeryBoldTextStyle(fontSize: 16, color: AppColors.textHigh), overflow: TextOverflow.ellipsis)),
                    Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(value: c.progress, color: AppColors.secondaryTeal, backgroundColor: Colors.white10, borderRadius: BorderRadius.circular(4)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${c.signatures} / ${c.goal} signatures", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- 5. Benchmarks (Keep implementation) ---
// --- 5. Benchmarks (Benchmarks implemented in dashboard) ---

// --- 6. Deep Insights Section ---
class DeepInsightsSection extends StatelessWidget {
  final DeepAnalyticsData stats;

  const DeepInsightsSection({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Traffic Sources
        if (stats.trafficSources.isNotEmpty)
          _buildInsightCard(
            "Traffic Sources", 
            Feather.activity, 
            TrafficSourcesSection(sources: stats.trafficSources)
          ),

        // Geo Impact
        if (stats.geoImpact.isNotEmpty)
          _buildInsightCard(
            "Geographic Impact", 
            Feather.map_pin, 
            GeoImpactList(data: stats.geoImpact)
          ),
          
        // Petition Funnel
        if (stats.petitionFunnel.isNotEmpty)
          _buildInsightCard(
            "Petition Conversion Funnel",
            Feather.filter,
            PetitionFunnelChart(funnel: stats.petitionFunnel)
          ),
          
        // Community
        if (stats.communityPerformance.isNotEmpty)
          _buildInsightCard(
            "Community Performance",
            Feather.users,
            CommunityPerformanceList(communities: stats.communityPerformance)
          ),
      ],
    );
  }

  Widget _buildInsightCard(String title, IconData icon, Widget content) {
    return Column(
      children: [
        AnalyticsSectionHeader(title: title, icon: icon),
        content,
        SizedBox(height: 24),
      ],
    );
  }
}
