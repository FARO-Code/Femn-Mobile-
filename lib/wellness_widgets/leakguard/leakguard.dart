import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for opening links/calls
import 'package:femn/customization/colors.dart'; 
import 'package:femn/wellness_widgets/leakguard/negotiation_playbook.dart';
import 'package:femn/wellness_widgets/leakguard/negotiation_data.dart';
import 'package:femn/wellness_widgets/leakguard/fake_payment_generator.dart';
import 'package:femn/wellness_widgets/leakguard/evidence_locker.dart';
import 'package:femn/wellness_widgets/leakguard/social_airlock.dart';
import 'cease_desist_generator.dart';
import 'deepfake_defense.dart';

class LeakGuardScreen extends StatelessWidget {
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
          "Leak Guard",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Feather.info, color: AppColors.textMedium),
            onPressed: () {
              // Info Dialog Logic
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    padding: EdgeInsets.all(24),
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Feather.shield, color: AppColors.primaryLavender),
                            SizedBox(width: 10),
                            Text("About LeakGuard", style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("WHAT IS SEXTORTION?", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text("Sextortion is a crime where someone threatens to share your intimate images or videos unless you pay money or do what they say. It relies on fear and panic.", style: TextStyle(color: AppColors.textMedium, height: 1.5)),
                                SizedBox(height: 24),
                                Text("HOW WE PROTECT YOU", style: TextStyle(color: AppColors.primaryLavender, fontSize: 12, fontWeight: FontWeight.bold)),
                                SizedBox(height: 16),
                                _buildInfoItem("Panic Button", "Instantly lock down your social media accounts to hide your friends list from the attacker."),
                                _buildInfoItem("Negotiation Playbook", "Psychological scripts to stall the attacker and buy you time without paying."),
                                _buildInfoItem("Fake Payment", "Generate a realistic 'Pending' transaction receipt to fool them into waiting."),
                                _buildInfoItem("Evidence Locker", "Securely store proofs (screenshots/threats) in an encrypted vault hidden from your gallery."),
                                _buildInfoItem("Social Airlock", "Step-by-step guides to harden your privacy settings on Facebook, Instagram, and LinkedIn."),
                                _buildInfoItem("Cease & Desist", "Generate a formal legal document citing criminal codes to scare the attacker."),
                                _buildInfoItem("Deepfake Defense", "Statements to deny the authenticity of leaks by claiming they are AI-generated."),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLavender),
                            onPressed: () => Navigator.pop(context),
                            child: Text("Understood", style: TextStyle(color: Colors.white)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.elevation),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLavender.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Feather.shield, color: AppColors.primaryLavender, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Anti-Sextortion Defense",
                          style: TextStyle(
                            color: AppColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Secure your digital footprint and get help immediately.",
                          style: TextStyle(color: AppColors.textMedium, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            SizedBox(height: 24),

            // Scrollable Features List
            Expanded(
              child: ListView(
                physics: BouncingScrollPhysics(),
                children: [
                  
                  // PHASE 2: EMERGENCY (Top Priority)
                  Text(
                    "CRITICAL RESPONSE",
                    style: TextStyle(
                      color: Colors.redAccent, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      letterSpacing: 1.2
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildPanicButton(context),
                  SizedBox(height: 24),

                  // PHASE 2: TACTICAL TOOLS (During)
                  Text(
                    "TACTICAL TOOLS",
                    style: TextStyle(
                      color: AppColors.textMedium, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      letterSpacing: 1.2
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildFeatureTile(
                    context,
                    title: "Negotiation Playbook",
                    subtitle: "Scripts to stall and de-escalate.",
                    icon: Feather.message_square,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NegotiationPlaybookScreen()),
                      );
                    },
                  ),
                  _buildFeatureTile(
                    context,
                    title: "Fake Payment Generator",
                    subtitle: "Create a decoy receipt to buy time.",
                    icon: Feather.credit_card,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => FakePaymentForm()),
                      );
                    },
                  ),
                  _buildFeatureTile(
                    context,
                    title: "Evidence Locker",
                    subtitle: "Securely store proofs before deleting.",
                    icon: Feather.hard_drive,
                    color: Colors.tealAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EvidenceLockerScreen()),
                      );
                    },
                  ),

                  SizedBox(height: 24),

                  // PHASE 1 & 3: PREVENTION & LEGAL (Before/After)
                  Text(
                    "PREVENTION & LEGAL",
                    style: TextStyle(
                      color: AppColors.textMedium, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      letterSpacing: 1.2
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildFeatureTile(
                    context,
                    title: "Social Airlock",
                    subtitle: "Hide friend lists & lock profiles.",
                    icon: Feather.lock,
                    color: AppColors.primaryLavender,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SocialAirlockScreen()),
                      );
                    },
                  ),
                  _buildFeatureTile(
                    context,
                    title: "Cease & Desist",
                    subtitle: "Generate formal legal warnings.",
                    icon: Feather.file_text,
                    color: AppColors.primaryLavender,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CeaseDesistScreen()),
                      );
                    },
                  ),
                  _buildFeatureTile(
                    context,
                    title: "Deepfake Defense",
                    subtitle: "Plausible deniability strategy.",
                    icon: Feather.cpu,
                    color: AppColors.primaryLavender,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DeepfakeDefenseScreen()),
                      );
                    },
                  ),
                  
                  SizedBox(height: 24),

                  // ---------------------------------------------
                  // NEW SECTION: WHO TO CONTACT
                  // ---------------------------------------------
                  Text(
                    "IMMEDIATE HELP & REPORTING",
                    style: TextStyle(
                      color: Colors.greenAccent, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      letterSpacing: 1.2
                    ),
                  ),
                  SizedBox(height: 10),

                  // --- NIGERIA SUPPORT ---
                  Text("Nigeria Support", style: TextStyle(color: AppColors.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  
                  _buildContactCard(
                    context,
                    title: "NAPTIP",
                    desc: "Agency for Prohibition of Trafficking in Persons. Handles blackmail & violence cases.",
                    actions: [
                      _ContactAction(icon: Feather.phone, label: "627 (Toll-Free)", value: "tel:627"),
                      _ContactAction(icon: Feather.mail, label: "info@naptip.gov.ng", value: "mailto:info@naptip.gov.ng"),
                      _ContactAction(icon: Feather.globe, label: "naptip.gov.ng", value: "https://naptip.gov.ng"),
                    ]
                  ),
                  _buildContactCard(
                    context,
                    title: "NPF-NCCC",
                    desc: "Nigeria Police Cybercrime Centre. Report cyberstalking & sextortion.",
                    actions: [
                      _ContactAction(icon: Feather.globe, label: "Report Portal (incb.police.gov.ng)", value: "https://incb.police.gov.ng"),
                      _ContactAction(icon: Feather.mail, label: "police@nccc.gov.ng", value: "mailto:police@nccc.gov.ng"),
                    ]
                  ),
                  _buildContactCard(
                    context,
                    title: "WARIF",
                    desc: "Women at Risk International Foundation. Confidential counseling & support.",
                    actions: [
                      _ContactAction(icon: Feather.phone, label: "0800 927 43472", value: "tel:080092743472"),
                      _ContactAction(icon: Feather.message_circle, label: "WhatsApp: 0907 819 0505", value: "https://wa.me/2349078190505"),
                    ]
                  ),

                  SizedBox(height: 16),

                  // --- GLOBAL DEFENSE ---
                  Text("Global & Technical Defense", style: TextStyle(color: AppColors.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),

                  _buildContactCard(
                    context,
                    title: "StopNCII.org",
                    desc: "Create a digital hash of your images to block them from uploading to FB, Insta, TikTok & OnlyFans.",
                    actions: [
                      _ContactAction(icon: Feather.shield, label: "Open StopNCII.org", value: "https://stopncii.org"),
                    ]
                  ),
                  _buildContactCard(
                    context,
                    title: "Take It Down (For Minors)",
                    desc: "Operated by NCMEC. Removes images of anyone under 18 from the internet.",
                    actions: [
                      _ContactAction(icon: Feather.user_minus, label: "Open TakeItDown", value: "https://takeitdown.ncmec.org"),
                    ]
                  ),
                  _buildContactCard(
                    context,
                    title: "FBI / IC3",
                    desc: "Internet Crime Complaint Center. Use if perpetrator is international/US-based.",
                    actions: [
                      _ContactAction(icon: Feather.flag, label: "File Complaint (ic3.gov)", value: "https://ic3.gov"),
                    ]
                  ),

                  // Bottom Padding
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Feather.check_circle, size: 16, color: AppColors.textDisabled),
          SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4, fontFamily: 'Roboto'),
                children: [
                  TextSpan(text: "$title: ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Contact Card for Help Section
  Widget _buildContactCard(BuildContext context, {required String title, required String desc, required List<_ContactAction> actions}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.elevation),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 4),
          Text(desc, style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
          SizedBox(height: 12),
          Column(
            children: actions.map((action) {
              return InkWell(
                onTap: () async {
                  final Uri uri = Uri.parse(action.value);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not launch ${action.label}")));
                  }
                },
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: action.value.replaceAll(RegExp(r'(tel:|mailto:|https:)'), '')));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Copied ${action.label} to clipboard"),
                    backgroundColor: AppColors.primaryLavender,
                    duration: Duration(seconds: 1),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Icon(action.icon, size: 14, color: AppColors.primaryLavender),
                      SizedBox(width: 8),
                      Text(action.label, style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.w600, fontSize: 12)),
                      Spacer(),
                      Icon(Feather.copy, size: 12, color: AppColors.textDisabled),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  // WIDGET: The Big Red Panic Button
  Widget _buildPanicButton(BuildContext context) {
    return SocialLockdownButton(
      onTap: () {
        // Trigger your actual logic here
        print("Panic Protocol Started");
      },
    );
  }

  // WIDGET: Standard Feature Tile
  Widget _buildFeatureTile(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elevation),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper Class for Contact Actions
class _ContactAction {
  final IconData icon;
  final String label;
  final String value; // tel:..., mailto:..., or https:...

  _ContactAction({required this.icon, required this.label, required this.value});
}

class SocialLockdownButton extends StatefulWidget {
  final VoidCallback onTap;

  const SocialLockdownButton({Key? key, required this.onTap}) : super(key: key);

  @override
  _SocialLockdownButtonState createState() => _SocialLockdownButtonState();
}

class _SocialLockdownButtonState extends State<SocialLockdownButton> {
  bool _isCalmed = false;

  void _activateLockdown() {
    if (_isCalmed) return; // Prevent double taps

    // 1. Trigger the logic passed from parent
    widget.onTap();

    // 2. Start the visual calming transition
    setState(() => _isCalmed = true);
  }

  @override
  Widget build(BuildContext context) {
    // Define active colors based on state
    final Color primaryColor = _isCalmed ? AppColors.primaryLavender : Colors.redAccent;
    final Color glowColor = _isCalmed ? AppColors.primaryLavender.withOpacity(0.25) : Colors.redAccent.withOpacity(0.2);
    
    return GestureDetector(
      onTap: _activateLockdown,
      child: AnimatedContainer(
        // Slow, 1.5s duration for a deep breath effect
        duration: Duration(milliseconds: 1500),
        curve: Curves.easeInOutCubic, 
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Gradient animates from Red/Transparent to Lavender/Transparent
          gradient: LinearGradient(
            colors: [glowColor, Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isCalmed ? AppColors.primaryLavender : Colors.redAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // --- ANIMATED ICON CIRCLE ---
            AnimatedContainer(
              duration: Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: glowColor,
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 600),
                child: Icon(
                  _isCalmed ? Feather.shield : Feather.alert_triangle,
                  key: ValueKey(_isCalmed), // Key enforces the switch animation
                  color: primaryColor,
                  size: 24,
                ),
              ),
            ),
            
            SizedBox(width: 16),
            
            // --- ANIMATED TEXT ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 1500),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Roboto', // Ensure this matches your app font
                    ),
                    child: Text(_isCalmed ? "Social Airlock Active" : "Do Not Panic"),
                  ),
                  SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 1500),
                    style: TextStyle(
                      color: _isCalmed ? AppColors.primaryLavender : AppColors.textMedium,
                      fontSize: 13,
                    ),
                    child: Text(_isCalmed 
                      ? "Protocol initiated. Stay safe." 
                      : "Let's fix this together, step by step."
                    ),
                  ),
                ],
              ),
            ),

            // --- LIKE BUTTON ANIMATION ---
            AnimatedSwitcher(
              duration: Duration(milliseconds: 800),
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Creates a "Pop" effect (scales up then settles)
                return ScaleTransition(
                  scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                  child: child,
                );
              },
              child: _isCalmed
                  ? Icon(
                      Feather.heart, // Filled heart
                      key: ValueKey('filled'),
                      color: AppColors.primaryLavender,
                      size: 26,
                    )
                  : Icon(
                      Feather.heart, // Outline heart
                      key: ValueKey('outline'),
                      color: AppColors.textDisabled,
                      size: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}