import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/widgets/femn_background.dart';
import '../services/therapy_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/therapy_models.dart';

class TherapyDiscoveryScreen extends StatefulWidget {
  @override
  _TherapyDiscoveryScreenState createState() => _TherapyDiscoveryScreenState();
}

class _TherapyDiscoveryScreenState extends State<TherapyDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TherapyService _therapyService = TherapyService();

  String _selectedCategory = 'All';
  List<String> _selectedSpecializations = [];
  bool _showAdvancedFilters = false;

  final List<String> _categories = [
    'All',
    'Anxiety',
    'Depression',
    'Trauma',
    'Relationships',
    'Stress',
    'Grief',
    'Addiction',
    'Self-esteem',
  ];

  final List<String> _specializationOptions = [
    'CBT',
    'EMDR',
    'Family Therapy',
    'Couples Counseling',
    'Art Therapy',
    'Trauma-Informed',
    'LGBTQ+ Affirming',
    'Mindfulness',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FemnBackground(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.only(
                top: 60.0,
                left: 24,
                right: 24,
                bottom: 20,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.elevation,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Feather.arrow_left,
                        color: AppColors.textHigh,
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Therapy',
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () => _showPendingRequests(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.elevation,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Feather.clock,
                        color: AppColors.primaryLavender,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.elevation,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppColors.textHigh),
                  decoration: InputDecoration(
                    hintText: 'Search therapists...',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    border: InputBorder.none,
                    icon: Icon(
                      Feather.search,
                      color: AppColors.primaryLavender,
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
            ),

            // Horizontal Category Filter (Circles Style)
            Container(
              height: 60,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategory = category;
                      // When clicking a main category, we might want to clear specific specializations or keep them?
                      // Keeping them allows for "Anxiety" + "CBT".
                    }),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondaryTeal
                            : AppColors.elevation,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isSelected ? 0.3 : 0.1,
                            ),
                            blurRadius: isSelected ? 6 : 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textMedium,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // "I specialise in" Filter (Multi-select)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8,
              ),
              child: GestureDetector(
                onTap: () => setState(
                  () => _showAdvancedFilters = !_showAdvancedFilters,
                ),
                child: Row(
                  children: [
                    Text(
                      "Filter by Specialization",
                      style: TextStyle(
                        color: AppColors.primaryLavender,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      _showAdvancedFilters
                          ? Feather.chevron_up
                          : Feather.chevron_down,
                      color: AppColors.primaryLavender,
                    ),
                  ],
                ),
              ),
            ),

            if (_showAdvancedFilters)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8,
                ),
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
                        "I specialise in",
                        style: TextStyle(
                          color: AppColors.primaryLavender,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _specializationOptions.map((option) {
                          final isSelected = _selectedSpecializations.contains(
                            option,
                          );
                          return FilterChip(
                            label: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMedium,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (v) {
                              setState(() {
                                if (v)
                                  _selectedSpecializations.add(option);
                                else
                                  _selectedSpecializations.remove(option);
                              });
                            },
                            selectedColor: AppColors.secondaryTeal,
                            backgroundColor: AppColors.backgroundDeep,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.secondaryTeal
                                    : AppColors.textDisabled,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Therapists List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _therapyService.getTherapists(
                  situation: _selectedCategory == 'All'
                      ? null
                      : _selectedCategory,
                  // We can't easily filter strictly by multiple specializations in Firestore query without composite indexes or client side filtering.
                  // For now, we will filter client-side for the multi-select.
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryLavender,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No therapists found.",
                        style: TextStyle(color: AppColors.textMedium),
                      ),
                    );
                  }

                  // Client-side filtering for search text and multi-select specializations
                  var therapists = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final search = _searchController.text.toLowerCase();

                    // Search Filter
                    if (search.isNotEmpty && !name.contains(search))
                      return false;

                    // Specialization Filter (Match ANY or ALL? Usually ANY for filters, or ALL for strict. Let's do partial match overlap)
                    if (_selectedSpecializations.isNotEmpty) {
                      final specs = List<String>.from(
                        data['specialization'] ?? [],
                      );
                      // Check if therapist has any of the selected specializations? Or all?
                      // "I specialise in" X, Y usually means I want someone who knows X OR Y.
                      // But maybe user wants someone who knows X AND Y.
                      // Let's go with ANY for now as it's more permissive.
                      if (!specs.any(
                        (s) => _selectedSpecializations.contains(s),
                      ))
                        return false;
                    }

                    return true;
                  }).toList();

                  if (therapists.isEmpty) {
                    return Center(
                      child: Text(
                        "No matching therapists.",
                        style: TextStyle(color: AppColors.textMedium),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: therapists.length,
                    itemBuilder: (context, index) {
                      final therapistData =
                          therapists[index].data() as Map<String, dynamic>;
                      return _buildTherapistCard(
                        therapistData,
                        therapists[index].id,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistCard(Map<String, dynamic> data, String id) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image:
                    (data['profileImage'] != null &&
                        data['profileImage'].isNotEmpty)
                    ? CachedNetworkImageProvider(data['profileImage'])
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['fullName'] ?? 'Therapist',
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  (data['specialization'] as List<dynamic>? ?? []).join(', '),
                  style: TextStyle(
                    color: AppColors.primaryLavender,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Feather.star,
                      color: AppColors.accentMustard,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      (data['averageRating'] ?? 0.0).toStringAsFixed(1),
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '(${data['totalRatings'] ?? 0})',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12,
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: () => _showTherapistDetails(context, data, id),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryTeal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Book",
                          style: TextStyle(
                            color: AppColors.secondaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  void _showTherapistDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String therapistId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(24),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textDisabled,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image:
                                (data['profileImage'] != null &&
                                    data['profileImage'].isNotEmpty)
                                ? CachedNetworkImageProvider(
                                    data['profileImage'],
                                  )
                                : AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        data['fullName'] ?? 'Therapist',
                        style: TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Text(
                        (data['specialization'] as List<dynamic>? ?? []).join(
                          ', ',
                        ),
                        style: TextStyle(
                          color: AppColors.primaryLavender,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Feather.star,
                          (data['averageRating'] ?? 0.0).toStringAsFixed(1),
                          "Rating",
                        ),
                        _buildStatItem(
                          Feather.users,
                          '${data['totalClients'] ?? 0}',
                          "Clients",
                        ),
                        _buildStatItem(
                          Feather.file_text,
                          '${data['reportCount'] ?? 0}', // Maybe reports isn't something to brag about?
                          // The prompt said "report number" - assuming this means something positive or just transparency?
                          // Could also mean session reports? Let's stick to what's in data.
                          "Reports",
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text(
                      "About",
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      (data['bio'] is List)
                          ? (data['bio'] as List).join('\n')
                          : (data['bio']?.toString() ??
                                "No bio available. This therapist helps with various mental health challenges."),
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Availability",
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    // Just a placeholder or data['availability'] if exists
                    Text(
                      (data['availability'] is List)
                          ? (data['availability'] as List).join(', ')
                          : (data['availability']?.toString() ??
                                "Mon - Fri, 9:00 AM - 5:00 PM"),
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showBookingDialog(context, therapistId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLavender,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Book Journey",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryLavender, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textHigh,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppColors.textMedium, fontSize: 12),
        ),
      ],
    );
  }

  void _showBookingDialog(BuildContext context, String therapistId) {
    final TextEditingController _problemController = TextEditingController();
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                "Describe your situation",
                style: TextStyle(color: AppColors.textHigh),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "This helps the therapist understand your needs before accepting the request.",
                    style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _problemController,
                    maxLines: 4,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      hintText: "I'm feeling...",
                      hintStyle: TextStyle(color: AppColors.textDisabled),
                      filled: true,
                      fillColor: AppColors.backgroundDeep,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_problemController.text.isEmpty) return;

                          setState(() => _isLoading = true);
                          final error = await _therapyService.bookTherapist(
                            therapistId,
                            SessionType.oneDay, // Defaulting for now
                            _problemController.text,
                          );

                          setState(() => _isLoading = false);
                          Navigator.pop(context); // Close dialog

                          if (error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Request sent successfully!"),
                                backgroundColor: AppColors.secondaryTeal,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Send Request",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPendingRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Pending Requests",
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('therapy_sessions')
                          .where(
                            'clientId',
                            isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                          )
                          .where(
                            'status',
                            isEqualTo: SessionStatus.pending.index,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryLavender,
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              "No pending requests.",
                              style: TextStyle(color: AppColors.textMedium),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final therapistId = data['therapistId'];

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(therapistId)
                                  .get(),
                              builder: (context, therapistSnapshot) {
                                if (!therapistSnapshot.hasData)
                                  return SizedBox.shrink();
                                final therapist =
                                    therapistSnapshot.data!.data()
                                        as Map<String, dynamic>;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage:
                                            (therapist['profileImage'] !=
                                                    null &&
                                                therapist['profileImage']
                                                    .isNotEmpty)
                                            ? CachedNetworkImageProvider(
                                                therapist['profileImage'],
                                              )
                                            : AssetImage(
                                                    'assets/default_avatar.png',
                                                  )
                                                  as ImageProvider,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              therapist['fullName'] ??
                                                  'Therapist',
                                              style: TextStyle(
                                                color: AppColors.textHigh,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Pending Approval",
                                              style: TextStyle(
                                                color: AppColors.accentMustard,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Feather.trash_2,
                                          color: AppColors.textDisabled,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('therapy_sessions')
                                              .doc(doc.id)
                                              .delete();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
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
}
