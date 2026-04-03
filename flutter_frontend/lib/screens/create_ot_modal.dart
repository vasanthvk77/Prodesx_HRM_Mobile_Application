import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/ot_model.dart';
import '../providers/ot_provider.dart';
import '../providers/auth_provider.dart';
import '../core/api_config.dart';
import '../widgets/custom_snackbar.dart';

class CreateOTModal extends ConsumerStatefulWidget {
  final OvertimeRecord? editData;
  const CreateOTModal({super.key, this.editData});

  @override
  ConsumerState<CreateOTModal> createState() => _CreateOTModalState();
}

class _CreateOTModalState extends ConsumerState<CreateOTModal> {
  final _formKey = GlobalKey<FormState>();
  final _hoursCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedEmployee;
  List<Map<String, dynamic>> _employees = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _hoursCtrl.text = widget.editData!.hours.toString();
      _rateCtrl.text = widget.editData!.ratePerHour?.toString() ?? '';
      _remarksCtrl.text = widget.editData!.remarks ?? '';
      _selectedDate = widget.editData!.overDutyDate;
      _selectedEmployee = {
        'id': widget.editData!.employeeId,
        'name': widget.editData!.employeeName,
        'employeeCode': widget.editData!.employeeCode,
        'profilePictureUrl': widget.editData!.profilePictureUrl,
      };
    }
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    final state = ref.read(otProvider);
    if (state.employees.isNotEmpty) {
      setState(() {
        _employees = List<Map<String, dynamic>>.from(state.employees);
        if (widget.editData != null) {
          final emp = _employees.firstWhere((e) => e['id'] == widget.editData!.employeeId, orElse: () => _selectedEmployee!);
          _selectedEmployee = emp;
        }
      });
      return;
    }
    
    final orgId = state.selectedOrgId;
    if (orgId != null) {
      try {
        final res = await http.get(
          Uri.parse('${ApiConfig.employees}?orgId=$orgId'),
          headers: ref.read(authProvider).requestHeaders,
        );
        if (res.statusCode == 200) {
          final List data = json.decode(res.body);
          setState(() {
            _employees = List<Map<String, dynamic>>.from(data);
            if (widget.editData != null) {
              final emp = _employees.firstWhere((e) => e['id'] == widget.editData!.employeeId, orElse: () => _selectedEmployee!);
              _selectedEmployee = emp;
            }
          });
        }
      } catch (_) {}
    }
  }

  double get _computedAmount {
    final h = double.tryParse(_hoursCtrl.text) ?? 0;
    final r = double.tryParse(_rateCtrl.text) ?? 0;
    return h * r;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFF3182ce);

    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 10, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editData != null ? 'Edit Employee OT' : 'Add Employee OT',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  splashRadius: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Body ──────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Search
                    const Text('Staff Member *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    if (_selectedEmployee == null)
                      _buildEmployeeSearch(theme, isDark)
                    else
                      _buildEmployeePreview(theme, isDark, accent),

                    const SizedBox(height: 20),

                    // Date Selection
                    const Text('OT Date *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildDatePicker(context, theme, isDark),

                    const SizedBox(height: 20),

                    // Calculation Details
                    const Text('Calculation Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_hoursCtrl, 'Hours *', TextInputType.number, isDark, validator: (v) => v!.isEmpty ? 'Req' : null),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildTextField(_rateCtrl, 'Rate (₹/hr)', TextInputType.number, isDark),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Computed Amount Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Computed Amount:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            '₹${NumberFormat('#,##,###').format(_computedAmount)}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Remarks
                    const Text('Reason/Remarks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildTextField(_remarksCtrl, 'Type here...', TextInputType.multiline, isDark, maxLines: 3),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Record', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, TextInputType type, bool isDark, {int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      validator: validator,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3182ce), width: 1.5)),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (d != null) setState(() => _selectedDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13)),
            const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSearch(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () => _showEmployeePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 18, color: Colors.grey),
            SizedBox(width: 12),
            Text('Search & Select Employee...', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeePreview(ThemeData theme, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3), style: BorderStyle.solid), 
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withOpacity(0.1),
            backgroundImage: _selectedEmployee!['profilePictureUrl'] != null
                ? NetworkImage(ApiConfig.getFullImageUrl(_selectedEmployee!['profilePictureUrl']))
                : null,
            child: _selectedEmployee!['profilePictureUrl'] == null ? Text(_selectedEmployee!['name']?[0] ?? '?', style: TextStyle(color: accent, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedEmployee!['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF3182ce))),
                const SizedBox(height: 2),
                Text('${_selectedEmployee!['employeeCode']} • ${_selectedEmployee!['designation'] ?? 'Staff'}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                  child: Text(_selectedEmployee!['department'] ?? 'Staff', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ),
          ),
          if (widget.editData == null)
            IconButton(
              onPressed: () => setState(() => _selectedEmployee = null), 
              icon: const Icon(Icons.close, size: 16),
              splashRadius: 20,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  void _showEmployeePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeePicker(
        employees: _employees,
        onSelect: (emp) {
          setState(() => _selectedEmployee = emp);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _selectedEmployee == null) {
      CustomSnackbar.show(context: context, message: 'Select employee and fill all fields', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final user = ref.read(authProvider).user;
    if (user != null) {
      final payload = {
        'organizationId': ref.read(otProvider).selectedOrgId,
        'employeeId': _selectedEmployee!['id'],
        'overDutyDate': _selectedDate.toIso8601String(),
        'hours': double.parse(_hoursCtrl.text),
        'ratePerHour': double.tryParse(_rateCtrl.text),
        'remarks': _remarksCtrl.text,
        if (widget.editData != null) 'overDutyId': widget.editData!.overDutyId,
      };

      final success = widget.editData != null
          ? await ref.read(otProvider.notifier).updateOT(payload)
          : await ref.read(otProvider.notifier).saveOT(payload);

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          CustomSnackbar.show(context: context, message: 'Record saved successfully');
        }
      } else {
        if (mounted) {
          CustomSnackbar.show(context: context, message: 'Failed to save record', isError: true);
        }
      }
    }
    setState(() => _isSaving = false);
  }
}

class _EmployeePicker extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final Function(Map<String, dynamic>) onSelect;

  const _EmployeePicker({required this.employees, required this.onSelect});

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  late List<Map<String, dynamic>> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.employees;
  }

  void _filter(String q) {
    setState(() {
      _filtered = widget.employees.where((e) {
        final name = (e['name'] ?? '').toLowerCase();
        final code = (e['organization_Employee_id'] ?? e['employeeCode'] ?? '').toLowerCase();
        return name.contains(q.toLowerCase()) || code.contains(q.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search Employee Name or ID',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, i) {
                final e = _filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  leading: CircleAvatar(
                    backgroundImage: e['profilePictureUrl'] != null
                        ? NetworkImage(ApiConfig.getFullImageUrl(e['profilePictureUrl']))
                        : null,
                    child: e['profilePictureUrl'] == null ? Text(e['name']?[0] ?? '?', style: const TextStyle(fontSize: 12)) : null,
                  ),
                  title: Text(e['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(e['employeeCode'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () => widget.onSelect(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
