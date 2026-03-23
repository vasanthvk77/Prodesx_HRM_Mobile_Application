import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed permission_handler (handled by browser on Web)
import '../widgets/custom_snackbar.dart';
import '../services/face_service.dart';
import '../providers/auth_provider.dart';

class FaceAttendanceScreen extends ConsumerStatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  ConsumerState<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends ConsumerState<FaceAttendanceScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isVerifying = false;
  String _statusMessage = 'Align your face to mark attendance';
  double _verifyProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // On Web/Antigravity, browser handles camera permissions.
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _markAttendance() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Capturing face samples...';
      _verifyProgress = 0.1;
    });

    try {
      List<Uint8List> images = [];
      // Quick capture of 3 images
      for (int i = 0; i < 3; i++) {
        final XFile image = await _controller!.takePicture();
        final bytes = await image.readAsBytes();
        images.add(bytes);
        setState(() => _verifyProgress = 0.1 + (i + 1) * 0.2);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _statusMessage = 'Verifying with server...';
        _verifyProgress = 0.8;
      });

      final result = await ref.read(faceServiceProvider).verifyFace(images);

      if (mounted) {
        if (result['status'] == 'success') {
          // Now call .NET backend to record attendance
          setState(() => _statusMessage = 'Recording in database...');
          
          final auth = ref.read(authProvider);
          final dbResult = await ref.read(faceServiceProvider).markAttendance(
            employeeId: result['employee_code'], // Use official code instead of PK
            role: result['role'] ?? 'User',
            userId: auth.user?.id,
          );

          if (mounted) {
            if (dbResult['status'] != 'error') {
               setState(() {
                _statusMessage = 'Attendance Marked: ${result['name']}';
                _verifyProgress = 1.0;
                _isVerifying = false;
              });
              CustomSnackbar.show(
                context: context, 
                message: 'Attendance Marked Successfully for ${result['name']} (${result['employee_code']})'
              );
            } else {
               setState(() {
                _statusMessage = 'Database Error';
                _isVerifying = false;
              });
              CustomSnackbar.show(context: context, message: 'Recognition success, but DB record failed.', isError: true);
            }
          }
        } else {
          setState(() {
            _statusMessage = 'Verification Failed';
            _verifyProgress = 0.0;
            _isVerifying = false;
          });
          CustomSnackbar.show(context: context, message: 'Recognition failed. Please try again.', isError: true);
        }
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _isVerifying = false;
          _statusMessage = 'Error occurred';
        });
        CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera Preview
          if (_isInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Immersive Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Face Scanner UI
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isVerifying ? Colors.blue : Colors.white24,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(140),
                  ),
                  child: Stack(
                    children: [
                      if (_isVerifying)
                        const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isVerifying)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    child: LinearProgressIndicator(
                      value: _verifyProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
              ],
            ),
          ),

          // Action Button
          Positioned(
            bottom: 50,
            child: GestureDetector(
              onTap: _isVerifying ? null : _markAttendance,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isVerifying ? Colors.grey : Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.face,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
