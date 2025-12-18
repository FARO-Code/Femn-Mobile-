import 'package:femn/addpost.dart';
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
class FirestoreService {}