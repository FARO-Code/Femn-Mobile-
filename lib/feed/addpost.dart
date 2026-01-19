import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/app.dart' hide ProfileScreen;
import 'package:femn/customization/colors.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/services/custom_camera_screen.dart';
import 'package:femn/services/custom_gallery_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:femn/services/embers_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:femn/feed/feed_service.dart';
import 'package:femn/feed/upload_service.dart';

class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  // Split Controllers for UI
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController(); // Replaces old _captionController for logic
  final TextEditingController _linkController = TextEditingController();
  
  final FocusNode _bodyFocusNode = FocusNode();
  
  File? _mediaFile;
  String _mediaType = 'image'; 
  bool _isUploading = false;
  
  VideoPlayerController? _videoController; 

  // Tagging / Mentions Logic variables
  List<DocumentSnapshot> _userSuggestions = [];
  bool _showSuggestions = false;
  String _currentTagQuery = "";
  Timer? _debounceTimer;

  // Constraints
  final int _maxFileSize = 15 * 1024 * 1024 * 1024; // 15 GB

  // Whitelist Data
  final List<String> _allowedDomains = [
    'globalfundforwomen.org', 'urgentactionfund.org', 'mamacash.org', 'awdf.org',
    'wphfund.org', 'feministcoalition2020.com', 'awid.org', 'equalitynow.org',
    'womankind.org.uk', 'riseuptogether.org', 'gofundme.com', 'kickstarter.com',
    'indiegogo.com', 'justgiving.com', 'ketto.org', 'milaap.org', 'unwomen.org',
    'ohchr.org', 'amnesty.org', 'hrw.org', 'unicef.org', 'genderdata.worldbank.org',
    'oecd.org', 'data2x.org', 'eff.org', 'frontlinedefenders.org', 'accessnow.org',
    'tacticaltech.org', 'who.int', 'ippf.org', 'msf.org', 'reproductiverights.org',
    'change.org', 'thepetitionsite.com', 'avaaz.org', 'ipetitions.com', 'coworker.org',
    'moveon.org', 'civist.eu', 'petition.parliament.uk', 'whitehouse.gov',
    'petiport.europarl.europa.eu', 'facebook.com', 'youtube.com', 'instagram.com',
    'whatsapp.com', 'tiktok.com', 'wechat.com', 'telegram.org', 'messenger.com',
    'snapchat.com', 'reddit.com'
  ];

  @override
  void initState() {
    super.initState();
    // Attach tagging listener to the BODY controller
    _bodyController.addListener(_onCaptionChanged);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onCaptionChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _linkController.dispose();
    _bodyFocusNode.dispose();
    _debounceTimer?.cancel();
    _videoController?.dispose(); 
    super.dispose();
  }

  // --- Tagging Logic (Applied to Body) ---

  void _onCaptionChanged() {
    String text = _bodyController.text;
    TextSelection selection = _bodyController.selection;
    
    if (selection.baseOffset < 0) return;

    String textBeforeCursor = text.substring(0, selection.baseOffset);
    int atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      bool isValidStart = atIndex == 0 || textBeforeCursor[atIndex - 1] == ' ';
      
      if (isValidStart) {
        String query = textBeforeCursor.substring(atIndex + 1);
        if (!query.contains(' ')) {
          _currentTagQuery = query;
          _onTagQueryChanged(query);
          return;
        }
      }
    }

    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _onTagQueryChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchUsersForTag(query);
    });
  }

  Future<void> _searchUsersForTag(String query) async {
    if (query.isEmpty) {
      setState(() => _showSuggestions = false);
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(10)
          .get();

      List<DocumentSnapshot> docs = snapshot.docs;

      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
          
      List<String> following = List<String>.from(currentUserDoc['following'] ?? []);

      docs.sort((a, b) {
        String idA = a.id;
        String idB = b.id;
        bool followsA = following.contains(idA);
        bool followsB = following.contains(idB);

        if (followsA && !followsB) return -1;
        if (!followsA && followsB) return 1;
        return 0;
      });

      setState(() {
        _userSuggestions = docs;
        _showSuggestions = docs.isNotEmpty;
      });

    } catch (e) {
      print("Error searching users: $e");
    }
  }

  void _addTagToCaption(String username) {
    String text = _bodyController.text;
    TextSelection selection = _bodyController.selection;
    String textBeforeCursor = text.substring(0, selection.baseOffset);
    int atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      String newText = text.replaceRange(atIndex + 1, selection.baseOffset, "$username ");
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.fromPosition(
        TextPosition(offset: atIndex + 1 + username.length + 1)
      );
    }
    
    setState(() {
      _showSuggestions = false;
    });
  }

  // --- Navigation & File Handling ---

  Future<void> _openCustomGallery() async {
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomGalleryScreen()),
    );
    if (result != null) _processSelectedFile(result);
  }

  Future<void> _openCustomCamera() async {
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomCameraScreen()),
    );
    if (result != null) _processSelectedFile(result);
  }

  void _processSelectedFile(File file) async {
    String type = _getFileType(file.path);
    int sizeInBytes = await file.length();
    if (sizeInBytes > _maxFileSize) {
      _showError('File is too large. Max size is 15GB.');
      return;
    }

    if (type == 'video') {
      _videoController?.dispose(); 
      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {}); 
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }

    setState(() {
      _mediaFile = file;
      _mediaType = type;
    });
  }

  String _getFileType(String path) {
    String ext = path.split('.').last.toLowerCase();
    List<String> videoExtensions = [
      'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'mts'
    ];
    if (videoExtensions.contains(ext)) return 'video';
    return 'image';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.backgroundDeep)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // --- Link Validation ---
  bool _validateLink(String url) {
    if (url.isEmpty) return true; // Empty is valid (no link)
    Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      // Try adding https if missing
      uri = Uri.tryParse("https://$url");
    }
    
    if (uri == null || uri.host.isEmpty) return false;

    // Check if host ends with any allowed domain
    // e.g., "m.facebook.com" ends with "facebook.com"
    return _allowedDomains.any((domain) => uri!.host.endsWith(domain));
  }

  void _showWhitelistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Allowed Websites", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: _allowedDomains.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.check_circle_outline, color: AppColors.primaryLavender, size: 16),
                  title: Text(_allowedDomains[index], style: TextStyle(color: AppColors.textMedium)),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text("Close", style: TextStyle(color: AppColors.primaryLavender)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  // --- Upload Logic ---

  void _uploadPost() {
    if (_mediaFile == null) return;
    
    // 1. Validation Logic
    if (!_mediaFile!.existsSync()) {
       _showError('File error. Please select again.');
       return;
    }

    String link = _linkController.text.trim();
    if (link.isNotEmpty) {
      if (!_validateLink(link)) {
        _showError('Link not allowed. Tap the info icon to see approved sites.');
        return;
      }
      // Ensure scheme
      if (!link.startsWith('http')) {
        link = 'https://$link';
      }
    }

    // Combine Title and Body for the final caption logic
    String title = _titleController.text.trim();
    String body = _bodyController.text.trim();
    String finalCaption = "";
    
    if (title.isNotEmpty && body.isNotEmpty) {
      finalCaption = "$title\n\n$body";
    } else if (title.isNotEmpty) {
      finalCaption = title;
    } else {
      finalCaption = body;
    }

    // 2. Hand off to Service
    PostUploadService.instance.startUpload(
      file: _mediaFile!,
      caption: finalCaption,
      mediaType: _mediaType,
      context: context,
      linkUrl: link.isNotEmpty ? link : null,
    );

    // 3. Immediate Exit
    Navigator.of(context).pop(); 
  }

  // --- Widgets ---

  Widget _buildSuggestionsList() {
    if (!_showSuggestions) return SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
        border: Border.all(color: AppColors.elevation)
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _userSuggestions.length,
        itemBuilder: (context, index) {
          final user = _userSuggestions[index].data() as Map<String, dynamic>;
          final String username = user['username'] ?? 'User';
          final String profileImage = user['profileImage'] ?? '';
          final String fullName = user['fullName'] ?? '';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.elevation,
              backgroundImage: profileImage.isNotEmpty 
                ? CachedNetworkImageProvider(profileImage) 
                : AssetImage('assets/default_avatar.png') as ImageProvider,
              radius: 16,
            ),
            title: Text(username, style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
            subtitle: Text(fullName, style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            dense: true,
            onTap: () => _addTagToCaption(username),
          );
        },
      ),
    );
  }

  Widget _buildSplitCircleButton() {
    double size = 200.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Create Post",
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2
          ),
        ),
        SizedBox(height: 30),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              )
            ],
          ),
          child: ClipOval(
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.primaryLavender,
                    child: InkWell(
                      onTap: _openCustomGallery, 
                      child: Container(
                        height: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FeatherIcons.uploadCloud, color: AppColors.backgroundDeep, size: 32),
                            SizedBox(height: 8),
                            Text(
                              "Upload",
                              style: TextStyle(
                                color: AppColors.backgroundDeep,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: AppColors.elevation, 
                    child: InkWell(
                      onTap: _openCustomCamera,
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: AppColors.backgroundDeep, width: 1)
                          )
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FeatherIcons.camera, color: AppColors.primaryLavender, size: 32),
                            SizedBox(height: 8),
                            Text(
                              "Capture",
                              style: TextStyle(
                                color: AppColors.primaryLavender,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          "Photos • Videos • GIFs",
          style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
        )
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLavender)),
              SizedBox(height: 16),
              Text(
                'Uploading...',
                style: TextStyle(color: AppColors.textHigh, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4, // Reduced height to fit fields
        minHeight: 200,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _mediaType == 'video'
              ? _videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
              : Image.file(
                  _mediaFile!,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInputFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // 1. Unified Caption Box (Title + Divider + Body)
          Container(
            decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.elevation)
            ),
            child: Column(
              children: [
                // TITLE INPUT
                TextField(
                  controller: _titleController,
                  maxLength: 90,
                  style: TextStyle(color: AppColors.textHigh, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: AppColors.textDisabled, fontWeight: FontWeight.bold),
                    contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    border: InputBorder.none,
                    counterText: "", // Hide character count visually
                  ),
                ),
                
                // THIN ALMOST INVISIBLE SEPARATOR
                Divider(height: 1, thickness: 1, color: AppColors.textDisabled.withOpacity(0.1)),
                
                // BODY INPUT
                TextField(
                  controller: _bodyController,
                  focusNode: _bodyFocusNode,
                  style: TextStyle(color: AppColors.textHigh, fontSize: 16),
                  minLines: 3,
                  maxLines: null,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    hintText: 'Type @ to tag friends or # for tags...',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                    counterText: "",
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12),

          // 2. Link Input Field
          Container(
             decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    style: TextStyle(color: AppColors.secondaryTeal, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a link (e.g. gofundme.com/...)',
                      hintStyle: TextStyle(color: AppColors.textDisabled),
                      prefixIcon: Icon(FeatherIcons.link, color: AppColors.textDisabled, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(FeatherIcons.info, color: AppColors.primaryLavender, size: 18),
                  tooltip: 'Allowed Websites',
                  onPressed: _showWhitelistDialog,
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Note: Only links from verified organizations are allowed.",
                style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: AppColors.primaryLavender),
          onPressed: () {
            if (_mediaFile != null) {
              setState(() {
                _mediaFile = null;
                _showSuggestions = false;
                _videoController?.dispose();
                _videoController = null;
                // Clear fields
                _titleController.clear();
                _bodyController.clear();
                _linkController.clear();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: _mediaFile != null 
          ? Text(
              'New Post',
              style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
            )
          : null,
        actions: [
          if (_mediaFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(FeatherIcons.check, color: AppColors.primaryLavender),
                onPressed: _isUploading ? null : _uploadPost,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                if (_mediaFile != null) ...[
                  _buildMediaPreview(),
                  _buildEnhancedInputFields(), // Replaces simple caption field
                  
                  // Suggestions placed in flow
                  _buildSuggestionsList(),

                  SizedBox(height: 100), 
                ] else
                  Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Center(
                      child: _buildSplitCircleButton(),
                    ),
                  ),
              ],
            ),
          ),
          if (_isUploading) _buildUploadProgress(),
        ],
      ),
    );
  }
}