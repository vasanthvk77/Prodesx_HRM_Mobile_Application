import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/manage_users.dart';

import '../providers/auth_provider.dart';
import '../repositories/manage_users.dart';
import '../widgets/org_dropdown.dart';

/// A professional and clean version of the Create User popup.
/// Includes Logo Upload UI for organization creation to match JSX reference.
class CreateUserPopup extends ConsumerStatefulWidget {
  final VoidCallback onUserCreated;

  const CreateUserPopup({super.key, required this.onUserCreated});

  @override
  ConsumerState<CreateUserPopup> createState() => _CreateUserPopupState();
}

class _CreateUserPopupState extends ConsumerState<CreateUserPopup> {
  // Form keys and Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Selected values for dropdowns
  UserRole? _selectedRole;
  UserOrganization? _selectedOrg;

  // New Organization Panel State
  bool _showAddOrgPanel = false;
  final _orgNameController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgAddressController = TextEditingController();
  bool _isSavingOrg = false;
  
  // Note: Logo handling using image_picker.
  XFile? _selectedLogo; 

  // Loading and Notification states
  bool _isLoading = false;
  List<UserRole> _roles = [];
  List<UserOrganization> _organizations = [];
  String? _statusMessage;
  Color _statusColor = Colors.redAccent;


  // Colors based on the target design
  static const Color bgColor = Color(0xFF0F172A); // Rich Navy
  static const Color fieldBgColor = Color(0xFF1E293B); // Slate 800
  static const Color labelColor = Color(0xFF94A3B8); // Slate 400
  static const Color primaryBlue = Color(0xFF3B82F6); // Premium Blue

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;

      final repo = ManageUsersRepository(token: token);
      final results = await Future.wait([
        repo.getRoles(),
        repo.getOrganizations(),
      ]);

      setState(() {
        _roles = results[0] as List<UserRole>;
        _organizations = results[1] as List<UserOrganization>;
        
        final myRole = ref.read(authProvider).user?.role;
        if (myRole != 'SuperAdmin') {
          _roles = _roles.where((r) => r.roleName == 'User').toList();
        }

        if (_roles.isNotEmpty) _selectedRole = _roles.first;
        if (_organizations.isNotEmpty) _selectedOrg = _organizations.first;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _showToast("Failed to load roles or organizations.", isError: true);
        setState(() => _isLoading = false);
      }

    }
  }

  Future<void> _handleCreateUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrg == null || _selectedRole == null) {
      _showToast('Please select organization and role', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      final repo = ManageUsersRepository(token: token!);

      final error = await repo.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        roleName: _selectedRole!.roleName,
        organizationId: _selectedOrg!.id,
      );

      if (error == null) {
        widget.onUserCreated();
        if (mounted) Navigator.of(context).pop();
        // Since we are popping, we don't need to show success toast here, 
        // the parent screen should handle it or we can show it before pop.
      } else {
        _showToast(error, isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showToast("An unexpected error occurred.", isError: true);
      setState(() => _isLoading = false);
    }

  }

  Future<void> _handleCreateOrg() async {
    if (_orgNameController.text.isEmpty) {
      _showToast("Organization name is required", isError: true);
      return;
    }

    setState(() => _isSavingOrg = true);
    try {
      final token = ref.read(authProvider).token;
      final repo = ManageUsersRepository(token: token!);

      final newOrg = await repo.createOrganization(
        name: _orgNameController.text.trim(),
        email: _orgEmailController.text.trim(),
        phone: _orgPhoneController.text.trim(),
        address: _orgAddressController.text.trim(),
        logo: _selectedLogo,
      );

      setState(() {
        _organizations.add(newOrg);
        _selectedOrg = newOrg;
        _showAddOrgPanel = false;
        _isSavingOrg = false;
        _selectedLogo = null;
        _orgNameController.clear();
        _orgEmailController.clear();
        _orgPhoneController.clear();
        _orgAddressController.clear();
      });
      _showToast("Organization created!");
    } catch (e) {
      setState(() => _isSavingOrg = false);
      _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedLogo = image);
      }
    } catch (e) {
      _showToast("Failed to pick image", isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {

    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusColor = isError ? Colors.redAccent : Colors.greenAccent.shade400;
    });
    
    // Auto-clear after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }


  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = ref.watch(authProvider).user?.role == 'SuperAdmin';

    return Dialog(
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading && _roles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3)),
                        )
                      else ...[
                        _buildLabel("Full Name", isRequired: true),
                        _buildTextField(
                          controller: _nameController,
                          hint: "e.g. John Smith",
                          validator: (v) => v!.isEmpty ? "Full Name is required" : null,
                        ),
                        const SizedBox(height: 12),

                        _buildLabel("Email Address", isRequired: true),
                        _buildTextField(
                          controller: _emailController,
                          hint: "john@company.com",
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.isEmpty) return "Email Address is required";
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return "Invalid email format";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildLabel("Password", isRequired: true),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "Min. 6 characters",
                          isPassword: true,
                          validator: (v) => v!.length < 6 ? "Must be at least 6 characters" : null,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Role"),
                                  _buildDropdown<UserRole>(
                                    value: _selectedRole,
                                    items: _roles,
                                    onChanged: (val) => setState(() => _selectedRole = val),
                                    itemBuilder: (role) => Text(role.roleName),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildLabel("Organization", isRequired: true),
                                      if (isSuperAdmin) 
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: _buildAddBtn(),
                                        ),
                                    ],
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: OrgDropdown(
                                      value: _selectedOrg?.id.toString(),
                                      items: _organizations.map((org) => OrgDropdownItem(
                                        id: org.id.toString(),
                                        name: org.name,
                                        logoUrl: org.logoUrl,
                                      )).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedOrg = _organizations.firstWhere((o) => o.id.toString() == val);
                                          });
                                        }
                                      },
                                      isCompact: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        if (_showAddOrgPanel) _buildAddOrgPanel(),

                        if (_statusMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _statusColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _statusColor == Colors.redAccent ? Icons.error_outline : Icons.check_circle_outline,
                                  color: _statusColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _statusMessage = null),
                                  icon: Icon(Icons.close, color: _statusColor, size: 14),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add_outlined, color: primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Create New User",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "Fill in details and assign organization access",
                  style: TextStyle(color: labelColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: labelColor, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text("Cancel", style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleCreateUser,
            icon: _isLoading 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add_outlined, size: 15),
            label: Text(_isLoading ? "Creating..." : "Create User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          children: [
            if (isRequired)
              const TextSpan(text: " *", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        filled: true,
        fillColor: fieldBgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 1),
        ),
        errorStyle: const TextStyle(fontSize: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required Widget Function(T) itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 36,
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: fieldBgColor,
          icon: const Icon(Icons.expand_more, color: labelColor, size: 18),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                child: itemBuilder(item),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAddBtn() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showAddOrgPanel = !_showAddOrgPanel),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _showAddOrgPanel ? primaryBlue.withOpacity(0.1) : fieldBgColor,
            border: Border.all(color: _showAddOrgPanel ? primaryBlue : Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _showAddOrgPanel ? Icons.remove : Icons.add,
            size: 18,
            color: _showAddOrgPanel ? primaryBlue : labelColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAddOrgPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "NEW ORGANIZATION",
            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),

          const SizedBox(height: 12),
          _buildTextField(controller: _orgNameController, hint: "Name *"),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField(controller: _orgEmailController, hint: "Email", keyboardType: TextInputType.emailAddress)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(controller: _orgPhoneController, hint: "Phone", keyboardType: TextInputType.phone)),
            ],
          ),
          const SizedBox(height: 12),
          
          // --- LOGO UPLOAD SECTION (Visual Only for now) ---
          _buildLogoUploadSection(),
          
          const SizedBox(height: 12),
          _buildTextField(controller: _orgAddressController, hint: "Address"),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showAddOrgPanel = false),
                child: const Text("Cancel", style: TextStyle(color: labelColor, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSavingOrg ? null : _handleCreateOrg,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue, width: 1),
                  elevation: 0,
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _isSavingOrg 
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))
                    : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _selectedLogo != null
                ? Image.file(File(_selectedLogo!.path), fit: BoxFit.cover)
                : const Icon(Icons.business_outlined, color: labelColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedLogo != null ? "Logo selected" : "Organization Logo (Optional)",
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _pickImage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_outlined, color: primaryBlue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _selectedLogo != null ? "Change Logo" : "Choose File",
                        style: const TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedLogo != null)
            IconButton(
              onPressed: () => setState(() => _selectedLogo = null),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

}
