import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../repositories/organization_repository.dart';
import '../widgets/custom_snackbar.dart';
import '../providers/navigation_provider.dart';

import '../models/organization.dart';

class OrganizationCreationScreen extends ConsumerStatefulWidget {
  final Organization? organization;
  final VoidCallback? onSuccess;

  const OrganizationCreationScreen({
    super.key,
    this.organization,
    this.onSuccess,
  });

  @override
  ConsumerState<OrganizationCreationScreen> createState() => _OrganizationCreationScreenState();
}

class _OrganizationCreationScreenState extends ConsumerState<OrganizationCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');

  bool _isSaving = false;
  bool _isFetchingLocation = false;

  // Dummy switches as requested
  bool _enableQR = false;
  bool _enableFace = true;
  bool _enableGeofencing = true;
  bool _enableOffline = false;

  @override
  void initState() {
    super.initState();
    if (widget.organization != null) {
      final org = widget.organization!;
      _nameController.text = org.name;
      _emailController.text = org.email ?? '';
      _phoneController.text = org.phone ?? '';
      _addressController.text = org.address ?? '';
      _latController.text = org.latitude?.toString() ?? '';
      _lngController.text = org.longitude?.toString() ?? '';
      _radiusController.text = org.allowedRadius.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
        if (mounted) {
          CustomSnackbar.show(context: context, message: 'Location fetched successfully');
        }
      } else {
        if (mounted) {
          CustomSnackbar.show(context: context, message: 'Location permission denied', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error fetching location: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _goBack() {
    ref.read(navigationProvider.notifier).setDashboardContent(null);
  }

  Future<void> _saveOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.organization != null) {
        // Update existing
        await ref.read(organizationRepositoryProvider).updateOrganization(
          id: widget.organization!.id,
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          latitude: double.tryParse(_latController.text),
          longitude: double.tryParse(_lngController.text),
          allowedRadius: int.tryParse(_radiusController.text),
        );
      } else {
        // Create new
        await ref.read(organizationRepositoryProvider).createOrganization(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          latitude: double.tryParse(_latController.text),
          longitude: double.tryParse(_lngController.text),
          allowedRadius: int.tryParse(_radiusController.text),
        );
      }

      if (mounted) {
        CustomSnackbar.show(
          context: context, 
          message: widget.organization != null ? 'Organization updated successfully' : 'Organization created successfully'
        );
        if (widget.onSuccess != null) widget.onSuccess!();
        _goBack();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text(
          widget.organization != null ? 'Edit Organisation' : 'Add New Organisation', 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _goBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('General Information'),
              const SizedBox(height: 16),
              _buildTextField(_nameController, 'Organisation Name *', Icons.business, validator: (v) => v!.isEmpty ? 'Name is required' : null),
              _buildTextField(_emailController, 'Official Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildTextField(_addressController, 'Primary Address', Icons.location_on_outlined, maxLines: 2),
              
              const SizedBox(height: 32),
              _buildSectionTitle('Attendance Policy'),
              const SizedBox(height: 8),
              _buildDummySwitch('Enable QR Scanner', _enableQR, (v) => setState(() => _enableQR = v)),
              _buildDummySwitch('Enable Face Attendance', _enableFace, (v) => setState(() => _enableFace = v)),
              _buildDummySwitch('Enable Geofencing', _enableGeofencing, (v) => setState(() => _enableGeofencing = v)),
              _buildDummySwitch('Enable Offline Mode', _enableOffline, (v) => setState(() => _enableOffline = v)),

              const SizedBox(height: 32),
              _buildSectionTitle('Geofencing Configuration'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_latController, 'Latitude', Icons.location_searching, isCompact: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_lngController, 'Longitude', Icons.location_searching, isCompact: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_radiusController, 'Allowed Radius (Meters)', Icons.radar_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isFetchingLocation ? null : _getCurrentLocation,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFetchingLocation)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                            else
                              const Icon(Icons.add_location_alt_outlined, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            const Text(
                              'Get Current Location',
                              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _goBack,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveOrganization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        shadowColor: Colors.blueAccent.withOpacity(0.3),
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.blueAccent,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isCompact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 0 : 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.withOpacity(0.7)),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDummySwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blueAccent,
      inactiveTrackColor: Colors.grey.withOpacity(0.2),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
