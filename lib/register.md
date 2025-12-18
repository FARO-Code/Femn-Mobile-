After the "dont have an account? sign up." is clicked i want the user to have three options. 1, sign up as a Personal Account, Organisation Account, or Therapist Account.

For Personal Account that is already settled in the code below (though make some adjustments for the fact it isnt the only account type now.. )

For Organisation Account the user should have the following feilds to fill [Organization Sign-Up Fields
Field	Required / Optional	Type / Input	Notes / Options
Organization Name	Required	Text	Official name
Email	Required	Text / Email	Work email for login & contact
Password	Required	Password	Must be 6+ chars
Category	Required	Dropdown	e.g., NGO, Startup, Women’s Group, Educational, Activist
Country	Required	Dropdown / Text	Country of operation
Mission Statement	Required	Text (short)	1–2 sentence summary
Logo	Optional	File / Image	Upload image
Website	Optional	Text / URL	Official website
Phone	Optional	Text / Number	Contact number
Address	Optional	Text	Physical office or mailing address
Social Links	Optional	Map / Multiple Text	e.g., Instagram, Twitter URLs
Bio / About Us	Optional	Text (long)	Extended description
Areas of Focus	Optional	Multi-select / Chips	e.g., Gender Equality, Education, Health, Advocacy]

and for Therapists they should have the following to fill [Therapist Sign-Up Fields (Updated)
Field	Required / Optional	Type / Input	Notes / Options
Full Name	Required	Text	Real or display name
Email	Required	Text / Email	For login & communication
Password	Required	Password	Must be 6+ chars
Username	Required	Text	Display handle
Account Type	Required	Hidden / Auto	Always "therapist"
Specialization	Required	Dropdown / Multi-select	e.g., Anxiety, Trauma, Relationships, Depression, Self-esteem
Experience Level	Required	Dropdown	Options: Certified Therapist, Psych Student, Peer Listener, Volunteer
Bio	Required	Text (short)	Intro about approach or motivation
Available Hours	Required	Text / Dropdown	e.g., Weekends only, Evenings 6–10 PM
Profile Image	Optional	File / Image	Upload profile pic
Certifications	Optional	File / Multiple Images	Upload certificates (if certified)
Languages	Optional	Multi-select / Chips	Languages spoken
Gender Preference	Optional	Dropdown	Open to all, Male only, Female only, Other
Region	Optional	Dropdown / Text	e.g., West Africa, Middle East, North America, Europe]


On an organisation profile page.. they also have the following adjustments/differences from a personal profile page (1. Profile Info

Keep:

Profile image/logo upload

Bio / description

Posts (can be updates, campaigns, announcements)

Followers/Following (maybe only followers, since orgs don’t usually follow)

Stats (posts count, followers, optional embers-like metric)

Change/Add:

Full Name → Organization Name

Username → Handle/Slug (e.g., @orgname)

Category/Type (dropdown: NGO, Non-profit, Company, Collective, Community)

Region/Location (e.g., West Africa, Middle East)

Website / Contact Email

Optional fields:

Phone number

Social media links

Mission statement

Year founded

Maybe show website button, contact button, or call/email button.

Highlight verified organization badge if applicable.

)

and for therapists (1. Profile Info

Keep:

Profile image / avatar

Full name

Bio (professional summary, experience, approach)Contact button (email, DM, or in-app messaging)

Show region and specialization prominently
Username / handle

Followers / stats (optional)

Change/Add:

Region (e.g., West Africa, Middle East…)

Specializations (multi-select dropdown: Anxiety, Depression, Relationship, Trauma…)

Qualifications / Credentials (text or upload certificate)

Optional fields:

Years of experience

Languages spoken

Availability (text or calendar, optional if you later add booking)

Social links / website) on their profile page


Lastly.. like verified badges in other apps [1. Organisations (general)

Icon: briefcase → symbolizes business/organisation professionally.

2. Verified Organisations

Icon: check-circle → a universal “verified” tick badge.

3. Therapists (general)

Icon: user → simple, shows individual profile / professional.

4. Verified Therapists

Icon: user-check → combines the person + verified tick, clearly shows credibility.]


Dont add verification feautres yet since i havent created a universal admin.. but leave the code open to future additions of it


Now give me the full code










[import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  Future<String?> signIn(String email, String password) async {
    return await _authService.signIn(email, password);
  }
  
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> interests,
    String profileImage = '',
    String bio = '', // Add this parameter
  }) async {
    // FIXED: Use _authService.signUp instead of trying to access _auth and _firestore directly
    return await _authService.signUp(
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
  
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}] auth_provider.dart













[import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// ========== AUTH SERVICE ==========
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // In AuthService signUp function, update the user data:
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'profileImage': profileImage,
        'interests': interests,
        'followers': [],
        'following': [],
        'posts': 0,
        'embers': 0, // NEW: Initialize Embers to 0
        'createdAt': DateTime.now(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
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

// ========== LOGIN SCREEN ==========
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
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade400,
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
      if (error != null) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade200, Colors.pink.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo / Icon
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(Icons.favorite, color: Colors.pink.shade600, size: 50),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Femn",
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Welcome Back!",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: Colors.pink.shade900),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Email",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.pink.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) =>
                                  value!.isEmpty ? "Enter your email" : null,
                            ),
                          ),
                          // Password
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _passwordController,
                              style: TextStyle(color: Colors.pink.shade900),
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Password",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.pink.shade600),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.pink.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? "Enter your password" : null,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Submit button
                          _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: Text(
                                      "Login",
                                      style: TextStyle(
                                          color: Colors.pink.shade600,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => SignupScreen()));
                            },
                            child: Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}

// ========== SIGNUP SCREEN ==========
class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _profileImage;
  DateTime? _dateOfBirth;

  List<String> _selectedInterests = [];

  final List<String> _interestsOptions = [
    'Feminist literature',
    'Gender equality activism',
    'Mental health awareness',
    'Body positivity',
    'LGBTQ+ support',
    'Career & entrepreneurship',
    'Women in tech',
    'Health & wellness',
    'Period & reproductive health',
    'Art & creativity',
    'Social justice',
    'Environmental activism',
    'Self-care & mindfulness',
    'Politics & policy',
    'Personal growth & motivation',
    'Education & learning',
    'Intersectional feminism',
    'Fashion & style',
    'Travel & cultural exploration',
    'Networking & mentorship'
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      if (_dateOfBirth == null) {
        _showError("Please select your date of birth");
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showError("Passwords do not match");
        return;
      }

      setState(() => _isLoading = true);

      String profileUrl = '';
      if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_profileImage!);
        profileUrl = await ref.getDownloadURL();
      }

      String? error = await AuthService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        interests: _selectedInterests,
        profileImage: profileUrl,
      );

      setState(() => _isLoading = false);
      if (error != null) {
        _showError(error);
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade200, Colors.pink.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo / Icon
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(Icons.favorite, color: Colors.pink.shade600, size: 50),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Femn",
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Create your account",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 30),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Profile Image
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              backgroundColor: Colors.white.withOpacity(0.9),
                              child: _profileImage == null
                                  ? Icon(Icons.camera_alt, size: 40, color: Colors.pink.shade600)
                                  : null,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Email
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: Colors.pink.shade900),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Email",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.pink.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty ? "Enter your email" : null,
                            ),
                          ),
                          // Password
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _passwordController,
                              style: TextStyle(color: Colors.pink.shade900),
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Password",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.pink.shade600),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.pink.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => v!.length < 6
                                  ? "Password must be 6+ chars"
                                  : null,
                            ),
                          ),
                          // Confirm Password
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              style: TextStyle(color: Colors.pink.shade900),
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Confirm Password",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.pink.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => v != _passwordController.text
                                  ? "Passwords do not match"
                                  : null,
                            ),
                          ),
                          // Username
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _usernameController,
                              style: TextStyle(color: Colors.pink.shade900),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Username",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.person_outline, color: Colors.pink.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? "Enter a username" : null,
                            ),
                          ),
                          // Full Name
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _fullNameController,
                              style: TextStyle(color: Colors.pink.shade900),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                hintText: "Full Name",
                                hintStyle: TextStyle(color: Colors.pink.shade300),
                                prefixIcon: Icon(Icons.badge_outlined, color: Colors.pink.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? "Enter your full name" : null,
                            ),
                          ),
                          // Date of Birth
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  _dateOfBirth == null
                                      ? "Select Date of Birth"
                                      : "DOB: ${_dateOfBirth!.toLocal()}".split(' ')[0],
                                  style: TextStyle(
                                    color: Colors.pink.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              trailing: Icon(Icons.calendar_today, color: Colors.pink.shade600),
                              onTap: _selectDOB,
                            ),
                          ),
                          // Interests
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Select Interests",
                                    style: TextStyle(
                                      color: Colors.pink.shade900,
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
                                            color: selected ? Colors.white : Colors.pink.shade700,
                                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: selected,
                                        onSelected: (v) => setState(() {
                                          if (v) _selectedInterests.add(i);
                                          else _selectedInterests.remove(i);
                                        }),
                                        selectedColor: Colors.pink.shade600,
                                        backgroundColor: Colors.pink.shade50,
                                        checkmarkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: selected 
                                                ? Colors.pink.shade600 
                                                : Colors.pink.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          // Submit button
                          _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: Text(
                                      "Sign Up",
                                      style: TextStyle(
                                          color: Colors.pink.shade600,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}] auth.dart













[import 'package:femn/addpost.dart';
import 'package:femn/groups.dart';
import 'package:femn/messaging.dart';
import 'package:femn/wellness.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'auth.dart';
import 'post.dart';
import 'campaign.dart';
import 'auth_provider.dart';
import 'fonts.dart'; // Import the fonts file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Femn',
      theme: ThemeData(
        primaryColor: Colors.pink.shade100,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: Colors.pink.shade200,
          secondary: Colors.pink.shade400,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          error: Colors.red.shade400,
        ),
        textTheme: TextTheme(
          bodyLarge: primaryTextStyle(fontSize: 18.0),
          bodyMedium: primaryTextStyle(fontSize: 16.0),
          displayLarge: primaryVeryBoldTextStyle(fontSize: 32.0),
          displayMedium: primaryVeryBoldTextStyle(fontSize: 28.0),
          displaySmall: primaryVeryBoldTextStyle(fontSize: 24.0),
          headlineMedium: primaryVeryBoldTextStyle(fontSize: 20.0),
          headlineSmall: primaryVeryBoldTextStyle(fontSize: 18.0),
          titleLarge: primaryVeryBoldTextStyle(fontSize: 16.0),
          titleMedium: secondaryTextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          titleSmall: secondaryTextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
          bodySmall: secondaryTextStyle(fontSize: 12.0),
          labelLarge: secondaryVeryBoldTextStyle(fontSize: 16.0),
          labelSmall: secondaryTextStyle(fontSize: 10.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink.shade300,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: secondaryVeryBoldTextStyle(fontSize: 16),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.pink.shade50,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          labelStyle: secondaryTextStyle(color: Colors.pink.shade700),
        ),
        cardTheme: CardThemeData(
          color: Colors.pink.shade50,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                User? user = snapshot.data;
                return user == null ? LoginScreen() : HomeScreen();
              }
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            },
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Home Screen with Bottom Navigation
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    FeedScreen(),
    GroupsScreen(),
    WellnessScreen(),
    CampaignsScreen(),
    MessagingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), // bottom spacing
        child: Align(
          alignment: Alignment.bottomCenter, // center horizontally
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE1E0),
                borderRadius: BorderRadius.circular(40),
                // removed border for a cleaner look
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8), // soft downward shadow
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Feather.home, "Home", 0),
                  _buildNavItem(Feather.hexagon, "Circle", 1),
                  _buildNavItem(Feather.user, "You", 2),
                  _buildNavItem(Feather.message_circle, "Inbox", 4),
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFA3B5).withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isSelected ? 26 : 22,
              color: const Color(0xFFE35773)
                  .withOpacity(isSelected ? 1.0 : 0.7),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE35773),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

}

// --- FIREBASE SETUP ---
class FirestoreService {}] main.dart













[import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'addpost.dart'; // Make sure to import your AddPostScreen
import 'settings.dart';

// Profile Screen
class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({required this.userId});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isEditing = false;
  File? _profileImageFile;
  bool _isOwnProfile = false;
  final Map<String, String?> _profileImageCache = {};

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    // Call the fix function when the profile screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fixMissingBioFields();
    });
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
      // Upload new profile image
      await _uploadProfileImage();
    }
  }

  Future<void> _saveProfileChanges() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'fullName': _fullNameController.text,
            'bio': _bioController.text,
          });
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImageFile == null) return;
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(
            '$currentUserId.jpg',
          ); // match your folder & filename convention
      // upload
      await storageRef.putFile(_profileImageFile!);
      // get download URL
      final downloadURL = await storageRef.getDownloadURL();
      // write URL into Firestore (merge to avoid wiping other fields)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({'profileImage': downloadURL}, SetOptions(merge: true));
      // cache it locally
      _profileImageCache[currentUserId] = downloadURL;
      // optional UI refresh
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile picture updated!')));
    } catch (e, st) {
      print('Error uploading profile image: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    }
  }

  // Add this function to your ProfileScreen class
  Future<void> fixMissingBioFields() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
              'bio': '', // This will create the bio field if it doesn't exist
            }, SetOptions(merge: true)); // merge: true keeps existing data
        print('Bio field added successfully');
      }
    } catch (e) {
      print('Error adding bio field: $e');
    }
  }

  // cached fetcher used by FutureBuilder in your avatar widget
  Future<String?> _getProfileImageUrl(String uid) async {
    // return cached if available (including explicit null)
    if (_profileImageCache.containsKey(uid)) return _profileImageCache[uid];
    try {
      // try the most common filename(s) — adjust to match your real storage naming
      final possiblePaths = [
        'profile_images/$uid.jpg',
        'profile_images/$uid.jpeg',
        'profile_images/$uid.png',
        'profile_images/$uid.webp',
      ];
      String? found;
      for (final p in possiblePaths) {
        try {
          final url = await FirebaseStorage.instance
              .ref()
              .child(p)
              .getDownloadURL();
          found = url;
          break;
        } catch (e) {
          // ignore, try next candidate
        }
      }
      // cache result (even if null) to avoid repeated lookups
      _profileImageCache[uid] = found;
      return found;
    } catch (e) {
      print('Unexpected error getting profile image url for $uid: $e');
      _profileImageCache[uid] = null;
      return null;
    }
  }

  // one-time backfill for existing users whose Firestore profileImage is empty
  Future<void> backfillProfileImages() async {
    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();
      int updated = 0;
      for (final doc in usersSnap.docs) {
        final uid = doc.id;
        final data = doc.data();
        final existing = (data['profileImage'] ?? '') as String;
        if (existing.isNotEmpty) continue; // already set
        // try to find a matching file in Storage
        final url = await _getProfileImageUrl(uid);
        if (url != null && url.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'profileImage': url,
          }, SetOptions(merge: true));
          updated++;
        }
      }
      print('Backfill complete, updated $updated user(s)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backfill complete, updated $updated user(s)')),
      );
    } catch (e) {
      print('Backfill failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backfill failed: $e')));
    }
  }

  // Build the posts grid with the add post button
  Widget _buildPostsGrid(String userId, bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts'));
        }
        final posts = snapshot.hasData ? snapshot.data!.docs : [];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: isOwnProfile
                ? posts.length + 1
                : posts.length, // Add 1 for the create post button
            itemBuilder: (context, index) {
              // If it's the first item and it's the user's own profile, show create post button
              if (isOwnProfile && index == 0) {
                return _buildCreatePostButton();
              }
              // Adjust index for posts since we added the create post button at index 0
              final postIndex = isOwnProfile ? index - 1 : index;
              if (postIndex < 0 || postIndex >= posts.length) {
                return Container(); // Safety check
              }
              var post = posts[postIndex];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PostDetailScreen(postId: post.id, userId: userId),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    child: post['mediaType'] == 'image'
                        ? CachedNetworkImage(
                            imageUrl: post['mediaUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.image, color: Colors.grey[400]),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error),
                          )
                        : Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Build the create post button
  Widget _buildCreatePostButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddPostScreen()),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Color(0xFFFFB7C5), width: 1.5),
        ),
        color: const Color(0xFFFFE1E0), // same soft pink bg as other cards
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 40,
                  color: Color(0xFFE56982), // accent color to match
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create Post',
                  style: TextStyle(
                    color: Color(0xFFE56982),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final isOwnProfile = widget.userId == currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: isOwnProfile
            ? [
                // 👇 Settings button
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsScreen(), // create this screen
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found'));
          }
          var user = snapshot.data!;
          // Initialize controllers with current values
          if (_fullNameController.text.isEmpty) {
            _fullNameController.text = user['fullName'];
          }
          if (_bioController.text.isEmpty) {
            _bioController.text =
                user['bio'] ?? ''; // FIXED: Added ?? '' for safety
          }
          return Column(
            children: [
              // Profile header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: user['profileImage'].isNotEmpty
                              ? CachedNetworkImageProvider(user['profileImage'])
                              : AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                        ),
                        if (isOwnProfile)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 12, // Reduced radius for smaller size
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              child: IconButton(
                                padding:
                                    EdgeInsets.zero, // remove extra padding
                                constraints:
                                    BoxConstraints(), // remove default size
                                icon: Icon(
                                  _isEditing ? Icons.save : Icons.edit,
                                  color: Colors.white,
                                  size:
                                      14, // slightly smaller so it stays centered
                                ),
                                onPressed: () {
                                  if (_isEditing) {
                                    _saveProfileChanges();
                                  } else {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                            controller: _fullNameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                            ),
                          )
                        : Text(
                            user['fullName'],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    SizedBox(height: 2),
                    Text('@${user['username']}'),
                    SizedBox(height: 0),
                    _isEditing
                        ? TextFormField(
                            controller: _bioController,
                            decoration: InputDecoration(
                              labelText: 'Bio',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          )
                        : Text(
                            user['bio'] ?? 'No bio yet', // fallback text
                            textAlign: TextAlign.center,
                          ),
                    SizedBox(height: 4),
                    // Pill-shaped stats container
                    ProfileStatsWidget(
                      userId: widget.userId,
                      isOwnProfile: isOwnProfile,
                    ),
                    if (!isOwnProfile) SizedBox(height: 16),
                    if (!isOwnProfile)
                      ElevatedButton(
                        onPressed: () async {
                          // Follow/unfollow logic
                          List followers = List.from(user['followers']);
                          if (followers.contains(currentUserId)) {
                            // Unfollow
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .update({
                                  'followers': FieldValue.arrayRemove([
                                    currentUserId,
                                  ]),
                                });
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .update({
                                  'following': FieldValue.arrayRemove([
                                    widget.userId,
                                  ]),
                                });
                          } else {
                            // Follow
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .update({
                                  'followers': FieldValue.arrayUnion([
                                    currentUserId,
                                  ]),
                                });
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .update({
                                  'following': FieldValue.arrayUnion([
                                    widget.userId,
                                  ]),
                                });
                            // Create follow notification
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .add({
                                  'type': 'follow',
                                  'fromUserId': currentUserId,
                                  'toUserId': widget.userId,
                                  'timestamp': DateTime.now(),
                                  'read': false,
                                });
                          }
                        },
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.userId)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.hasData) {
                              List followers = List.from(
                                userSnapshot.data!['followers'],
                              );
                              return Text(
                                followers.contains(currentUserId)
                                    ? 'Unfollow'
                                    : 'Follow',
                              );
                            }
                            return Text('Follow');
                          },
                        ),
                      ),
                  ],
                ),
              ),
              // Posts grid section
              Expanded(child: _buildPostsGrid(widget.userId, isOwnProfile)),
            ],
          );
        },
      ),
    );
  }
}

// Other User Profile Screen (simplified version)
// Update the OtherUserProfileScreen to be a stateful widget
class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  const OtherUserProfileScreen({required this.userId});
  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (userDoc.exists) {
      final followers = List<String>.from(userDoc['followers'] ?? []);
      setState(() {
        _isFollowing = followers.contains(currentUserId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found'));
          }
          var user = snapshot.data!;
          return Column(
            children: [
              // Profile header (similar to ProfileScreen but without edit options)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: user['profileImage'].isNotEmpty
                          ? CachedNetworkImageProvider(user['profileImage'])
                          : AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                    ),
                    SizedBox(height: 8),
                    Text(
                      user['fullName'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('@${user['username']}'),
                    SizedBox(height: 0),
                    Text(
                      user['bio'] ?? 'No bio yet', // FIXED: Added fallback text
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    ProfileStatsWidget(
                      userId: widget.userId,
                      isOwnProfile: false,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (_isFollowing) {
                          // Unfollow
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.userId)
                              .update({
                                'followers': FieldValue.arrayRemove([
                                  currentUserId,
                                ]),
                              });
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUserId)
                              .update({
                                'following': FieldValue.arrayRemove([
                                  widget.userId,
                                ]),
                              });
                        } else {
                          // Follow
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.userId)
                              .update({
                                'followers': FieldValue.arrayUnion([
                                  currentUserId,
                                ]),
                              });
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUserId)
                              .update({
                                'following': FieldValue.arrayUnion([
                                  widget.userId,
                                ]),
                              });
                        }
                        setState(() {
                          _isFollowing = !_isFollowing;
                        });
                      },
                      child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                    ),
                  ],
                ),
              ),
              // User's posts grid (using staggered view)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: widget.userId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading posts'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No posts yet'));
                    }
                    final posts = snapshot.data!.docs;
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MasonryGridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          var post = posts[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(
                                    postId: post.id,
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                child: post['mediaType'] == 'image'
                                    ? CachedNetworkImage(
                                        imageUrl: post['mediaUrl'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Colors.grey[300],
                                              child: Icon(
                                                Icons.image,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.error),
                                      )
                                    : Container(
                                        color: Colors.black,
                                        child: Center(
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Followers/Following Screen
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;
  const FollowListScreen({required this.userId, required this.showFollowers});
  @override
  _FollowListScreenState createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showFollowers ? 'Followers' : 'Following'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(child: Text('User not found'));
          }
          final userData = userSnapshot.data!;
          final List<String> userIds = List<String>.from(
            widget.showFollowers
                ? userData['followers']
                : userData['following'],
          );
          if (userIds.isEmpty) {
            return Center(
              child: Text(
                widget.showFollowers
                    ? 'No followers yet'
                    : 'Not following anyone',
              ),
            );
          }
          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final userId = userIds[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(),
                      title: Text('Loading...'),
                    );
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(
                      leading: CircleAvatar(),
                      title: Text('User not found'),
                    );
                  }
                  final user = userSnapshot.data!;
                  return _buildUserTile(
                    user['uid'],
                    user['username'],
                    user['fullName'],
                    user['profileImage'],
                    isFollowing: _isOwnProfile
                        ? null // Don't show follow button for own profile
                        : List.from(
                            userData['followers'],
                          ).contains(currentUserId),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile(
    String userId,
    String username,
    String fullName,
    String profileImage, {
    bool? isFollowing,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profileImage.isNotEmpty
            ? CachedNetworkImageProvider(profileImage)
            : AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(username),
      subtitle: Text(fullName),
      trailing: _isOwnProfile
          ? null
          : isFollowing == null
          ? null
          : ElevatedButton(
              onPressed: () async {
                // Follow/unfollow logic
                if (isFollowing) {
                  // Unfollow
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                        'followers': FieldValue.arrayRemove([currentUserId]),
                      });
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .update({
                        'following': FieldValue.arrayRemove([userId]),
                      });
                } else {
                  // Follow
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                        'followers': FieldValue.arrayUnion([currentUserId]),
                      });
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .update({
                        'following': FieldValue.arrayUnion([userId]),
                      });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? Colors.grey[300]
                    : Theme.of(context).colorScheme.secondary,
                foregroundColor: isFollowing ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(isFollowing ? 'Following' : 'Follow'),
            ),
      onTap: () {
        if (userId == currentUserId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: userId),
            ),
          );
        }
      },
    );
  }
}

class ProfileStatsWidget extends StatelessWidget {
  final String userId;
  final bool isOwnProfile;
  ProfileStatsWidget({required this.userId, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE1E0),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFFFB7C5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // POSTS
              _buildStat(
                label: "Posts",
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
              ),
              // FOLLOWERS
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FollowListScreen(userId: userId, showFollowers: true),
                    ),
                  );
                },
                child: _buildStatFuture("Followers", userId, true),
              ),
              // FOLLOWING
              GestureDetector(
                onTap: isOwnProfile
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowListScreen(
                              userId: userId,
                              showFollowers: false,
                            ),
                          ),
                        );
                      }
                    : null,
                child: _buildStatFuture("Following", userId, false),
              ),
              // EMBERS
              _buildEmbersStat(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbersStat(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        int embers = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          embers = snapshot.data!['embers'] ?? 0;
        }
        return Column(
          children: [
            Text(
              "Embers",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE56982),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              embers.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFFE56982),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStat({
    required String label,
    required Stream<QuerySnapshot> stream,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE56982),
          ),
        ),
        const SizedBox(height: 2),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFFE56982),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatFuture(String label, String userId, bool followers) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE56982),
          ),
        ),
        const SizedBox(height: 2),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List list = List.from(
                snapshot.data![followers ? 'followers' : 'following'],
              );
              return Text(
                list.length.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFE56982),
                ),
              );
            }
            return const Text(
              "0",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFFE56982),
              ),
            );
          },
        ),
      ],
    );
  }
}
] profile.dart













[// settings.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'addpost.dart'; // Make sure to import your AddPostScreen
import 'profile.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                // Handle profile navigation
                // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Other screen components (if needed)
class OtherUserProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Other User Profile")),
      body: Center(child: Text("This is another user's profile.")),
    );
  }
}

class FollowListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Follow List")),
      body: Center(child: Text("List of followers/following.")),
    );
  }
}

// Example: ProfileStatsWidget (if not already defined elsewhere)
class ProfileStatsWidget extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;

  ProfileStatsWidget({required this.posts, required this.followers, required this.following});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text("$posts Posts"),
        Text("$followers Followers"),
        Text("$following Following"),
      ],
    );
  }
}] settings.dart













[import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Firebase Services
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;

// Auth Provider
class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password, String name) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'interests': [],
        'followers': 0,
        'following': 0,
        'pins': 0,
      });
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// Pin Model
class Pin {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String creatorId;
  final String creatorName;
  final String? websiteUrl;
  final int saves;
  final int likes;
  final DateTime createdAt;
  final List<String> tags;

  Pin({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.creatorId,
    required this.creatorName,
    this.websiteUrl,
    this.saves = 0,
    this.likes = 0,
    required this.createdAt,
    this.tags = const [],
  });

  factory Pin.fromMap(Map<String, dynamic> data, String id) {
    return Pin(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      websiteUrl: data['websiteUrl'],
      saves: data['saves'] ?? 0,
      likes: data['likes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'websiteUrl': websiteUrl,
      'saves': saves,
      'likes': likes,
      'createdAt': Timestamp.fromDate(createdAt),
      'tags': tags,
    };
  }
}

// Board Model
class Board {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final bool isSecret;
  final String? coverImageUrl;
  final int pinCount;
  final DateTime createdAt;
  final List<String> collaborators;

  Board({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    this.isSecret = false,
    this.coverImageUrl,
    this.pinCount = 0,
    required this.createdAt,
    this.collaborators = const [],
  });

  factory Board.fromMap(Map<String, dynamic> data, String id) {
    return Board(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      creatorId: data['creatorId'] ?? '',
      isSecret: data['isSecret'] ?? false,
      coverImageUrl: data['coverImageUrl'],
      pinCount: data['pinCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      collaborators: List<String>.from(data['collaborators'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'isSecret': isSecret,
      'coverImageUrl': coverImageUrl,
      'pinCount': pinCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'collaborators': collaborators,
    };
  }
}

// Pin Provider
class PinProvider with ChangeNotifier {
  final List<Pin> _pins = [];
  final List<Board> _boards = [];
  bool _isLoading = false;

  List<Pin> get pins => _pins;
  List<Board> get boards => _boards;
  bool get isLoading => _isLoading;

  Future<void> fetchPins() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('pins')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _pins.clear();
      for (var doc in snapshot.docs) {
        _pins.add(Pin.fromMap(doc.data(), doc.id));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching pins: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserBoards(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('boards')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _boards.clear();
      for (var doc in snapshot.docs) {
        _boards.add(Board.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching boards: $e');
      }
    }
  }

  Future<String> createPin({
    required String title,
    required String description,
    required Uint8List imageData,
    required String userId,
    required String userName,
    String? websiteUrl,
    List<String> tags = const [],
    required String boardId,
  }) async {
    try {
      // Upload image to storage
      final String fileName = 'pins/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snapshot = await uploadTask;
      final String imageUrl = await snapshot.ref.getDownloadURL();

      // Create pin document
      final pinDoc = _firestore.collection('pins').doc();
      final pin = Pin(
        id: pinDoc.id,
        title: title,
        description: description,
        imageUrl: imageUrl,
        creatorId: userId,
        creatorName: userName,
        websiteUrl: websiteUrl,
        tags: tags,
        createdAt: DateTime.now(),
      );

      await pinDoc.set(pin.toMap());

      // Add pin to board
      await _firestore.collection('boards').doc(boardId).update({
        'pinCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('board_pins').doc('${boardId}_${pinDoc.id}').set({
        'boardId': boardId,
        'pinId': pinDoc.id,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Update user pin count
      await _firestore.collection('users').doc(userId).update({
        'pins': FieldValue.increment(1),
      });

      _pins.insert(0, pin);
      notifyListeners();

      return pinDoc.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating pin: $e');
      }
      rethrow;
    }
  }

  Future<void> savePin(String pinId, String boardId, String userId) async {
    try {
      await _firestore.collection('saves').doc('${userId}_$pinId').set({
        'userId': userId,
        'pinId': pinId,
        'boardId': boardId,
        'savedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('pins').doc(pinId).update({
        'saves': FieldValue.increment(1),
      });

      // Update the local pin data
      final index = _pins.indexWhere((pin) => pin.id == pinId);
      if (index != -1) {
        _pins[index] = Pin(
          id: _pins[index].id,
          title: _pins[index].title,
          description: _pins[index].description,
          imageUrl: _pins[index].imageUrl,
          creatorId: _pins[index].creatorId,
          creatorName: _pins[index].creatorName,
          websiteUrl: _pins[index].websiteUrl,
          saves: _pins[index].saves + 1,
          likes: _pins[index].likes,
          createdAt: _pins[index].createdAt,
          tags: _pins[index].tags,
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving pin: $e');
      }
    }
  }

  Future<String> createBoard({
    required String name,
    required String description,
    required String userId,
    bool isSecret = false,
  }) async {
    try {
      final boardDoc = _firestore.collection('boards').doc();
      final board = Board(
        id: boardDoc.id,
        name: name,
        description: description,
        creatorId: userId,
        isSecret: isSecret,
        createdAt: DateTime.now(),
      );

      await boardDoc.set(board.toMap());
      _boards.add(board);
      notifyListeners();

      return boardDoc.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating board: $e');
      }
      rethrow;
    }
  }
}

// User Provider
class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = false;

  Map<String, dynamic>? get currentUserData => _currentUserData;
  bool get isLoading => _isLoading;

  Future<void> fetchCurrentUserData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _currentUserData = doc.data()!;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user data: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserInterests(String userId, List<String> interests) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'interests': interests,
      });
      _currentUserData?['interests'] = interests;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating interests: $e');
      }
    }
  }
}

// Auth Wrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null) {
      return const OnboardingScreen();
    } else {
      return const MainAppScreen();
    }
  }
}

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  final List<String> _selectedInterests = [];

  final List<Map<String, dynamic>> _onboardingPages = [
    {
      'title': 'Discover your inspiration',
      'description': 'Find ideas for all your projects and interests',
      'image': 'assets/onboarding1.png',
    },
    {
      'title': 'Save what you love',
      'description': 'Collect and organize your favorite ideas',
      'image': 'assets/onboarding2.png',
    },
    {
      'title': 'Create and share',
      'description': 'Share your own ideas with the world',
      'image': 'assets/onboarding3.png',
    },
  ];

  final List<String> _interests = [
    'Home Decor',
    'DIY & Crafts',
    'Fashion',
    'Food & Drink',
    'Photography',
    'Travel',
    'Art',
    'Technology',
    'Fitness',
    'Education',
    'Gardening',
    'Business',
  ];

  void _nextPage() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      // Navigate to sign up
    }
  }

  void _selectInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: _onboardingPages.length + 1,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (context, index) {
          if (index < _onboardingPages.length) {
            return _buildOnboardingPage(_onboardingPages[index]);
          } else {
            return _buildInterestsPage();
          }
        },
      ),
    );
  }

  Widget _buildOnboardingPage(Map<String, dynamic> page) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Image.asset(
            page['image'],
            height: 300,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          Text(
            page['title'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page['description'],
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(_currentPage == _onboardingPages.length - 1 ? 'Get Started' : 'Continue'),
          ),
          const SizedBox(height: 16),
          if (_currentPage < _onboardingPages.length - 1)
            TextButton(
              onPressed: () {
                _pageController.jumpToPage(_onboardingPages.length);
              },
              child: const Text('Skip'),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInterestsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick your interests'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select at least 5 interests to personalize your experience',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: _interests.length,
              itemBuilder: (context, index) {
                final interest = _interests[index];
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (_) => _selectInterest(interest),
                  selectedColor: Colors.red.withOpacity(0.2),
                  checkmarkColor: Colors.red,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.red : Colors.black,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedInterests.length >= 5
                  ? () {
                      // Save interests and navigate to auth
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// Auth Screen
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  Future<void> _signUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FEMN'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sign In'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSignInForm(authProvider),
          _buildSignUpForm(authProvider),
        ],
      ),
    );
  }

  Widget _buildSignInForm(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (authProvider.error != null)
            Text(
              authProvider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: authProvider.isLoading
                ? const CircularProgressIndicator()
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(AuthProvider authProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (authProvider.error != null)
            Text(
              authProvider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: authProvider.isLoading
                ? const CircularProgressIndicator()
                : const Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}

// Main App Screen
class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeFeedScreen(),
    const SearchScreen(),
    const CreatePinScreen(),
    const NotificationsScreen(),
    const ProfileScreen(userId: '',),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Home Feed Screen
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPins();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPins() async {
    final pinProvider = Provider.of<PinProvider>(context, listen: false);
    await pinProvider.fetchPins();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMorePins();
    }
  }

  Future<void> _loadMorePins() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    // Simulate loading more pins
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinProvider = Provider.of<PinProvider>(context);
    Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FEMN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              // Show feed tuning options
            },
          ),
        ],
      ),
      body: pinProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPins,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.7,
                ),
                itemCount: pinProvider.pins.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == pinProvider.pins.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final pin = pinProvider.pins[index];
                  return PinCard(pin: pin);
                },
              ),
            ),
    );
  }
}

// Pin Card Widget
class PinCard extends StatelessWidget {
  final Pin pin;

  const PinCard({super.key, required this.pin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PinDetailScreen(pin: pin),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  pin.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                pin.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${pin.saves}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 16),
                    onPressed: () {
                      // Show more options
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pin Detail Screen
class PinDetailScreen extends StatelessWidget {
  final Pin pin;

  const PinDetailScreen({super.key, required this.pin});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                pin.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.save_alt),
                onPressed: () {
                  _showSaveDialog(context, authProvider.user!.uid);
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  _sharePin(context);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pin.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (pin.websiteUrl != null)
                    ElevatedButton(
                      onPressed: () {
                        // Open website
                      },
                      child: const Text('Visit website'),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.push_pin, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${pin.saves} saves'),
                      const SizedBox(width: 16),
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${pin.likes} likes'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                // Like pin
              },
            ),
            IconButton(
              icon: const Icon(Icons.comment),
              onPressed: () {
                // Show comments
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                _showSaveDialog(context, authProvider.user!.uid);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Provider.of<PinProvider>(context, listen: false).fetchUserBoards(userId),
          builder: (context, snapshot) {
            final pinProvider = Provider.of<PinProvider>(context);
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save to board',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pinProvider.boards.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Create new board'),
                            onTap: () {
                              _createNewBoard(context);
                            },
                          );
                        }
                        final board = pinProvider.boards[index - 1];
                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(board.name),
                          onTap: () {
                            _saveToBoard(context, board.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveToBoard(BuildContext context, String boardId) {
    final pinProvider = Provider.of<PinProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    pinProvider.savePin(pin.id, boardId, authProvider.user!.uid);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pin saved!')),
    );
  }

  void _createNewBoard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final _boardNameController = TextEditingController();
        final _boardDescController = TextEditingController();
        bool _isSecret = false;

        return AlertDialog(
          title: const Text('Create new board'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _boardNameController,
                decoration: const InputDecoration(
                  labelText: 'Board name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _boardDescController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isSecret,
                    onChanged: (value) {
                      // Handle secret board
                    },
                  ),
                  const Text('Secret board'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pinProvider = Provider.of<PinProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                
                try {
                  final boardId = await pinProvider.createBoard(
                    name: _boardNameController.text,
                    description: _boardDescController.text,
                    userId: authProvider.user!.uid,
                    isSecret: _isSecret,
                  );
                  _saveToBoard(context, boardId);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating board: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _sharePin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                onTap: () {
                  // Copy link to clipboard
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share via...'),
                onTap: () {
                  // Share via native share sheet
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Create Pin Screen
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  Uint8List? _imageData;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageData = bytes;
      });
    }
  }

  Future<void> _createPin() async {
    if (_imageData == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image and title')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pinProvider = Provider.of<PinProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      await pinProvider.createPin(
        title: _titleController.text,
        description: _descriptionController.text,
        imageData: _imageData!,
        userId: authProvider.user!.uid,
        userName: userProvider.currentUserData?['name'] ?? 'User',
        websiteUrl: _websiteController.text.isNotEmpty ? _websiteController.text : null,
        boardId: 'default_board', // You might want to let user choose board
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin created successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating pin: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Pin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _createPin,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageData == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add image'),
                          ],
                        ),
                      )
                    : Image.memory(_imageData!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 800,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website URL (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }
}

// Search Screen
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SearchAppBar(),
      body: Center(
        child: Text('Search functionality would go here'),
      ),
    );
  }
}

// Search AppBar
class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SearchAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search for ideas',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }
}

// Notifications Screen
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: Center(
        child: Text('Notifications will appear here'),
      ),
    );
  }
}

// Profile Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required String userId});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.currentUserData == null && authProvider.user != null) {
      userProvider.fetchCurrentUserData(authProvider.user!.uid);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProvider.currentUserData?['name'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.currentUserData?['email'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Pins', userProvider.currentUserData?['pins'] ?? 0),
                      _buildStatColumn('Followers', userProvider.currentUserData?['followers'] ?? 0),
                      _buildStatColumn('Following', userProvider.currentUserData?['following'] ?? 0),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        authProvider.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}] app.dart