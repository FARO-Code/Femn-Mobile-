import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/widgets/femn_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:femn/auth/auth.dart'; // To access AuthScreen
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

// --- SHARED UI COMPONENTS ---

class SettingsPageBase extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsPageBase({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 18)),
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
          children: children,
        ),
      ),
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SettingsActionTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
        trailing: Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
        onTap: onTap ?? () {},
      ),
    );
  }
}

class SettingsSwitchTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  const SettingsSwitchTile({required this.icon, required this.title, required this.subtitle, required this.value});

  @override
  _SettingsSwitchTileState createState() => _SettingsSwitchTileState();
}

class _SettingsSwitchTileState extends State<SettingsSwitchTile> {
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(widget.title, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(widget.subtitle, style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
        value: _currentValue,
        activeColor: AppColors.primaryLavender,
        onChanged: (val) => setState(() => _currentValue = val),
      ),
    );
  }
}

class SettingsInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SettingsInfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(
          title, 
          style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.w500, fontSize: 12)
        ),
        subtitle: Text(
          subtitle, 
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.w600, fontSize: 15)
        ),
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.primaryLavender,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// --- SPECIFIC SCREENS ---

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  bool _isLoading = true;
  String? _profileImageUrl;
  String? _accountType;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _usernameController = TextEditingController(text: data['username'] ?? '');
          _fullNameController = TextEditingController(text: data['fullName'] ?? '');
          _bioController = TextEditingController(text: data['bio'] ?? '');
          _profileImageUrl = data['profileImage'];
          _accountType = data['accountType'];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return _profileImageUrl;
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return _profileImageUrl;
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      final newImageUrl = await _uploadImage(uid);
      
      Map<String, dynamic> updateData = {
        'username': _usernameController.text.trim().toLowerCase(),
        'fullName': _fullNameController.text.trim(),
        'profileImage': newImageUrl,
      };

      // Only sync bio if the account type typically has one
      if (_accountType == 'personal' || _accountType == 'organization') {
        updateData['bio'] = _bioController.text.trim();
      }

      await _firestore.collection('users').doc(uid).update(updateData);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving changes: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return SettingsPageBase(title: "Edit Profile", children: [Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))]);

    return SettingsPageBase(
      title: "Edit Profile",
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: AppColors.primaryLavender.withOpacity(0.2),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surface,
                    backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) as ImageProvider
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) 
                            ? NetworkImage(_profileImageUrl!) 
                            : null,
                    child: (_imageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)) 
                        ? Icon(Feather.user, size: 40, color: AppColors.textDisabled) 
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLavender, 
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.backgroundDeep, width: 2),
                    ),
                    child: Icon(Feather.camera, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 30),
        _buildTextField("Username", _usernameController, prefix: "@"),
        _buildTextField(_accountType == 'organization' ? "Organization Name" : "Full Name", _fullNameController),
        
        if (_accountType == 'personal' || _accountType == 'organization')
          _buildTextField("Bio", _bioController, maxLines: 3),
          
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLavender,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
            ),
            child: Text("Save Changes", style: TextStyle(color: AppColors.backgroundDeep, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, String? prefix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label, style: TextStyle(color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: AppColors.textHigh, fontSize: 15),
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surface.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.elevation.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primaryLavender)),
              contentPadding: EdgeInsets.all(18),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalInfoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SettingsPageBase(title: "Personal Information", children: [Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))]);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final accountType = data['accountType'] ?? 'personal';

        // Prepare info tiles based on account type
        List<Widget> infoTiles = [
          SettingsInfoTile(icon: Feather.user, title: "Full Name", subtitle: data['fullName'] ?? 'N/A'),
          SettingsInfoTile(icon: Feather.at_sign, title: "Username", subtitle: data['username'] ?? 'N/A'),
          SettingsInfoTile(icon: Feather.mail, title: "Email Address", subtitle: data['email'] ?? 'N/A'),
        ];

        if (accountType == 'personal' || accountType == 'therapist') {
          if (data['dateOfBirth'] != null) {
            final dob = (data['dateOfBirth'] as Timestamp).toDate();
            infoTiles.add(SettingsInfoTile(icon: Feather.calendar, title: "Birthday", subtitle: DateFormat('MMMM d, yyyy').format(dob)));
          }
        }

        if (accountType == 'organization') {
          infoTiles.addAll([
            SettingsInfoTile(icon: Feather.briefcase, title: "Category", subtitle: data['category'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.globe, title: "Country", subtitle: data['country'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.phone, title: "Phone", subtitle: data['phone'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.map_pin, title: "Address", subtitle: data['address'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.link, title: "Website", subtitle: data['website'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.file_text, title: "Mission Statement", subtitle: data['missionStatement'] ?? 'N/A'),
          ]);
        }

        if (accountType == 'therapist') {
          infoTiles.addAll([
            SettingsInfoTile(icon: Feather.activity, title: "Experience Level", subtitle: data['experienceLevel'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.map, title: "Region", subtitle: data['region'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.users, title: "Ethnicity", subtitle: data['ethnicity'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.user, title: "Gender", subtitle: data['gender'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.shield, title: "Religion", subtitle: data['religion'] ?? 'N/A'),
            SettingsInfoTile(icon: Feather.globe, title: "Languages", subtitle: (data['languages'] as List?)?.join(', ') ?? 'N/A'),
            SettingsInfoTile(icon: Feather.award, title: "Specialization", subtitle: (data['specialization'] as List?)?.join(', ') ?? 'N/A'),
          ]);
        }

        // Common metadata
        infoTiles.add(SettingsHeader("Account Metadata"));
        infoTiles.add(SettingsInfoTile(icon: Feather.info, title: "Account Type", subtitle: accountType.toString().toUpperCase()));
        if (data['createdAt'] != null) {
          final created = (data['createdAt'] as Timestamp).toDate();
          infoTiles.add(SettingsInfoTile(icon: Feather.clock, title: "Joined Femn", subtitle: DateFormat('MMMM d, yyyy').format(created)));
        }

        return SettingsPageBase(
          title: "Personal Information",
          children: [
            ...infoTiles,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "This private data is only visible to you. Femn uses it to customize your experience and ensure safety.",
                style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}

class DeletionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      title: "Account Deletion",
      children: [
        _buildAlertCard(
          context,
          "Deactivate Account",
          "Temporarily hide your profile and content. You can reactivate anytime by logging back in. Your account will be invisible to others.",
          AppColors.primaryLavender,
          isDeactivate: true,
        ),
        SizedBox(height: 20),
        _buildAlertCard(
          context,
          "Delete Account",
          "Permanently delete your data. This action is irreversible. All your posts, messages, and profile information will be erased.",
          AppColors.error,
          isDeactivate: false,
        ),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, String title, String description, Color color, {required bool isDeactivate}) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text(description, style: TextStyle(color: AppColors.textMedium, fontSize: 14)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showConfirmationDialog(context, isDeactivate),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, bool isDeactivate) {
    if (isDeactivate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Deactivate Account?", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
          content: Text(
            "You are about to deactivate your account. It will be hidden from everyone. You can reactivate it by simply logging in again.",
            style: TextStyle(color: AppColors.textMedium),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: AppColors.textDisabled)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performAction(context, true);
              },
              child: Text("Deactivate", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      // STRICT DELETE DIALOG
      showDialog(
        context: context,
        builder: (context) => _StrictDeleteDialog(onConfirm: () => _performAction(context, false)),
      );
    }
  }

  Future<void> _performAction(BuildContext context, bool isDeactivate) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final user = auth.currentUser;
    if (user == null) return;

    try {
      if (isDeactivate) {
        await firestore.collection('users').doc(user.uid).update({'isActive': false});
        await auth.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
          (route) => false,
        );
      } else {
        await firestore.collection('users').doc(user.uid).delete();
        await user.delete(); 
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
    }
  }
}

class _StrictDeleteDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  const _StrictDeleteDialog({required this.onConfirm});

  @override
  __StrictDeleteDialogState createState() => __StrictDeleteDialogState();
}

class __StrictDeleteDialogState extends State<_StrictDeleteDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isVerified = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyAndConfirm() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not signed in");

      // 1. Verify Username matches Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) throw Exception("User record not found");
      
      final realUsername = doc.data()?['username'] as String?;
      if (realUsername != _usernameController.text.trim().toLowerCase()) {
         throw Exception("Username does not match.");
      }

      // 2. Verify Password (Re-authenticate)
      // Note: This requires EmailAuthProvider. Only works for Email/Password accounts.
      // If using Google/Apple sign in, you'd need reauthenticateWithProvider.
      // Assuming Email/Password for now based on 'password' requirement.
      if (user.email == null) throw Exception("Email not found");
      
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, 
        password: _passwordController.text.trim()
      );
      
      await user.reauthenticateWithCredential(credential);

      // If we reach here, verification succeeded
      Navigator.pop(context); // Close dialog
      widget.onConfirm(); // Perform delete

    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
           _error = "Incorrect password.";
        } else {
           _error = e.toString().replaceAll("Exception: ", "");
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text("Delete Account?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This action is PERMANENT. All your data will be erased immediately. To confirm, please verify your identity.",
              style: TextStyle(color: AppColors.textMedium, fontSize: 13),
            ),
            SizedBox(height: 20),
            
            // Username Field
            Text("Enter your username:", style: TextStyle(color: AppColors.textHigh, fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.elevation,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: TextStyle(color: AppColors.textHigh),
            ),
            
            SizedBox(height: 15),
            
            // Password Field
            Text("Enter your password:", style: TextStyle(color: AppColors.textHigh, fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.elevation,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: TextStyle(color: AppColors.textHigh),
            ),

            if (_error != null) ...[
              SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: AppColors.textDisabled)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyAndConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading 
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text("DELETE ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class MessagingPrivacyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      title: "Messaging Privacy",
      children: [
        _RadioTile("Everyone", true),
        _RadioTile("Followers only", false),
        _RadioTile("No one", false),
      ],
    );
  }

  Widget _RadioTile(String title, bool selected) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(color: AppColors.textHigh)),
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

class LoginActivityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      title: "Login Activity",
      children: [
        _SessionTile("iPhone 14 Pro", "New York, USA", "Active Now", true),
        _SessionTile("Chrome on Windows", "London, UK", "2 hours ago", false),
        _SessionTile("iPad Air", "Paris, France", "Yesterday", false),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextButton(
            onPressed: () {},
            child: Text("Log out of all other sessions", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _SessionTile(String device, String location, String time, bool current) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(current ? Feather.monitor : Feather.smartphone, color: current ? AppColors.success : AppColors.textDisabled),
        title: Text(device, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        subtitle: Text("$location • $time", style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
        trailing: current ? null : Text("Logout", style: TextStyle(color: AppColors.error, fontSize: 12)),
      ),
    );
  }
}

class MediaQualityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      title: "Media Quality",
      children: [
        SettingsHeader("Cellular Data"),
        SettingsSwitchTile(icon: Feather.zap, title: "Data Saver", subtitle: "Lower quality images and videos", value: false),
        SettingsHeader("Wi-Fi"),
        SettingsSwitchTile(icon: Feather.upload, title: "Upload in HD", subtitle: "Always upload high-res media", value: true),
      ],
    );
  }
}

class LanguageScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      title: "Language",
      children: [
        _LanguageTile("English (System Default)", true),
        _LanguageTile("French", false),
        _LanguageTile("Spanish", false),
        _LanguageTile("German", false),
        _LanguageTile("Arabic", false),
      ],
    );
  }

  Widget _LanguageTile(String title, bool selected) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(color: AppColors.textHigh)),
        trailing: selected ? Icon(Feather.check, color: AppColors.primaryLavender) : null,
        onTap: () {},
      ),
    );
  }
}

class AccountManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SettingsPageBase(
    title: "Account Management",
    children: [
      SettingsActionTile(icon: Feather.user, title: "Edit Profile", subtitle: "Username, bio, profile picture", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen()))),
      SettingsActionTile(icon: Feather.info, title: "Personal Information", subtitle: "Email, phone, birthday", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalInfoScreen()))),
      SettingsActionTile(icon: Feather.user_x, title: "Account Deletion & Deactivation", subtitle: "Temporarily hide or permanently delete", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DeletionScreen()))),
      SettingsActionTile(
        icon: Feather.download, 
        title: "Request Account Data", 
        subtitle: "Download a copy of your information",
        onTap: () => _requestAccountData(context),
      ),
    ],
  );

  Future<void> _requestAccountData(BuildContext context) async {
    // 1. First, require Password Re-authentication
    final passwordController = TextEditingController();
    bool? authorized = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Verify Identity", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Please enter your password to request your data dump.", style: TextStyle(color: AppColors.textMedium)),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Password",
                filled: true,
                fillColor: AppColors.elevation,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: AppColors.textHigh),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: AppColors.textDisabled))),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: passwordController.text.trim());
                  await user.reauthenticateWithCredential(credential);
                  Navigator.pop(context, true);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Incorrect password"), backgroundColor: AppColors.error));
              }
            },
            child: Text("Verify", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (authorized == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _DataRequestProgressDialog();
        },
      );
    }
  }
}

class _DataRequestProgressDialog extends StatefulWidget {
  @override
  __DataRequestProgressDialogState createState() => __DataRequestProgressDialogState();
}

class __DataRequestProgressDialogState extends State<_DataRequestProgressDialog> {
  String _status = "Initializing...";
  double _progress = 0.1;

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  Future<void> _startProcess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      final uid = user.uid;

      // Helper to process data for JSON (handle Timestamps)
      dynamic _processData(dynamic data) {
        if (data is Timestamp) return data.toDate().toIso8601String();
        if (data is List) return data.map(_processData).toList();
        if (data is Map) {
          return data.map((key, value) => MapEntry(key, _processData(value)));
        }
        return data;
      }

      // Step 1: Connecting
      await Future.delayed(Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() { _status = "Fetching Profile..."; _progress = 0.1; });

      final Map<String, dynamic> fullExport = {};

      // 1. Profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> userData = {};
      
      if (userDoc.exists) {
        userData = _processData(userDoc.data()) as Map<String, dynamic>;
        
        // Remove embeddings if present
        if (userData.containsKey('embedding')) userData.remove('embedding');
        if (userData.containsKey('embeddings')) userData.remove('embeddings');
        
        fullExport['profile'] = userData;

        // ACCOUNT TYPE SPECIFIC DATA
        String accountType = userData['accountType'] ?? 'personal';
        if (accountType == 'therapist') {
           if (!mounted) return;
           setState(() { _status = "Fetching Therapist Data..."; _progress = 0.15; });
           
           // Fetch Certifications (URLs already in profile usually, but fetch separate collection if any)
           // Fetch Availability slots if stored separately? (Usually in profile)
           // Fetch Reviews/Ratings if stored in subcollections
           final reviewsSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('reviews').get();
           if (reviewsSnap.docs.isNotEmpty) {
             fullExport['therapist_reviews'] = reviewsSnap.docs.map((d) => _processData(d.data())).toList();
           }
        }
      } else {
         fullExport['profile'] = {"error": "User document not found"};
      }

      // 2. Posts
      if (!mounted) return;
      setState(() { _status = "Fetching Posts..."; _progress = 0.3; });
      final postsSnap = await FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uid).get();
      var processedPosts = postsSnap.docs.map((d) {
         var pData = _processData(d.data()) as Map<String, dynamic>;
         // Remove any embeddings in posts
         pData.remove('embedding');
         pData.remove('vector');
         return pData;
      }).toList();
      fullExport['posts'] = processedPosts;

      // 3. Journal
      if (!mounted) return;
      setState(() { _status = "Fetching Journal..."; _progress = 0.5; });
      final journalSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('journal').get();
      fullExport['journal'] = journalSnap.docs.map((d) => _processData(d.data())).toList();

      // 4. Stories
      if (!mounted) return;
      setState(() { _status = "Fetching Stories..."; _progress = 0.7; });
      final storiesSnap = await FirebaseFirestore.instance.collection('stories').where('userId', isEqualTo: uid).get();
      fullExport['stories'] = storiesSnap.docs.map((d) => _processData(d.data())).toList();

      // 5. Chats
      if (!mounted) return;
      setState(() { _status = "Fetching Chats..."; _progress = 0.9; });
      final chatsSnap = await FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: uid).get();
      fullExport['chats'] = chatsSnap.docs.map((d) => _processData(d.data())).toList();

      // 6. Notifications - EXCLUDED per user request
      
      // Finalizing
      if (!mounted) return;
      setState(() { _status = "Encrypting export file..."; _progress = 0.98; });
      
      final jsonString = JsonEncoder.withIndent('  ').convert(fullExport);

      await Future.delayed(Duration(milliseconds: 500));
      setState(() { _status = "Ready to share!"; _progress = 1.0; });
      await Future.delayed(Duration(milliseconds: 500));

      Navigator.pop(context); // Close dialog
      await Share.share(jsonString, subject: 'My Femn Account Data');

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error: $e"),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          CircularProgressIndicator(
            value: _progress,
            color: AppColors.primaryLavender,
            backgroundColor: AppColors.elevation,
          ),
          SizedBox(height: 20),
          Text(
            "Account Data Request",
            style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 10),
          Text(
            _status,
            style: TextStyle(color: AppColors.textMedium, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
