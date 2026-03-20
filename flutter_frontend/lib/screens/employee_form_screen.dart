import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/designation.dart';
import '../models/department.dart';
import '../repositories/employee_repository.dart';
import '../repositories/designation_repository.dart';
import '../repositories/department_repository.dart';
import '../core/api_config.dart';
import '../widgets/custom_snackbar.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final Employee? employee;
  final int? organizationId;
  final String? organizationName;

  const EmployeeFormScreen({super.key, this.employee, this.organizationId, this.organizationName});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Data
  List<EmployeeField> _fields = [];
  List<Designation> _designations = [];
  List<Department> _departments = [];
  
  // Form Values
  final Map<String, dynamic> _values = {};
  XFile? _profileImage;
  XFile? _signatureImage;
  Uint8List? _profileImageBytes;
  Uint8List? _signatureImageBytes;
  String? _profileImageUrl;
  String? _signatureImageUrl;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);
    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      final desigRepo = ref.read(designationRepositoryProvider);
      final deptRepo = ref.read(departmentRepositoryProvider);

      final fields = await empRepo.getFormFields(widget.organizationId);
      _fields = fields;

      if (widget.organizationId != null) {
        final results = await Future.wait([
          desigRepo.getDesignations(widget.organizationId),
          deptRepo.getDepartments(widget.organizationId!),
        ]);
        _designations = results[0] as List<Designation>;
        _departments = results[1] as List<Department>;
      }

      // Initialize values from employee if editing
      if (widget.employee != null) {
        final emp = widget.employee!;
        _values['name'] = emp.name;
        _values['email'] = emp.email;
        _values['employeeCode'] = emp.employeeCode;
        _values['salutation'] = emp.salutation;
        _values['designation'] = emp.designation;
        _values['designationId'] = emp.designationId;
        _values['department'] = emp.department;
        _values['departmentId'] = emp.departmentId;
        _values['gender'] = emp.gender;
        _values['mobile'] = emp.mobile;
        _values['joiningDate'] = emp.joiningDate;
        _values['dateOfBirth'] = emp.dateOfBirth;
        _values['fatherOrSpouse'] = emp.fatherOrSpouse;
        _values['presentAddress'] = emp.presentAddress;
        _values['permanentAddress'] = emp.permanentAddress;
        _values['employeePfNo'] = emp.employeePfNo;
        _values['employeeEsicNo'] = emp.employeeEsicNo;
        _values['employeeAadharNo'] = emp.employeeAadharNo;
        _values['days80ServiceCompletionDate'] = emp.days80ServiceCompletionDate;
        _values['permanentAppointmentDate'] = emp.permanentAppointmentDate;
        _values['periodOfSuspension'] = emp.periodOfSuspension?.toString();
        _values['dateOfExit'] = emp.dateOfExit;
        _values['reasonForExit'] = emp.reasonForExit;
        _values['remarks'] = emp.remarks;
        _values['status'] = emp.status;

        _profileImageUrl = emp.profilePictureUrl;
        _signatureImageUrl = emp.signatureImageUrl;

        try {
          final bankDetails = await empRepo.getBankDetails(emp.id);
          if (bankDetails != null) {
            _values['accountNumber'] = bankDetails.accountNumber?.toString();
            _values['bankName'] = bankDetails.accountHolderName;
            _values['branchName'] = bankDetails.branch;
            _values['ifscCode'] = bankDetails.ifsc;
          }
        } catch (e) {
          debugPrint('Failed to load bank details: $e');
        }

        // Load custom fields
        _values.addAll(emp.customFields);
      } else {
        // Defaults for new employee
        _values['status'] = 'Active';
      }

    } catch (e) {
      CustomSnackbar.show(context: context, message: 'Error loading form: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackbar.show(context: context, message: 'Please fill in all mandatory fields', isError: true);
      return;
    }
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      final coreFieldKeys = {
        'employeeCode', 'salutation', 'name', 'email', 'designation', 'designationId', 
        'gender', 'mobile', 'joiningDate', 'dateOfBirth', 'profilePictureUrl', 
        'fatherOrSpouse', 'presentAddress', 'permanentAddress', 'employeePfNo', 
        'employeeEsicNo', 'employeeAadharNo', 'days80ServiceCompletionDate', 
        'permanentAppointmentDate', 'periodOfSuspension', 'signatureImageUrl', 
        'thumbImpressionImageUrl', 'dateOfExit', 'reasonForExit', 'department', 
        'departmentId', 'remarks', 'status'
      };

      final bankFieldKeys = _fields.where((f) => f.sectionName == 'Bank Account Details').map((f) => f.fieldKey).toSet();
      
      final Map<String, dynamic> payload = {
        'organizationId': widget.organizationId,
      };

      final Map<String, dynamic> customFs = {};
      final Map<String, dynamic> bankPayload = {
        'organizationId': widget.organizationId,
      };

      _values.forEach((key, value) {
        if (bankFieldKeys.contains(key)) {
           if (key == 'accountNumber') bankPayload['accountNumber'] = int.tryParse(value.toString());
           else if (key == 'bankName') bankPayload['accountHolderName'] = value.toString();
           else if (key == 'branchName') bankPayload['branch'] = value.toString();
           else if (key == 'ifscCode') bankPayload['ifsc'] = value.toString();
           else bankPayload[key] = value;
        } else if (coreFieldKeys.contains(key)) {
          if (value is DateTime) {
            payload[key] = value.toIso8601String();
          } else {
            if (key == 'periodOfSuspension') payload[key] = int.tryParse(value.toString());
            else payload[key] = value;
          }
        } else {
          customFs[key] = value;
        }
      });

      payload['customFieldsJson'] = customFs.isNotEmpty ? jsonEncode(customFs) : null;

      int currentId;
      if (widget.employee == null) {
        currentId = await empRepo.createEmployee(payload);
      } else {
        currentId = widget.employee!.id;
        await empRepo.updateEmployee(currentId, payload);
      }

      // Handle bank details explicitly
      if (bankPayload.length > 1 && currentId > 0) {
        await empRepo.saveBankDetails(currentId, bankPayload);
      }

      // Handle File Uploads
      if (_profileImage != null && currentId > 0) await empRepo.uploadPhoto(currentId, _profileImage!);
      if (_signatureImage != null && currentId > 0) await empRepo.uploadSignature(currentId, _signatureImage!);

      if (mounted) {
        CustomSnackbar.show(context: context, message: widget.employee != null ? 'Employee updated successfully!' : 'Employee added successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      CustomSnackbar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    final sections = <String, List<EmployeeField>>{};
    for (var field in _fields.where((f) => f.isVisible)) {
      sections.putIfAbsent(field.sectionName, () => []).add(field);
    }
    
    final sortedSectionNames = sections.keys.toList()..sort((a, b) {
      final orderA = sections[a]!.first.sectionOrder;
      final orderB = sections[b]!.first.sectionOrder;
      return orderA.compareTo(orderB);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employee == null ? 'New Employee Registration' : 'Edit Employee Profile', 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
            if (widget.organizationName != null)
              Text(widget.organizationName!, 
                style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))))
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                child: const Text('SAVE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sortedSectionNames.map((sectionName) => _buildSection(sectionName, sections[sectionName]!, constraints)),
                  const SizedBox(height: 16),
                  _buildSignatureSection(),
                  const SizedBox(height: 48),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<EmployeeField> fields, BoxConstraints constraints) {
    fields.sort((a, b) => a.fieldOrder.compareTo(b.fieldOrder));
    final isPersonalInfo = title == 'Personal Information';
    final isLargeScreen = constraints.maxWidth > 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getSectionIcon(title),
              const SizedBox(width: 10),
              Text(title.toUpperCase(), 
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 20),
          if (isPersonalInfo && isLargeScreen)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildFieldsGrid(fields, constraints),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 140,
                  child: _buildImageSection(),
                ),
              ],
            )
          else if (isPersonalInfo)
            Column(
              children: [
                _buildImageSection(),
                const SizedBox(height: 24),
                _buildFieldsGrid(fields, constraints),
              ],
            )
          else
            _buildFieldsGrid(fields, constraints),
        ],
      ),
    );
  }

  Widget _getSectionIcon(String title) {
    IconData icon;
    switch (title) {
      case 'Personal Information': icon = Icons.person; break;
      case 'Bank Account Details': icon = Icons.credit_card; break;
      case 'Contact Info': icon = Icons.phone; break;
      case 'Exit Details & Remarks': icon = Icons.logout; break;
      default: icon = Icons.settings;
    }
    return Icon(icon, color: Colors.blue, size: 18);
  }

  Widget _buildFieldsGrid(List<EmployeeField> fields, BoxConstraints constraints) {
    final isLargeScreen = constraints.maxWidth > 600;
    
    if (!isLargeScreen) {
      return Column(
        children: fields.map((f) => _buildField(f)).toList(),
      );
    }

    // Grid-like layout for large screens
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildField(fields[i])),
              const SizedBox(width: 16),
              if (i + 1 < fields.length)
                Expanded(child: _buildField(fields[i + 1]))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        )
      );
    }
    return Column(children: rows);
  }

  Widget _buildField(EmployeeField field) {
    Widget input;

    switch (field.componentType) {
      case 'dropdown':
      case 'select':
        input = _buildDropdownField(field);
        break;
      case 'date':
        input = _buildDateField(field);
        break;
      case 'textarea':
        input = _buildTextField(field, maxLines: 3);
        break;
      default:
        input = _buildTextField(field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: field.displayLabel,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                    children: [
                      if (field.isMandatory)
                        const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (field.fieldKey == 'permanentAddress')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24, width: 24,
                      child: Checkbox(
                        value: _values['presentAddress'] != null && _values['permanentAddress'] == _values['presentAddress'],
                        onChanged: (val) {
                          setState(() {
                            if (val == true && _values['presentAddress'] != null) {
                              _values['permanentAddress'] = _values['presentAddress'];
                            } else {
                              _values['permanentAddress'] = '';
                            }
                          });
                        },
                        activeColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Same as Present', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ),
        input,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTextField(EmployeeField field, {int maxLines = 1}) {
    if (field.fieldKey == 'permanentAddress') {
        final initial = _values[field.fieldKey]?.toString() ?? '';
        return TextFormField(
          key: ValueKey('perm_addr_${initial.hashCode}'),
          initialValue: initial,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: maxLines,
          decoration: _inputDecoration(field.displayLabel),
          validator: (val) => field.isMandatory && (val == null || val.trim().isEmpty) ? '${field.displayLabel} is required' : null,
          onSaved: (val) => _values[field.fieldKey] = val,
          onChanged: (val) => _values[field.fieldKey] = val,
        );
    }
    return TextFormField(
      initialValue: _values[field.fieldKey]?.toString(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      decoration: _inputDecoration(field.displayLabel),
      validator: (val) {
        if (field.isMandatory && (val == null || val.trim().isEmpty)) return '${field.displayLabel} is required';
        if (val != null && val.trim().isNotEmpty) {
           if (field.fieldKey == 'email') {
              if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$").hasMatch(val)) return 'Please enter a valid email address.';
           } else if (field.fieldKey == 'mobile') {
              if (!RegExp(r"^\+?[1-9]\d{1,14}$").hasMatch(val)) return 'Please enter a valid mobile number (10-15 digits).';
           } else if (field.fieldKey == 'employeePfNo') {
              if (!RegExp(r"^[A-Z]{2}[A-Z]{3}[0-9]{7}[0-9]{3}[0-9]{7}$").hasMatch(val)) return 'Please enter a valid PF number (e.g., APBOM00000000000000000).';
           } else if (field.fieldKey == 'employeeEsicNo') {
              if (!RegExp(r"^[0-9]{17}$").hasMatch(val)) return 'Please enter a valid ESIC number (exact 17 digits).';
           } else if (field.fieldKey == 'employeeAadharNo') {
              if (!RegExp(r"^\d{4}\s?\d{4}\s?\d{4}$").hasMatch(val)) return 'Please enter a valid Aadhar number (12 digits).';
           } else if (field.fieldKey == 'ifscCode') {
              if (!RegExp(r"^[A-Z]{4}0[A-Z0-9]{6}$").hasMatch(val)) return 'Please enter a valid IFSC code (e.g., SBIN0000001).';
           } else if (field.fieldKey == 'accountNumber') {
              if (!RegExp(r"^\d{9,18}$").hasMatch(val)) return 'Please enter a valid account number (9-18 digits).';
           } else if (field.fieldKey == 'periodOfSuspension') {
             if (int.tryParse(val) == null) return 'Must be a valid number.';
           }
        }
        return null;
      },
      onSaved: (val) => _values[field.fieldKey] = val,
      onChanged: (val) => _values[field.fieldKey] = val,
    );
  }

  Widget _buildDropdownField(EmployeeField field) {
    List<DropdownMenuItem<dynamic>> items = [];
    
    if (field.fieldKey == 'designationId' || field.fieldKey == 'designation') {
      items = _designations.map((d) => DropdownMenuItem(value: d.designationName, child: Text(d.designationName, style: const TextStyle(fontSize: 14)))).toList();
    } else if (field.fieldKey == 'departmentId' || field.fieldKey == 'department') {
      items = _departments.map((d) => DropdownMenuItem(value: d.departmentName, child: Text(d.departmentName, style: const TextStyle(fontSize: 14)))).toList();
    } else if (field.fieldKey == 'salutation') {
      items = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList();
    } else if (field.fieldKey == 'gender') {
      items = ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14)))).toList();
    } else if (field.options != null) {
      items = field.options!.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList();
    }

    return DropdownButtonFormField<dynamic>(
      value: _values[field.fieldKey],
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _inputDecoration(field.displayLabel),
      items: items,
      onChanged: (val) => setState(() => _values[field.fieldKey] = val),
      validator: (val) => field.isMandatory && (val == null || val.toString().trim().isEmpty) ? '${field.displayLabel} is required' : null,
    );
  }

  Widget _buildDateField(EmployeeField field) {
    final dynamic rawVal = _values[field.fieldKey];
    DateTime? currentVal;
    if (rawVal is DateTime) {
      currentVal = rawVal;
    } else if (rawVal is String) {
      currentVal = DateTime.tryParse(rawVal);
    }
    
    final String labelText = currentVal != null ? DateFormat('yyyy-MM-dd').format(currentVal) : 'Select Date';

    return FormField<DateTime>(
      initialValue: currentVal,
      validator: (val) => field.isMandatory && currentVal == null ? '${field.displayLabel} is required' : null,
      builder: (state) {
        return InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: currentVal ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              builder: (context, child) => Theme(data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Colors.blue, onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white),
                dialogBackgroundColor: const Color(0xFF0F172A),
              ), child: child!),
            );
            if (date != null) {
              setState(() => _values[field.fieldKey] = date);
              state.didChange(date);
            }
          },
          child: InputDecorator(
            decoration: _inputDecoration(field.displayLabel).copyWith(errorText: state.errorText),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(labelText, style: TextStyle(color: currentVal != null ? Colors.white : Colors.white38, fontSize: 14)),
                const Icon(Icons.calendar_today, size: 16, color: Colors.white38),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 2),
                image: _profileImageBytes != null 
                    ? DecorationImage(image: MemoryImage(_profileImageBytes!), fit: BoxFit.cover) 
                    : (_profileImageUrl != null ? DecorationImage(image: NetworkImage(ApiConfig.getFullImageUrl(_profileImageUrl!)), fit: BoxFit.cover) : null),
              ),
              child: (_profileImageBytes == null && _profileImageUrl == null) 
                  ? const Icon(Icons.person, size: 50, color: Colors.white24) 
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  onPressed: _pickProfileImage,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Profile Photo', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_edu, color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Text('SIGNATURE / THUMB IMPRESSION', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: InkWell(
              onTap: _pickSignatureImage,
              borderRadius: BorderRadius.circular(12),
              child: _signatureImageBytes != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_signatureImageBytes!, fit: BoxFit.contain)) 
                  : (_signatureImageUrl != null 
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(ApiConfig.getFullImageUrl(_signatureImageUrl!), fit: BoxFit.contain)) 
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.upload_file, color: Colors.white24, size: 28),
                            SizedBox(height: 8),
                            Text('Tap to upload signature', style: TextStyle(color: Colors.white24, fontSize: 13))
                          ]
                        )),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      hintText: 'Enter $label',
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _profileImage = image;
        _profileImageBytes = bytes;
      });
    }
  }

  Future<void> _pickSignatureImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _signatureImage = image;
        _signatureImageBytes = bytes;
      });
    }
  }
}
