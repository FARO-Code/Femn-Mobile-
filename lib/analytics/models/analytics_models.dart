import 'package:flutter/material.dart';

// 1. Overview Dashboard
class OverviewStats {
  final int totalFollowers;
  final int followersGained; // Will be 0 if no history
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final int profileVisits; // New
  final double engagementRate; // Percentage

  OverviewStats({
    required this.totalFollowers,
    required this.followersGained,
    required this.totalViews,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.profileVisits,
    required this.engagementRate,
  });
}

class GrowthPoint {
  final DateTime date;
  final int value;

  GrowthPoint(this.date, this.value);
}

// 2. Content Analytics
class ContentPerformance {
  final String id;
  final String title;
  final String type; // 'post', 'petition', 'poll'
  final String thumbnailUrl;
  final int views; 
  final int likes;
  final int comments;
  final int shares;      // New
  final int saves;       // New
  final int linkClicks;  // New
  final DateTime postedAt;
  final dynamic originalDoc; 
  final String? source; // Feed, Profile, Search etc (Primary source if aggregated)

  ContentPerformance({
    required this.id,
    required this.title,
    required this.type,
    required this.thumbnailUrl,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.linkClicks,
    required this.postedAt,
    this.originalDoc,
    this.source,
  });
}

// 3. Audience Insights
class AudienceDemographic {
  final String label; // e.g., "18-24", "Female"
  final double percentage; // 0-100

  AudienceDemographic(this.label, this.percentage);
}

class ActivityHour {
  final int hour; // 0-23
  final int activityLevel; // 0-100 scale

  ActivityHour(this.hour, this.activityLevel);
}

class AudienceData {
  final List<AudienceDemographic> ageGroups;
  final List<AudienceDemographic> genderBreakdown;
  final List<AudienceDemographic> topLocations; 
  final List<ActivityHour> activityByHour;

  AudienceData({
    required this.ageGroups,
    required this.genderBreakdown,
    required this.topLocations,
    required this.activityByHour,
  });
}

// 4. Engagement Metrics (Simplified - removed sentiment)
class EngagementMetrics {
  final double likeToCommentRatio;
  final double responseRate;

  EngagementMetrics({
    required this.likeToCommentRatio,
    required this.responseRate,
  });
}

// 5. Campaign/Advocacy Analytics
class CampaignStats {
  final String campaignId;
  final String title;
  final int signatures;
  final int goal;
  final double progress; // 0-1

  CampaignStats({
    required this.campaignId,
    required this.title,
    required this.signatures,
    required this.goal,
    required this.progress,
  });
}

// 6. Monetization (Embers)
class RevenueData {
  final int totalEmbers;
  final int fromContent;
  final int fromPartnerships;
  final List<GrowthPoint> earnedHistory;

  RevenueData({
    required this.totalEmbers,
    required this.fromContent,
    required this.fromPartnerships,
    required this.earnedHistory,
  });
}

// 7. Competitive Analysis
class CompetitiveBenchmark {
  final String metricName; 
  final double yourValue;
  final double industryAverage;
  final double topCreatorAverage;

  CompetitiveBenchmark({
    required this.metricName,
    required this.yourValue,
    required this.industryAverage,
    required this.topCreatorAverage,
  });
}

// --- NEW DEEP ANALYTICS MODELS ---

class TrafficSourceData {
  final String sourceName; // e.g., "For You", "Profile", "Search"
  final int visits;
  final double percentage;

  TrafficSourceData(this.sourceName, this.visits, this.percentage);
}

class GeoImpactData {
  final String region;
  final int count;
  final double percentage;

  GeoImpactData(this.region, this.count, this.percentage);
}

class PetitionFunnelData {
  final String step; // "Views", "Signatures", "Shares"
  final int count;
  final double conversionRate; // % from previous step

  PetitionFunnelData(this.step, this.count, this.conversionRate);
}

class CommunityStats {
  final String groupId;
  final String groupName;
  final int engagementCount;

  CommunityStats(this.groupId, this.groupName, this.engagementCount);
}

class DeepAnalyticsData {
  final List<TrafficSourceData> trafficSources;
  final List<GeoImpactData> geoImpact; // For petitions
  final List<PetitionFunnelData> petitionFunnel;
  final List<CommunityStats> communityPerformance;

  DeepAnalyticsData({
    required this.trafficSources,
    required this.geoImpact,
    required this.petitionFunnel,
    required this.communityPerformance,
  });
}

// Singleton Container for all Dashboard Data
class AnalyticsDashboardData {
  final OverviewStats overview;
  final List<GrowthPoint> followerGrowth;
  final List<ContentPerformance> topContent;
  final AudienceData audience;
  final EngagementMetrics engagement;
  final List<CampaignStats> campaigns;
  final RevenueData revenue;
  final List<CompetitiveBenchmark> benchmarks;
  final DeepAnalyticsData deepStats; // NEW

  AnalyticsDashboardData({
    required this.overview,
    required this.followerGrowth,
    required this.topContent,
    required this.audience,
    required this.engagement,
    required this.campaigns,
    required this.revenue,
    required this.benchmarks,
    required this.deepStats,
  });
}
