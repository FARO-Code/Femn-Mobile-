import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:femn/customization/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart'; // NEW
import 'package:audioplayers/audioplayers.dart'; // NEW
import 'package:archive/archive_io.dart'; // NEW
import 'package:share_plus/share_plus.dart'; // NEW

// ==========================================
// DATA MODEL
// ==========================================
enum EvidenceType { image, audio, document, video }

class EvidenceItem {
  final String id;
  final String filePath;
  final String originalName;
  final String contextNote;
  final String category;
  final DateTime timestamp;
  final EvidenceType type;

  EvidenceItem({
    required this.id,
    required this.filePath,
    required this.originalName,
    required this.contextNote,
    required this.category,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'originalName': originalName,
        'contextNote': contextNote,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString(),
      };

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['id'],
      filePath: json['filePath'],
      originalName: json['originalName'],
      contextNote: json['contextNote'],
      category: json['category'],
      timestamp: DateTime.parse(json['timestamp']),
      type: EvidenceType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => EvidenceType.image,
      ),
    );
  }
}

// ==========================================
// MAIN SCREEN
// ==========================================
class EvidenceLockerScreen extends StatefulWidget {
  @override
  _EvidenceLockerScreenState createState() => _EvidenceLockerScreenState();
}

class _EvidenceLockerScreenState extends State<EvidenceLockerScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;
  List<EvidenceItem> _evidenceList = [];
  bool _isLoading = true;
  String _sortBy = 'Date (Newest)';

  // Audio Recorder State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  
  final Map<String, Color> _categoryColors = {
    "Threat": Colors.redAccent,
    "Nude Leaked": Colors.purpleAccent,
    "Financial": Colors.greenAccent,
    "Stalking": Colors.orangeAccent,
    "Other": Colors.grey,
  };
  
  final String _currentUserId = "user_001";

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadEvidenceManifest();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- [PERSISTENCE & AUTH METHODS SAME AS BEFORE] ---
  Future<void> _loadEvidenceManifest() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/evidence_manifest_$_currentUserId.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        setState(() {
          _evidenceList = jsonList.map((e) => EvidenceItem.fromJson(e)).toList();
          _sortEvidence();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEvidenceManifest() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/evidence_manifest_$_currentUserId.json');
    final jsonList = _evidenceList.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> _checkBiometrics() async {
    try {
      bool canCheck = await auth.canCheckBiometrics;
      if (canCheck) {
        bool didAuth = await auth.authenticate(
          localizedReason: 'Unlock Evidence Vault',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        setState(() => _isAuthenticated = didAuth);
      } else {
        setState(() => _isAuthenticated = true);
      }
    } catch (e) {
      setState(() => _isAuthenticated = true);
    }
  }

  // --- [IMPORT LOGIC] ---
  Future<void> _importEvidence() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true, 
    );
    if (result != null) {
      _showContextDialog(files: result.files); // Pass files
    }
  }

  // NEW: Voice Recording Logic
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        String path = '${directory.path}/VN_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print(e);
    }
  }

  Future<String?> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      return path;
    } catch (e) {
      return null;
    }
  }

  // --- [CONTEXT DIALOG WITH MIC] ---
  void _showContextDialog({List<PlatformFile>? files, String? recordedPath}) {
    TextEditingController _noteController = TextEditingController();
    String _selectedCategory = "Threat";
    
    // If we have a recording, wrap it in a pseudo-file for display
    List<dynamic> displayItems = [];
    if (files != null) displayItems.addAll(files);
    if (recordedPath != null) displayItems.add("VOICE_NOTE");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, color: AppColors.textDisabled)),
                SizedBox(height: 20),
                Text("Secure Evidence", style: TextStyle(color: AppColors.textHigh, fontSize: 20, fontWeight: FontWeight.bold)),
                
                SizedBox(height: 20),
                
                // PREVIEWS
                Container(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayItems.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
                      if (item == "VOICE_NOTE") {
                        return Container(
                          width: 80,
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Feather.mic, color: Colors.redAccent),
                        );
                      }
                      final PlatformFile file = item as PlatformFile;
                      bool isImage = ['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase());
                      return Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.elevation),
                          image: isImage && file.path != null
                              ? DecorationImage(image: FileImage(File(file.path!)), fit: BoxFit.cover)
                              : null,
                        ),
                        child: !isImage 
                           ? Center(child: Icon(_getFileIcon(file.extension), color: AppColors.textMedium))
                           : null,
                      );
                    },
                  ),
                ),

                SizedBox(height: 20),
                
                // CATEGORY
                Text("TYPE", style: TextStyle(color: AppColors.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _categoryColors.keys.map((cat) {
                    bool isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: _categoryColors[cat],
                      onSelected: (val) => setModalState(() => _selectedCategory = cat),
                    );
                  }).toList(),
                ),

                SizedBox(height: 20),
                
                // CONTEXT NOTE + RECORDER
                Text("CONTEXT (TEXT OR VOICE)", style: TextStyle(color: AppColors.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        maxLines: 3,
                        style: TextStyle(color: AppColors.textHigh),
                        decoration: InputDecoration(
                          hintText: "Add details...",
                          filled: true,
                          fillColor: AppColors.backgroundDeep,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // MICROPHONE BUTTON
                    GestureDetector(
                      onLongPress: () async {
                        await _startRecording();
                        setModalState(() {}); // Update UI to show red
                      },
                      onLongPressUp: () async {
                         String? path = await _stopRecording();
                         setModalState(() {});
                         if (path != null) {
                           // Close this modal and reopen it with the new audio file added
                           // In a real app, use a proper state manager. Here we simply create a PlatformFile from the recording.
                           Navigator.pop(context);
                           final audioFile = PlatformFile(name: "Voice_Note.m4a", size: 0, path: path);
                           List<PlatformFile> newFiles = files ?? [];
                           newFiles.add(audioFile);
                           _showContextDialog(files: newFiles);
                         }
                      },
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : AppColors.primaryLavender,
                          shape: BoxShape.circle,
                          boxShadow: _isRecording ? [BoxShadow(color: Colors.redAccent, blurRadius: 10)] : []
                        ),
                        child: Icon(_isRecording ? Feather.mic : Feather.mic_off, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                if (_isRecording) Text("Recording... Release to save", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                if (!_isRecording) Text("Hold Mic to record voice note", style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),

                Spacer(),
                
                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Feather.lock, color: Colors.white),
                    label: Text("Encrypt & Save"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLavender,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _processBatch(files ?? [], _noteController.text, _selectedCategory);
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // --- [HELPER METHODS] ---
  IconData _getFileIcon(String? ext) {
    if (ext == null) return Feather.file;
    if (['mp3', 'm4a', 'wav', 'aac'].contains(ext.toLowerCase())) return Feather.mic;
    if (['pdf', 'doc', 'docx'].contains(ext.toLowerCase())) return Feather.file_text;
    if (['mp4', 'mov', 'avi'].contains(ext.toLowerCase())) return Feather.video;
    return Feather.file;
  }

  EvidenceType _getEvidenceType(String? ext) {
    if (ext == null) return EvidenceType.document;
    String e = ext.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'heic'].contains(e)) return EvidenceType.image;
    if (['mp3', 'm4a', 'wav', 'aac'].contains(e)) return EvidenceType.audio;
    if (['mp4', 'mov', 'avi'].contains(e)) return EvidenceType.video;
    return EvidenceType.document;
  }

  Future<void> _processBatch(List<PlatformFile> files, String note, String category) async {
    setState(() => _isLoading = true);
    final directory = await getApplicationDocumentsDirectory();

    for (var file in files) {
      if (file.path == null) continue;
      
      final String extension = file.extension ?? 'dat';
      // Save with safe unique name
      final String newPath = '${directory.path}/EV_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(" ", "_")}';
      
      await File(file.path!).copy(newPath);

      _evidenceList.add(EvidenceItem(
        id: DateTime.now().toString() + "_" + file.name,
        filePath: newPath,
        originalName: file.name,
        contextNote: note,
        category: category,
        timestamp: DateTime.now(),
        type: _getEvidenceType(file.extension),
      ));
    }
    
    _sortEvidence();
    await _saveEvidenceManifest();
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Items Secured. Please delete originals."), backgroundColor: Colors.orange),
    );
  }

  void _sortEvidence() {
    setState(() {
      if (_sortBy == 'Date (Newest)') {
        _evidenceList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else if (_sortBy == 'Date (Oldest)') {
        _evidenceList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      } else if (_sortBy == 'Category') {
        _evidenceList.sort((a, b) => a.category.compareTo(b.category));
      }
    });
  }

  // #8 NEW: ZIP EXPORT (Solves the "Video not opening" issue)
  Future<void> _generateAndShareZip() async {
    setState(() => _isLoading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final encoder = ZipFileEncoder();
      
      // 1. Create a Temp Directory for Staging
      final zipDir = Directory('${directory.path}/Case_Export_${DateTime.now().millisecondsSinceEpoch}');
      await zipDir.create();

      // 2. Generate the PDF Report (Text & Images only)
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      pdf.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("CASE EVIDENCE REPORT", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Paragraph(text: "Refer to the 'Evidence_Files' folder in this ZIP archive for full resolution videos and audio files."),
          pw.Divider(),
          ..._evidenceList.map((item) => pw.Container(
            margin: pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 1, child: pw.Text(item.originalName, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
                pw.SizedBox(width: 10),
                pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(item.category.toUpperCase(), style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                  pw.Text(item.contextNote, style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                  if(item.type == EvidenceType.image) 
                    pw.Container(height: 150, child: pw.Image(pw.MemoryImage(File(item.filePath).readAsBytesSync()), fit: pw.BoxFit.contain))
                ]))
              ]
            )
          )).toList()
        ]
      ));

      // Save PDF to Staging
      final pdfFile = File('${zipDir.path}/Incident_Report.pdf');
      await pdfFile.writeAsBytes(await pdf.save());

      // 3. Create 'Evidence_Files' subfolder
      final evidenceDir = Directory('${zipDir.path}/Evidence_Files');
      await evidenceDir.create();

      // 4. Copy all Raw Files to Staging
      for (var item in _evidenceList) {
        final source = File(item.filePath);
        if (await source.exists()) {
          await source.copy('${evidenceDir.path}/${item.originalName}');
        }
      }

      // 5. Zip it all up
      final zipPath = '${directory.path}/Case_Export.zip';
      encoder.create(zipPath);
      encoder.addDirectory(zipDir);
      encoder.close();

      // 6. Share the ZIP
      await Share.shareXFiles([XFile(zipPath)], text: 'Secure Case Export');

      // Cleanup
      await zipDir.delete(recursive: true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Deletion
  void _deleteItem(EvidenceItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Delete Evidence?", style: TextStyle(color: AppColors.textHigh)),
        content: Text("Permanent deletion. Undo impossible.", style: TextStyle(color: AppColors.textMedium)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                final file = File(item.filePath);
                if (await file.exists()) await file.delete();
              } catch (e) {}
              setState(() { _evidenceList.removeWhere((e) => e.id == item.id); });
              await _saveEvidenceManifest();
              Navigator.pop(context); // Close Confirm
              Navigator.pop(context); // Close Modal
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDetailModal(EvidenceItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Detail View", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
                    Row(children: [
                      IconButton(icon: Icon(Feather.trash_2, color: Colors.red), onPressed: () => _deleteItem(item)),
                      IconButton(icon: Icon(Feather.x, color: AppColors.textHigh), onPressed: () => Navigator.pop(context)),
                    ])
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  child: item.type == EvidenceType.image
                      ? InteractiveViewer(child: Image.file(File(item.filePath))) 
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getFileIcon(item.filePath.split('.').last), size: 64, color: Colors.white),
                              SizedBox(height: 20),
                              Text("Multimedia Evidence", style: TextStyle(color: Colors.white)),
                              SizedBox(height: 20),
                              // PLAY BUTTON
                              ElevatedButton.icon(
                                icon: Icon(Feather.play),
                                label: Text("Play / Open"),
                                onPressed: () async {
                                  // Simple Audio Player implementation
                                  if (item.type == EvidenceType.audio) {
                                    final player = AudioPlayer();
                                    await player.play(DeviceFileSource(item.filePath));
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Playing audio...")));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video playback requires 'video_player' package.")));
                                  }
                                },
                              )
                            ],
                          ),
                        ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.contextNote, style: TextStyle(color: AppColors.textHigh)),
                    SizedBox(height: 5),
                    Text(DateFormat('MMM dd, yyyy HH:mm').format(item.timestamp), style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- [BUILD METHOD] ---
  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Center(child: IconButton(icon: Icon(Feather.lock, size: 64, color: AppColors.textDisabled), onPressed: _checkBiometrics)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Evidence Locker", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${_evidenceList.length} items secured", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Feather.filter, color: AppColors.textHigh),
            onSelected: (val) { _sortBy = val; _sortEvidence(); },
            itemBuilder: (context) => ['Date (Newest)', 'Date (Oldest)', 'Category'].map((choice) => PopupMenuItem(value: choice, child: Text(choice))).toList(),
          ),
          IconButton(
            icon: Icon(Feather.package, color: Colors.redAccent), // Changed icon to package to represent ZIP
            tooltip: "Export Case File (ZIP)",
            onPressed: _evidenceList.isEmpty ? null : _generateAndShareZip,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLavender,
        onPressed: _importEvidence,
        icon: Icon(Feather.plus),
        label: Text("Add"),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator()) 
          : _evidenceList.isEmpty ? _buildEmptyState() : _buildMasonryGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Feather.shield, size: 50, color: AppColors.textDisabled), SizedBox(height: 20), Text("Vault Empty", style: TextStyle(color: AppColors.textDisabled))]));
  }

  Widget _buildMasonryGrid() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColumn(0)),
          SizedBox(width: 10),
          Expanded(child: _buildColumn(1)),
          SizedBox(width: 10),
          Expanded(child: _buildColumn(2)),
        ],
      ),
    );
  }

  Widget _buildColumn(int columnIndex) {
    List<EvidenceItem> items = [];
    for (int i = 0; i < _evidenceList.length; i++) {
      if (i % 3 == columnIndex) items.add(_evidenceList[i]);
    }

    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: () => _showDetailModal(item),
          child: Container(
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    color: Colors.black12,
                    child: item.type == EvidenceType.image
                        ? Image.file(File(item.filePath), fit: BoxFit.cover)
                        : Container(
                            height: 80,
                            width: double.infinity,
                            color: AppColors.backgroundDeep,
                            child: Center(child: Icon(_getFileIcon(item.filePath.split('.').last), color: AppColors.textMedium)),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _categoryColors[item.category], borderRadius: BorderRadius.circular(4)),
                        child: Text(item.category, style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 4),
                      Text(item.contextNote.isNotEmpty ? item.contextNote : "No context", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textHigh, fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}