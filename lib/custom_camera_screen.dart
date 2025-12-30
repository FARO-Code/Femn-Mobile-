import 'dart:io';
import 'package:camera/camera.dart';
import 'package:femn/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class CustomCameraScreen extends StatefulWidget {
  @override
  _CustomCameraScreenState createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isPhotoMode = true; // Toggle between Photo and Video
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile image = await _controller!.takePicture();
      Navigator.pop(context, File(image.path));
    } catch (e) {
      print("Error capturing photo: $e");
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      Navigator.pop(context, File(video.path));
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  void _switchCamera() {
    setState(() {
      _isInitializing = true;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Center(child: CameraPreview(_controller!)),

          // 2. Top Controls (Close & Flash could go here)
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: Icon(FeatherIcons.x, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. Side Controls (Flip Camera)
          Positioned(
            top: 60,
            right: 20,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(FeatherIcons.refreshCw, color: Colors.white),
                  onPressed: _switchCamera,
                ),
                Text("Flip", style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),

          // 4. Bottom Controls (Capture & Mode Switcher)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Shutter Button
                GestureDetector(
                  onTap: _isPhotoMode ? _takePhoto : _toggleRecording,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        height: _isRecording ? 30 : 60,
                        width: _isRecording ? 30 : 60,
                        decoration: BoxDecoration(
                          color: _isPhotoMode ? Colors.white : Colors.red,
                          borderRadius: _isRecording 
                              ? BorderRadius.circular(4) 
                              : BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Mode Selector (Photo / Video Text)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isPhotoMode = true),
                      child: Text(
                        "Photo",
                        style: TextStyle(
                          color: _isPhotoMode ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => setState(() => _isPhotoMode = false),
                      child: Text(
                        "Video",
                        style: TextStyle(
                          color: !_isPhotoMode ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(blurRadius: 5, color: Colors.black)],
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
}