import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart'; // <--- Ensure this file exists
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:femn/hub_screens/post.dart'; // <--- Ensure this file exists
import 'package:femn/widgets/femn_background.dart';

// ==========================================
// 1. DATA & VALIDATORS (New Additions)
// ==========================================

class CountryData {
  static const List<String> allCountries = [
    "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda", "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan",
    "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi",
    "Cabo Verde", "Cambodia", "Cameroon", "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Congo", "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czech Republic",
    "Denmark", "Djibouti", "Dominica", "Dominican Republic",
    "East Timor", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia",
    "Fiji", "Finland", "France",
    "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana",
    "Haiti", "Honduras", "Hungary",
    "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy", "Ivory Coast",
    "Jamaica", "Japan", "Jordan",
    "Kazakhstan", "Kenya", "Kiribati", "Korea, North", "Korea, South", "Kosovo", "Kuwait", "Kyrgyzstan",
    "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg",
    "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique", "Myanmar",
    "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "North Macedonia", "Norway",
    "Oman",
    "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Poland", "Portugal",
    "Qatar",
    "Romania", "Russia", "Rwanda",
    "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Sudan", "Spain", "Sri Lanka", "Sudan", "Suriname", "Sweden", "Switzerland", "Syria",
    "Taiwan", "Tajikistan", "Tanzania", "Thailand", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu",
    "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States", "Uruguay", "Uzbekistan",
    "Vanuatu", "Vatican City", "Venezuela", "Vietnam",
    "Yemen",
    "Zambia", "Zimbabwe"
  ];
}

class UsernameValidator {
  static final Set<String> _reservedWords = {
    'admin', 'administrator', 'root', 'system', 'support', 'help', 'info',
    'service', 'staff', 'marketing', 'sales', 'billing', 'api', 'bot',
    'crawler', 'security', 'signin', 'login', 'register', 'join', 'account',
    'settings', 'dashboard', 'notifications', 'messages', 'search', 'explore',
    'femn', 'femnteam', 'official', 'moderator'
  };

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return "Username is required";
    }

    // Check length
    if (value.length < 3) return "Username must be at least 3 characters";
    if (value.length > 20) return "Username must be under 20 characters";

    // Convert to lowercase for checking logic
    final lowerValue = value.toLowerCase();

    // Check Reserved Words
    if (_reservedWords.contains(lowerValue)) {
      return "This username is reserved";
    }

    // Check Allowed Characters (a-z, 0-9, _, .)
    final validCharacters = RegExp(r'^[a-z0-9._]+$');
    if (!validCharacters.hasMatch(lowerValue)) {
      return "Use only letters, numbers, dot (.), or underscore (_)";
    }

    // Check Placement (Start/End)
    if (lowerValue.startsWith('_') || lowerValue.startsWith('.')) {
      return "Cannot start with underscore or dot";
    }
    if (lowerValue.endsWith('_') || lowerValue.endsWith('.')) {
      return "Cannot end with underscore or dot";
    }

    // Check Consecutive Special Characters
    if (lowerValue.contains('..') || lowerValue.contains('__') || 
        lowerValue.contains('._') || lowerValue.contains('_.')) {
      return "Cannot have consecutive special characters";
    }

    return null; // Valid
  }
}

// ========== SPLASH SCREEN ==========
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  _navigateToAuth() async {
    await Future.delayed(Duration(seconds: 3));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: FemnBackground(
        imagePath: 'assets/femn_bg.png',
        opacity: 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FEMN LOGO
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface, 
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage("assets/default_avatar.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Femn",
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh, 
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== AUTHENTICATION SCREEN ==========
class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FemnBackground(
        opacity: 0.8,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage("assets/default_avatar.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Femn",
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLavender,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Connect, Share, and Heal",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 60),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLavender,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: Text(
                        "Login",
                        style: TextStyle(
                            color: AppColors.backgroundDeep,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Signup Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AccountTypeScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textHigh,
                        side: BorderSide(color: AppColors.primaryLavender, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                            color: AppColors.primaryLavender,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== ACCOUNT TYPES ==========
enum AccountType { personal, organization, therapist }

// ========== AUTH SERVICE ==========
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generic Sign Up
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> interests,
    String profileImage = '',
    String bio = ''
  }) async {
    return await signUpPersonal(
      email: email,
      password: password,
      username: username,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      interests: interests,
      profileImage: profileImage,
      bio: bio,
    );
  }

  // Personal Account Sign Up
  Future<String?> signUpPersonal({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> interests,
    String profileImage = '',
    String bio = '',
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'profileImage': profileImage,
        'interests': interests,
        'bio': bio,
        'accountType': 'personal',
        'followers': [],
        'following': [],
        'posts': 0,
        'embers': 0,
        'createdAt': DateTime.now(),
        'isVerified': false,
        'isActive': true,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Organization Account Sign Up
  Future<String?> signUpOrganization({
    required String email,
    required String password,
    required String organizationName,
    required String category,
    required String country,
    required String missionStatement,
    String username = '',
    String profileImage = '',
    String website = '',
    String phone = '',
    String address = '',
    List<String> socialLinks = const [],
    String bio = '',
    List<String> areasOfFocus = const [],
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      String generatedUsername = username.isEmpty 
          ? organizationName.toLowerCase().replaceAll(' ', '_')
          : username;
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'username': generatedUsername,
        'fullName': organizationName,
        'organizationName': organizationName,
        'category': category,
        'country': country,
        'missionStatement': missionStatement,
        'profileImage': profileImage,
        'website': website,
        'phone': phone,
        'address': address,
        'socialLinks': socialLinks,
        'bio': bio,
        'areasOfFocus': areasOfFocus,
        'accountType': 'organization',
        'followers': [],
        'following': [],
        'posts': 0,
        'embers': 0,
        'createdAt': DateTime.now(),
        'isVerified': false,
        'isActive': true,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Therapist Account Sign Up
  Future<String?> signUpTherapist({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required List<String> specialization,
    required String experienceLevel,
    required DateTime dateOfBirth,
    required List<AvailabilitySlot> availability,
    String profileImage = '',
    List<File>? certificationFiles,
    List<String> languages = const [],
    List<String> livedExperiences = const [],
    String region = '',
    String ethnicity = '',
    String gender = '',
    bool isLgbtqPlus = false,
    String religion = '',
  }) async {
    try {
      // 1. Create User
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = cred.user!.uid;

      // 2. Upload Certifications (Now authorized as user is created)
      List<String> certificationUrls = [];
      if (certificationFiles != null && certificationFiles.isNotEmpty) {
        for (var i = 0; i < certificationFiles.length; i++) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('therapist_certifications')
              .child(uid)
              .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          await ref.putFile(certificationFiles[i]);
          certificationUrls.add(await ref.getDownloadURL());
        }
      }

      // Calculate Age Range
      final age = DateTime.now().year - dateOfBirth.year;
      String ageRange = 'Adult';
      if (age < 18) ageRange = 'Adolescent';
      else if (age <= 25) ageRange = 'Young Adult';
      else if (age <= 60) ageRange = 'Adult';
      else ageRange = 'Elderly';

      // 3. Save User Document
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'specialization': specialization,
        'experienceLevel': experienceLevel,
        'dateOfBirth': dateOfBirth,
        'availability': availability.map((s) => s.toMap()).toList(),
        'profileImage': profileImage,
        'certifications': certificationUrls,
        'languages': languages,
        'livedExperiences': livedExperiences,
        'region': region,
        'ethnicity': ethnicity,
        'gender': gender,
        'isLgbtqPlus': isLgbtqPlus,
        'religion': religion,
        'ageRange': ageRange,
        'accountType': 'therapist',
        'followers': [],
        'following': [],
        'posts': 0,
        'embers': 0,
        'createdAt': DateTime.now(),
        'isVerified': false,
        'isActive': true,
        'totalRatings': 0,
        'averageRating': 0.0,
        'reports': 0,
        'activeClients': 0,
        'totalClients': 0,
        'strikes': 0,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// ========== ACCOUNT TYPE SELECTION SCREEN ==========
class AccountTypeScreen extends StatelessWidget {
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: FemnBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage("assets/default_avatar.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Choose Account Type",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLavender,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Select the type of account that best fits you",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Expanded(
                child: Column(
                  children: [
                    _buildAccountTypeCard(
                      context,
                      icon: Feather.user,
                      title: "Personal Account",
                      subtitle: "For individuals looking to connect and share",
                      type: AccountType.personal,
                      color: AppColors.primaryLavender,
                    ),
                    SizedBox(height: 20),
                    _buildAccountTypeCard(
                      context,
                      icon: Feather.briefcase,
                      title: "Organization Account",
                      subtitle: "For NGOs, companies, and community groups",
                      type: AccountType.organization,
                      color: AppColors.secondaryTeal,
                    ),
                    SizedBox(height: 20),
                    _buildAccountTypeCard(
                      context,
                      icon: Feather.activity,
                      title: "Therapist Account",
                      subtitle: "For mental health professionals and volunteers",
                      type: AccountType.therapist,
                      color: AppColors.accentMustard,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildAccountTypeCard(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required AccountType type,
  required Color color,
}) {
  return Card(
    elevation: 4,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignupScreen(accountType: type),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.elevation,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12, 
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Feather.chevron_right, color: AppColors.textDisabled, size: 16),
          ],
        ),
      ),
    ),
  );
}
}

// ========== UPDATED SIGNUP SCREEN ==========
class SignupScreen extends StatefulWidget {
  final AccountType accountType;
  const SignupScreen({required this.accountType});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;

  int _getTotalSteps() {
    switch (widget.accountType) {
      case AccountType.personal: return 3;
      case AccountType.organization: return 3;
      case AccountType.therapist: return 7;
    }
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < _getTotalSteps() - 1) {
        setState(() => _currentStep++);
      } else {
        _signup();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  String _getStepTitle() {
    switch (widget.accountType) {
      case AccountType.personal:
        if (_currentStep == 0) return "Basic Info";
        if (_currentStep == 1) return "Security";
        return "Your Interests";
      case AccountType.organization:
        if (_currentStep == 0) return "Account Details";
        if (_currentStep == 1) return "Profile Info";
        return "Areas of Focus";
      case AccountType.therapist:
        if (_currentStep == 0) return "Professional Identity";
        if (_currentStep == 1) return "Account & Age";
        if (_currentStep == 2) return "Demographics";
        if (_currentStep == 3) return "Availability";
        if (_currentStep == 4) return "Professional Focus";
        if (_currentStep == 5) return "Lived Experience";
        return "Languages Spoken";
    }
  }

  // Personal Account Fields
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  List<String> _selectedInterests = [];

  // Organization Account Fields
  final _organizationNameController = TextEditingController();
  final _missionStatementController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCountry;
  List<String> _selectedAreasOfFocus = [];
  List<String> _socialLinks = [''];

  // Therapist Account Fields
  final _therapistFullNameController = TextEditingController();
  final _therapistUsernameController = TextEditingController();
  List<String> _selectedSpecializations = [];
  List<String> _selectedLivedExperiences = [];
  String? _selectedExperienceLevel;
  String? _selectedRegion;
  List<String> _selectedLanguages = [];
  String? _selectedEthnicity;
  String? _selectedGender;
  bool _isLgbtqPlus = false;
  String? _selectedReligion;
  List<Map<String, dynamic>> _availabilityGroups = [];
  List<File> _certificationFiles = [];

  // Options
  final List<String> _interestsOptions = [
    'Feminist literature', 'Gender equality activism', 'Mental health awareness',
    'Body positivity', 'LGBTQ+ support', 'Career & entrepreneurship',
  ];
  final List<String> _organizationCategories = [
    'NGO', 'Startup', 'Women\'s Group', 'Educational', 'Activist', 
    'Non-profit', 'Company', 'Collective', 'Community'
  ];
  
  // UPDATED: Using the comprehensive Country list
  final List<String> _countries = CountryData.allCountries;

  final List<String> _specializations = [
    'Anxiety', 'Depression', 'Trauma', 'Relationships', 'Self-esteem',
    'Stress Management', 'Grief', 'Addiction', 'Family Therapy',
    'LGBTQ+', 'Autistic / AuDHD', 'Dyslexic', 'Non-verbal', 'Mixed-Race',
    'Refugee / Asylee experience', 'Caste-oppression informed', 'Colorism-informed',
    'Anti-colonial / Decolonial framework', 'Racial trauma', 'Indigenous',
    'Ex-religious / Religious trauma', 'Fat Positive / Health at Every Size (HAES)',
    'Body Neutrality focused', 'Physically Disabled / Wheelchair user',
    'Deaf / Hard of Hearing (ASL proficient)', 'Blind / Low Vision informed',
    'Eating Disorder recovery', 'Post-partum / Maternal mental health',
    'Infertility / Miscarriage support', 'Menopause / Hormonal health',
    'Cancer survivor / Oncology-informed', 'Terminal illness / End-of-life care',
    'Veteran / Military family', 'First Responder (Police, Fire, EMT)',
    'Medical Professional (Doctors, Nurses)', 'Tech industry / Burnout specialist',
    'Artist / Creative professional', 'Academic / Higher Ed focus',
    'Sex Work positive', 'Social Activist / Organizer', 'Foster Care system alum',
    'Adoption / Adoptee', 'Elder / Geriatric focus', 'Domestic Violence survivor',
    'Sexual Assault survivor', 'Childhood Emotional Neglect (CEN)',
    'Narcissistic Abuse recovery', 'Incarceration / Justice-involved',
    'Homelessness / Housing instability', 'Poverty / Class-straddling mobility',
    'Relinquishment trauma', 'Cult recovery', 'Intergenerational / Ancestral trauma',
    'Feminist / Liberation-focused'
  ];

  final List<String> _livedExperiences = [
    'LGBTQ+', 'Autistic / AuDHD', 'Dyslexic', 'Non-verbal', 'Mixed-Race',
    'Refugee / Asylee experience', 'Caste-oppression informed', 'Colorism-informed',
    'Anti-colonial / Decolonial framework', 'Racial trauma', 'Indigenous',
    'Ex-religious / Religious trauma', 'Fat Positive / Health at Every Size (HAES)',
    'Body Neutrality focused', 'Physically Disabled / Wheelchair user',
    'Deaf / Hard of Hearing (ASL proficient)', 'Blind / Low Vision informed',
    'Eating Disorder recovery', 'Post-partum / Maternal mental health',
    'Infertility / Miscarriage support', 'Menopause / Hormonal health',
    'Cancer survivor / Oncology-informed', 'Terminal illness / End-of-life care',
    'Veteran / Military family', 'First Responder (Police, Fire, EMT)',
    'Medical Professional (Doctors, Nurses)', 'Tech industry / Burnout specialist',
    'Artist / Creative professional', 'Academic / Higher Ed focus',
    'Sex Work positive', 'Social Activist / Organizer', 'Foster Care system alum',
    'Adoption / Adoptee', 'Elder / Geriatric focus', 'Domestic Violence survivor',
    'Sexual Assault survivor', 'Childhood Emotional Neglect (CEN)',
    'Narcissistic Abuse recovery', 'Incarceration / Justice-involved',
    'Homelessness / Housing instability', 'Poverty / Class-straddling mobility',
    'Relinquishment trauma', 'Cult recovery', 'Intergenerational / Ancestral trauma',
    'Feminist / Liberation-focused'
  ];

  final Set<String> _sensitiveSpecializations = {
    'Trauma', 'Addiction', 'Eating Disorder recovery', 'Post-partum / Maternal mental health',
    'Infertility / Miscarriage support', 'Cancer survivor / Oncology-informed',
    'Terminal illness / End-of-life care', 'Domestic Violence survivor',
    'Sexual Assault survivor', 'Childhood Emotional Neglect (CEN)',
    'Narcissistic Abuse recovery', 'Incarceration / Justice-involved',
    'Racial trauma', 'Intergenerational / Ancestral trauma', 'Cult recovery',
    'Relinquishment trauma', 'Medical Professional (Doctors, Nurses)'
  };
  final List<String> _experienceLevels = [
    'Certified Therapist', 'Psych Student', 'Peer Listener', 'Volunteer'
  ];
  final List<String> _genderPreferences = [
    'Open to all', 'Male only', 'Female only', 'Other'
  ];
  final List<String> _regions = [
    'West Africa', 'Middle East', 'North America', 'Europe', 
    'Asia', 'South America', 'Central Africa'
  ];
  final List<String> _languages = [
    'English', 'French', 'Spanish', 'Arabic', 'Swahili',
    'Portuguese', 'Hindi', 'Yoruba', 'Zulu', 'Mandarin', 'Japanese', 'Bengali',
    'German', 'Italian', 'Russian', 'Korean', 'Turkish', 'Vietnamese', 'Thai', 
    'Polish', 'Dutch', 'Amharic', 'Oromo', 'Hausa', 'Igbo', 'Shona', 'Twi',
    'Wolof', 'Somali', 'Berber', 'Urdu', 'Punjabi', 'Telugu', 'Marathi', 'Tamil',
    'Gujarati', 'Malayalam', 'Kannada', 'Persian', 'Pashto', 'Kurdish', 'Hebrew',
    'Indonesian', 'Malay', 'Tagalog', 'Burmese', 'Khmer', 'Lao', 'Greek', 'Czech',
    'Hungarian', 'Swedish', 'Finnish', 'Danish', 'Norwegian', 'Ukrainian', 'Romanian',
    'Catalan', 'Basque', 'Galician', 'Quechua', 'Guarani', 'Aymara', 'Nahuatl', 'Maya',
    'ASL (American Sign Language)', 'BSL (British Sign Language)', 'ISL (International Sign Language)'
  ];
  final List<String> _ethnicities = [
    'Asian', 'Black', 'Blasian', 'White', 'Hispanic', 'Middle Eastern', 'Indigenous', 'Other'
  ];
  final List<String> _genders = [
    'Male', 'Female', 'Non-binary', 'Transgender', 'Other'
  ];
  final List<String> _religions = [
    'Christianity', 'Islam', 'Hinduism', 'Buddhism', 'Sikhism', 'Judaism', 
    'Agnostic', 'Atheist', 'Spiritual', 'Traditional', 'Other'
  ];
  final List<String> _ageRanges = [
    'Adolescent', 'Young Adult', 'Adult', 'Elderly'
  ];
  final List<String> _areasOfFocus = [
    'Gender Equality', 'Education', 'Health', 'Advocacy',
    'Poverty Alleviation', 'Environmental Justice', 'Youth Development'
  ];

  Future<void> _pickCertificationFiles() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _certificationFiles.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _addSocialLink() {
    setState(() {
      _socialLinks.add('');
    });
  }

  void _removeSocialLink(int index) {
    setState(() {
      _socialLinks.removeAt(index);
    });
  }

  void _updateSocialLink(int index, String value) {
    setState(() {
      _socialLinks[index] = value;
    });
  }


  void _addAvailabilityGroup() {
    setState(() {
      _availabilityGroups.add({
        'days': <String>[],
        'start': TimeOfDay(hour: 9, minute: 0),
        'end': TimeOfDay(hour: 17, minute: 0),
      });
    });
  }

  void _removeAvailabilityGroup(int index) {
    setState(() {
      _availabilityGroups.removeAt(index);
    });
  }

  void _toggleDayInGroup(int groupIndex, String day) {
    setState(() {
      final days = _availabilityGroups[groupIndex]['days'] as List<String>;
      if (days.contains(day)) {
        days.remove(day);
      } else {
        days.add(day);
      }
    });
  }

  Future<void> _selectTimeRange(int groupIndex, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _availabilityGroups[groupIndex]['start'] : _availabilityGroups[groupIndex]['end'],
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _availabilityGroups[groupIndex]['start'] = picked;
        } else {
          _availabilityGroups[groupIndex]['end'] = picked;
        }
      });
    }
  }

  List<AvailabilitySlot> _flattenAvailability() {
    List<AvailabilitySlot> flattened = [];
    for (var group in _availabilityGroups) {
      final days = group['days'] as List<dynamic>;
      final start = group['start'] as TimeOfDay;
      final end = group['end'] as TimeOfDay;
      for (var day in days) {
        flattened.add(AvailabilitySlot(
          day: day.toString(),
          startTime: start,
          endTime: end,
        ));
      }
    }
    return flattened;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.backgroundDeep)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError("Passwords do not match");
        return;
      }
      setState(() => _isLoading = true);

      try {
        String? error;
        String profileUrl = '';

        switch (widget.accountType) {
          case AccountType.personal:
            if (_dateOfBirth == null) {
              _showError("Please select your date of birth");
              setState(() => _isLoading = false);
              return;
            }
            error = await AuthService().signUpPersonal(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              // Force lowercase username
              username: _usernameController.text.trim().toLowerCase(),
              fullName: _fullNameController.text.trim(),
              dateOfBirth: _dateOfBirth!,
              interests: _selectedInterests,
              profileImage: profileUrl,
              bio: '',
            );
            break;
          case AccountType.organization:
            if (_selectedCategory == null || _selectedCountry == null) {
              _showError("Please fill all required fields");
              setState(() => _isLoading = false);
              return;
            }
            error = await AuthService().signUpOrganization(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              organizationName: _organizationNameController.text.trim(),
              category: _selectedCategory!,
              country: _selectedCountry!,
              missionStatement: _missionStatementController.text.trim(),
              // Force lowercase username
              username: _organizationNameController.text.trim().toLowerCase().replaceAll(' ', '_'),
              profileImage: profileUrl,
              website: _websiteController.text.trim(),
              phone: _phoneController.text.trim(),
              address: _addressController.text.trim(),
              socialLinks: _socialLinks.where((link) => link.isNotEmpty).toList(),
              bio: '',
              areasOfFocus: _selectedAreasOfFocus,
            );
            break;
          case AccountType.therapist:
            final flattened = _flattenAvailability();
            
            // Age Check
            if (_dateOfBirth == null) {
              _showError("Please select your date of birth");
              setState(() => _isLoading = false);
              return;
            }
            final age = DateTime.now().year - _dateOfBirth!.year;
            if (age < 18) {
              _showError("You must be at least 18 years old to be a therapist.");
              setState(() => _isLoading = false);
              return;
            }

            if (_selectedSpecializations.isEmpty || _selectedExperienceLevel == null || flattened.isEmpty) {
              _showError("Please fill all required fields, including availability days");
              setState(() => _isLoading = false);
              return;
            }

            // Certification Requirement check
            if ((_selectedExperienceLevel == 'Certified Therapist' || _selectedExperienceLevel == 'Psych Student') && _certificationFiles.isEmpty) {
              _showError("Professionals and Students must upload certifications.");
              setState(() => _isLoading = false);
              return;
            }
            
            error = await AuthService().signUpTherapist(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              fullName: _therapistFullNameController.text.trim(),
              // Force lowercase username
              username: _therapistUsernameController.text.trim().toLowerCase(),
              specialization: _selectedSpecializations,
              livedExperiences: _selectedLivedExperiences,
              experienceLevel: _selectedExperienceLevel!,
              dateOfBirth: _dateOfBirth!,
              availability: flattened,
              profileImage: profileUrl,
              certificationFiles: _certificationFiles,
              languages: _selectedLanguages,
              region: _selectedRegion ?? '',
              ethnicity: _selectedEthnicity ?? '',
              gender: _selectedGender ?? '',
              isLgbtqPlus: _selectedSpecializations.contains('LGBTQ+') || _selectedLivedExperiences.contains('LGBTQ+'),
              religion: _selectedReligion ?? '',
            );
            break;
        }

        setState(() => _isLoading = false);

        if (error != null) {
          _showError(error);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => FeedScreen()),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showError("An error occurred: $e");
      }
    }
  }

  Widget _buildPersonalForm() {
    if (_currentStep == 0) {
      return Column(
        children: [
          _buildTextField(
            controller: _fullNameController,
            hintText: "Full Name",
            icon: Feather.user,
            validator: (v) => v!.isEmpty ? "Enter your full name" : null,
          ),
          _buildTextField(
            controller: _usernameController,
            hintText: "Username",
            icon: Feather.at_sign,
            validator: (v) => UsernameValidator.validate(v),
          ),
          _buildTextField(
            controller: _emailController,
            hintText: "Email *",
            icon: Feather.mail,
            validator: (v) => v!.isEmpty ? "Enter your email" : null,
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        children: [
          _buildDateOfBirthField(),
          _buildTextField(
            controller: _passwordController,
            hintText: "Password *",
            icon: Feather.lock,
            validator: (v) => v!.length < 6 ? "Password must be 6+ chars" : null,
            obscureText: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          _buildTextField(
            controller: _confirmPasswordController,
            hintText: "Confirm Password *",
            icon: Feather.lock,
            validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
            obscureText: _obscureConfirmPassword,
            onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ],
      );
    } else {
      return _buildInterestsField();
    }
  }

  Widget _buildOrganizationForm() {
    if (_currentStep == 0) {
      return Column(
        children: [
          _buildTextField(
            controller: _organizationNameController,
            hintText: "Organization Name",
            icon: Feather.briefcase,
            validator: (v) => v!.isEmpty ? "Enter organization name" : null,
          ),
          _buildTextField(
            controller: _emailController,
            hintText: "Email *",
            icon: Feather.mail,
            validator: (v) => v!.isEmpty ? "Enter email" : null,
          ),
          _buildTextField(
            controller: _passwordController,
            hintText: "Password *",
            icon: Feather.lock,
            validator: (v) => v!.length < 6 ? "Password must be 6+ chars" : null,
            obscureText: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          _buildTextField(
            controller: _confirmPasswordController,
            hintText: "Confirm Password *",
            icon: Feather.lock,
            validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
            obscureText: _obscureConfirmPassword,
            onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        children: [
          _buildTextField(
            controller: _missionStatementController,
            hintText: "Mission Statement *",
            icon: Feather.file_text,
            maxLines: 3,
            validator: (v) => v!.isEmpty ? "Enter mission statement" : null,
          ),
          _buildDropdown(
            value: _selectedCategory,
            hint: "Select Category *",
            items: _organizationCategories,
            icon: Feather.grid,
            onChanged: (value) => setState(() => _selectedCategory = value),
            validator: (value) => value == null ? "Select a category" : null,
          ),
          _buildTextField(
            controller: _websiteController,
            hintText: "Website (optional)",
            icon: Feather.globe,
          ),
          _buildTextField(
            controller: _phoneController,
            hintText: "Phone (optional)",
            icon: Feather.phone,
          ),
          _buildSocialLinksField(),
          _buildTextField(
            controller: _addressController,
            hintText: "Address (optional)",
            icon: Feather.map_pin,
          ),
          _buildDropdown(
            value: _selectedCountry,
            hint: "Select Country *",
            items: _countries,
            icon: Feather.globe,
            onChanged: (value) => setState(() => _selectedCountry = value),
            validator: (value) => value == null ? "Select a country" : null,
          ),
        ],
      );
    } else {
      return _buildMultiSelectChips(
        title: "Areas of Focus (optional)",
        options: _areasOfFocus,
        selected: _selectedAreasOfFocus,
        onChanged: (selected) => setState(() => _selectedAreasOfFocus = selected),
      );
    }
  }

  Widget _buildTherapistForm() {
    if (_currentStep == 0) {
      return Column(
        children: [
          _buildTextField(
            controller: _therapistFullNameController,
            hintText: "Full Name *",
            icon: Feather.user,
            validator: (v) => v!.isEmpty ? "Enter your full name" : null,
          ),
          _buildTextField(
            controller: _therapistUsernameController,
            hintText: "Username *",
            icon: Feather.at_sign,
            validator: (v) => UsernameValidator.validate(v),
          ),
          _buildTextField(
            controller: _emailController,
            hintText: "Email *",
            icon: Feather.mail,
            validator: (v) => v!.isEmpty ? "Enter your email" : null,
          ),
          _buildDropdown(
            value: _selectedExperienceLevel,
            hint: "Experience Level *",
            items: _experienceLevels,
            icon: Feather.activity,
            onChanged: (value) => setState(() {
              _selectedExperienceLevel = value;
              if (value != 'Certified Therapist') {
                _selectedSpecializations.removeWhere((s) => _sensitiveSpecializations.contains(s));
              }
            }),
            validator: (value) => value == null ? "Select experience level" : null,
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        children: [
          _buildDateOfBirthField(),
          _buildTextField(
            controller: _passwordController,
            hintText: "Password *",
            icon: Feather.lock,
            validator: (v) => v!.length < 6 ? "Password must be 6+ chars" : null,
            obscureText: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          _buildTextField(
            controller: _confirmPasswordController,
            hintText: "Confirm Password *",
            icon: Feather.lock,
            validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
            obscureText: _obscureConfirmPassword,
            onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          if (_selectedExperienceLevel == 'Certified Therapist' || _selectedExperienceLevel == 'Psych Student')
            _buildCertificationsField(),
        ],
      );
    } else if (_currentStep == 2) {
      return Column(
        children: [
          _buildDropdown(
            value: _selectedEthnicity,
            hint: "Race & Ethnicity *",
            items: _ethnicities,
            icon: Feather.user,
            onChanged: (value) => setState(() => _selectedEthnicity = value),
            validator: (value) => value == null ? "Select ethnicity" : null,
          ),
          _buildDropdown(
            value: _selectedGender,
            hint: "Gender *",
            items: _genders,
            icon: Feather.user,
            onChanged: (value) => setState(() => _selectedGender = value),
            validator: (value) => value == null ? "Select gender" : null,
          ),
          _buildDropdown(
            value: _selectedRegion,
            hint: "Region (optional)",
            items: _regions,
            icon: Feather.map,
            onChanged: (value) => setState(() => _selectedRegion = value),
          ),
          _buildDropdown(
            value: _selectedReligion,
            hint: "Religion *",
            items: _religions,
            icon: Feather.shield,
            onChanged: (value) => setState(() => _selectedReligion = value),
            validator: (value) => value == null ? "Select religion" : null,
          ),
        ],
      );
    } else if (_currentStep == 3) {
      return _buildAvailabilityField();
    } else if (_currentStep == 4) {
      final List<String> availableSpecializations = _selectedExperienceLevel == 'Certified Therapist' 
        ? _specializations 
        : _specializations.where((s) => !_sensitiveSpecializations.contains(s)).toList();
      return _buildMultiSelectChips(
        title: "Specialization (I specialize in helping...) *",
        options: availableSpecializations,
        selected: _selectedSpecializations,
        onChanged: (selected) => setState(() => _selectedSpecializations = selected),
      );
    } else if (_currentStep == 5) {
      return _buildMultiSelectChips(
        title: "I am / Have experienced...",
        options: _livedExperiences,
        selected: _selectedLivedExperiences,
        onChanged: (selected) => setState(() => _selectedLivedExperiences = selected),
      );
    } else {
      return _buildMultiSelectChips(
        title: "Languages Spoken (optional)",
        options: _languages,
        selected: _selectedLanguages,
        onChanged: (selected) => setState(() => _selectedLanguages = selected),
      );
    }
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevation, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          cursorColor: AppColors.primaryLavender,
          style: TextStyle(color: AppColors.textHigh), 
          maxLines: maxLines,
          obscureText: obscureText,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.elevation,
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textDisabled),
            prefixIcon: Icon(icon, color: AppColors.primaryLavender),
            suffixIcon: (hintText.toLowerCase().contains('password') && onToggleObscure != null)
                ? IconButton(
                    icon: Icon(
                      obscureText ? Feather.eye_off : Feather.eye,
                      color: AppColors.primaryLavender,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator,
        ),
      ),
    );
  }

  // ========== UPDATED DROPDOWN WIDGET ==========
  // Matches style of TextFields and includes Icon support
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevation, // Matches TextField background
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true, // Prevents overflow for long country names
          menuMaxHeight: 300, // Limits height so list is scrollable
          icon: Icon(Feather.chevron_down, color: AppColors.textDisabled),
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 16,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
          dropdownColor: AppColors.surface, // Dark dropdown menu
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent, // Transparent because Container handles color
            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textDisabled),
            prefixIcon: Icon(icon, color: AppColors.primaryLavender),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: AppColors.primaryLavender, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textHigh),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          title: Text(
          _dateOfBirth == null
              ? "Select Date of Birth *"
              : "DOB: ${DateFormat('yyyy-MM-dd').format(_dateOfBirth!)}",
            style: TextStyle(
              color: AppColors.textHigh,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(Feather.calendar, color: AppColors.primaryLavender),
          onTap: _selectDOB,
        ),
      ),
    );
  }

  Future<void> _selectDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryLavender,
              onPrimary: AppColors.backgroundDeep,
              surface: AppColors.surface,
              onSurface: AppColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Widget _buildInterestsField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Interests",
              style: TextStyle(
                color: AppColors.primaryLavender,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _interestsOptions.map((i) {
                final selected = _selectedInterests.contains(i);
                return FilterChip(
                  label: Text(
                    i,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textMedium,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) _selectedInterests.add(i);
                    else _selectedInterests.remove(i);
                  }),
                  selectedColor: AppColors.secondaryTeal, 
                  backgroundColor: AppColors.backgroundDeep, 
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? AppColors.secondaryTeal : AppColors.textDisabled,
                      width: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String title,
    required List<String> options,
    required List<String> selected,
    required Function(List<String>) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.primaryLavender,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMedium)),
                  selected: isSelected,
                  onSelected: (v) {
                    final newSelected = List<String>.from(selected);
                    if (v) {
                      newSelected.add(option);
                    } else {
                      newSelected.remove(option);
                    }
                    onChanged(newSelected);
                  },
                  selectedColor: AppColors.secondaryTeal,
                  backgroundColor: AppColors.backgroundDeep,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppColors.secondaryTeal : AppColors.textDisabled),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityField() {
    final List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final List<String> shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Work Availability *",
                      style: TextStyle(
                        color: AppColors.primaryLavender,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "Set your available time slots",
                      style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Feather.plus_circle, color: AppColors.secondaryTeal, size: 28),
                  onPressed: _addAvailabilityGroup,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_availabilityGroups.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDeep.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textDisabled.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Feather.clock, color: AppColors.textDisabled, size: 32),
                    SizedBox(height: 8),
                    Text(
                      "No availability slots added yet",
                      style: TextStyle(color: AppColors.textDisabled, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ..._availabilityGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              final List<String> selectedDays = List<String>.from(group['days']);

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryLavender.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Select Days", style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold, fontSize: 13)),
                        GestureDetector(
                          onTap: () => _removeAvailabilityGroup(index),
                          child: Icon(Feather.x, color: AppColors.error, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (dayIdx) {
                          final day = weekDays[dayIdx];
                          final isSelected = selectedDays.contains(day);
                          return GestureDetector(
                            onTap: () => _toggleDayInGroup(index, day),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: 4),
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.secondaryTeal : AppColors.textDisabled.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                shortDays[dayIdx],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textMedium,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTimeRange(index, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.elevation,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("START TIME", style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    (group['start'] as TimeOfDay).format(context),
                                    style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Feather.arrow_right, color: AppColors.textDisabled, size: 16),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTimeRange(index, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.elevation,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("END TIME", style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    (group['end'] as TimeOfDay).format(context),
                                    style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Social Links (optional)",
                  style: TextStyle(
                    color: AppColors.primaryLavender,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Feather.plus, color: AppColors.primaryLavender),
                  onPressed: _addSocialLink,
                ),
              ],
            ),
            ..._socialLinks.asMap().entries.map((entry) {
              final index = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextFormField(
                          decoration: InputDecoration(
                            hintText: "https://...",
                            hintStyle: TextStyle(color: AppColors.textDisabled),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          style: TextStyle(color: AppColors.textHigh),
                          onChanged: (value) => _updateSocialLink(index, value),
                        ),
                      ),
                    ),
                    if (_socialLinks.length > 1)
                      IconButton(
                        icon: Icon(Feather.x, color: AppColors.error),
                        onPressed: () => _removeSocialLink(index),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationsField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Certifications (optional)",
              style: TextStyle(
                color: AppColors.primaryLavender,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            if (_certificationFiles.isNotEmpty)
              ..._certificationFiles.map((file) => ListTile(
                leading: Icon(Feather.file, color: AppColors.primaryLavender),
                title: Text(file.path.split('/').last, style: TextStyle(color: AppColors.textHigh)),
                trailing: IconButton(
                  icon: Icon(Feather.trash_2, color: AppColors.error),
                  onPressed: () => setState(() => _certificationFiles.remove(file)),
                ),
              )).toList(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickCertificationFiles,
                icon: Icon(Feather.upload),
                label: Text("Upload Certifications"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primaryLavender,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAccountTypeTitle() {
    switch (widget.accountType) {
      case AccountType.personal:
        return "Personal Account";
      case AccountType.organization:
        return "Organization Account";
      case AccountType.therapist:
        return "Therapist Account";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FemnBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // FEMN LOGO
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage("assets/default_avatar.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Femn",
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLavender,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _getStepTitle(),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Step ${_currentStep + 1} of ${_getTotalSteps()}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.primaryLavender,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 30),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Step-specific content
                        _buildAccountTypeSpecificForm(),

                        SizedBox(height: 30),

                        // Action buttons
                        _isLoading
                            ? CircularProgressIndicator(color: AppColors.primaryLavender)
                            : Row(
                                children: [
                                  if (_currentStep > 0) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _previousStep,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.primaryLavender),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        child: Text("Back", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryLavender,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        elevation: 4,
                                        shadowColor: Colors.black.withOpacity(0.2),
                                      ),
                                      child: Text(
                                        _currentStep == _getTotalSteps() - 1 ? "Sign Up" : "Next",
                                        style: TextStyle(
                                            color: AppColors.backgroundDeep,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeSpecificForm() {
    switch (widget.accountType) {
      case AccountType.personal:
        return _buildPersonalForm();
      case AccountType.organization:
        return _buildOrganizationForm();
      case AccountType.therapist:
        return _buildTherapistForm();
    }
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.backgroundDeep)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      String? error = await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);
      if (error != null) {
        _showError(error);
      } else {
        // Check for deactivation
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            if (doc.exists && doc.data()?['isActive'] == false) {
              bool? reactivate = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text("Reactivate Account?", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
                  content: Text(
                    "Your account is currently deactivated. Would you like to reactivate it and log in?",
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel", style: TextStyle(color: AppColors.textDisabled)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("Reactivate", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (reactivate == true) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isActive': true});
              } else {
                await AuthService().signOut();
                setState(() => _isLoading = false);
                return;
              }
            }
          } catch (e) {
            print("Error checking active status: $e");
          }
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FeedScreen()), 
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/femn_state.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.9), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // FEMN LOGO
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage("assets/default_avatar.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Femn",
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLavender,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Welcome Back!",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppColors.textMedium,
                    ),
                  ),
                  SizedBox(height: 40),
                  // FORM
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // EMAIL FIELD
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.elevation,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              cursorColor: AppColors.primaryLavender,
                              style: TextStyle(color: AppColors.textHigh),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.elevation,
                                hintText: "Email",
                                hintStyle: TextStyle(color: AppColors.textDisabled),
                                prefixIcon: Icon(Feather.mail, color: AppColors.primaryLavender),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) => value!.isEmpty ? "Enter your email" : null,
                            ),
                          ),
                        ),
                        // PASSWORD FIELD
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.elevation,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              cursorColor: AppColors.primaryLavender,
                              style: TextStyle(color: AppColors.textHigh),
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.elevation,
                                hintText: "Password",
                                hintStyle: TextStyle(color: AppColors.textDisabled),
                                prefixIcon: Icon(Feather.lock, color: AppColors.primaryLavender),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Feather.eye_off : Feather.eye,
                                    color: AppColors.primaryLavender,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) => value!.isEmpty ? "Enter your password" : null,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // LOGIN BUTTON
                        _isLoading
                            ? CircularProgressIndicator(color: AppColors.primaryLavender)
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLavender,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  child: Text(
                                    "Login",
                                    style: TextStyle(
                                      color: AppColors.backgroundDeep,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                        SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AccountTypeScreen()),
                            );
                          },
                          child: Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(
                              color: AppColors.primaryLavender,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== HOME SCREEN ==========
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Femn", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: Container(
        // Subtle gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.elevation,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage("assets/default_avatar.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 30),
              Text(
                "Welcome to Femn!",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Connect, Share, and Heal Together",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textMedium,
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () {
                    AuthService().signOut().then((_) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => AuthScreen()),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface, // Surface colored button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                  ),
                  child: Text(
                    "Logout",
                    style: TextStyle(
                      color: AppColors.primaryLavender, // Lavender Text
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== AVAILABILITY SLOT MODEL ==========
class AvailabilitySlot {
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  AvailabilitySlot({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  AvailabilitySlot copyWith({
    String? day,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return AvailabilitySlot(
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
    };
  }

  static AvailabilitySlot fromMap(Map<String, dynamic> map) {
    return AvailabilitySlot(
      day: map['day'] ?? 'Monday',
      startTime: TimeOfDay(hour: map['startHour'] ?? 9, minute: map['startMinute'] ?? 0),
      endTime: TimeOfDay(hour: map['endHour'] ?? 17, minute: map['endMinute'] ?? 0),
    );
  }
}
