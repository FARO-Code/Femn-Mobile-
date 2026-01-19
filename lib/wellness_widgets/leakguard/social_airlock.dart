import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart'; // Ensure matches your project
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher: ^6.1.11 to pubspec.yaml

// ==========================================
// DATA MODEL
// ==========================================
enum RiskLevel { easy, medium, private }

class AirlockApp {
  final String name;
  final IconData icon;
  final Color brandColor;
  final RiskLevel riskLevel;
  final String description;
  final List<String> steps;
  final String? deepLink; // Optional: "fb://settings" etc.

  AirlockApp({
    required this.name,
    required this.icon,
    required this.brandColor,
    required this.riskLevel,
    required this.description,
    required this.steps,
    this.deepLink,
  });
}

// ==========================================
// MAIN SCREEN
// ==========================================
class SocialAirlockScreen extends StatelessWidget {
  
  // 🟢 GROUP 1: EASY FIX
  final List<AirlockApp> _easyFixApps = [
    AirlockApp(
      name: "Facebook",
      icon: FontAwesome.facebook,
      brandColor: Color(0xFF1877F2),
      riskLevel: RiskLevel.easy,
      description: "Facebook is the worst offender for public friend lists, but offers the best controls to fix it.",
      steps: [
        "Go to **Settings & Privacy > Settings**.",
        "Scroll to Audience and Visibility, tap **How people find and contact you**.",
        "Find **Who can see your friends list?**",
        "Change it to **Only Me**.",
        "Note: Mutual friends remain visible."
      ],
    ),
    AirlockApp(
      name: "TikTok",
      icon: FontAwesome.music, // Proxy for TikTok
      brandColor: Colors.black,
      riskLevel: RiskLevel.easy,
      description: "Hide your following list so people can’t see which creators or friends you are watching.",
      steps: [
        "Go to Profile > **Menu (≡)**.",
        "Tap **Settings and privacy > Privacy**.",
        "Tap **Following list**.",
        "Change it to **Only me**."
      ],
    ),
    AirlockApp(
      name: "LinkedIn",
      icon: FontAwesome.linkedin,
      brandColor: Color(0xFF0077B5),
      riskLevel: RiskLevel.easy,
      description: "Competitors and nosey coworkers often look here to see who you know.",
      steps: [
        "Tap profile pic > **Settings & Privacy**.",
        "Tap **Visibility** on the left menu.",
        "Find **Connections**.",
        "Toggle **Connection visibility** to **Off**."
      ],
    ),
    AirlockApp(
      name: "YouTube",
      icon: FontAwesome.youtube,
      brandColor: Color(0xFFFF0000),
      riskLevel: RiskLevel.easy,
      description: "Hide your subscriptions so people can't profile you based on channels you watch.",
      steps: [
        "Go to **Settings > Privacy**.",
        "Toggle **On** for **'Keep all my subscriptions private'**."
      ],
    ),
  ];

  // 🟡 GROUP 2: ALL OR NOTHING
  final List<AirlockApp> _hardFixApps = [
    AirlockApp(
      name: "Instagram",
      icon: FontAwesome.instagram,
      brandColor: Color(0xFFE1306C),
      riskLevel: RiskLevel.medium,
      description: "Instagram does not let you hide 'Following' unless you go Private.",
      steps: [
        "**Option A (Recommended):** Go to Settings > Privacy > **Private Account**.",
        "**Option B (Public):** You must manually block specific people. They cannot see your list if blocked."
      ],
    ),
    AirlockApp(
      name: "Twitter (X)",
      icon: FontAwesome.twitter,
      brandColor: Color(0xFF1DA1F2),
      riskLevel: RiskLevel.medium,
      description: "Like Instagram, you cannot hide who you follow if your tweets are public.",
      steps: [
        "Go to Settings & Support > Settings and privacy.",
        "Tap **Privacy and safety > Audience and tagging**.",
        "Check **Protect your posts**."
      ],
    ),
    AirlockApp(
      name: "Threads",
      icon: FontAwesome.at,
      brandColor: Colors.black,
      riskLevel: RiskLevel.medium,
      description: "Since it is tied to Instagram, it follows the same logic.",
      steps: [
        "Go to Privacy settings.",
        "Switch to **Private Profile**."
      ],
    ),
  ];

  // 🔵 GROUP 3: INHERENTLY PRIVATE
  final List<AirlockApp> _privateApps = [
    AirlockApp(
      name: "Snapchat",
      icon: FontAwesome.snapchat_ghost,
      brandColor: Color(0xFFFFFC00),
      riskLevel: RiskLevel.private,
      description: "Ensure you aren't visible in 'Quick Add' recommendations.",
      steps: [
        "Go to **Settings > Privacy Controls**.",
        "Find **See Me in Quick Add**.",
        "**Uncheck** it."
      ],
    ),
    AirlockApp(
      name: "Reddit",
      icon: FontAwesome.reddit,
      brandColor: Color(0xFFFF4500),
      riskLevel: RiskLevel.private,
      description: "Prevent people from following your username and tracking your posts.",
      steps: [
        "Go to **User Settings > Profile**.",
        "Toggle Off **Show active communities**.",
        "Toggle Off **Allow people to follow you**."
      ],
    ),
    AirlockApp(
      name: "Discord",
      icon: MaterialCommunityIcons.discord,
      brandColor: Color(0xFF5865F2),
      riskLevel: RiskLevel.private,
      description: "Friend lists are private by default. Only 'Mutual Friends' are visible.",
      steps: [
        "Your list is already safe.",
        "Check **User Settings > Privacy & Safety** to restrict DMs from server members."
      ],
    ),
    AirlockApp(
      name: "Telegram",
      icon: FontAwesome.telegram,
      brandColor: Color(0xFF0088CC),
      riskLevel: RiskLevel.private,
      description: "Hide your phone number so strangers can't find your profile.",
      steps: [
        "Go to **Settings > Privacy and Security**.",
        "Tap **Phone Number**.",
        "Set 'Who can see my phone number?' to **Nobody**."
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Social Airlock",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 30),
            
            _buildSectionHeader("THE 'EASY FIX' GROUP", Colors.greenAccent, "Public profile, hidden friends."),
            _buildBentoGrid(context, _easyFixApps),
            SizedBox(height: 30),

            _buildSectionHeader("THE 'ALL OR NOTHING' GROUP", Colors.orangeAccent, "Must be Private to hide friends."),
            _buildBentoGrid(context, _hardFixApps),
            SizedBox(height: 30),

            _buildSectionHeader("INHERENTLY PRIVATE", Colors.blueAccent, "Check these just in case."),
            _buildBentoGrid(context, _privateApps),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLavender.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLavender.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Feather.lock, color: AppColors.primaryLavender, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lock Your Doors",
                  style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  "Extortionists use your friend lists to find leverage. Hide them now.",
                  style: TextStyle(color: AppColors.textMedium, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, List<AirlockApp> apps) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1, // Slightly wider than square
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        return _buildAppCard(context, apps[index]);
      },
    );
  }

  Widget _buildAppCard(BuildContext context, AirlockApp app) {
    return GestureDetector(
      onTap: () => _showAppGuide(context, app),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          border: Border.all(color: AppColors.elevation),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: app.brandColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(app.icon, color: app.brandColor, size: 30),
            ),
            SizedBox(height: 12),
            Text(
              app.name,
              style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              "Tap to secure",
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppGuide(BuildContext context, AirlockApp app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, color: AppColors.textDisabled)),
            SizedBox(height: 24),
            
            // Header
            Row(
              children: [
                Icon(app.icon, color: app.brandColor, size: 32),
                SizedBox(width: 16),
                Text(app.name, style: TextStyle(color: AppColors.textHigh, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 24),

            // Description
            Text("THE REALITY", style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 8),
            Text(
              app.description,
              style: TextStyle(color: AppColors.textHigh, fontSize: 14, height: 1.5),
            ),
            
            SizedBox(height: 24),

            // Steps
            Text("THE FIX", style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: app.steps.length,
                separatorBuilder: (_,__) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24, height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLavender.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text("${index + 1}", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app.steps[index].replaceAll('**', ''), // Simple markdown strip
                          style: TextStyle(color: AppColors.textHigh, fontSize: 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Launch Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: app.brandColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                   // In a real app, use url_launcher to open the specific app
                   Navigator.pop(context);
                },
                child: Text("Open ${app.name}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}