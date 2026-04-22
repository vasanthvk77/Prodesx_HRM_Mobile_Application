import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../core/api_config.dart';
import 'package:http/http.dart' as http;
import '../widgets/digital_clock.dart';
import '../widgets/org_dropdown.dart';
import '../widgets/custom_snackbar.dart';

class PrivateDashboard extends ConsumerStatefulWidget {
  const PrivateDashboard({super.key});

  @override
  ConsumerState<PrivateDashboard> createState() => _PrivateDashboardState();
}

class _PrivateDashboardState extends ConsumerState<PrivateDashboard> {
  // Mock/State data for the dashboard modules
  int pendingTasks = 0;
  int overdueTasks = 0;
  int inProgressProjects = 0;
  int overdueProjects = 0;
  int totalDeals = 0;
  int convertedDeals = 0;
  int pendingFollowUps = 0;
  int upcomingFollowUps = 0;
  int totalTickets = 0;
  
  List<dynamic> _shifts = [];
  List<dynamic> _tickets = [];
  List<dynamic> _birthdays = [];
  Map<String, dynamic>? _myEmployeeData;
  Map<String, dynamic>? _attendanceStatus;
  
  String? _selectedOrgId;
  int? _currentEmployeeId;
  List<Map<String, dynamic>> _orgData = [];
  bool _isLoadingOrgs = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final authState = ref.read(authProvider);
    final token = authState.token;
    
    if (token == null) return;

    if (mounted) {
      setState(() {
        // Reset all stats to 0 as requested
        pendingTasks = 0;
        overdueTasks = 0;
        inProgressProjects = 0;
        overdueProjects = 0;
        totalDeals = 0;
        convertedDeals = 0;
        pendingFollowUps = 0;
        upcomingFollowUps = 0;
        totalTickets = 0;
        _shifts = [];
        _tickets = [];
        _birthdays = [];
        _myEmployeeData = null;
        _attendanceStatus = null;
        _currentEmployeeId = null;
      });
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      // 1. Fetch Organizations if not already loaded
      if (_orgData.isEmpty) {
        await _fetchOrganizations(headers);
      }

      // 2. Fetch leads for Deal stats
      final leadUri = Uri.parse(ApiConfig.leads);
      final leadResponse = await http.get(leadUri, headers: headers).timeout(const Duration(seconds: 10));
      
      if (leadResponse.statusCode == 200) {
        final decoded = jsonDecode(leadResponse.body);
        if (decoded is List) {
          if (mounted) {
            setState(() {
              totalDeals = decoded.length;
              convertedDeals = decoded.where((l) => l is Map && l['createDeal'] == true).length;
            });
          }
        }
      }

      // 3. Fetch Employees and Resolve "Me"
      await _fetchEmployeeData(headers, _selectedOrgId);
      
      // 4. Fetch Shift Roster (Depends on employeeId)
      await _fetchShiftData(headers, _selectedOrgId);
 
      // 5. Fetch Attendance Status (Depends on employeeId)
      await _fetchAttendanceStatus(headers, _selectedOrgId);

      // Note: Tasks, Projects, FollowUps, and Tickets endpoints are not yet fully implemented in the backend.
      // They remain 0 as requested until endpoints are available.
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _fetchShiftData(Map<String, String> headers, String? orgId) async {
    try {
      final now = DateTime.now();
      final start = DateFormat('yyyy-MM-dd').format(now);
      final end = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));
      
      String shiftUrl = '${ApiConfig.shiftRoster}?start=$start&end=$end';
      if (orgId != null) {
        shiftUrl += '&orgId=$orgId';
      }
      
      final response = await http.get(Uri.parse(shiftUrl), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          if (mounted) {
            setState(() {
              _shifts = decoded;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shifts = [];
        });
      }
      // debugPrint('Error fetching shift data: $e');
    }
  }

  Future<void> _fetchAttendanceStatus(Map<String, String> headers, String? orgId) async {
    if (orgId == null || _currentEmployeeId == null) {
      if (mounted) {
        setState(() => _attendanceStatus = {'isScheduled': false, 'status': 'No Data'});
      }
      return;
    }

    try {
      String url = '${ApiConfig.attendanceStatus}?employeeId=$_currentEmployeeId&orgId=$orgId';
      
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _attendanceStatus = decoded;
          });
        }
      }
    } catch (e) {
      // debugPrint('Error fetching attendance status: $e');
      if (mounted) {
        setState(() => _attendanceStatus = {'isScheduled': false, 'status': 'Error'});
      }
    }
  }

  Future<void> _fetchEmployeeData(Map<String, String> headers, String? orgId) async {
    if (orgId == null) return;

    try {
      String url = '${ApiConfig.employees}?organizationId=$orgId';
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final authState = ref.read(authProvider);
          final user = authState.user;
          final userEmail = user?.email.toLowerCase();
          final userId = user?.id.toString();
          
          // 1. Resolve My Employee Record (Email or ID match as per React code)
          final me = decoded.firstWhere(
            (e) => (e['email']?.toString().toLowerCase() == userEmail || 
                    e['userId']?.toString() == userId),
            orElse: () => null,
          );

          if (me != null) {
            if (mounted) {
              setState(() {
                _myEmployeeData = me;
                _currentEmployeeId = me['id'];
              });
            }
          }

          // 2. Process Birthdays (This month)
          final now = DateTime.now();
          final bdays = decoded.where((e) {
            final dobRaw = e['dateOfBirth'];
            if (dobRaw == null) return false;
            try {
              final dob = DateTime.parse(dobRaw.toString());
              return dob.month == now.month;
            } catch(_) { return false; }
          }).map((e) {
            final dob = DateTime.parse(e['dateOfBirth'].toString());
            return {
              'name': e['name'],
              'date': DateFormat('MMM dd').format(dob),
              'isSelf': e['id'] == _currentEmployeeId
            };
          }).toList();

          if (mounted) {
            setState(() {
              _birthdays = bdays;
            });
          }
        }
      }
    } catch (e) {
      // debugPrint('Error fetching employee data: $e');
    }
  }

  Future<void> _fetchOrganizations(Map<String, String> headers) async {
    try {
      // Try /organizations first
      var response = await http.get(Uri.parse(ApiConfig.organizations), headers: headers);
      
      if (response.statusCode != 200) {
        // Fallback to /users/organizations
        response = await http.get(Uri.parse(ApiConfig.userOrganizations), headers: headers);
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final List<Map<String, dynamic>> fetchedOrgs = decoded.map((org) {
            if (org is Map<String, dynamic>) return org;
            return <String, dynamic>{'name': org.toString(), 'id': org.toString()};
          }).toList();

          if (mounted) {
            setState(() {
              _orgData = fetchedOrgs;
              if (_orgData.isNotEmpty) {
                _selectedOrgId = _orgData.first['id']?.toString();
              } else {
                _selectedOrgId = null;
              }
              _isLoadingOrgs = false;
            });
          }
        } else {
          if (mounted) {
            setState(() { _isLoadingOrgs = false; });
          }
        }
      } else {
        if (mounted) {
          setState(() { _isLoadingOrgs = false; });
        }
      }
    } catch (e) {
      // debugPrint('Error fetching organizations: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrgs = false;
          _orgData = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      final brightness = Theme.of(context).brightness;
      final isDark = brightness == Brightness.dark;
      
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            'Dashboard',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(
              CupertinoIcons.bars,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          trailing: _buildPunchButton(),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isLandscape = constraints.maxWidth > constraints.maxHeight;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    if (!isLandscape) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(child: DigitalClock()),
                          const SizedBox(width: 10),
                          _buildOrgSelector(),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      child: isLandscape 
                        ? _buildLandscapeLayout(user)
                        : _buildPortraitLayout(user),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildHeader(isLandscape),
              const SizedBox(height: 10),
              Expanded(
                child: isLandscape 
                  ? _buildLandscapeLayout(user)
                  : _buildPortraitLayout(user),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isLandscape) {
    return Column(
      children: [
        Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: Theme.of(context).iconTheme.color),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            _buildTimeWidget(),
          ],
        ),
        if (!isLandscape) const SizedBox(height: 10),
        if (!isLandscape)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _buildOrgSelector()),
              const SizedBox(width: 8),
              _buildPunchButton(),
            ],
          ),
      ],
    );
  }

  Widget _buildPunchButton() {
    final status = _attendanceStatus?['status'] ?? 'Loading...';
    final isScheduled = _attendanceStatus?['isScheduled'] ?? false;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    String label = 'Punch In';
    Color color = Colors.blueAccent;
    bool disabled = !isScheduled || status == 'Holiday' || status == 'NoShift' || status == 'ShiftCompleted' || status == 'Loading...';

    if (status == 'ReadyToPunchOut') {
      label = 'Punch Out';
      color = Colors.orange;
    } else if (status == 'ShiftCompleted') {
      label = 'Completed';
    }

    if (isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: color == Colors.blueAccent ? CupertinoColors.activeBlue : color,
        borderRadius: BorderRadius.circular(10),
        onPressed: disabled ? null : _handlePunch,
        minSize: 32,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ElevatedButton(
      onPressed: disabled ? null : _handlePunch,
      style: ElevatedButton.styleFrom(
        backgroundColor: color == Colors.blueAccent ? Theme.of(context).colorScheme.primary : color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Future<void> _handlePunch() async {
    if (_currentEmployeeId == null || _selectedOrgId == null) return;

    final authState = ref.read(authProvider);
    final token = authState.token;
    if (token == null) return;

    final status = _attendanceStatus?['status'];
    final isPunchIn = status == 'ReadyToPunchIn';
    final now = DateTime.now();
    
    final payload = {
      'employeeId': _currentEmployeeId,
      'organizationId': int.tryParse(_selectedOrgId!),
      'date': DateFormat('yyyy-MM-dd').format(now),
      'attendanceTypeId': 0, 
      'calculatedStatus': 'P',
      'isProcessed': false
    };

    if (isPunchIn) {
      payload['punchIn'] = now.toIso8601String();
    } else {
      payload['punchIn'] = _attendanceStatus?['punchInTime'];
      payload['punchOut'] = now.toIso8601String();
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.attendancePunch),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: isPunchIn ? 'Punched in successfully' : 'Punched out successfully',
          );
        }
        _loadDashboardData();
      }
    } catch (e) {
      // debugPrint('Punch error: $e');
    }
  }

  Widget _buildTimeWidget() {
    return const DigitalClock();
  }

  Widget _buildOrgSelector() {
    if (_isLoadingOrgs) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: 16, 
            height: 16, 
            child: Theme.of(context).platform == TargetPlatform.iOS
              ? const CupertinoActivityIndicator(radius: 8)
              : const CircularProgressIndicator(strokeWidth: 2)
          )
        ),
      );
    }

    if (_orgData.isEmpty) return const SizedBox();

    return OrgDropdown(
      value: _selectedOrgId,
      showLabel: true,
      isCompact: false,
      items: _orgData.map((org) => OrgDropdownItem(
        id: org['id']?.toString() ?? '',
        name: org['name']?.toString() ?? 'Unknown',
        logoUrl: org['logoUrl']?.toString(),
      )).toList(),
      onChanged: (String? newValue) async {
        if (newValue != null && newValue != _selectedOrgId) {
          final authNotifier = ref.read(authProvider.notifier);
          try {
            await authNotifier.switchOrganization(newValue);
            
            if (mounted) {
              setState(() {
                _selectedOrgId = newValue;
              });
            }
            
            await _loadDashboardData();
            
            if (mounted) {
              CustomSnackbar.show(
                context: context,
                message: 'Switched organization successfully',
              );
            }
          } catch (e) {
            if (mounted) {
              CustomSnackbar.show(
                context: context,
                message: 'Failed to switch: $e',
                isError: true,
              );
            }
          }
        }
      },
    );
  }

  Widget _buildPortraitLayout(dynamic user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileCard(user),
          const SizedBox(height: 20),
          _buildStatsGrid(crossAxisCount: 2),
          const SizedBox(height: 20),
          _buildBirthdays(),
          const SizedBox(height: 20),
          _buildShiftSchedule(),
          const SizedBox(height: 20),
          _buildTickets(),
          const SizedBox(height: 20),
          _buildWeekTimelogs(),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(dynamic user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileCard(user),
                const SizedBox(height: 20),
                _buildBirthdays(),
                const SizedBox(height: 20),
                _buildShiftSchedule(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatsGrid(crossAxisCount: 3),
                const SizedBox(height: 20),
                _buildWeekTimelogs(),
                const SizedBox(height: 20),
                _buildCalendarWidget(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Safe profile image rendering
  Widget _buildProfileCard(dynamic user) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(isIOS ? 20 : 16),
      child: Stack(
        children: [
          if (isIOS)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isIOS 
                ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7))
                : Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(isIOS ? 20 : 16),
              border: Border.all(
                color: isIOS 
                  ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
                  : Theme.of(context).dividerColor
              ),
              boxShadow: (Theme.of(context).brightness == Brightness.light && !isIOS)
                  ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _myEmployeeData?['profilePictureUrl'] != null && _myEmployeeData!['profilePictureUrl'].toString().isNotEmpty
                  ? Image.network(
                      ApiConfig.getFullImageUrl(_myEmployeeData!['profilePictureUrl'].toString()),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(isIOS),
                    )
                  : _buildDefaultAvatar(isIOS),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '—',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      user?.role ?? '—',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Designation: ${_myEmployeeData?['designation'] ?? '—'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProfileStat('Tasks', pendingTasks.toString()),
              _buildProfileStat('Projects', inProgressProjects.toString()),
              _buildProfileStat('Tickets', totalTickets.toString()),
            ],
          ),
        ],
      ),
    ),
  ],
),
);
}

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(bool isIOS) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.blueGrey,
      child: Icon(
        isIOS ? CupertinoIcons.person_fill : Icons.person, 
        color: Colors.white
      ),
    );
  }

  Widget _buildStatsGrid({required int crossAxisCount}) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: 1.4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildKPIContainer('Tasks', [
          {'val': pendingTasks, 'label': 'PENDING', 'color': Colors.blue},
          {'val': overdueTasks, 'label': 'OVERDUE', 'color': Colors.red},
        ]),
        _buildKPIContainer('Projects', [
          {'val': inProgressProjects, 'label': 'In Progress', 'color': Colors.blue},
          {'val': overdueProjects, 'label': 'Overdue', 'color': Colors.red},
        ]),
        _buildKPIContainer('Follow Ups', [
          {'val': pendingFollowUps, 'label': 'Pending', 'color': Colors.blue},
          {'val': upcomingFollowUps, 'label': 'Upcoming', 'color': Colors.green},
        ]),
        _buildKPIContainer('Deal', [
          {'val': totalDeals, 'label': 'Total Deals', 'color': Colors.blue},
          {'val': convertedDeals, 'label': 'Converted Deals', 'color': Colors.green},
        ]),
        _buildTickets(),
      ],
    );
  }

  Widget _buildKPIContainer(String title, List<Map<String, dynamic>> stats) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(isIOS ? 18 : 16),
      child: Stack(
        children: [
          if (isIOS)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIOS 
                ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7))
                : Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(isIOS ? 18 : 16),
              border: Border.all(
                color: isIOS 
                  ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
                  : Theme.of(context).dividerColor
              ),
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(title, style: TextStyle(color: Theme.of(context).textTheme.titleSmall?.color, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Icon(
                Theme.of(context).platform == TargetPlatform.iOS 
                  ? CupertinoIcons.ellipsis 
                  : Icons.more_horiz, 
                color: Theme.of(context).textTheme.bodySmall?.color, 
                size: 14
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stats.map((stat) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      stat['val'].toString(),
                      style: TextStyle(color: stat['color'], fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    stat['label'].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 8, letterSpacing: 0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    ),
  ],
),
);
}

  Widget _buildShiftSchedule() {
    final personalShifts = _shifts.where((shift) {
      if (shift is! Map) return false;
      return shift['employeeId'] == _currentEmployeeId;
    }).toList();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Icon(
                    Theme.of(context).platform == TargetPlatform.iOS 
                      ? CupertinoIcons.calendar 
                      : Icons.calendar_today, 
                    color: Theme.of(context).colorScheme.primary, 
                    size: 16
                  ),
                  const SizedBox(width: 8),
                  Text('Shift Schedule', style: TextStyle(color: Theme.of(context).textTheme.titleSmall?.color, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Employee Shift', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (personalShifts.isEmpty)
            _buildEmptyState(Icons.calendar_month_outlined, '- No record found. -')
          else
            ..._generateShiftRows(personalShifts),
        ],
      ),
    );
  }

  Widget _buildBirthdays() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.cake, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Text('Birthdays', style: TextStyle(color: Theme.of(context).textTheme.titleSmall?.color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          if (_birthdays.isEmpty)
            _buildEmptyState(Icons.cake_outlined, '- No record found. -')
          else
            ..._birthdays.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: b['isSelf'] == true ? Colors.pinkAccent : Theme.of(context).scaffoldBackgroundColor,
                    child: Text(
                      b['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['name']?.toString() ?? '—',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          b['date']?.toString() ?? '—',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (b['isSelf'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4)),
                      child: Text("It's you", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 8)),
                    ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildTickets() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tickets', style: TextStyle(color: Theme.of(context).textTheme.titleSmall?.color, fontWeight: FontWeight.bold)),
              const Icon(Icons.airplane_ticket_outlined, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 15),
          if (_tickets.isEmpty)
            _buildEmptyState(Icons.confirmation_number_outlined, '- No record found. -')
          else
            ..._tickets.map((t) => const SizedBox()).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).dividerColor, size: 40),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
        ],
      ),
    );
  }

  List<Widget> _generateShiftRows(List<dynamic> shifts) {
    // 1. Deduplicate identical records
    final seen = <String>{};
    final uniqueShifts = shifts.where((shift) {
      if (shift is! Map) return false;
      final key = '${shift['date']}_${shift['shiftName']}_${shift['startTime']}_${shift['endTime']}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    return uniqueShifts.map((shift) {
      final dateRaw = shift['date']?.toString() ?? '';
      DateTime? dt;
      try { dt = DateTime.parse(dateRaw); } catch(_) {}
      
      final dayStr = dt != null ? DateFormat('MMM dd').format(dt) : '---';
      final weekdayStr = dt != null ? DateFormat('EEEE').format(dt) : '---';
      final shiftName = shift['shiftName']?.toString() ?? 'Shift';
      final startTime = shift['startTime']?.toString() ?? '';
      final endTime = shift['endTime']?.toString() ?? '';
      final isOffDay = shift['isOffDay'] == true || shiftName.toLowerCase().contains('off');
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 45, child: Text(dayStr, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11))),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: Text(weekdayStr, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7), fontSize: 11))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isOffDay ? Colors.blueGrey.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shiftName,
                style: TextStyle(color: isOffDay ? Theme.of(context).textTheme.bodySmall?.color : Theme.of(context).colorScheme.primary, fontSize: 10),
              ),
            ),
            if (!isOffDay && startTime.isNotEmpty) ...[
              const SizedBox(width: 15),
              Text('$startTime - $endTime', style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildWeekTimelogs() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Week Timelogs', style: TextStyle(color: Theme.of(context).textTheme.titleSmall?.color, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Last This Week', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DayBubble(day: 'Su'),
              _DayBubble(day: 'Mo'),
              _DayBubble(day: 'Tu'),
              _DayBubble(day: 'We'),
              _DayBubble(day: 'Th'),
              _DayBubble(day: 'Fr'),
              _DayBubble(day: 'Sa'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.0, // 0 as requested
              child: Container(color: Colors.blue),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration: 0s', style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text('Break: 0s', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Theme.of(context).textTheme.bodySmall?.color, size: 40),
            const SizedBox(height: 10),
            Text('Calendar View', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            Text('Coming Soon', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


class _DayBubble extends StatelessWidget {
  final String day;
  final bool isActive;

  const _DayBubble({required this.day, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: isActive ? null : Border.all(color: Theme.of(context).dividerColor),
      ),
      alignment: Alignment.center,
      child: Text(
        day,
        style: TextStyle(
          color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
