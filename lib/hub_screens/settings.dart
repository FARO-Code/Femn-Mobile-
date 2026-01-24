// settings.dart
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:femn/auth/auth.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/widgets/femn_background.dart';
import 'package:femn/hub_screens/settings_subpages.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.primaryLavender),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FemnBackground(
        child: ListView(
          padding: const EdgeInsets.only(top: kToolbarHeight + 20, left: 16, right: 16, bottom: 40),
          children: [
            _buildSectionHeader("Account Management"),
            _buildMenuTile(context, Feather.user, "Account", "Profile, Personal Info, Deletion", AccountManagementScreen()),
            
            _buildSectionHeader("Privacy & Security"),
            _buildMenuTile(context, Feather.eye, "Privacy", "Visibility, Status, Blocking", PrivacySettingsScreen()),
            _buildMenuTile(context, Feather.shield, "Security", "Password, 2FA, Activity", SecuritySettingsScreen()),

            _buildSectionHeader("Preferences"),
            _buildMenuTile(context, Feather.bell, "Notifications", "Push, Email, and SMS", NotificationSettingsScreen()),
            _buildMenuTile(context, Feather.sliders, "Content & Feed", "Quality, Autoplay, Language", ContentPreferencesScreen()),
            _buildMenuTile(context, Feather.monitor, "Accessibility & Display", "Themes, Text Size, Alt Text", AccessibilitySettingsScreen()),

            _buildSectionHeader("Information"),
            _buildMenuTile(context, Feather.help_circle, "Support & About", "FAQ, Legal, App Version", SupportAboutScreen()),

            SizedBox(height: 30),
            
            _buildActionTile(
              context, 
              Feather.plus_circle, 
              "Add Account", 
              () => {},
              color: AppColors.primaryLavender,
            ),
            _buildActionTile(
              context, 
              Feather.log_out, 
              "Logout", 
              () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              },
              color: AppColors.error,
              isBold: true,
            ),
            
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  "Femn v1.0.4",
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.primaryLavender.withOpacity(0.8),
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, IconData icon, String title, String subtitle, Widget screen) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
        trailing: Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color, bool isBold = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primaryLavender).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? AppColors.primaryLavender, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? AppColors.textHigh, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        trailing: Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// --- CATEGORY SCREENS ---



class PrivacySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Privacy",
    children: [
      SettingsSwitchTile(icon: Feather.eye, title: "Account Visibility", subtitle: "Toggle between Public and Private status", value: false),
      SettingsSwitchTile(icon: Feather.activity, title: "Active Status", subtitle: "Show when you're online", value: true),
      SettingsActionTile(icon: Feather.slash, title: "Blocked Accounts", subtitle: "Manage users you've blocked"),
      SettingsActionTile(icon: Feather.volume_x, title: "Muted Accounts", subtitle: "Content hidden without blocking"),
      SettingsActionTile(icon: Feather.mail, title: "Messaging Privacy", subtitle: "Control who can send you direct messages", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MessagingPrivacyScreen()))),
      SettingsActionTile(icon: Feather.at_sign, title: "Tagging & Mentions", subtitle: "Control who can tag or mention you"),
    ],
  );
}

class SecuritySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Security",
    children: [
      SettingsActionTile(icon: Feather.lock, title: "Change Password", subtitle: "Standard form to update your password"),
      SettingsActionTile(icon: Feather.shield, title: "Two-Factor Authentication (2FA)", subtitle: "SMS or Authenticator app verification"),
      SettingsActionTile(icon: Feather.monitor, title: "Login Activity", subtitle: "Manage active sessions and locations", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoginActivityScreen()))),
      SettingsSwitchTile(icon: Feather.save, title: "Saved Login Info", subtitle: "Save credentials on this device", value: true),
    ],
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Notifications",
    children: [
      SettingsHeader("Push Notifications"),
      SettingsSwitchTile(icon: Feather.heart, title: "Likes, Comments, & Mentions", subtitle: "Activity on your posts", value: true),
      SettingsSwitchTile(icon: Feather.user_plus, title: "New Followers", subtitle: "When someone follows you", value: true),
      SettingsSwitchTile(icon: Feather.message_square, title: "Direct Messages", subtitle: "New message alerts", value: true),
      SettingsSwitchTile(icon: Feather.info, title: "App updates/news", subtitle: "Stay informed about Femn", value: false),
      SettingsHeader("Email Notifications"),
      SettingsSwitchTile(icon: Feather.mail, title: "Marketing emails", subtitle: "Special offers and news", value: false),
      SettingsSwitchTile(icon: Feather.trending_up, title: "Product updates", subtitle: "New features and releases", value: true),
      SettingsSwitchTile(icon: Feather.list, title: "Activity digests", subtitle: "Summary of your network's activity", value: false),
      SettingsHeader("SMS Notifications"),
      SettingsSwitchTile(icon: Feather.shield, title: "Security alerts", subtitle: "Login attempts and account changes", value: true),
      SettingsSwitchTile(icon: Feather.key, title: "OTPs", subtitle: "One-time passwords for authentication", value: true),
    ],
  );
}

class ContentPreferencesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Content & Feed",
    children: [
      SettingsActionTile(icon: Feather.image, title: "Media Quality", subtitle: "Data saver mode for cellular data", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MediaQualityScreen()))),
      SettingsSwitchTile(icon: Feather.play_circle, title: "Autoplay", subtitle: "Toggle video autoplay on/off (or Wi-Fi only)", value: false),
      SettingsActionTile(icon: Feather.alert_triangle, title: "Sensitive Content Control", subtitle: "Filter or blur sensitive content"),
      SettingsActionTile(icon: Feather.globe, title: "Language", subtitle: "Set your app language preference", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LanguageScreen()))),
    ],
  );
}

class AccessibilitySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Accessibility & Display",
    children: [
      SettingsHeader("Appearance"),
      _buildAppearanceTile(context, "Light mode", false),
      _buildAppearanceTile(context, "Dark mode", true),
      _buildAppearanceTile(context, "System Default", false),
      SettingsHeader("Readability"),
      SettingsActionTile(icon: Feather.type, title: "Text Size", subtitle: "Adjustable font scaling"),
      SettingsSwitchTile(icon: Feather.eye, title: "Alt Text", subtitle: "Manage automatic alt-text generation", value: true),
    ],
  );

  Widget _buildAppearanceTile(BuildContext context, String title, bool selected) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.w600, fontSize: 15)),
        trailing: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? AppColors.primaryLavender : AppColors.textDisabled, width: 2)),
          child: CircleAvatar(radius: 6, backgroundColor: selected ? AppColors.primaryLavender : Colors.transparent),
        ),
        onTap: () {},
      ),
    );
  }
}

class SupportAboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Support & About",
    children: [
      SettingsActionTile(icon: Feather.help_circle, title: "Help Center / FAQ", subtitle: "External support pages"),
      SettingsActionTile(icon: Feather.flag, title: "Report a Problem", subtitle: "Bug reports and feedback"),
      SettingsActionTile(icon: Feather.file_text, title: "Terms of Service", subtitle: "Legal agreement"),
      SettingsActionTile(icon: Feather.shield, title: "Privacy Policy", subtitle: "Data handling policy"),
      SettingsActionTile(icon: Feather.code, title: "Open Source Libraries", subtitle: "Attribution for code libraries used"),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            children: [
              Text("App Version", style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
              Text("1.0.4", style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    ],
  );
}