import 'package:femn/feed/addpost.dart';
import 'package:femn/circle/groups.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/hub_screens/messaging.dart';
import 'package:femn/hub_screens/wellness.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT YOUR COLORS FILE
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'auth/auth.dart';
import 'hub_screens/post.dart';
import 'circle/campaign.dart'; // Ensure filename matches (campaign.dart or campaigns.dart)
import 'auth/auth_provider.dart';
import 'customization/fonts.dart';
import 'package:app_links/app_links.dart'; // <--- ADD THIS IMPORT
import 'dart:async';
import 'package:femn/services/deep_link_service.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:femn/widgets/femn_background.dart';

import 'services/notification_service.dart'; // <--- Notification Service
import 'services/navigation_service.dart'; // <--- ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Activate App Check with debug providers
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(
    ChangeNotifierProvider(create: (context) => AuthProvider(), child: MyApp()),
  );

  // Initialize Notifications
  NotificationService().initialize();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'Femn',
      theme: ThemeData(
        // --- 1. Global Color Settings ---
        brightness: Brightness.dark,
        primaryColor: AppColors.primaryLavender,
        scaffoldBackgroundColor: Colors.transparent, // Deep Dark Background

        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryLavender,
          secondary: AppColors.secondaryTeal,
          surface: AppColors.surface,
          onPrimary: AppColors.backgroundDeep, // Dark text on Lavender buttons
          onSecondary: Colors.white, // White text on Teal elements
          onSurface: AppColors.textHigh, // Off-white text on surfaces
          error: AppColors.error,
        ),

        // --- 2. Text Theme (Defaulting to Off-White) ---
        textTheme: TextTheme(
          bodyLarge: primaryTextStyle(
            fontSize: 18.0,
            color: AppColors.textHigh,
          ),
          bodyMedium: primaryTextStyle(
            fontSize: 16.0,
            color: AppColors.textMedium,
          ),
          displayLarge: primaryVeryBoldTextStyle(
            fontSize: 32.0,
            color: AppColors.textHigh,
          ),
          displayMedium: primaryVeryBoldTextStyle(
            fontSize: 28.0,
            color: AppColors.textHigh,
          ),
          displaySmall: primaryVeryBoldTextStyle(
            fontSize: 24.0,
            color: AppColors.textHigh,
          ),
          headlineMedium: primaryVeryBoldTextStyle(
            fontSize: 20.0,
            color: AppColors.textHigh,
          ),
          headlineSmall: primaryVeryBoldTextStyle(
            fontSize: 18.0,
            color: AppColors.textHigh,
          ),
          titleLarge: primaryVeryBoldTextStyle(
            fontSize: 16.0,
            color: AppColors.textHigh,
          ),
          titleMedium: secondaryTextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
          titleSmall: secondaryTextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
          bodySmall: secondaryTextStyle(
            fontSize: 12.0,
            color: AppColors.textMedium,
          ),
          labelLarge: secondaryVeryBoldTextStyle(
            fontSize: 16.0,
            color: AppColors.textHigh,
          ),
          labelSmall: secondaryTextStyle(
            fontSize: 10.0,
            color: AppColors.textMedium,
          ),
        ),

        // --- 3. Component Themes ---
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.primaryLavender),
          titleTextStyle: TextStyle(
            color: AppColors.textHigh,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLavender,
            foregroundColor: AppColors.backgroundDeep, // Dark text on button
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: secondaryVeryBoldTextStyle(
              fontSize: 16,
              color: AppColors.backgroundDeep,
            ),
            elevation: 2,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.elevation, // Dark container for inputs
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.primaryLavender,
              width: 1.5,
            ),
          ),
          labelStyle: secondaryTextStyle(color: AppColors.textMedium),
          hintStyle: secondaryTextStyle(color: AppColors.textDisabled),
        ),

        cardTheme: CardThemeData(
          color: AppColors.surface, // Dark surface for cards
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        iconTheme: IconThemeData(color: AppColors.primaryLavender),

        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      ),
      builder: (context, child) {
        return FemnBackground(child: child!);
      },
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                User? user = snapshot.data;
                return user == null ? LoginScreen() : HomeScreen();
              }
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLavender,
                  ),
                ),
              );
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

  // --- DEEP LINKING VARIABLES ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final List<Widget> _screens = [
    FeedScreen(),
    GroupsScreen(),
    WellnessScreen(),
    CampaignsScreen(),
    MessagingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // <--- Initialize Listener on Startup
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // <--- Clean up when screen closes
    super.dispose();
  }

  // --- DEEP LINKING LOGIC ---
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Handle "Cold Start" (App was closed, link opened it)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (e) {
      print("Deep Link Error: $e");
    }

    // 2. Handle "Warm Start" (App was in background, link brought it to front)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });
  }

  Future<void> _handleLink(Uri uri) async {
    print("Link received: $uri");

    if (uri.pathSegments.contains('post')) {
      final String postId = uri.pathSegments.last;

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLavender),
        ),
      );

      try {
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();

        // Dismiss loading
        if (mounted) Navigator.pop(context);

        if (doc.exists) {
          final data = doc.data();
          final userId = data?['userId'];

          if (userId != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: postId,
                  userId: userId,
                  source: 'deep_link',
                ),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error: Post has no author associated"),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Post not found"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context))
          Navigator.pop(context); // Ensure dialog closes
        print("Deep link navigation error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error opening post"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Allow background to show
      body: _screens[_currentIndex],
      extendBody: true, // Allows content to go behind the floating nav bar
      extendBodyBehindAppBar: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), // bottom spacing
        child: Align(
          alignment: Alignment.bottomCenter, // center horizontally
          child: Container(
            width:
                MediaQuery.of(context).size.width *
                0.8, // Slightly wider for comfort
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.95), // Dark Surface
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.4,
                  ), // Stronger shadow for depth in dark mode
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: AppColors.elevation, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Feather.home, "Home", 0),
                _buildNavItem(Feather.hexagon, "Circle", 1),
                _buildNavItem(Feather.user, "You", 2),
                // _buildNavItem(Feather.flag, "Campaigns", 3), // Optional: Uncomment if you want 5 items
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
          // Use Teal for selected state background, heavily transparent
          color: isSelected
              ? AppColors.secondaryTeal.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isSelected ? 24 : 22,
              // Lavender for active, Medium Gray for inactive
              color: isSelected
                  ? AppColors.primaryLavender
                  : AppColors.textMedium.withOpacity(0.7),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLavender, // Lavender Text
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
