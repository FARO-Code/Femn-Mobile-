import 'dart:io';
import 'dart:ui' as ui;
import 'package:femn/customization/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:femn/widgets/femn_background.dart';

class TextPostEditor extends StatefulWidget {
  @override
  _TextPostEditorState createState() => _TextPostEditorState();
}

class _TextPostEditorState extends State<TextPostEditor> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // State Variables
  int _selectedBgIndex = 0;
  int _selectedFontIndex = 0;
  int _selectedColorIndex = 0; // Text Color
  TextAlign _textAlign = TextAlign.center;
  bool _isConverting = false;

  // Refinement: Aspect Ratios
  double _aspectRatio = 1.0; 

  // Configuration Lists
  final List<List<Color>> _backgrounds = [
    // --- SOLID COLORS (Popular) ---
    [Colors.black, Colors.black],
    [Colors.white, Colors.white],
    [Color(0xFFF5F5F5), Color(0xFFF5F5F5)], // Off-white
    [Color(0xFF333333), Color(0xFF333333)], // Dark Gray
    [Colors.redAccent, Colors.redAccent],
    [Colors.blue, Colors.blue],
    [Colors.green, Colors.green],
    [Colors.purple, Colors.purple],
    [Colors.orange, Colors.orange],
    [Colors.pink, Colors.pink],
    [Colors.teal, Colors.teal],
    [Color(0xFF18FFFF), Color(0xFF18FFFF)], // Cyan Accent
    [Color(0xFFFFD740), Color(0xFFFFD740)], // Amber Accent

    // --- GRADIENTS (Popular) ---
    [AppColors.primaryLavender, AppColors.backgroundDeep], // Default
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple Love
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Bloody Mary
    [Color(0xFF1fa2ff), Color(0xFF12d8fa), Color(0xFFa6ffcb)], // Aquamarine
    [Color(0xFFAA076B), Color(0xFF61045F)], // Aubergine
    [Color(0xFFFF9966), Color(0xFFFF5E62)], // Sunset
    [Color(0xFF2193b0), Color(0xFF6dd5ed)], // Cool Blue
    [Color(0xFFcc2b5e), Color(0xFF753a88)], // Purple Berry
    [Color(0xFF00C9FF), Color(0xFF92FE9D)], // Lime Water
    [Color(0xFFe65c00), Color(0xFFF9D423)], // Orange Yellow
    [Color(0xFF40E0D0), Color(0xFFFF8C00), Color(0xFFFF0080)], // Wedding Day
    [Color(0xFF11998e), Color(0xFF38ef7d)], // Green
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // Moonlit Asteroid
    [Color(0xFF833ab4), Color(0xFFfd1d1d), Color(0xFFfcb045)], // Instagram-ish
  ];

  final List<TextStyle> _fontStyles = [
    GoogleFonts.roboto(fontWeight: FontWeight.bold),
    GoogleFonts.lato(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
    GoogleFonts.openSans(fontWeight: FontWeight.bold),
    GoogleFonts.montserrat(fontWeight: FontWeight.w900),
    GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic), // Serif
    GoogleFonts.robotoSlab(fontWeight: FontWeight.bold), // Slab
    GoogleFonts.merriweather(fontWeight: FontWeight.w900),
    GoogleFonts.dancingScript(fontWeight: FontWeight.bold), // Handwriting
    GoogleFonts.pacifico(), // Handwriting
    GoogleFonts.caveat(fontWeight: FontWeight.bold, fontSize: 36), // Handwriting
    GoogleFonts.permanentMarker(), // Marker
    GoogleFonts.bangers(letterSpacing: 2), // Comic
    GoogleFonts.oswald(fontWeight: FontWeight.bold),
    GoogleFonts.righteous(), // Sci-fi
    GoogleFonts.fredoka(), // Rounded
    GoogleFonts.pressStart2p(fontSize: 20), // Retro
    GoogleFonts.audiowide(), // Tech
    GoogleFonts.lobster(), // Display
    GoogleFonts.abrilFatface(), // Display Serif
  ];

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    AppColors.primaryLavender,
    AppColors.secondaryTeal,
    AppColors.accentMustard,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.limeAccent,
    Colors.yellowAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _focusNode.requestFocus();
    });
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to update "Render" layer
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    if (_textController.text.trim().isEmpty) return;

    // 1. Unfocus to hide cursor/keyboard
    _focusNode.unfocus();
    
    // Wait for UI to update (cursor removal)
    setState(() => _isConverting = true);
    await Future.delayed(Duration(milliseconds: 300)); 

    try {
      // 2. Capture the boundary
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // Upscale for better quality
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. Save to Temporary File
      final tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/text_post_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      // 4. Return File
      Navigator.pop(context, file);

    } catch (e) {
      print("Error generating text post image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating image. Try again.")),
      );
      // Re-enable input if failed
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _toggleAlignment() {
    setState(() {
      if (_textAlign == TextAlign.right) {
        _textAlign = TextAlign.left;
      } else if (_textAlign == TextAlign.left) {
        _textAlign = TextAlign.center;
      } else {
        _textAlign = TextAlign.right;
      }
    });
  }

  void _showFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Container(
          height: 150,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text("Select Font", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               SizedBox(height: 12),
               Expanded(
                 child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fontStyles.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedFontIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedFontIndex = index);
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          margin: EdgeInsets.only(right: 12),
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.grey[900],
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected ? null : Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            "Aa",
                            style: _fontStyles[index].copyWith(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
               ),
            ],
          ),
        );
      }
    );
  }

  void _showColorPicker(bool isBackground) {
     showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        return Container(
          height: 150,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(isBackground ? "Select Background" : "Select Text Color", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               SizedBox(height: 12),
               Expanded(
                 child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: isBackground ? _backgrounds.length : _textColors.length,
                    itemBuilder: (context, index) {
                      
                      if (isBackground) {
                        final colors = _backgrounds[index];
                        bool isSelected = _selectedBgIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedBgIndex = index);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 60,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: colors.length > 1
                                ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                                : null,
                              color: colors.length == 1 ? colors[0] : null,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                            child: isSelected ? Icon(Feather.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      } else {
                        final color = _textColors[index];
                        bool isSelected = _selectedColorIndex == index;
                        return GestureDetector(
                           onTap: () {
                            setState(() => _selectedColorIndex = index);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 50, margin: EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: Colors.white, width: isSelected ? 4 : 1)
                            ),
                          ),
                        );
                      }
                    },
                  ),
               ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Background
    final bgColors = _backgrounds[_selectedBgIndex];
    final bool isGradient = bgColors.length > 1 && bgColors[0] != bgColors[1];

    BoxDecoration bgDecoration = BoxDecoration(
      color: isGradient ? null : bgColors[0],
      gradient: isGradient
          ? LinearGradient(
              colors: bgColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
    );

    // 2. Determine Text Style
    final TextStyle currentFont = _fontStyles[_selectedFontIndex];
    final Color textColor = _textColors[_selectedColorIndex];

    IconData alignIcon;
    switch (_textAlign) {
      case TextAlign.left: alignIcon = Feather.align_left; break;
      case TextAlign.right: alignIcon = Feather.align_right; break;
      default: alignIcon = Feather.align_center; break;
    }

    // 3. Build UI
    return FemnBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Allow FemnBackground to show
        resizeToAvoidBottomInset: false, // Prevent resizing canvas when keyboard opens (overlay)
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Feather.chevron_left, color: Colors.white), // Standard Back Button
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Create Text Post", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isConverting ? null : _generateImage,
              child: _isConverting 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primaryLavender, strokeWidth: 2))
                : Text("Done", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
        body: Column(
          children: [
            // --- CAPTURE AREA ---
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView( 
                    child: RepaintBoundary(
                      key: _repaintBoundaryKey,
                      child: AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: Container(
                          decoration: bgDecoration,
                          // Force alignment to center to avoid whitespace issues
                          alignment: Alignment.center,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // LAYER 1: RENDER (This is what we see/capture)
                                  Padding(
                                    padding: const EdgeInsets.all(32.0), // INVISIBLE PADDING added to canvas/text
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth - 64, // Subtract padding
                                          // We don't constrain height here, let it grow. FittedBox will shrink it.
                                        ),
                                        child: Text(
                                          _textController.text.isEmpty ? "Type something..." : _textController.text,
                                          textAlign: _textAlign,
                                          style: currentFont.copyWith(
                                            color: _textController.text.isEmpty ? textColor.withOpacity(0.5) : textColor,
                                            fontSize: 30, // Reduced from 60 to prevent word breaking
                                            shadows: [
                                              Shadow(color: Colors.black26, offset: Offset(0,2), blurRadius: 4)
                                            ]
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
  
                                  // LAYER 2: INPUT (Invisible, handles typing)
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0), // Match padding
                                      child: TextField(
                                        controller: _textController,
                                        focusNode: _focusNode,
                                        maxLines: null,
                                        expands: true, // Fill the space
                                        textAlignVertical: TextAlignVertical.center, // Vertically center cursor?
                                        textAlign: _textAlign,
                                        // Make strictly invisible
                                        style: TextStyle(color: Colors.transparent, fontSize: 1), 
                                        decoration: InputDecoration(
                                          filled: false, // Override
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          counterText: "",
                                        ),
                                        cursorColor: _isConverting ? Colors.transparent : Colors.white54, // Visible cursor
                                        showCursor: true,
                                        enableInteractiveSelection: !_isConverting,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
  
            // --- TOOLS AREA ---
            Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent to show background
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  // Aspect Ratio Selector
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                     child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       _buildRatioBtn(1.0, "1:1"),
                       SizedBox(width: 16),
                       _buildRatioBtn(4 / 5, "4:5"), // Portrait
                       SizedBox(width: 16),
                       _buildRatioBtn(9 / 16, "9:16"), // Story
                     ],
                   ),
                 ),
                 SizedBox(height: 12),
                 Divider(color: Colors.white24, height: 1),
                 SizedBox(height: 20),

                // Main Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                       // 1. Alignment Toggle
                       _buildToolBtn(
                         icon: alignIcon,
                         label: "Align",
                         onTap: _toggleAlignment,
                       ),

                       // 2. Font Picker Modal
                       _buildToolBtn(
                         icon: Feather.type, // 'Aa' concept
                         label: "Font",
                         onTap: _showFontPicker,
                       ),

                       // 3. Text Color Picker Modal
                       _buildToolBtn(
                         icon: null,
                         customContent: Container(
                           width: 24, height: 24,
                           decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: textColor,
                              border: Border.all(color: Colors.white, width: 2)
                           ),
                         ),
                         label: "Color",
                         onTap: () => _showColorPicker(false),
                       ),

                       // 4. Background Picker Modal
                        _buildToolBtn(
                         icon: null,
                         customContent: Container(
                           width: 24, height: 24,
                           decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isGradient
                                ? LinearGradient(colors: bgColors)
                                : null,
                              color: isGradient ? null : bgColors[0],
                              border: Border.all(color: Colors.white, width: 2)
                           ),
                         ),
                         label: "Background",
                         onTap: () => _showColorPicker(true),
                       ),
                     ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          )
        ],
      ),
    ));
  }

  Widget _buildToolBtn({IconData? icon, Widget? customContent, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: customContent ?? Icon(icon, color: Colors.white, size: 22),
          ),
          SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 10))
        ],
      ),
    );
  }

  Widget _buildRatioBtn(double ratio, String label) {
    bool isSelected = _aspectRatio == ratio;
    // Handle approximate double comparison
    if ((_aspectRatio - ratio).abs() < 0.01) isSelected = true;

    return GestureDetector(
      onTap: () => setState(() => _aspectRatio = ratio),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(16)
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12
          )
        ),
      ),
    );
  }
}
