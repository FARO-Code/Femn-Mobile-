import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../../customization/colors.dart';
import '../../customization/fonts.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics_sections.dart';
import '../../widgets/femn_background.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  @override
  _AnalyticsDashboardScreenState createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  int _selectedDays = 30; // Default view
  late Future<AnalyticsDashboardData> _dataFuture;
  final AnalyticsService _service = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _service.fetchDashboardData(_selectedDays);
    });
  }

  void _onDaysChanged(int days) {
    if (_selectedDays == days) return;
    _selectedDays = days;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses FemnBackground from main
      appBar: AppBar(
        title: Text("Creator Analytics", style: primaryVeryBoldTextStyle(fontSize: 20, color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.primaryLavender),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FemnBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _dataFuture;
          },
          color: AppColors.primaryLavender,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: FutureBuilder<AnalyticsDashboardData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error loading analytics", style: TextStyle(color: AppColors.error)));
                } else if (!snapshot.hasData) {
                  return Center(child: Text("No data available"));
                }

                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Range Selector
                    _buildTimeSelector(),
                    SizedBox(height: 24),

                    // 1. Overview
                    AnalyticsSectionHeader(title: "Overview", icon: Feather.activity),
                    OverviewSection(stats: data.overview, growth: data.followerGrowth),

                    // 2. Content Performance
                    SizedBox(height: 12),
                    AnalyticsSectionHeader(title: "Top Content", icon: Feather.video, onMore: () {}),
                    ContentSection(content: data.topContent),

                    // 3. Audience
                    AnalyticsSectionHeader(title: "Audience Insights", icon: Feather.users),
                    AudienceSection(data: data.audience),
                    
                    // 3.5 Deep Insights (Traffic, Geo, Funnel)
                    DeepInsightsSection(stats: data.deepStats),

                    // 4. Campaigns
                    if (data.campaigns.isNotEmpty) ...[
                      AnalyticsSectionHeader(title: "Advocacy Impact", icon: Feather.flag),
                      CampaignSection(campaigns: data.campaigns),
                    ],

                    // 5. Monetization
                    AnalyticsSectionHeader(title: "Earnings", icon: Feather.dollar_sign),
                    _buildMonetizationCard(data.revenue),
                    
                    // 6. Benchmarks
                    AnalyticsSectionHeader(title: "Competitive Benchmark", icon: Feather.bar_chart_2),
                    _buildBenchmarkList(data.benchmarks),

                    SizedBox(height: 48),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTimeOption("7 Days", 7),
          _buildTimeOption("30 Days", 30),
          _buildTimeOption("90 Days", 90),
        ],
      ),
    );
  }

  Widget _buildTimeOption(String label, int days) {
    bool isSelected = _selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onDaysChanged(days),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primaryLavender : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonetizationCard(RevenueData revenue) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Embers Earned", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Feather.zap, color: AppColors.accentMustard, size: 20),
                    SizedBox(width: 4),
                    Text("${revenue.totalEmbers}", style: primaryVeryBoldTextStyle(fontSize: 24, color: AppColors.textHigh)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 40, width: 1, color: Colors.white10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Content", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
                Text("${revenue.fromContent}", style: primaryVeryBoldTextStyle(fontSize: 16, color: AppColors.textHigh)),
                SizedBox(height: 4),
                Text("Partnerships", style: secondaryTextStyle(fontSize: 12, color: AppColors.textMedium)),
                Text("${revenue.fromPartnerships}", style: primaryVeryBoldTextStyle(fontSize: 16, color: AppColors.textHigh)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildPredictionCard and _buildEngagementCard

  Widget _buildBenchmarkList(List<CompetitiveBenchmark> benchmarks) {
    return Column(
      children: benchmarks.map((b) {
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.elevation,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.metricName, style: secondaryVeryBoldTextStyle(fontSize: 14, color: AppColors.textHigh)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("You: ${b.yourValue}%", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
                  Text("Avg: ${b.industryAverage}%", style: TextStyle(color: AppColors.textMedium)),
                ],
              ),
              SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: (b.yourValue / (b.topCreatorAverage * 1.2)).clamp(0.0, 1.0),
                    child: Container(height: 6, decoration: BoxDecoration(color: AppColors.primaryLavender, borderRadius: BorderRadius.circular(3))),
                  ),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.elevation,
      highlightColor: AppColors.surface,
      child: Column(
        children: List.generate(5, (index) => 
          Container(
            height: 150, 
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)
            ),
          )
        ),
      ),
    );
  }
}
