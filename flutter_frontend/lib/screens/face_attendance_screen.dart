import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_snackbar.dart';
import '../services/face_service.dart';
import '../providers/auth_provider.dart';
import '../repositories/organization_repository.dart';

class FaceAttendanceScreen extends ConsumerStatefulWidget {
  final int? organizationId;
  const FaceAttendanceScreen({super.key, this.organizationId});

  @override
  ConsumerState<FaceAttendanceScreen> createState() =>
      _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends ConsumerState<FaceAttendanceScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isVerifying = false;
  bool _isCheckingLocation = false;
  bool _hasStarted = false;
  bool _isSuccess = false; // New state for success animation
  bool _isInRange = false;
  String _statusMessage = 'Align your face to mark attendance';
  String _locationStatus = '';
  double _verifyProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Removed automatic _checkGeofence() to prevent eager camera requests in IndexedStack
  }

  void _resetState() {
    if (!mounted) return;
    setState(() {
      _hasStarted = false;
      _isInRange = false;
      _isCheckingLocation = false;
      _isVerifying = false;
      _isSuccess = false;
      _isInitialized = false; // Important: Clear camera initialization state
      _verifyProgress = 0.0;
      _statusMessage = 'Align your face to mark attendance';
      _locationStatus = '';
    });
    
    // Ensure controller is cleaned up and nullified
    _controller?.dispose();
    _controller = null;
  }

  void _startAttendanceFlow() async {
    // 1. ASK USER FIRST (Explicit confirmation required)
    if (mounted) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check Location?'),
          content: const Text('To proceed, the app will verify if you are within the office range. Do you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }

    setState(() {
      _hasStarted = true;
      _isCheckingLocation = true; // Set immediately to prevent Access Denied flash
      _statusMessage = 'Requesting location access...';
    });
    
    // Add small delay to prevent rapid DB spikes from many screen launches
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      _checkGeofence();
    }
  }

  Future<void> _checkGeofence() async {
    setState(() {
      _isCheckingLocation = true;
      _locationStatus = 'Verifying office location...';
      _statusMessage = 'Fetching your current location...';
    });

    try {
      // 1. Get Organization Details for Coordinates
      final auth = ref.read(authProvider);
      final orgId = widget.organizationId ?? auth.user?.organizationId ?? 0;

      if (orgId == 0) {
        throw Exception('Your account is not assigned to an organization. Please contact your administrator.');
      }

      final org = await ref.read(organizationRepositoryProvider).getOrganizationById(orgId);

      // If no coordinates are set, we might want to skip or enforce. 
      // User said "IF YES THEN ONLY ASK FOR CAMERA PERMISSION"
      if (org.latitude == null || org.longitude == null) {
        debugPrint('Geofencing: No coordinates set for organization ${org.name}. Defaulting to IN RANGE.');
        setState(() {
          _isInRange = true;
          _isCheckingLocation = false;
        });
        _initializeCamera();
        return;
      }

      // 2. Check Permissions and Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          bool? openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('To proceed, please enable location services in your device settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enable'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await Geolocator.openLocationSettings();
          }
        }
        throw Exception('Location services are disabled. Please enable GPS and try again.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          bool? requestNow = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission'),
              content: const Text('This app needs your location to verify you are at the office. Allow permission?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (requestNow == true) {
            permission = await Geolocator.requestPermission();
          } else {
            throw Exception('Location permissions are required to mark attendance.');
          }
        }
        
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // 3. Get Current Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Calculate Distance
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        org.latitude!,
        org.longitude!,
      );

      int allowedRadius = org.allowedRadius ?? 100;

      if (distanceInMeters <= allowedRadius) {
        setState(() {
          _isInRange = true;
          _isCheckingLocation = false;
        });
        _initializeCamera(); // Only ask for camera if in range
      } else {
        setState(() {
          _isInRange = false;
          _isCheckingLocation = false;
          _locationStatus = 'OUTSIDE OFFICE RANGE';
          _statusMessage = 'Please reach your office to mark attendance.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
          _locationStatus = 'LOCATION ERROR';
          _statusMessage = e.toString().contains('Exception: ') ? e.toString().split('Exception: ')[1] : 'Error: $e';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_controller != null) return; // Already initialized or in progress

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
    if (_isVerifying || !_isInRange) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Capturing face samples...';
      _verifyProgress = 0.1;
    });

    try {
      List<Uint8List> images = [];
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

      final auth = ref.read(authProvider);
      final orgId = widget.organizationId ?? auth.user?.organizationId ?? 0;

      final result = await ref
          .read(faceServiceProvider)
          .verifyFace(images, organizationId: orgId);

      if (mounted) {
        if (result['status'] == 'success') {
          setState(() => _statusMessage = 'Recording in database...');

          final dbResult = await ref.read(faceServiceProvider).markAttendance(
                employeeId: result['employee_code'],
                role: result['role'] ?? 'User',
                organizationId: orgId,
                userId: auth.user?.id,
              );

          if (mounted) {
            if (dbResult['status'] != 'error') {
              setState(() {
                _isSuccess = true;
                _statusMessage = 'Attendance Marked: ${result['name']}';
                _verifyProgress = 1.0;
                _isVerifying = false;
              });

              // Add a small delay for the success animation before popping
              await Future.delayed(const Duration(milliseconds: 2000));
              
              if (mounted) {
                _controller?.dispose();
                _controller = null;
                ref.read(navigationProvider.notifier).setIndex(0);
              }
            } else {
              setState(() {
                _statusMessage = 'Database Error';
                _isVerifying = false;
              });
            }
          }
        } else {
          setState(() {
            _statusMessage = 'Verification Failed';
            _verifyProgress = 0.0;
            _isVerifying = false;
          });
          CustomSnackbar.show(
            context: context,
            message: 'Recognition failed. Please try again.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _statusMessage = 'Error occurred';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tab changes to reset state when leaving this tab
    ref.listen(navigationProvider, (previous, next) {
      if (next.currentIndex != 1) { // 1 is the index of Attendance in MainShell for Users
         _resetState();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () {
            _controller?.dispose();
            _controller = null;
            ref.read(navigationProvider.notifier).setIndex(0);
          },
        ),
        title: const Text(
          'Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera Preview (only if in range and initialized)
          if (!_isCheckingLocation && _isInRange && _isInitialized && _controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else if (_isCheckingLocation)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 20),
                  Text(
                    'Verifying Office Location...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Immersive Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Main UI
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_hasStarted)
                    Column(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.blueAccent, size: 80),
                        const SizedBox(height: 24),
                        const Text(
                          'Office Attendance',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Please verify your location to proceed.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _startAttendanceFlow,
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('Start Verification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    )
                  else if (!_isInRange && !_isCheckingLocation)
                    Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.location_off, color: Colors.redAccent, size: 60),
                          SizedBox(height: 20),
                          Text(
                            'Access Denied',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Please reach your office to mark attendance.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else if (_isInRange)
                    Container(
                      width: 280,
                      height: 380,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isVerifying ? Colors.blueAccent : Colors.white24,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(140),
                        boxShadow: [
                          if (_isVerifying)
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (_isVerifying)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _verifyProgress,
                          minHeight: 10,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Action Button
          if (_isInRange && _isInitialized)
            Positioned(
              bottom: 60,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _isVerifying ? null : _markAttendance,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isVerifying ? Colors.grey : Colors.blueAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.5),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.face, color: Colors.white, size: 45),
                  ),
                ),
              ),
            ),
          
          if (!_isInRange && !_isCheckingLocation)
            Positioned(
              bottom: 60,
              child: TextButton.icon(
                onPressed: _checkGeofence,
                icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                label: const Text('Retry Location Check', style: TextStyle(color: Colors.blueAccent)),
              ),
            ),
          
          // Success Overlay
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.black, size: 80),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Success!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Attendance Recorded Successfully',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
