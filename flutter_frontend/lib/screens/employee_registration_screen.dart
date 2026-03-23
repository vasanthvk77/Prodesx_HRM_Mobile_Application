import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed google_mlkit_face_detection (not compatible with Web)
// Removed permission_handler (handled by browser on Web)
import '../repositories/employee_repository.dart';
import '../models/employee.dart';
import '../widgets/custom_snackbar.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/face_service.dart';
import 'face_attendance_screen.dart';

enum EnrollmentPose { straight, left, right, down, complete }

class EmployeeRegistrationScreen extends ConsumerStatefulWidget {
  const EmployeeRegistrationScreen({super.key});

  @override
  ConsumerState<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends ConsumerState<EmployeeRegistrationScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  Employee? _selectedEmployee;
  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;
  
  // Server-side pose detection will be used instead of local FaceDetector
  
  bool _isCapturing = false;
  EnrollmentPose _currentPose = EnrollmentPose.straight;
  double _progress = 0.0;
  String _statusMessage = 'Select an employee to begin';
  List<Uint8List> _capturedImages = [];
  Map<EnrollmentPose, int> _poseCount = {
    EnrollmentPose.straight: 0,
    EnrollmentPose.left: 0,
    EnrollmentPose.right: 0,
    EnrollmentPose.down: 0,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEmployees();
  }

  Future<void> _checkPermissions() async {
    // On Web/Antigravity, browser handles camera permissions.
    // On Mobile, this can be added back if needed, but for now we skip to initialize.
    _initializeCamera();
  }

  Future<void> _loadEmployees() async {
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(employeeRepositoryProvider);
      final list = await repo.getEmployees(auth.user?.organizationId);
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
        CustomSnackbar.show(context: context, message: 'Error loading employees: $e', isError: true);
      }
    }
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

  Future<void> _startAutonomousRegistration() async {
    if (_selectedEmployee == null) {
      CustomSnackbar.show(context: context, message: 'Please select an employee first', isError: true);
      return;
    }

    setState(() {
      _isCapturing = true;
      _currentPose = EnrollmentPose.straight;
      _progress = 0.0;
      _capturedImages = [];
      _statusMessage = 'Look Straight into the camera...';
      _poseCount.updateAll((key, value) => 0);
    });

    _automationLoop();
  }

  Future<void> _automationLoop() async {
    while (_isCapturing && mounted) {
      if (_currentPose == EnrollmentPose.complete) break;

      try {
        final XFile image = await _controller!.takePicture();
        final bytes = await image.readAsBytes();
        
        // Call FastAPI for pose detection
        final result = await ref.read(faceServiceProvider).detectPose(bytes);
        final String detectedPose = result['pose'] ?? 'None';

        if (detectedPose == 'None') {
          setState(() => _statusMessage = 'Face not detected. Align your face.');
          continue;
        }

        final isValid = detectedPose.toLowerCase() == _currentPose.name.toLowerCase();

        if (isValid) {
          _capturedImages.add(bytes); // Store bytes directly
          _poseCount[_currentPose] = _poseCount[_currentPose]! + 1;

          if (_poseCount[_currentPose]! >= 5) {
            _transitionPose();
          } else {
             _statusMessage = 'Capturing ${_currentPose.name.toUpperCase()} (${_poseCount[_currentPose]}/5)...';
          }
        } else {
          _statusMessage = 'Turn to the correct pose: ${_currentPose.name.toUpperCase()}';
        }

        setState(() {
          _progress = _capturedImages.length / 20;
        });

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Automation error: $e');
      }
    }

    if (_currentPose == EnrollmentPose.complete) {
      _submitRegistration();
    }
  }

  // Pose check is now handled on the server side

  void _transitionPose() {
    setState(() {
      if (_currentPose == EnrollmentPose.straight) _currentPose = EnrollmentPose.left;
      else if (_currentPose == EnrollmentPose.left) _currentPose = EnrollmentPose.right;
      else if (_currentPose == EnrollmentPose.right) _currentPose = EnrollmentPose.down;
      else if (_currentPose == EnrollmentPose.down) _currentPose = EnrollmentPose.complete;
    });
  }

  Future<void> _submitRegistration() async {
    setState(() => _statusMessage = 'Finalizing with server...');
    final auth = ref.read(authProvider);
    
    final result = await ref.read(faceServiceProvider).registerFace(
      employeeId: _selectedEmployee!.employeeCode ?? _selectedEmployee!.id.toString(),
      role: _selectedEmployee!.designation ?? 'Employee', 
      images: _capturedImages,
      userId: auth.user?.id,
    );

    if (mounted) {
      setState(() => _isCapturing = false);
      if (result['status'] == 'success') {
        CustomSnackbar.show(context: context, message: 'Registration Successfully completed');
      } else {
        CustomSnackbar.show(context: context, message: 'Server error: ${result['message']}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Face Management', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => ref.read(navigationProvider.notifier).setDashboardContent(null),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_add), text: 'Enrollment'),
              Tab(icon: Icon(Icons.how_to_reg), text: 'Attendance'),
            ],
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            _buildEnrollmentView(),
            const FaceAttendanceScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentView() {
    return SafeArea(
      child: Column(
        children: [
          // Employee Selection
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _isLoadingEmployees 
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<Employee>(
                  decoration: InputDecoration(
                    labelText: 'Select Employee',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.person_search),
                  ),
                  value: _selectedEmployee,
                  items: _employees.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name),
                  )).toList(),
                  onChanged: _isCapturing ? null : (val) => setState(() => _selectedEmployee = val),
                ),
          ),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-Enrollment Progress', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_progress >= 1.0 ? Colors.green : Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          // Camera Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInitialized)
                      Transform.scale(
                        scale: 1.25,
                        child: CameraPreview(_controller!),
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    
                    // Guided Overlay
                    CustomPaint(
                      size: Size.infinite,
                      painter: _FaceMaskPainter(progress: _progress),
                    ),

                    // Instructions
                    Positioned(
                      bottom: 30,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Control Button
          if (!_isCapturing && _progress < 1.0)
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _selectedEmployee == null ? null : _startAutonomousRegistration,
                  icon: const Icon(Icons.play_circle_fill, size: 28),
                  label: const Text('Start Auto-Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            )
           else if (_progress >= 1.0 && !_isCapturing)
             Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text(
                'Registration Successful',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaceMaskPainter extends CustomPainter {
  final double progress;
  _FaceMaskPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final progressPaint = Paint()
      ..color = progress >= 1.0 ? Colors.green : const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.52,
    );

    canvas.drawOval(rect, paint);
    
    if (progress > 0) {
      canvas.drawArc(rect, -1.57, 6.28 * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_FaceMaskPainter oldDelegate) => oldDelegate.progress != progress;
}
