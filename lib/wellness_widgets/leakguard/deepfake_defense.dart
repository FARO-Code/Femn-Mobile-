import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

class DeepfakeDefenseScreen extends StatefulWidget {
  @override
  _DeepfakeDefenseScreenState createState() => _DeepfakeDefenseScreenState();
}

class _DeepfakeDefenseScreenState extends State<DeepfakeDefenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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
        title: Text("Deepfake Defense", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLavender,
          labelColor: AppColors.primaryLavender,
          unselectedLabelColor: AppColors.textDisabled,
          tabs: [
            Tab(text: "STATEMENT GENERATOR"),
            Tab(text: "STRATEGY GUIDE"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneratorTab(),
          _buildStrategyTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: THE DENIAL GENERATOR
  // ==========================================
  Widget _buildGeneratorTab() {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        _buildInfoCard(
          "Plausible Deniability",
          "In the age of AI, 'Truth' is debatable. You do not have to admit anything. Use these scripts to cast doubt immediately.",
          Feather.shield,
          Colors.blueAccent,
        ),
        SizedBox(height: 24),
        Text("SELECT AUDIENCE", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        SizedBox(height: 12),
        
        _buildScriptCard(
          title: "Public Social Media (The 'Outraged' Post)",
          usageContext: "Use this on Instagram Stories, Twitter, or WhatsApp Status immediately after a leak threat.",
          script: "I have been made aware of AI-generated deepfake images circulating with my likeness. This is a targeted harassment campaign using illegal technology. \n\nI am working with the authorities to trace the source. If you receive these fake images, do not engage. Blocking and reporting is the only help I need. #Deepfake #CyberSafety",
          tags: ["Public", "Formal", "Instagram"],
        ),

        _buildScriptCard(
          title: "Family & Parents (The 'Simple' Explanation)",
          usageContext: "Use this for older relatives who don't understand tech.",
          script: "Mum/Dad, someone hacked my account and is using AI (Artificial Intelligence) to edit my face onto naked bodies. It’s a common scam happening to thousands of people right now. It is not real, but it is scary. I am handling it with the police.",
          tags: ["Family", "Simple", "WhatsApp"],
        ),

        _buildScriptCard(
          title: "Work / Employer (The 'HR' Defense)",
          usageContext: "Use this if the extortionist threatens to email your boss.",
          script: "I am writing to formally notify you that I am currently the victim of a cyber-harassment attack involving 'Deepfake' technology. Criminals are generating synthetic explicit imagery to extort me.\n\nThis is a police matter (Case Ref: PENDING). I wanted to alert you in case they attempt to contact the company. These images are fabricated and malicious.",
          tags: ["Professional", "HR", "Email"],
        ),

        _buildScriptCard(
          title: "The 'Gaslight' Response (To Friends)",
          usageContext: "Use this in group chats if someone asks.",
          script: "Lol have you seen the AI edits? They didn't even get my tattoo right. It's crazy what apps can do these days. Ignore that trash.",
          tags: ["Casual", "Dismissive"],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: STRATEGY & EDUCATION
  // ==========================================
  Widget _buildStrategyTab() {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text("HOW TO SOW DOUBT", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        SizedBox(height: 12),
        _buildStrategyItem(
          "1. Point out 'Glitchy' Details",
          "Even if the photo is real, AI often struggles with hands, teeth, and background text. Tell people: 'Look at the fingers, look at the shadow. It's clearly AI.' Most people won't look close enough to verify, but they will believe the doubt.",
        ),
        _buildStrategyItem(
          "2. The 'Hacked' Narrative",
          "It is easier for people to believe you were hacked than to believe you are a victim of revenge porn. Stick to the story: 'My iCloud/Snapchat was breached and they are using AI tools.'",
        ),
        _buildStrategyItem(
          "3. Anger, Not Shame",
          "If you act ashamed, people assume it's real. If you act angry and violated by 'technology,' people see you as a victim of a crime. Shift the narrative from 'I took a nude' to 'Criminals are stealing my face.'",
        ),
        
        SizedBox(height: 30),
        Text("EXPLAINING AI TO BOOMERS", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.elevation),
          ),
          child: Column(
            children: [
              Text(
                "\"It's like Photoshop, but automatic.\"",
                style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                "Older generations trust photos. You must explain that apps now exist where you upload one selfie, and it generates a nude body that matches your skin tone perfectly. Show them a news article about 'Deepfake Scams' if necessary.",
                style: TextStyle(color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildInfoCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text(desc, style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // FIX: Renamed 'context' to 'usageContext' to avoid conflict
  Widget _buildScriptCard({required String title, required String usageContext, required String script, required List<String> tags}) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text(usageContext, style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: tags.map((tag) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLavender.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag, style: TextStyle(color: AppColors.primaryLavender, fontSize: 10, fontWeight: FontWeight.bold)),
                  )).toList(),
                )
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.elevation),
          
          // Script Body
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.black12,
            child: Text(
              script,
              style: GoogleFonts.robotoMono(
                color: AppColors.textHigh,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: Icon(Feather.copy, size: 16, color: AppColors.textMedium),
                  label: Text("Copy Text", style: TextStyle(color: AppColors.textMedium)),
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: script));
                    // 'context' now refers to the State's BuildContext, which works
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Statement copied!")));
                  },
                ),
              ),
              Container(width: 1, height: 48, color: AppColors.elevation),
              Expanded(
                child: TextButton.icon(
                  icon: Icon(Feather.share, size: 16, color: AppColors.primaryLavender),
                  label: Text("Share", style: TextStyle(color: AppColors.primaryLavender)),
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    Share.share(script);
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStrategyItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Feather.check_circle, color: Colors.greenAccent, size: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 6),
                Text(desc, style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}