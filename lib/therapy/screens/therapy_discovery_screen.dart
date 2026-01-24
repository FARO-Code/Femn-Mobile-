import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/customization/fonts.dart';
import 'package:femn/hub_screens/profile.dart';
import '../services/therapy_service.dart';
import 'therapy_history_screen.dart';
import 'package:femn/customization/layout.dart';

class TherapyDiscoveryScreen extends StatefulWidget {
  @override
  _TherapyDiscoveryScreenState createState() => _TherapyDiscoveryScreenState();
}

class _TherapyDiscoveryScreenState extends State<TherapyDiscoveryScreen> {
  final TherapyService _therapyService = TherapyService();
  
  // --- Search & Standard Filters ---
  String? _selectedSituation;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<String> _situations = [
    'Anxiety', 'Depression', 'Breakup', 'Loss', 'Trauma', 'Stress', 'Relationships', 'Career', 'Family'
  ];
  // --- Advanced Filtering State ---
  String _selectedType = 'All';
  String _selectedLanguage = 'All';
  String _selectedGender = 'All';
  String _selectedRegion = 'All'; 
  String _selectedEthnicity = 'All';
  String _selectedReligion = 'All';
  String _selectedAgeRange = 'All';
  bool _selectedIsLgbtqPlus = false;
  String? _selectedLivedExperience;

  final List<String> _types = ['All', 'Professional', 'Peer Listener'];
  final List<String> _languages = ['All', 'English', 'Spanish', 'French', 'Arabic', 'Mandarin', 'Japanese', 'Bengali'];
  final List<String> _genders = ['All', 'Male', 'Female', 'Non-binary', 'Transgender'];
  final List<String> _regions = ['All', 'North America', 'Europe', 'Asia', 'West Africa', 'South Africa', 'Middle East'];
  final List<String> _ethnicities = ['All', 'Asian', 'Black', 'Blasian', 'White', 'Hispanic', 'Middle Eastern', 'Indigenous', 'Other'];
  final List<String> _religions = ['All', 'Christianity', 'Islam', 'Hinduism', 'Buddhism', 'Sikhism', 'Judaism', 'Agnostic', 'Atheist', 'Spiritual', 'Traditional', 'Other'];
  final List<String> _ageRanges = ['All', 'Adolescent', 'Young Adult', 'Adult', 'Elderly'];
  
  final List<String> _livedExperienceOptions = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchAndFilter(),
            _buildCategoryFilter(),
            Expanded(child: _buildTherapistGrid()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryLavender,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TherapyHistoryScreen())),
        child: Icon(Feather.clock, color: AppColors.backgroundDeep),
        tooltip: 'History',
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 0), // Reduced top padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Align with back button
        children: [
          IconButton(
            icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find support",
                  style: primaryVeryBoldTextStyle(fontSize: 24, color: AppColors.textHigh), // Slightly smaller
                ),
                Text(
                  "Browse specialists or listeners.",
                  style: primaryTextStyle(fontSize: 14, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48, // Fixed height for consistency
              decoration: BoxDecoration(
                color: AppColors.elevation,
                borderRadius: BorderRadius.circular(30), // Curve edges #3
              ),
              child: TextField(
                controller: _searchController,
                style: primaryTextStyle(color: AppColors.textHigh),
                textAlignVertical: TextAlignVertical.center, // Center text vertically
                decoration: InputDecoration(
                  isDense: true, // Reduces internal padding naturally
                  hintText: "Search...",
                  hintStyle: primaryTextStyle(color: AppColors.textDisabled),
                  prefixIcon: Icon(Feather.search, color: AppColors.textMedium, size: 20),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none, 
                  contentPadding: EdgeInsets.zero, // Important for TextAlignVertical.center
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(Feather.x, size: 16, color: AppColors.textMedium),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.elevation,
                shape: BoxShape.circle,
                border: (_selectedType != 'All' || _selectedLanguage != 'All' || _selectedRegion != 'All' || _selectedGender != 'All' || _selectedEthnicity != 'All' || _selectedReligion != 'All' || _selectedAgeRange != 'All' || _selectedIsLgbtqPlus || _selectedLivedExperience != null) 
                    ? Border.all(color: AppColors.accentMustard, width: 2) // Visual indicator if active
                    : null,
              ),
              child: Icon(Feather.sliders, color: AppColors.textHigh, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 40, // Reduce overall height #1
      margin: EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _situations.length + 1,
        separatorBuilder: (c, i) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSituation == null;
            return _buildFilterChip("All", isSelected, () {
              setState(() => _selectedSituation = null);
            });
          }
          final situation = _situations[index - 1];
          final isSelected = _selectedSituation == situation;
          return _buildFilterChip(situation, isSelected, () {
            setState(() => _selectedSituation = isSelected ? null : situation);
          });
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 16), // Reduced padding inside
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLavender : AppColors.surface,
          borderRadius: BorderRadius.circular(20), // Smaller radius for shorter pill
          border: Border.all(
            color: isSelected ? AppColors.primaryLavender : AppColors.elevation,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: isSelected 
              ? secondaryVeryBoldTextStyle(fontSize: 13, color: AppColors.backgroundDeep)
              : secondaryTextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true, // Allow it to be taller if needed
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder to update sheet state locally
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.elevation, borderRadius: BorderRadius.circular(2)))),
                  SizedBox(height: 20),
                  Text("Refine Results", style: primaryVeryBoldTextStyle(fontSize: 20, color: AppColors.textHigh)),
                  SizedBox(height: 20),
                  
                  _buildSheetFilterOption("Type", _types, _selectedType, (val) => setSheetState(() => _selectedType = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Region", _regions, _selectedRegion, (val) => setSheetState(() => _selectedRegion = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Language", _languages, _selectedLanguage, (val) => setSheetState(() => _selectedLanguage = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Gender", _genders, _selectedGender, (val) => setSheetState(() => _selectedGender = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Lived Experience", ['All', ..._livedExperienceOptions], _selectedLivedExperience ?? 'All', (val) => setSheetState(() => _selectedLivedExperience = val == 'All' ? null : val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Ethnicity", _ethnicities, _selectedEthnicity, (val) => setSheetState(() => _selectedEthnicity = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Religion", _religions, _selectedReligion, (val) => setSheetState(() => _selectedReligion = val)),
                  SizedBox(height: 16),
                  _buildSheetFilterOption("Target Age", _ageRanges, _selectedAgeRange, (val) => setSheetState(() => _selectedAgeRange = val)),
                  SizedBox(height: 16),
                  
                  // LGBTQ+ Filter
                  GestureDetector(
                    onTap: () => setSheetState(() => _selectedIsLgbtqPlus = !_selectedIsLgbtqPlus),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedIsLgbtqPlus ? AppColors.primaryLavender.withOpacity(0.2) : AppColors.elevation,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _selectedIsLgbtqPlus ? AppColors.primaryLavender : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(Feather.heart, color: _selectedIsLgbtqPlus ? AppColors.primaryLavender : AppColors.textDisabled, size: 20),
                          SizedBox(width: 12),
                          Text("LGBTQ+ Support Only", style: secondaryTextStyle(color: _selectedIsLgbtqPlus ? AppColors.textHigh : AppColors.textMedium)),
                          Spacer(),
                          if (_selectedIsLgbtqPlus) Icon(Feather.check, color: AppColors.primaryLavender, size: 16),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                             setState(() {
                               _selectedType = 'All';
                               _selectedRegion = 'All';
                               _selectedLanguage = 'All';
                               _selectedGender = 'All';
                               _selectedEthnicity = 'All';
                               _selectedReligion = 'All';
                               _selectedAgeRange = 'All';
                               _selectedIsLgbtqPlus = false;
                               _selectedLivedExperience = null;
                             });
                             Navigator.pop(context);
                          },
                          child: Text("Reset", style: secondaryTextStyle(color: AppColors.textMedium)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild of main screen
                            Navigator.pop(context);
                          },
                          child: Text("Apply Filters"),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildSheetFilterOption(String title, List<String> options, String selected, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: secondaryVeryBoldTextStyle(fontSize: 14, color: AppColors.textMedium)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? null : Border.all(color: AppColors.elevation),
                ),
                child: Text(
                  opt, 
                  style: secondaryTextStyle(
                    fontSize: 12, 
                    color: isSelected ? Colors.white : AppColors.textMedium,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  )
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTherapistGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _therapyService.getTherapists(
        situation: _selectedSituation,
        region: _selectedRegion,
        ethnicity: _selectedEthnicity,
        gender: _selectedGender,
        isLgbtqPlus: _selectedIsLgbtqPlus,
        religion: _selectedReligion,
        ageRange: _selectedAgeRange,
        language: _selectedLanguage,
        livedExperience: _selectedLivedExperience,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No specialist found nearby.', style: primaryTextStyle(color: AppColors.textMedium)));
        }

        var therapists = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();

        // --- Client-Side Filtering ---
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          therapists = therapists.where((t) {
            final name = (t['fullName'] ?? '').toString().toLowerCase();
            final specs = (t['specialization'] as List? ?? []).join(' ').toLowerCase();
            return name.contains(q) || specs.contains(q);
          }).toList();
        }

        if (_selectedType != 'All') {
          therapists = therapists.where((t) {
             final exp = (t['experienceLevel'] ?? '').toString();
             if (_selectedType == 'Professional') return exp == 'Certified Therapist';
             if (_selectedType == 'Peer Listener') return exp == 'Peer Listener';
             return true;
          }).toList();
        }
        // -----------------------------

        if (therapists.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Feather.filter, size: 40, color: AppColors.textDisabled),
                 SizedBox(height: 12),
                 Text('No matching results.', style: primaryTextStyle(color: AppColors.textMedium)),
                 TextButton(
                   onPressed: () {
                     setState(() {
                       _selectedType = 'All';
                       _selectedRegion = 'All';
                       _selectedLanguage = 'All';
                       _selectedGender = 'All';
                       _selectedEthnicity = 'All';
                       _selectedReligion = 'All';
                       _selectedAgeRange = 'All';
                       _selectedIsLgbtqPlus = false;
                       _selectedLivedExperience = null;
                       _selectedSituation = null;
                       _searchController.clear();
                       _searchQuery = "";
                     });
                   },
                   child: Text("Clear Filters", style: secondaryTextStyle(color: AppColors.primaryLavender)),
                 )
               ],
             )
           );
        }

        return MasonryGridView.count(
          padding: EdgeInsets.all(20),
          crossAxisCount: ResponsiveLayout.getColumnCount(context),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: therapists.length,
          itemBuilder: (context, index) {
            final therapist = therapists[index];
            return _buildTherapistCard(therapist['id'], therapist);
          },
        );
      },
    );
  }

  Widget _buildTherapistCard(String id, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: id))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Hero(
                    tag: 'therapist-$id', // nice transition
                    child: CachedNetworkImage(
                      imageUrl: data['profileImage'] ?? '',
                      placeholder: (context, url) => Container(color: AppColors.elevation, height: 160),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: AppColors.elevation,
                        child: Icon(Feather.user, size: 40, color: AppColors.textDisabled),
                      ),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (data['isVerified'] == true)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLavender.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Feather.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['fullName'] ?? 'Therapist',
                    style: primaryVeryBoldTextStyle(fontSize: 16, color: AppColors.textHigh),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: AppColors.accentMustard),
                      SizedBox(width: 4),
                      Text(
                        (data['averageRating'] ?? 0.0).toStringAsFixed(1),
                        style: secondaryVeryBoldTextStyle(color: AppColors.textHigh, fontSize: 13),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "(${data['totalRatings'] ?? 0})",
                        style: secondaryTextStyle(color: AppColors.textMedium, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (data['specialization'] as List? ?? [])
                        .take(2) // Limit to 2 tags to keep card clean
                        .map<Widget>((s) => Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.elevation,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.toString(), 
                                style: secondaryTextStyle(color: AppColors.secondaryTeal, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ))
                        .toList(),
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

