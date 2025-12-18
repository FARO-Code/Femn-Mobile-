import 'dart:typed_data';
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
}